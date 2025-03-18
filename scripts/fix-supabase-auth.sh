#!/bin/bash
set -e

echo "Fixing Supabase authentication configuration..."

# Modify pg_hba.conf and pg_ident.conf to fix authentication issues
docker exec -i ecommerceanalytics-supabase-db-1 bash << 'EOF'
# First, backup the original files
cp /var/lib/postgresql/data/pg_hba.conf /var/lib/postgresql/data/pg_hba.conf.bak
cp /var/lib/postgresql/data/pg_ident.conf /var/lib/postgresql/data/pg_ident.conf.bak

# Modify pg_ident.conf to add a proper mapping for ${DB_USER}
echo "# Added by fix script" >> /var/lib/postgresql/data/pg_ident.conf
echo "supabase_map    root            ${DB_USER}" >> /var/lib/postgresql/data/pg_ident.conf

# Modify pg_hba.conf to allow md5 authentication for ${DB_USER}
sed -i 's/local all  all                peer map=supabase_map/local all  all                md5/g' /var/lib/postgresql/data/pg_hba.conf

# Restart PostgreSQL within the container
pg_ctl -D /var/lib/postgresql/data reload
EOF

echo "Authentication configuration fixed. Restarting database container..."
docker restart ecommerceanalytics-supabase-db-1

echo "Waiting for database to start..."
sleep 10

echo "Fixing database permissions..."
docker exec -i ecommerceanalytics-supabase-db-1 psql -U postgres << 'EOF'
-- Grant privileges to ${DB_USER} user
ALTER USER ${DB_USER} WITH SUPERUSER;

-- Connect to ecommerce-db database
\c "ecommerce-db"

-- Create Airflow log table if it doesn't exist
CREATE TABLE IF NOT EXISTS log (
    id SERIAL PRIMARY KEY,
    dttm TIMESTAMP WITH TIME ZONE,
    event VARCHAR(500),
    owner VARCHAR(500),
    extra JSONB
);

-- Grant all privileges on olist schema and public schema
GRANT ALL PRIVILEGES ON SCHEMA public TO ${DB_USER};
GRANT ALL PRIVILEGES ON SCHEMA olist TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA olist TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA olist TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA olist TO ${DB_USER};

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA olist GRANT ALL ON TABLES TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA olist GRANT ALL ON SEQUENCES TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA olist GRANT ALL ON FUNCTIONS TO ${DB_USER};

-- Connect to metabase database and fix permissions
\c metabase

-- Create databasechangelog table if it doesn't exist in metabase
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

-- Grant permissions on metabase database
GRANT ALL PRIVILEGES ON SCHEMA public TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO ${DB_USER};
EOF

echo "Permissions and tables fixed successfully!"
echo "Restarting all containers to apply changes..."

docker restart ecommerceanalytics-metabase-1
docker restart ecommerceanalytics-airflow-scheduler-1
docker restart ecommerceanalytics-airflow-webserver-1

echo "Done! All services should now be running correctly."