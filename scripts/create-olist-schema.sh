#!/bin/bash
set -e

echo "Creating olist schema and setting permissions..."

# Create olist schema and set permissions
docker exec -i ecommerceanalytics-supabase-db-1 psql -U postgres << EOF
-- Create olist schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS olist;

-- Grant permissions for olist schema to ${DB_USER}
GRANT ALL PRIVILEGES ON SCHEMA olist TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA olist TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA olist TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA olist TO ${DB_USER};

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA olist GRANT ALL ON TABLES TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA olist GRANT ALL ON SEQUENCES TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA olist GRANT ALL ON FUNCTIONS TO ${DB_USER};

-- Grant permissions for public schema
GRANT ALL PRIVILEGES ON SCHEMA public TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO ${DB_USER};

-- Set olist as the search_path for ${DB_USER}
ALTER USER ${DB_USER} SET search_path TO olist, public;
EOF

echo "olist schema created and permissions set successfully!"

# Restart the services to apply changes
echo "Restarting services..."
docker restart ecommerceanalytics-supabase-db-1
docker restart ecommerceanalytics-metabase-1
docker restart ecommerceanalytics-airflow-webserver-1
docker restart ecommerceanalytics-airflow-scheduler-1

echo "All services restarted."