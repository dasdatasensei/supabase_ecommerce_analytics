#!/bin/bash
set -e

echo "Creating auth schema for Supabase Auth service..."

# Create auth schema and set permissions
docker exec -i ecommerceanalytics-supabase-db-1 bash -c "
  # Connect as superuser
  PGPASSWORD=postgres psql -h localhost -U supabase_admin -d postgres << EOF
  -- Switch to ecommerce-db
  \\c \"ecommerce-db\"

  -- Create auth schema if it doesn't exist
  CREATE SCHEMA IF NOT EXISTS auth;

  -- Grant permissions on auth schema
  GRANT ALL PRIVILEGES ON SCHEMA auth TO ${DB_USER};
  GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA auth TO ${DB_USER};
  GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA auth TO ${DB_USER};
  GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA auth TO ${DB_USER};

  -- Set default privileges
  ALTER DEFAULT PRIVILEGES IN SCHEMA auth GRANT ALL ON TABLES TO ${DB_USER};
  ALTER DEFAULT PRIVILEGES IN SCHEMA auth GRANT ALL ON SEQUENCES TO ${DB_USER};
  ALTER DEFAULT PRIVILEGES IN SCHEMA auth GRANT ALL ON FUNCTIONS TO ${DB_USER};
EOF
"

echo "Auth schema created successfully!"