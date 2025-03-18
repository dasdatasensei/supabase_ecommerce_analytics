"""
Ecommerce Analytics Pipeline DAG
--------------------------------
This DAG orchestrates the entire analytics workflow:
1. Extracts data from Supabase
2. Runs dbt models in the correct order
3. Refreshes Metabase dashboards

This is a production-ready implementation with proper error handling,
logging, and retry mechanisms.

Author: Dr. Jody-Ann S. Jones
Last Modified: March 18, 2025
Repository: https://github.com/dasdatasensei/supabase_ecommerce_analytics.git
"""

import os
from datetime import datetime, timedelta
import json
import logging
import traceback
from typing import Dict, Any, Optional, List

from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator
from airflow.providers.http.operators.http import SimpleHttpOperator
from airflow.models import Variable
from airflow.utils.trigger_rule import TriggerRule
import requests
import httpx
import psycopg2
from psycopg2 import sql
from psycopg2.extras import RealDictCursor

# Configure logging with more detailed format
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)

# Default arguments for the DAG
default_args = {
    "owner": "data_team",
    "depends_on_past": False,
    "email": ["analytics@example.com"],
    "email_on_failure": True,
    "email_on_retry": False,
    "retries": 3,
    "retry_delay": timedelta(minutes=5),
    "retry_exponential_backoff": True,
    "max_retry_delay": timedelta(minutes=60),
    "start_date": datetime(2023, 1, 1),
}


# Create a connection wrapper to standardize database operations and error handling
class DatabaseConnectionManager:
    """Manages database connections with proper error handling."""

    def __init__(self, conn_params: Dict[str, Any]):
        """
        Initialize with connection parameters.

        Args:
            conn_params: Dictionary with database connection parameters
        """
        self.conn_params = conn_params
        self.conn = None
        self.cursor = None

    def __enter__(self):
        """Context manager entry point - establishes connection."""
        try:
            self.conn = psycopg2.connect(**self.conn_params)
            self.cursor = self.conn.cursor(cursor_factory=RealDictCursor)
            return self.cursor
        except psycopg2.Error as e:
            logger.error(f"Database connection error: {e}")
            raise

    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit point - closes connection."""
        if self.cursor:
            self.cursor.close()
        if self.conn:
            if exc_type is None:
                self.conn.commit()
            else:
                self.conn.rollback()
            self.conn.close()

        # Log any exceptions that occurred
        if exc_type is not None:
            logger.error(f"An error occurred: {exc_val}")
            logger.error(traceback.format_exc())
            return False  # Re-raise the exception
        return True


# Environment variables and configurations
try:
    DBT_PROJECT_DIR = os.environ.get("DBT_PROJECT_DIR", "/opt/airflow/dbt_project")
    METABASE_URL = Variable.get("metabase_url", "http://metabase:3000")
    METABASE_USERNAME = Variable.get("metabase_username")
    METABASE_PASSWORD = Variable.get("metabase_password")
    SUPABASE_KEY = Variable.get("supabase_key")
    PRODUCT_DASHBOARD_ID = Variable.get("product_dashboard_id")
    CUSTOMER_DASHBOARD_ID = Variable.get("customer_dashboard_id")
    logger.info("Successfully loaded environment variables and configurations")
except Exception as e:
    logger.error(f"Error loading environment variables: {e}")
    logger.error(traceback.format_exc())
    raise

# Create headers for Supabase API
headers = {
    "apikey": SUPABASE_KEY,
    "Authorization": f"Bearer {SUPABASE_KEY}",
    "Content-Type": "application/json",
}

# Use the internal Docker network hostname
SUPABASE_INTERNAL_URL = "http://ecommerceanalytics-supabase-api-1:3000"

# Database connection parameters for the Supabase PostgreSQL database
SUPABASE_DB_PARAMS = {
    "host": os.environ.get("DB_HOST", "ecommerceanalytics-supabase-db-1"),
    "database": os.environ.get("DB_NAME", "ecommerce-db"),
    "user": os.environ.get("DB_USER", "ecommercedev"),
    "password": os.environ.get("DB_PASSWORD", "ecommercedev"),
    "port": int(os.environ.get("DB_PORT", 5432)),
    "connect_timeout": 10,
}

# Define the DAG
dag = DAG(
    "ecommerce_analytics_pipeline",
    default_args=default_args,
    description="End-to-end ecommerce analytics pipeline",
    schedule_interval="0 5 * * *",  # Run daily at 5 AM
    catchup=False,
    max_active_runs=1,  # Ensure only one run at a time
    tags=["ecommerce", "analytics", "dbt", "metabase"],
)


# Function to get Metabase auth token
def get_metabase_token() -> str:
    """
    Get authentication token from Metabase API.

    Returns:
        str: The authentication token

    Raises:
        Exception: If authentication fails
    """
    try:
        logger.info("Attempting to authenticate with Metabase")
        session_url = f"{METABASE_URL}/api/session"
        response = requests.post(
            session_url,
            json={"username": METABASE_USERNAME, "password": METABASE_PASSWORD},
            timeout=30,  # Add timeout
        )

        response.raise_for_status()
        token = response.json().get("id")

        if not token:
            raise ValueError("Authentication succeeded but no token was returned")

        logger.info("Successfully authenticated with Metabase")
        return token
    except requests.exceptions.RequestException as e:
        logger.error(f"Metabase authentication request error: {e}")
        raise
    except (KeyError, json.JSONDecodeError) as e:
        logger.error(f"Invalid response from Metabase API: {e}")
        raise
    except Exception as e:
        logger.error(f"Unexpected error in Metabase authentication: {e}")
        logger.error(traceback.format_exc())
        raise


# Function to refresh a Metabase dashboard
def refresh_metabase_dashboard(dashboard_id: str, **kwargs) -> str:
    """
    Trigger a refresh of a specific Metabase dashboard.

    Args:
        dashboard_id: The ID of the dashboard to refresh

    Returns:
        str: A summary of the refresh operation

    Raises:
        Exception: If the refresh operation fails
    """
    try:
        logger.info(f"Refreshing Metabase dashboard {dashboard_id}")

        # Get auth token
        token = get_metabase_token()

        # Refresh dashboard cards
        dashboard_url = f"{METABASE_URL}/api/dashboard/{dashboard_id}/cards"
        headers = {"X-Metabase-Session": token}

        # Get dashboard cards
        response = requests.get(dashboard_url, headers=headers, timeout=30)
        response.raise_for_status()

        dashboard_cards = response.json()
        logger.info(f"Found {len(dashboard_cards)} cards in dashboard {dashboard_id}")

        # Refresh each card
        success_count = 0
        error_count = 0
        for card in dashboard_cards:
            card_id = card["card"]["id"]
            try:
                logger.info(f"Refreshing card {card_id}")

                refresh_url = f"{METABASE_URL}/api/card/{card_id}/query"
                refresh_response = requests.post(
                    refresh_url, headers=headers, timeout=60
                )
                refresh_response.raise_for_status()
                success_count += 1
            except requests.exceptions.RequestException as e:
                logger.warning(f"Failed to refresh card {card_id}: {e}")
                error_count += 1

        refresh_summary = f"Dashboard {dashboard_id} refresh complete: {success_count} cards succeeded, {error_count} cards failed"
        logger.info(refresh_summary)
        return refresh_summary

    except requests.exceptions.RequestException as e:
        logger.error(f"HTTP error refreshing dashboard {dashboard_id}: {e}")
        raise
    except Exception as e:
        logger.error(f"Error refreshing dashboard {dashboard_id}: {e}")
        logger.error(traceback.format_exc())
        raise


# Function to extract data from Supabase
def extract_data_from_supabase(**kwargs) -> Dict[str, Any]:
    """
    Extract data from Supabase PostgreSQL database and store in staging tables.

    Returns:
        Dict[str, Any]: Summary of the extraction operation

    Raises:
        Exception: If extraction fails
    """
    try:
        logger.info("Starting data extraction from Supabase PostgreSQL database")

        # List of tables to extract with schema prefix
        tables = [
            {"name": "orders", "endpoint": "olist.orders"},
            {"name": "order_items", "endpoint": "olist.order_items"},
            {"name": "products", "endpoint": "olist.products"},
            {"name": "customers", "endpoint": "olist.customers"},
            {"name": "sellers", "endpoint": "olist.sellers"},
            {"name": "reviews", "endpoint": "olist.reviews"},
        ]

        tables_processed = 0
        tables_failed = 0
        rows_processed = 0

        # Connect using context manager for better error handling
        with DatabaseConnectionManager(SUPABASE_DB_PARAMS) as cursor:
            # Create raw schema if it doesn't exist
            cursor.execute("CREATE SCHEMA IF NOT EXISTS raw;")

            for table_info in tables:
                table = table_info["name"]
                endpoint = table_info["endpoint"]

                logger.info(f"Extracting data from {table} table")

                # Define the target schema and table
                target_schema = "raw"
                target_table = f"olist_{table}"

                try:
                    # Execute the query to fetch data
                    query = f"SELECT * FROM {endpoint}"
                    cursor.execute(query)

                    # Fetch all data
                    data = cursor.fetchall()

                    if not data:
                        logger.warning(f"No data found in {endpoint}")
                        continue

                    # Drop the target table if it exists
                    drop_table_query = sql.SQL("DROP TABLE IF EXISTS {}.{}").format(
                        sql.Identifier(target_schema), sql.Identifier(target_table)
                    )
                    cursor.execute(drop_table_query)

                    # Get column names and types from the first row
                    columns = data[0].keys()

                    # Create table with appropriate columns
                    create_table_columns = []
                    for col in columns:
                        # Determine appropriate data type
                        # This is a simplified approach - in a real scenario, you'd map types more carefully
                        data_type = "TEXT"
                        create_table_columns.append(f"{col} {data_type}")

                    create_table_query = f"""
                    CREATE TABLE {target_schema}.{target_table} (
                        {', '.join(create_table_columns)}
                    )
                    """
                    cursor.execute(create_table_query)

                    # Insert data
                    for row in data:
                        placeholders = ", ".join(["%s"] * len(columns))
                        columns_str = ", ".join(columns)
                        insert_query = f"""
                        INSERT INTO {target_schema}.{target_table} ({columns_str})
                        VALUES ({placeholders})
                        """
                        values = [row[col] for col in columns]
                        cursor.execute(insert_query, values)
                        rows_processed += 1

                    logger.info(f"Successfully processed {len(data)} rows from {table}")
                    tables_processed += 1

                except Exception as e:
                    logger.error(f"Error processing table {table}: {e}")
                    logger.error(traceback.format_exc())
                    tables_failed += 1

        result = {
            "tables_processed": tables_processed,
            "tables_failed": tables_failed,
            "rows_processed": rows_processed,
            "status": "success" if tables_failed == 0 else "partial_failure",
        }

        logger.info(f"Data extraction complete: {result}")
        return result

    except Exception as e:
        logger.error(f"Extraction process failed: {e}")
        logger.error(traceback.format_exc())
        raise


# Create a task for extracting data from Supabase
extract_task = PythonOperator(
    task_id="extract_data",
    python_callable=extract_data_from_supabase,
    provide_context=True,
    dag=dag,
)

# Create a task for running dbt models
dbt_run_task = BashOperator(
    task_id="dbt_run",
    bash_command=f"cd {DBT_PROJECT_DIR} && dbt run --profiles-dir=./profiles",
    dag=dag,
)

# Create a task for running dbt tests
dbt_test_task = BashOperator(
    task_id="dbt_test",
    bash_command=f"cd {DBT_PROJECT_DIR} && dbt test --profiles-dir=./profiles",
    dag=dag,
)

# Create a task for refreshing product dashboard
refresh_product_dashboard_task = PythonOperator(
    task_id="refresh_product_dashboard",
    python_callable=refresh_metabase_dashboard,
    op_kwargs={"dashboard_id": PRODUCT_DASHBOARD_ID},
    provide_context=True,
    dag=dag,
)

# Create a task for refreshing customer dashboard
refresh_customer_dashboard_task = PythonOperator(
    task_id="refresh_customer_dashboard",
    python_callable=refresh_metabase_dashboard,
    op_kwargs={"dashboard_id": CUSTOMER_DASHBOARD_ID},
    provide_context=True,
    dag=dag,
)

# Create a task to log the success of the entire pipeline
success_task = BashOperator(
    task_id="pipeline_success",
    bash_command='echo "Pipeline completed successfully at $(date)"',
    trigger_rule=TriggerRule.ALL_SUCCESS,
    dag=dag,
)

# Set up task dependencies
extract_task >> dbt_run_task >> dbt_test_task
(
    dbt_test_task
    >> refresh_product_dashboard_task
    >> refresh_customer_dashboard_task
    >> success_task
)

# Create a fallback task for logging failures
failure_task = BashOperator(
    task_id="log_failure",
    bash_command='echo "Pipeline failed at $(date)" >> /opt/airflow/logs/pipeline_failures.log',
    trigger_rule=TriggerRule.ONE_FAILED,
    dag=dag,
)

# Connect the failure task to all tasks
[
    extract_task,
    dbt_run_task,
    dbt_test_task,
    refresh_product_dashboard_task,
    refresh_customer_dashboard_task,
] >> failure_task
