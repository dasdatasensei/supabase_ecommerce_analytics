#!/bin/bash

set -e

echo "Setting up permissions for olist schema..."

# Connect to the database container
docker exec -i ecommerceanalytics-supabase-db-1 bash -c "psql -U postgres -d ecommerce-db << 'EOF'

-- Make sure the olist schema exists
CREATE SCHEMA IF NOT EXISTS olist;

-- Grant usage on schema to roles
GRANT USAGE ON SCHEMA olist TO anon, authenticated, service_role, authenticator;

-- Drop and recreate test table to ensure proper ownership
DROP TABLE IF EXISTS olist.api_test_table;
CREATE TABLE olist.api_test_table (
    id SERIAL PRIMARY KEY,
    name TEXT
);

-- Insert test data
INSERT INTO olist.api_test_table (name) VALUES ('test_a'), ('test_b') RETURNING *;

-- Grant permissions on all tables
GRANT SELECT ON ALL TABLES IN SCHEMA olist TO anon, authenticated, authenticator;
GRANT ALL ON ALL TABLES IN SCHEMA olist TO service_role;

-- Set default privileges for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA olist
    GRANT SELECT ON TABLES TO anon, authenticated, authenticator;

ALTER DEFAULT PRIVILEGES IN SCHEMA olist
    GRANT ALL ON TABLES TO service_role;

-- Grant permissions on sequences
GRANT USAGE ON ALL SEQUENCES IN SCHEMA olist TO anon, authenticated, service_role, authenticator;
GRANT ALL ON ALL SEQUENCES IN SCHEMA olist TO service_role;

-- Grant permissions on functions
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA olist TO anon, authenticated, service_role, authenticator;

-- Ensure ownership of schema is proper
ALTER SCHEMA olist OWNER TO postgres;

-- Make the api_test_table accessible specifically
GRANT SELECT ON olist.api_test_table TO anon, authenticated, authenticator;
GRANT ALL ON olist.api_test_table TO service_role;
GRANT USAGE ON SEQUENCE olist.api_test_table_id_seq TO anon, authenticated, service_role, authenticator;

-- Specifically set the anon role's permissions
GRANT SELECT ON olist.api_test_table TO anon;
GRANT USAGE ON SEQUENCE olist.api_test_table_id_seq TO anon;

EOF"

echo "Permissions for olist schema have been set up."