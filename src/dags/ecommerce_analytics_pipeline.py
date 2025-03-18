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

from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator
from airflow.providers.http.operators.http import SimpleHttpOperator
from airflow.models import Variable
from airflow.utils.trigger_rule import TriggerRule
import requests
import json
import logging
import traceback

# Configure logging
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

# Environment variables and configurations
try:
    DBT_PROJECT_DIR = "/opt/airflow/dbt_project"  # Hardcode the correct path
    METABASE_URL = Variable.get("metabase_url")
    METABASE_USERNAME = Variable.get("metabase_username")
    METABASE_PASSWORD = Variable.get("metabase_password")
    SUPABASE_KEY = Variable.get("supabase_key")
    PRODUCT_DASHBOARD_ID = Variable.get("product_dashboard_id")
    CUSTOMER_DASHBOARD_ID = Variable.get("customer_dashboard_id")
except Exception as e:
    logger.error(f"Error loading environment variables: {e}")
    raise

# Use httpx directly instead of postgrest-py to avoid async issues
import httpx

# Create headers for Supabase API
headers = {
    "apikey": SUPABASE_KEY,
    "Authorization": f"Bearer {SUPABASE_KEY}",
    "Content-Type": "application/json",
}

# Use the internal Docker network hostname instead of environment variable
SUPABASE_INTERNAL_URL = "http://ecommerceanalytics-supabase-api-1:3000/auth/v1"

# We'll directly use PostgreSQL for extracting data
import psycopg2

# Database connection parameters for the Supabase PostgreSQL database
SUPABASE_DB_PARAMS = {
    "host": "ecommerceanalytics-supabase-db-1",  # Internal Docker network hostname
    "database": "ecommerce-db",  # Ecommerce database
    "user": "ecommercedev",  # Ecommerce development user
    "password": "ecommercedev",  # Ecommerce development password
    "port": 5432,  # Supabase postgres port
    "connect_timeout": 10,  # Connection timeout in seconds
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
def get_metabase_token():
    """
    Get authentication token from Metabase API.
    """
    try:
        session_url = f"{METABASE_URL}/api/session"
        response = requests.post(
            session_url,
            json={"username": METABASE_USERNAME, "password": METABASE_PASSWORD},
        )

        response.raise_for_status()  # Raise exception for non-200 responses
        return response.json()["id"]
    except requests.exceptions.RequestException as e:
        logger.error(f"Metabase authentication error: {e}")
        raise
    except (KeyError, json.JSONDecodeError) as e:
        logger.error(f"Invalid response from Metabase API: {e}")
        raise
    except Exception as e:
        logger.error(f"Unexpected error in Metabase authentication: {e}")
        logger.error(traceback.format_exc())
        raise


# Function to refresh a Metabase dashboard
def refresh_metabase_dashboard(dashboard_id, **kwargs):
    """
    Trigger a refresh of a specific Metabase dashboard.
    """
    try:
        logger.info(f"Refreshing Metabase dashboard {dashboard_id}")

        # Get auth token
        token = get_metabase_token()

        # Refresh dashboard cards
        dashboard_url = f"{METABASE_URL}/api/dashboard/{dashboard_id}/cards"
        headers = {"X-Metabase-Session": token}

        # Get dashboard cards
        response = requests.get(dashboard_url, headers=headers)
        response.raise_for_status()  # Raise exception for non-200 responses

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
                refresh_response = requests.post(refresh_url, headers=headers)
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
def extract_data_from_supabase(**kwargs):
    """
    Extract data from Supabase PostgreSQL database and store in staging tables.
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

        # Connect to source and target databases
        try:
            # Connect to Supabase PostgreSQL database for both source and target
            conn_source = psycopg2.connect(**SUPABASE_DB_PARAMS)
            conn_source.autocommit = False

            conn = psycopg2.connect(**SUPABASE_DB_PARAMS)
            conn.autocommit = False  # Use transactions
            cursor = conn.cursor()

            # Create raw schema if it doesn't exist
            cursor.execute("CREATE SCHEMA IF NOT EXISTS raw;")
            conn.commit()

            tables_processed = 0
            tables_failed = 0
            rows_processed = 0

            for table_info in tables:
                table = table_info["name"]
                endpoint = table_info["endpoint"]

                logger.info(f"Extracting data from {table} table")

                # Define the target schema and table
                target_schema = "raw"
                target_table = f"olist_{table}"

                try:
                    # Open a new cursor for each query
                    cursor_source = conn_source.cursor()

                    # Execute the query to fetch data
                    query = f"SELECT * FROM {endpoint}"
                    cursor_source.execute(query)

                    # Fetch all data
                    data = cursor_source.fetchall()

                    # Get column names
                    column_names = [desc[0] for desc in cursor_source.description]

                    # Create a list of dictionaries with column names as keys
                    result_data = []
                    for row in data:
                        result_dict = {}
                        for i, value in enumerate(row):
                            result_dict[column_names[i]] = value
                        result_data.append(result_dict)

                    # Close the source cursor
                    cursor_source.close()

                    # Create a response-like object
                    response = type("obj", (object,), {"data": result_data})

                    # Create the target table (will be dynamically based on data schema)
                    if response.data and len(response.data) > 0:
                        # Get column names from first row
                        columns = response.data[0].keys()

                        # Start a transaction
                        try:
                            # Drop table if exists
                            cursor.execute(
                                f"DROP TABLE IF EXISTS {target_schema}.{target_table};"
                            )

                            # Create table with appropriate columns
                            create_table_sql = (
                                f"CREATE TABLE {target_schema}.{target_table} ("
                            )
                            for col in columns:
                                create_table_sql += f'"{col}" TEXT,'
                            create_table_sql = create_table_sql.rstrip(",") + ");"
                            cursor.execute(create_table_sql)

                            # Insert data in batches
                            batch_size = 1000
                            batches = [
                                response.data[i : i + batch_size]
                                for i in range(0, len(response.data), batch_size)
                            ]

                            for batch in batches:
                                for row in batch:
                                    placeholders = ",".join(["%s"] * len(row))
                                    columns_sql = ",".join(
                                        [f'"{col}"' for col in row.keys()]
                                    )
                                    insert_sql = f"INSERT INTO {target_schema}.{target_table} ({columns_sql}) VALUES ({placeholders})"
                                    cursor.execute(insert_sql, list(row.values()))

                            # Commit the transaction
                            conn.commit()
                            rows_processed += len(response.data)
                            tables_processed += 1
                            logger.info(
                                f"Successfully extracted {len(response.data)} rows from {table} to {target_schema}.{target_table}"
                            )
                        except Exception as e:
                            conn.rollback()
                            logger.error(
                                f"Database error while processing {table}: {e}"
                            )
                            tables_failed += 1
                            raise
                    else:
                        logger.info(f"No data found in {table}")
                        tables_processed += 1
                except Exception as e:
                    logger.error(f"Error extracting data from {table}: {e}")
                    tables_failed += 1

            # Close database connections
            cursor.close()
            conn.close()
            conn_source.close()

            extraction_summary = f"Data extraction complete: {tables_processed} tables succeeded, {tables_failed} tables failed, {rows_processed} total rows processed"
            logger.info(extraction_summary)
            return extraction_summary

        except psycopg2.Error as e:
            logger.error(f"Database connection error: {e}")
            raise

    except Exception as e:
        logger.error(f"Error extracting data: {e}")
        logger.error(traceback.format_exc())
        raise


# Task 1: Extract data from Supabase
extract_data_task = PythonOperator(
    task_id="extract_data_from_supabase",
    python_callable=extract_data_from_supabase,
    dag=dag,
    retries=3,
    retry_delay=timedelta(minutes=2),
)

# Task 2: Run dbt staging models
run_dbt_staging = BashOperator(
    task_id="run_dbt_staging",
    bash_command=f"cd {DBT_PROJECT_DIR} && dbt run --models tag:staging",
    dag=dag,
    retries=2,
    retry_delay=timedelta(minutes=1),
)

# Task 3: Run dbt intermediate models
run_dbt_intermediate = BashOperator(
    task_id="run_dbt_intermediate",
    bash_command=f"cd {DBT_PROJECT_DIR} && dbt run --models tag:intermediate",
    dag=dag,
    retries=2,
    retry_delay=timedelta(minutes=1),
)

# Task 4: Run dbt mart models
run_dbt_marts = BashOperator(
    task_id="run_dbt_marts",
    bash_command=f"cd {DBT_PROJECT_DIR} && dbt run --models tag:marts",
    dag=dag,
    retries=2,
    retry_delay=timedelta(minutes=1),
)

# Task 5: Run dbt tests
run_dbt_tests = BashOperator(
    task_id="run_dbt_tests",
    bash_command=f"cd {DBT_PROJECT_DIR} && dbt test",
    dag=dag,
    retries=1,
    retry_delay=timedelta(minutes=1),
)

# Task 6: Refresh Product Analytics Dashboard
refresh_product_dashboard = PythonOperator(
    task_id="refresh_product_dashboard",
    python_callable=refresh_metabase_dashboard,
    op_kwargs={"dashboard_id": PRODUCT_DASHBOARD_ID},
    dag=dag,
    retries=3,
    retry_delay=timedelta(minutes=2),
)

# Task 7: Refresh Customer Analytics Dashboard
refresh_customer_dashboard = PythonOperator(
    task_id="refresh_customer_dashboard",
    python_callable=refresh_metabase_dashboard,
    op_kwargs={"dashboard_id": CUSTOMER_DASHBOARD_ID},
    dag=dag,
    retries=3,
    retry_delay=timedelta(minutes=2),
)

# Task 8: Success notification task
success_notification = BashOperator(
    task_id="success_notification",
    bash_command='echo "The ecommerce analytics pipeline completed successfully on $(date)"',
    trigger_rule=TriggerRule.ALL_SUCCESS,  # Only runs if all upstream tasks succeed
    dag=dag,
)

# Set task dependencies
(
    extract_data_task
    >> run_dbt_staging
    >> run_dbt_intermediate
    >> run_dbt_marts
    >> run_dbt_tests
)
run_dbt_tests >> refresh_product_dashboard >> success_notification
run_dbt_tests >> refresh_customer_dashboard >> success_notification
