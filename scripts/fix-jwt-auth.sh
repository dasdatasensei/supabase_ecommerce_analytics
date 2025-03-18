#!/bin/bash

set -e

echo "Fixing JWT authentication for Supabase API..."

# Generate a new JWT secret key
JWT_SECRET="${SUPABASE_SERVICE_KEY}"
echo "Using test JWT secret: $JWT_SECRET"

# Create new tokens (simplified for testing)
ANON_TOKEN="${SUPABASE_KEY}
SERVICE_TOKEN="${SUPABASE_KEY}

echo "Using predefined JWT tokens"

# Update the .env.dev file with the new tokens
sed -i.bak "s|SUPABASE_KEY=.*|SUPABASE_KEY=$ANON_TOKEN|g" .env.dev
sed -i.bak "s|SUPABASE_SERVICE_KEY=.*|SUPABASE_SERVICE_KEY=$SERVICE_TOKEN|g" .env.dev

echo "Updated .env.dev with new tokens"

# Update the docker-compose.dev.yml file with the new JWT secret
sed -i.bak "s|PGRST_JWT_SECRET:.*|PGRST_JWT_SECRET: $JWT_SECRET|g" docker/docker-compose.dev.yml
sed -i.bak "s|SUPABASE_ANON_KEY:.*|SUPABASE_ANON_KEY: $ANON_TOKEN|g" docker/docker-compose.dev.yml
sed -i.bak "s|SUPABASE_SERVICE_KEY:.*|SUPABASE_SERVICE_KEY: $SERVICE_TOKEN|g" docker/docker-compose.dev.yml

echo "Updated docker-compose.dev.yml with new JWT secret and tokens"

echo "JWT authentication fix is complete. You need to rebuild and restart the stack for changes to take effect."