#!/bin/bash
set -e

# Log function for better visibility
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log "Starting database permission fixes..."

# Connect to the database container and run SQL commands
log "Connecting to database container and applying permissions..."

# Grant ${DB_USER} superuser privileges
docker exec -i ecommerceanalytics-supabase-db-1 psql -U supabase_admin -c "ALTER USER ${DB_USER} WITH SUPERUSER;"

# Grant permissions on public schema
docker exec -i ecommerceanalytics-supabase-db-1 psql -U supabase_admin -c "GRANT ALL PRIVILEGES ON SCHEMA public TO ${DB_USER};"
docker exec -i ecommerceanalytics-supabase-db-1 psql -U supabase_admin -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ${DB_USER};"
docker exec -i ecommerceanalytics-supabase-db-1 psql -U supabase_admin -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ${DB_USER};"
docker exec -i ecommerceanalytics-supabase-db-1 psql -U supabase_admin -c "GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO ${DB_USER};"

# Create airflow schema if it doesn't exist
docker exec -i ecommerceanalytics-supabase-db-1 psql -U supabase_admin -c "CREATE SCHEMA IF NOT EXISTS airflow;"
docker exec -i ecommerceanalytics-supabase-db-1 psql -U supabase_admin -c "GRANT ALL PRIVILEGES ON SCHEMA airflow TO ${DB_USER};"

# Create metabase schema if it doesn't exist
docker exec -i ecommerceanalytics-supabase-db-1 psql -U supabase_admin -c "CREATE SCHEMA IF NOT EXISTS metabase;"
docker exec -i ecommerceanalytics-supabase-db-1 psql -U supabase_admin -c "GRANT ALL PRIVILEGES ON SCHEMA metabase TO ${DB_USER};"

# Create metabase user if it doesn't exist
docker exec -i ecommerceanalytics-supabase-db-1 psql -U supabase_admin -c "
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'metabase') THEN
        CREATE USER metabase WITH PASSWORD 'metabase';
    END IF;
END
\$\$;
"

# Grant metabase user permissions
docker exec -i ecommerceanalytics-supabase-db-1 psql -U supabase_admin -c "GRANT ALL PRIVILEGES ON SCHEMA metabase TO metabase;"
docker exec -i ecommerceanalytics-supabase-db-1 psql -U supabase_admin -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA metabase TO metabase;"
docker exec -i ecommerceanalytics-supabase-db-1 psql -U supabase_admin -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA metabase TO metabase;"
docker exec -i ecommerceanalytics-supabase-db-1 psql -U supabase_admin -c "GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA metabase TO metabase;"

# Create metabase database if it doesn't exist
docker exec -i ecommerceanalytics-supabase-db-1 psql -U supabase_admin -c "
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'metabase') THEN
        CREATE DATABASE metabase WITH OWNER metabase;
    END IF;
END
\$\$;
"

# Allow metabase user to create tables in public schema
docker exec -i ecommerceanalytics-supabase-db-1 psql -U supabase_admin -c "GRANT ALL PRIVILEGES ON SCHEMA public TO metabase;"

# Fix the pg_hba.conf file to use md5 authentication instead of peer
log "Updating pg_hba.conf..."
docker exec -i ecommerceanalytics-supabase-db-1 bash -c "
    # Find the pg_hba.conf file
    PG_HBA_PATH=\$(find /var/lib/postgresql -name pg_hba.conf)

    if [ -n \"\$PG_HBA_PATH\" ]; then
        # Create a backup
        cp \$PG_HBA_PATH \${PG_HBA_PATH}.bak

        # Update the local connection line to use md5 instead of peer
        sed -i 's/local.*all.*all.*peer.*/local all all md5/' \$PG_HBA_PATH

        # Reload PostgreSQL configuration
        su - postgres -c \"pg_ctl reload\"
        echo 'PostgreSQL configuration reloaded'
    else
        echo 'Could not find pg_hba.conf'
    fi
"

log "Database permission fixes completed."
log "Restarting services for changes to take effect..."

# Restart the services
docker restart ecommerceanalytics-metabase-1
docker restart ecommerceanalytics-airflow-webserver-1
docker restart ecommerceanalytics-airflow-scheduler-1

log "All services restarted. The system should now be functioning properly."