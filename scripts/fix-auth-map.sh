#!/bin/bash
set -e

echo "Fixing PostgreSQL authentication mapping..."

# Connect to the PostgreSQL container
docker exec -it ecommerceanalytics-supabase-db-1 bash -c "
# Create or update the pg_ident.conf file to map the root user to ${DB_USER}
echo '# supabase_map
supabase_map      root            ${DB_USER}
supabase_map      root            postgres
supabase_map      root            supabase_admin' > /var/lib/postgresql/data/pg_ident.conf

# Make sure the pg_hba.conf file is properly configured
sed -i 's/local all  all                peer map=supabase_map/local all  all                trust/g' /var/lib/postgresql/data/pg_hba.conf

# Reload PostgreSQL configuration
su - postgres -c 'pg_ctl reload'

echo 'Authentication mapping fixed.'
"

# Restart the database container to apply changes
echo "Restarting database container..."
docker restart ecommerceanalytics-supabase-db-1

# Wait for the database to be ready
echo "Waiting for database to be ready..."
sleep 10

# Now fix permissions using the postgres superuser
docker exec -it ecommerceanalytics-supabase-db-1 bash -c "
su - postgres -c 'psql -c \"ALTER USER ${DB_USER} WITH SUPERUSER;\"'
su - postgres -c 'psql -c \"GRANT ALL PRIVILEGES ON SCHEMA public TO ${DB_USER};\"'
su - postgres -c 'psql -c \"GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ${DB_USER};\"'
su - postgres -c 'psql -c \"GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ${DB_USER};\"'
su - postgres -c 'psql -c \"GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO ${DB_USER};\"'

# Create airflow schema if it doesn't exist
su - postgres -c 'psql -c \"CREATE SCHEMA IF NOT EXISTS airflow;\"'
su - postgres -c 'psql -c \"GRANT ALL PRIVILEGES ON SCHEMA airflow TO ${DB_USER};\"'

# Create metabase schema if it doesn't exist
su - postgres -c 'psql -c \"CREATE SCHEMA IF NOT EXISTS metabase;\"'
su - postgres -c 'psql -c \"GRANT ALL PRIVILEGES ON SCHEMA metabase TO ${DB_USER};\"'

# Create metabase user if it doesn't exist
su - postgres -c 'psql -c \"DO
\\\$\\\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '\''metabase'\'') THEN
        CREATE USER metabase WITH PASSWORD '\''metabase'\'';
    END IF;
END
\\\$\\\$;\"'

# Grant metabase user permissions
su - postgres -c 'psql -c \"GRANT ALL PRIVILEGES ON SCHEMA metabase TO metabase;\"'
su - postgres -c 'psql -c \"GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA metabase TO metabase;\"'
su - postgres -c 'psql -c \"GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA metabase TO metabase;\"'
su - postgres -c 'psql -c \"GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA metabase TO metabase;\"'

# Create metabase database if it doesn't exist
su - postgres -c 'psql -c \"SELECT '\''CREATE DATABASE metabase WITH OWNER metabase'\'' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '\''metabase'\'');\"'

# Allow metabase user to create tables in public schema
su - postgres -c 'psql -c \"GRANT ALL PRIVILEGES ON SCHEMA public TO metabase;\"'

echo 'Database permissions fixed.'
"

# Restart all services to apply changes
echo "Restarting all services..."
docker restart ecommerceanalytics-metabase-1
docker restart ecommerceanalytics-airflow-webserver-1
docker restart ecommerceanalytics-airflow-scheduler-1

echo "All fixes applied and services restarted."