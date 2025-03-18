"""
Ecommerce Analytics Pipeline DAG
--------------------------------
This DAG orchestrates the entire analytics workflow:
1. Extracts data from Supabase
2. Runs dbt models in the correct order
3. Refreshes Metabase dashboards
"""

import os
from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator
from airflow.providers.http.operators.http import SimpleHttpOperator
from airflow.models import Variable
import requests
import json
import logging

# Configure logging
logger = logging.getLogger(__name__)

# Default arguments for the DAG
default_args = {
    "owner": "data_team",
    "depends_on_past": False,
    "email": ["analytics@example.com"],
    "email_on_failure": True,
    "email_on_retry": False,
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
    "start_date": datetime(2023, 1, 1),
}

# Environment variables and configurations
DBT_PROJECT_DIR = "{{ var.value.dbt_project_dir }}"
METABASE_URL = "{{ var.value.metabase_url }}"
METABASE_USERNAME = "{{ var.value.metabase_username }}"
METABASE_PASSWORD = "{{ var.value.metabase_password }}"
SUPABASE_URL = "{{ var.value.supabase_url }}"
SUPABASE_KEY = "{{ var.value.supabase_key }}"

# Dashboard IDs to refresh
PRODUCT_DASHBOARD_ID = "{{ var.value.product_dashboard_id }}"
CUSTOMER_DASHBOARD_ID = "{{ var.value.customer_dashboard_id }}"

# Define the DAG
dag = DAG(
    "ecommerce_analytics_pipeline",
    default_args=default_args,
    description="End-to-end ecommerce analytics pipeline",
    schedule_interval="0 5 * * *",  # Run daily at 5 AM
    catchup=False,
    tags=["ecommerce", "analytics", "dbt", "metabase"],
)


# Function to extract data from Supabase
def extract_data_from_supabase(**kwargs):
    """
    Extract data from Supabase and store in staging tables.
    """
    try:
        logger.info("Starting data extraction from Supabase")

        # For demonstration purposes, we're just simulating the data extraction
        # In a real implementation, you would use the Supabase API to extract data

        # List of tables to extract
        tables = [
            "orders",
            "order_items",
            "products",
            "customers",
            "sellers",
            "reviews",
        ]

        for table in tables:
            logger.info(f"Extracting data from {table} table")

            # Define the target schema and table
            target_schema = "raw"
            target_table = f"olist_{table}"

            # In a real implementation, this is where you would make API calls
            # or execute SQL queries to extract the data

            # For now, we'll just log the operations
            logger.info(
                f"Successfully extracted {table} data to {target_schema}.{target_table}"
            )

        return "Data extraction completed successfully"

    except Exception as e:
        logger.error(f"Error extracting data: {e}")
        raise


# Function to get Metabase auth token
def get_metabase_token():
    """
    Get authentication token from Metabase API.
    """
    session_url = f"{METABASE_URL}/api/session"
    response = requests.post(
        session_url, json={"username": METABASE_USERNAME, "password": METABASE_PASSWORD}
    )

    if response.status_code == 200:
        return response.json()["id"]
    else:
        raise Exception(f"Failed to authenticate with Metabase: {response.text}")


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
        if response.status_code != 200:
            raise Exception(f"Failed to get dashboard cards: {response.text}")

        dashboard_cards = response.json()

        # Refresh each card
        for card in dashboard_cards:
            card_id = card["card"]["id"]
            logger.info(f"Refreshing card {card_id}")

            refresh_url = f"{METABASE_URL}/api/card/{card_id}/query"
            refresh_response = requests.post(refresh_url, headers=headers)

            if refresh_response.status_code not in (200, 202):
                logger.warning(
                    f"Failed to refresh card {card_id}: {refresh_response.text}"
                )

        return f"Successfully refreshed dashboard {dashboard_id}"

    except Exception as e:
        logger.error(f"Error refreshing dashboard: {e}")
        raise


# Task 1: Extract data from Supabase
extract_data_task = PythonOperator(
    task_id="extract_data_from_supabase",
    python_callable=extract_data_from_supabase,
    dag=dag,
)

# Task 2: Run dbt staging models
run_dbt_staging = BashOperator(
    task_id="run_dbt_staging",
    bash_command=f"cd {DBT_PROJECT_DIR} && dbt run --models tag:staging",
    dag=dag,
)

# Task 3: Run dbt intermediate models
run_dbt_intermediate = BashOperator(
    task_id="run_dbt_intermediate",
    bash_command=f"cd {DBT_PROJECT_DIR} && dbt run --models tag:intermediate",
    dag=dag,
)

# Task 4: Run dbt mart models
run_dbt_marts = BashOperator(
    task_id="run_dbt_marts",
    bash_command=f"cd {DBT_PROJECT_DIR} && dbt run --models tag:marts",
    dag=dag,
)

# Task 5: Run dbt tests
run_dbt_tests = BashOperator(
    task_id="run_dbt_tests",
    bash_command=f"cd {DBT_PROJECT_DIR} && dbt test",
    dag=dag,
)

# Task 6: Refresh Product Analytics Dashboard
refresh_product_dashboard = PythonOperator(
    task_id="refresh_product_dashboard",
    python_callable=refresh_metabase_dashboard,
    op_kwargs={"dashboard_id": PRODUCT_DASHBOARD_ID},
    dag=dag,
)

# Task 7: Refresh Customer Analytics Dashboard
refresh_customer_dashboard = PythonOperator(
    task_id="refresh_customer_dashboard",
    python_callable=refresh_metabase_dashboard,
    op_kwargs={"dashboard_id": CUSTOMER_DASHBOARD_ID},
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
run_dbt_tests >> refresh_product_dashboard
run_dbt_tests >> refresh_customer_dashboard
