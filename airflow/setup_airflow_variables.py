#!/usr/bin/env python
"""
Setup Airflow Variables for Ecommerce Analytics Pipeline

Run this script to set up the required Airflow variables for the ecommerce analytics pipeline.
Usage: python setup_airflow_variables.py
"""

import os
import sys
import json
import argparse
from airflow.models import Variable

# Default values - override these with command line arguments
DEFAULT_CONFIG = {
    "dbt_project_dir": "/opt/airflow/dbt_project",
    "metabase_url": "http://metabase:3000",
    "metabase_username": "admin@example.com",
    "metabase_password": "your_metabase_password",
    "supabase_url": "http://supabase-db:8000",
    "supabase_key": "your_supabase_key",
    "product_dashboard_id": "1",  # Replace with actual Product dashboard ID
    "customer_dashboard_id": "2",  # Replace with actual Customer dashboard ID
}


def setup_variables(config):
    """
    Set up Airflow variables from the provided configuration.
    """
    for key, value in config.items():
        Variable.set(key, value)
        print(f"✅ Set variable: {key}")

    print("\nAirflow variables set successfully! 🚀")
    print("\nTo verify the variables, run the following command in the Airflow UI CLI:")
    print("airflow variables list")


def parse_args():
    """
    Parse command line arguments.
    """
    parser = argparse.ArgumentParser(
        description="Set up Airflow variables for the ecommerce analytics pipeline."
    )

    for key, value in DEFAULT_CONFIG.items():
        parser.add_argument(f"--{key}", default=value, help=f"{key} (default: {value})")

    parser.add_argument("--from-json", help="Load configuration from a JSON file")

    return parser.parse_args()


def main():
    """
    Main function to set up Airflow variables.
    """
    args = parse_args()

    if args.from_json:
        try:
            with open(args.from_json, "r") as f:
                config = json.load(f)
        except Exception as e:
            print(f"Error loading JSON configuration: {e}")
            sys.exit(1)
    else:
        # Convert args to dictionary, excluding the from_json parameter
        config = {k: v for k, v in vars(args).items() if k != "from_json"}

    try:
        setup_variables(config)
    except Exception as e:
        print(f"Error setting up Airflow variables: {e}")
        print(
            "\nMake sure the Airflow web server is running and AIRFLOW_HOME is set correctly."
        )
        sys.exit(1)


if __name__ == "__main__":
    main()
