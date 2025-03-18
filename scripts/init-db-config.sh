#!/bin/bash
set -e

# This script should be mounted in the docker-compose file as:
# - ./init-db-config.sh:/docker-entrypoint-initdb.d/init-db-config.sh

echo "Running custom database initialization..."

# Grant superuser to ${DB_USER}
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Update authentication method
    ALTER USER ${DB_USER} WITH PASSWORD '${DB_USER}';
    ALTER USER ${DB_USER} WITH SUPERUSER;

    -- Create olist schema
    CREATE SCHEMA IF NOT EXISTS olist;

    -- Create auth schema for Supabase Auth
    CREATE SCHEMA IF NOT EXISTS auth;

    -- Grant permissions on olist schema
    GRANT ALL PRIVILEGES ON SCHEMA olist TO ${DB_USER};
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA olist TO ${DB_USER};
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA olist TO ${DB_USER};
    GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA olist TO ${DB_USER};

    -- Grant permissions on auth schema
    GRANT ALL PRIVILEGES ON SCHEMA auth TO ${DB_USER};
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA auth TO ${DB_USER};
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA auth TO ${DB_USER};
    GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA auth TO ${DB_USER};

    -- Set default privileges for olist schema
    ALTER DEFAULT PRIVILEGES IN SCHEMA olist GRANT ALL ON TABLES TO ${DB_USER};
    ALTER DEFAULT PRIVILEGES IN SCHEMA olist GRANT ALL ON SEQUENCES TO ${DB_USER};
    ALTER DEFAULT PRIVILEGES IN SCHEMA olist GRANT ALL ON FUNCTIONS TO ${DB_USER};

    -- Set default privileges for auth schema
    ALTER DEFAULT PRIVILEGES IN SCHEMA auth GRANT ALL ON TABLES TO ${DB_USER};
    ALTER DEFAULT PRIVILEGES IN SCHEMA auth GRANT ALL ON SEQUENCES TO ${DB_USER};
    ALTER DEFAULT PRIVILEGES IN SCHEMA auth GRANT ALL ON FUNCTIONS TO ${DB_USER};

    -- Set search path
    ALTER USER ${DB_USER} SET search_path TO olist, auth, public;
EOSQL

echo "Database initialization complete!"