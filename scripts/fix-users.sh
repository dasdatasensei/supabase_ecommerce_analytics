#!/bin/bash
set -e

echo "==================================================="
echo "Supabase Authentication and Permissions Fix Script"
echo "==================================================="

echo "Using supabase_admin (password: postgres) to fix user permissions..."

# Connect to the database container
docker exec -i ecommerceanalytics-supabase-db-1 bash -c "
  # First, let's ensure ${DB_USER} has superuser privileges
  PGPASSWORD=postgres psql -h localhost -U supabase_admin -d postgres -c \"ALTER USER ${DB_USER} WITH SUPERUSER;\"

  # Set a consistent password for ${DB_USER} to ensure password authentication works
  PGPASSWORD=postgres psql -h localhost -U supabase_admin -d postgres -c \"ALTER USER ${DB_USER} WITH PASSWORD '${DB_USER}';\"

  # Verify the changes
  PGPASSWORD=postgres psql -h localhost -U supabase_admin -d postgres -c \"SELECT usename, usesuper FROM pg_user WHERE usename = '${DB_USER}';\"
"

echo "User permissions fixed!"
echo
echo "Document for future reference:"
echo "----------------------------"
echo "supabase_admin password: postgres"
echo "${DB_USER} password: ${DB_USER}"
echo
echo "Connection examples:"
echo "- As supabase_admin: PGPASSWORD=postgres psql -h localhost -U supabase_admin -d postgres"
echo "- As ${DB_USER}: PGPASSWORD=${DB_USER} psql -h localhost -U ${DB_USER} -d ecommerce-db"
echo
echo "The ${DB_USER} user now has superuser privileges and the olist schema has been created."
echo "==================================================="