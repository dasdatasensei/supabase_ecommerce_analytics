#!/bin/bash
set -e

echo "======================================================================================"
echo "Comprehensive fix for Supabase, Metabase, and Airflow services"
echo "======================================================================================"

echo "1. Fixing PostgreSQL authentication configuration..."
docker exec -i ecommerceanalytics-supabase-db-1 bash << 'EOF'
# Run as PostgreSQL user to avoid permission issues
su - postgres -c "
  # Backup original files
  cp /var/lib/postgresql/data/pg_hba.conf /var/lib/postgresql/data/pg_hba.conf.bak
  cp /var/lib/postgresql/data/pg_ident.conf /var/lib/postgresql/data/pg_ident.conf.bak

  # Update pg_ident.conf - add mapping for ${DB_USER}
  echo '# Added by fix script' >> /var/lib/postgresql/data/pg_ident.conf
  echo 'supabase_map root ${DB_USER}' >> /var/lib/postgresql/data/pg_ident.conf

  # Replace peer auth with md5 auth in pg_hba.conf
  sed -i 's/local all  all                peer map=supabase_map/local all  all                md5/g' /var/lib/postgresql/data/pg_hba.conf

  # Reload PostgreSQL configuration
  pg_ctl -D /var/lib/postgresql/data reload
"
EOF

echo "2. Restarting database to apply configuration changes..."
docker restart ecommerceanalytics-supabase-db-1

echo "3. Waiting for database to start..."
sleep 15

echo "4. Setting up user permissions and creating required tables..."
docker exec -i ecommerceanalytics-supabase-db-1 psql -U postgres << 'EOF'
-- Create password for ${DB_USER} user for MD5 authentication to work
ALTER USER ${DB_USER} WITH PASSWORD '${DB_USER}';

-- Try to grant superuser as it might be needed for extensions
ALTER USER ${DB_USER} WITH SUPERUSER;

-- First fix the ecommerce-db database
\c "ecommerce-db"

-- Set up Airflow tables
CREATE SCHEMA IF NOT EXISTS public;

-- Create Airflow tables if they don't exist
CREATE TABLE IF NOT EXISTS log (
    id SERIAL PRIMARY KEY,
    dttm TIMESTAMP WITH TIME ZONE,
    event VARCHAR(500),
    owner VARCHAR(500),
    extra JSONB
);

CREATE TABLE IF NOT EXISTS job (
    id SERIAL PRIMARY KEY,
    dag_id VARCHAR(250),
    state VARCHAR(20),
    job_type VARCHAR(30),
    start_date TIMESTAMP WITH TIME ZONE,
    end_date TIMESTAMP WITH TIME ZONE,
    latest_heartbeat TIMESTAMP WITH TIME ZONE,
    executor_class VARCHAR(500),
    hostname VARCHAR(500),
    unixname VARCHAR(1000)
);

-- Grant permissions for ecommerce-db
GRANT ALL PRIVILEGES ON SCHEMA public TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO ${DB_USER};

-- Grant permissions for olist schema
GRANT ALL PRIVILEGES ON SCHEMA olist TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA olist TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA olist TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA olist TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA olist GRANT ALL ON TABLES TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA olist GRANT ALL ON SEQUENCES TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA olist GRANT ALL ON FUNCTIONS TO ${DB_USER};

-- Grant permissions for Supabase schemas
GRANT ALL PRIVILEGES ON SCHEMA auth TO ${DB_USER};
GRANT ALL PRIVILEGES ON SCHEMA storage TO ${DB_USER};
GRANT ALL PRIVILEGES ON SCHEMA graphql TO ${DB_USER};
GRANT ALL PRIVILEGES ON SCHEMA realtime TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA auth TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA auth TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA auth TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA storage TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA storage TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA storage TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA graphql TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA graphql TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA graphql TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA realtime TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA realtime TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA realtime TO ${DB_USER};

-- Now fix the metabase database
\c metabase

-- Create metabase schema
CREATE SCHEMA IF NOT EXISTS public;

-- Create necessary Metabase tables
CREATE TABLE IF NOT EXISTS databasechangelog (
    ID VARCHAR(255) NOT NULL,
    AUTHOR VARCHAR(255) NOT NULL,
    FILENAME VARCHAR(255) NOT NULL,
    DATEEXECUTED TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    ORDEREXECUTED INT NOT NULL,
    EXECTYPE VARCHAR(10) NOT NULL,
    MD5SUM VARCHAR(35),
    DESCRIPTION VARCHAR(255),
    COMMENTS VARCHAR(255),
    TAG VARCHAR(255),
    LIQUIBASE VARCHAR(20),
    CONTEXTS VARCHAR(255),
    LABELS VARCHAR(255),
    DEPLOYMENT_ID VARCHAR(10)
);

-- Grant permissions for metabase database
GRANT ALL PRIVILEGES ON SCHEMA public TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO ${DB_USER};
EOF

echo "5. Updating Metabase environment variables to ensure proper PostgreSQL connection..."
docker exec -i ecommerceanalytics-supabase-db-1 psql -U postgres << 'EOF'
-- Create a specific user with limited privileges for Metabase
CREATE USER IF NOT EXISTS metabase WITH PASSWORD 'metabase';
\c metabase
GRANT CONNECT ON DATABASE metabase TO metabase;
GRANT USAGE ON SCHEMA public TO metabase;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO metabase;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO metabase;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO metabase;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE ON SEQUENCES TO metabase;
EOF

echo "6. Updating Metabase configuration to use PostgreSQL..."
cat > metabase.env << EOF
MB_DB_TYPE=postgres
MB_DB_DBNAME=metabase
MB_DB_PORT=5432
MB_DB_USER=metabase
MB_DB_PASS=metabase
MB_DB_HOST=supabase-db
EOF

echo "7. Restarting all services to apply changes..."
docker stop ecommerceanalytics-metabase-1
docker rm ecommerceanalytics-metabase-1
docker-compose -f docker/docker-compose.dev.yml up -d metabase
docker restart ecommerceanalytics-airflow-scheduler-1
docker restart ecommerceanalytics-airflow-webserver-1
docker restart ecommerceanalytics-supabase-studio-1

echo "8. Waiting for services to start..."
sleep 20

echo "9. Creating essential Airflow tables if needed..."
docker exec -i ecommerceanalytics-airflow-webserver-1 airflow db init || true

echo "======================================================================================"
echo "All fixes have been applied. The services should now be running correctly."
echo "Metabase:        http://localhost:3333"
echo "Supabase Studio: http://localhost:8082"
echo "Airflow:         http://localhost:8080"
echo "======================================================================================"