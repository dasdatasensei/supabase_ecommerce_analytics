#!/bin/bash
set -e

# Create the metabase user first
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE USER metabase WITH PASSWORD 'metabase';
EOSQL

# Create the metabase database
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE metabase;
    GRANT ALL PRIVILEGES ON DATABASE metabase TO metabase;
    GRANT ALL PRIVILEGES ON DATABASE metabase TO $POSTGRES_USER;
    \c metabase
    CREATE SCHEMA IF NOT EXISTS public;
    GRANT ALL ON SCHEMA public TO metabase;
    GRANT ALL PRIVILEGES ON SCHEMA public TO metabase;
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO metabase;
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO metabase;
    GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO metabase;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO metabase;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO metabase;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO metabase;
    ALTER DATABASE metabase OWNER TO metabase;
EOSQL

echo "Metabase database initialized successfully"

# Create the user-specified database if different from postgres
if [ "$POSTGRES_DB" != "$DB_NAME" ] && [ ! -z "$DB_NAME" ]; then
    echo "Creating database $DB_NAME..."
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        CREATE DATABASE "$DB_NAME";
        GRANT ALL PRIVILEGES ON DATABASE "$DB_NAME" TO $POSTGRES_USER;
    EOSQL

    # Create schema and extensions for Supabase
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$DB_NAME" <<-EOSQL
        CREATE SCHEMA IF NOT EXISTS "$DB_SCHEMA";
        GRANT ALL ON SCHEMA "$DB_SCHEMA" TO $POSTGRES_USER;
        GRANT ALL PRIVILEGES ON SCHEMA "$DB_SCHEMA" TO $POSTGRES_USER;
        CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
        CREATE EXTENSION IF NOT EXISTS "pgcrypto";
    EOSQL

    echo "Database $DB_NAME with schema $DB_SCHEMA initialized successfully"
fi

# Set up supabase-specific schemas and extensions
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    CREATE EXTENSION IF NOT EXISTS "pgcrypto";
    CREATE SCHEMA IF NOT EXISTS auth;
    CREATE SCHEMA IF NOT EXISTS storage;
    CREATE SCHEMA IF NOT EXISTS graphql;
    CREATE SCHEMA IF NOT EXISTS realtime;
    GRANT ALL ON SCHEMA auth TO $POSTGRES_USER;
    GRANT ALL ON SCHEMA storage TO $POSTGRES_USER;
    GRANT ALL ON SCHEMA graphql TO $POSTGRES_USER;
    GRANT ALL ON SCHEMA realtime TO $POSTGRES_USER;
EOSQL

echo "Supabase schemas and extensions initialized successfully"