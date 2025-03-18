#!/bin/bash
set -e

echo "Creating ${DB_USER} user and setting up database..."

# Run SQL commands to create user and database
docker exec -i ecommerceanalytics-supabase-db-1 psql -U postgres << EOF
-- Create the user if it doesn't exist
CREATE USER ${DB_USER} WITH PASSWORD '${DB_USER}';
ALTER USER ${DB_USER} WITH SUPERUSER;

-- Create the database if it doesn't exist
SELECT 'CREATE DATABASE "ecommerce-db"' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'ecommerce-db') \gexec
GRANT ALL PRIVILEGES ON DATABASE "ecommerce-db" TO ${DB_USER};

-- Connect to the ecommerce-db database
\c "ecommerce-db"

-- Create schema
CREATE SCHEMA IF NOT EXISTS olist;
GRANT ALL ON SCHEMA olist TO ${DB_USER};
GRANT ALL PRIVILEGES ON SCHEMA olist TO ${DB_USER};

-- Create extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create Supabase required schemas
CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS storage;
CREATE SCHEMA IF NOT EXISTS graphql;
CREATE SCHEMA IF NOT EXISTS realtime;
GRANT ALL ON SCHEMA auth TO ${DB_USER};
GRANT ALL ON SCHEMA storage TO ${DB_USER};
GRANT ALL ON SCHEMA graphql TO ${DB_USER};
GRANT ALL ON SCHEMA realtime TO ${DB_USER};

-- Check the role exists
SELECT rolname FROM pg_roles WHERE rolname='${DB_USER}';
EOF

echo "Database setup completed successfully!"