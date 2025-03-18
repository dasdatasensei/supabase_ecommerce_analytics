#!/bin/bash
set -e

echo "==================================================="
echo "Rebuilding and Restarting All Services"
echo "==================================================="

# Step 1: Stop all services
echo "Stopping all services..."
docker-compose -f docker/docker-compose.dev.yml down

# Step 2: Rebuild services if necessary
echo "Rebuilding services..."
docker-compose -f docker/docker-compose.dev.yml build

# Step 3: Start everything back up
echo "Starting all services..."
docker-compose -f docker/docker-compose.dev.yml up -d

# Step 4: Wait for database to be ready
echo "Waiting for database to initialize (30 seconds)..."
sleep 30

# Step 5: Reapply our fixes
echo "Reapplying fixes for database permissions..."

# Fix database permissions
docker exec -i ecommerceanalytics-supabase-db-1 bash -c "
  # Connect as supabase_admin to ensure we have privileges
  PGPASSWORD=postgres psql -h localhost -U supabase_admin -d postgres << EOF
  -- Make ${DB_USER} a superuser
  ALTER USER ${DB_USER} WITH SUPERUSER;

  -- Ensure password is set correctly
  ALTER USER ${DB_USER} WITH PASSWORD '${DB_USER}';

  -- Verify user privileges
  SELECT usename, usesuper FROM pg_user WHERE usename = '${DB_USER}';
EOF
"

# Create and configure olist schema
docker exec -i ecommerceanalytics-supabase-db-1 bash -c "
  # Connect as ${DB_USER}
  PGPASSWORD=${DB_USER} psql -h localhost -U ${DB_USER} -d \"ecommerce-db\" << EOF
  -- Create olist schema if it doesn't exist
  CREATE SCHEMA IF NOT EXISTS olist;

  -- Grant all privileges
  GRANT ALL PRIVILEGES ON SCHEMA olist TO ${DB_USER};
  ALTER DEFAULT PRIVILEGES IN SCHEMA olist GRANT ALL ON TABLES TO ${DB_USER};
  ALTER DEFAULT PRIVILEGES IN SCHEMA olist GRANT ALL ON SEQUENCES TO ${DB_USER};
  ALTER DEFAULT PRIVILEGES IN SCHEMA olist GRANT ALL ON FUNCTIONS TO ${DB_USER};

  -- Set search_path to include olist
  SET search_path TO olist, public;
EOF
"

# Verify all permissions are correct
echo "Verifying configurations..."
docker exec -i ecommerceanalytics-supabase-db-1 bash -c "
  PGPASSWORD=${DB_USER} psql -h localhost -U ${DB_USER} -d \"ecommerce-db\" -c \"SELECT current_schema, current_user;\";
  PGPASSWORD=${DB_USER} psql -h localhost -U ${DB_USER} -d \"ecommerce-db\" -c \"SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'olist';\";
"

# Restart dependent services to ensure they pick up changes
echo "Restarting dependent services..."
docker restart ecommerceanalytics-metabase-1
docker restart ecommerceanalytics-airflow-webserver-1
docker restart ecommerceanalytics-airflow-scheduler-1

echo "==================================================="
echo "Rebuild and restart complete!"
echo "Reminder for connections:"
echo "- Metabase: http://localhost:3333"
echo "- Supabase Studio: http://localhost:8082"
echo "- Airflow: http://localhost:8080"
echo "==================================================="