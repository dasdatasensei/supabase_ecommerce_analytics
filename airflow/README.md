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

### 1. Deploy the DAG to Airflow

Copy the DAG file to your Airflow container:

```bash
docker cp airflow/dags/ecommerce_analytics_pipeline.py ecommerceanalytics-airflow-webserver-1:/opt/airflow/dags/
```

### 2. Configure Variables in Airflow UI

1. Open Airflow UI at http://localhost:8080
2. Navigate to Admin > Variables
3. Add the following variables:
   - `dbt_project_dir`: `/opt/airflow/dbt_project`
   - `metabase_url`: `http://metabase:3000`
   - `metabase_username`: Your Metabase admin email
   - `metabase_password`: Your Metabase password
   - `supabase_url`: `http://supabase-db:8000`
   - `supabase_key`: Your Supabase key
   - `product_dashboard_id`: Your Metabase product dashboard ID
   - `customer_dashboard_id`: Your Metabase customer dashboard ID

### 3. Install Required Dependencies

Connect to the Airflow container and install required packages:

```bash
docker exec -it ecommerceanalytics-airflow-webserver-1 pip install postgrest requests
```

### 4. Copy dbt Project into Airflow Container

If your dbt project is not already accessible to Airflow:

```bash
docker cp ../dbt_project ecommerceanalytics-airflow-webserver-1:/opt/airflow/
```

### 5. Activate the DAG

In the Airflow UI, navigate to the DAGs page and enable the `ecommerce_analytics_pipeline` DAG.

## Monitoring and Maintenance

### Checking DAG Status

1. Go to the Airflow UI
2. View the `ecommerce_analytics_pipeline` DAG
3. Check for successful runs or any failed tasks

### Updating the DAG

If you need to make changes to the DAG:

1. Update the local `ecommerce_analytics_pipeline.py` file
2. Copy it again to the Airflow container:
   ```bash
   docker cp airflow/dags/ecommerce_analytics_pipeline.py ecommerceanalytics-airflow-webserver-1:/opt/airflow/dags/
   ```

### Troubleshooting

- **DAG not visible in Airflow**: Check for syntax errors or try restarting the Airflow webserver
- **dbt run failing**: Verify the dbt_project_dir path and ensure dbt is installed
- **Metabase refresh failing**: Check Metabase credentials and dashboard IDs
- **Supabase extraction failing**: Verify Supabase URL and API key

## Scheduling

The DAG runs daily at 5:00 AM by default. To change this:

1. Edit the `schedule_interval` parameter in the DAG definition
2. Use cron syntax (e.g., `0 8 * * *` for 8:00 AM daily)
