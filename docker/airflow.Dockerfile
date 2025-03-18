FROM apache/airflow:2.7.1-python3.11

USER root

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

USER airflow

# Install Python dependencies including dbt
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Set up dbt profiles directory
RUN mkdir -p /opt/airflow/src/dbt_project/profiles

# Create dbt profile
COPY docker/profiles.yml /opt/airflow/src/dbt_project/profiles/profiles.yml

# Set environment variables
ENV PYTHONPATH=/opt/airflow
ENV PYTHONUNBUFFERED=1