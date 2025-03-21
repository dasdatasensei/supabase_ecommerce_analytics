#!/bin/bash
set -e

echo "Starting database fixes..."

# Grant permissions on public schema
docker exec -i ecommerceanalytics-supabase-db-1 psql -U postgres -c "GRANT ALL PRIVILEGES ON SCHEMA public TO ${DB_USER};"
docker exec -i ecommerceanalytics-supabase-db-1 psql -U postgres -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ${DB_USER};"
docker exec -i ecommerceanalytics-supabase-db-1 psql -U postgres -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ${DB_USER};"
docker exec -i ecommerceanalytics-supabase-db-1 psql -U postgres -c "GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO ${DB_USER};"

# Create airflow schema if it doesn't exist
docker exec -i ecommerceanalytics-supabase-db-1 psql -U postgres -c "CREATE SCHEMA IF NOT EXISTS airflow;"
docker exec -i ecommerceanalytics-supabase-db-1 psql -U postgres -c "GRANT ALL PRIVILEGES ON SCHEMA airflow TO ${DB_USER};"

# Create metabase schema if it doesn't exist
docker exec -i ecommerceanalytics-supabase-db-1 psql -U postgres -c "CREATE SCHEMA IF NOT EXISTS metabase;"
docker exec -i ecommerceanalytics-supabase-db-1 psql -U postgres -c "GRANT ALL PRIVILEGES ON SCHEMA metabase TO ${DB_USER};"

# Create metabase user if it doesn't exist
docker exec -i ecommerceanalytics-supabase-db-1 psql -U postgres -c "DO \$\$ BEGIN IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'metabase') THEN CREATE USER metabase WITH PASSWORD 'metabase'; END IF; END \$\$;"

# Grant metabase user permissions
docker exec -i ecommerceanalytics-supabase-db-1 psql -U postgres -c "GRANT ALL PRIVILEGES ON SCHEMA metabase TO metabase;"
docker exec -i ecommerceanalytics-supabase-db-1 psql -U postgres -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA metabase TO metabase;"
docker exec -i ecommerceanalytics-supabase-db-1 psql -U postgres -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA metabase TO metabase;"
docker exec -i ecommerceanalytics-supabase-db-1 psql -U postgres -c "GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA metabase TO metabase;"

# Create metabase database if it doesn't exist
docker exec -i ecommerceanalytics-supabase-db-1 psql -U postgres -c "DO \$\$ BEGIN IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'metabase') THEN CREATE DATABASE metabase WITH OWNER metabase; END IF; END \$\$;"

# Allow metabase user to create tables in public schema
docker exec -i ecommerceanalytics-supabase-db-1 psql -U postgres -c "GRANT ALL PRIVILEGES ON SCHEMA public TO metabase;"

echo "Database fixes completed."
echo "Restarting services for changes to take effect..."

# Restart the services
docker restart ecommerceanalytics-metabase-1
docker restart ecommerceanalytics-airflow-webserver-1
docker restart ecommerceanalytics-airflow-scheduler-1

echo "All services restarted. The system should now be functioning properly."