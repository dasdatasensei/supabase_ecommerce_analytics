# Ecommerce Analytics Automation with Airflow

This directory contains the Airflow DAGs and setup scripts needed to automate the entire ecommerce analytics pipeline.

## Overview

The automation pipeline performs the following steps:

1. **Extract data from Supabase**

   - Pulls the latest data from various tables
   - Loads it into raw staging tables

2. **Transform data with dbt**

   - Runs staging models
   - Runs intermediate models
   - Runs mart models
   - Runs tests to validate data quality

3. **Refresh dashboards in Metabase**
   - Refreshes the Product Analytics dashboard
   - Refreshes the Customer Analytics dashboard

## Setup Instructions

### 1. Install Requirements

```bash
pip install apache-airflow apache-airflow-providers-http requests postgrest
```

### 2. Configure Airflow Variables

You can set up the required Airflow variables using the provided script:

```bash
python setup_airflow_variables.py
```

Or you can set them manually in the Airflow UI by navigating to Admin > Variables and adding:

- `dbt_project_dir`: Path to your dbt project directory
- `metabase_url`: URL of your Metabase instance
- `metabase_username`: Metabase admin username
- `metabase_password`: Metabase admin password
- `supabase_url`: URL of your Supabase project
- `supabase_key`: Your Supabase API key
- `product_dashboard_id`: ID of the Product Analytics dashboard in Metabase
- `customer_dashboard_id`: ID of the Customer Analytics dashboard in Metabase

### 3. Deploy the DAG

Copy the `ecommerce_analytics_pipeline.py` file to your Airflow DAGs folder:

```bash
cp ecommerce_analytics_pipeline.py $AIRFLOW_HOME/dags/
```

### 4. Activate the DAG

In the Airflow UI, navigate to the DAGs page and enable the `ecommerce_analytics_pipeline` DAG.

## DAG Schedule

The DAG is scheduled to run daily at 5:00 AM. You can modify the schedule in the DAG file by changing the `schedule_interval` parameter.

## Manual Trigger

You can also trigger the DAG manually from the Airflow UI:

1. Navigate to the DAGs page
2. Find the `ecommerce_analytics_pipeline` DAG
3. Click the "Trigger DAG" button

## Monitoring

The DAG includes logging and error handling. You can monitor the execution in the Airflow UI:

1. Go to the DAGs page
2. Click on the `ecommerce_analytics_pipeline` DAG
3. Click on a specific run
4. View the logs for each task

## Troubleshooting

### Common Issues

- **DAG not appearing in Airflow UI**: Make sure the DAG file is in the correct directory and has no syntax errors.
- **dbt command failing**: Check that the dbt project directory is correct and that dbt is installed in the Airflow environment.
- **Metabase refresh failing**: Verify the Metabase credentials and make sure the dashboard IDs are correct.
- **Supabase extraction failing**: Check the Supabase URL and API key.
