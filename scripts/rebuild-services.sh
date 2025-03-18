#!/bin/bash

set -e

echo "Rebuilding and restarting all services..."

# Stop all running containers
echo "Stopping all running containers..."
docker-compose -f docker/docker-compose.dev.yml down

# Apply JWT authentication fixes
echo "Applying JWT authentication fixes..."
chmod +x fix-jwt-auth.sh
./fix-jwt-auth.sh

# Rebuild and start the services
echo "Rebuilding and starting services..."
docker-compose -f docker/docker-compose.dev.yml up -d

# Wait for services to start
echo "Waiting for services to start..."
sleep 30

# Apply database permission fixes
echo "Applying database permission fixes..."
chmod +x fix-olist-permissions.sh
./fix-olist-permissions.sh

echo "All services have been rebuilt and restarted."
echo "You can now access:"
echo "- Supabase API: http://localhost:3000"
echo "- Supabase Studio: http://localhost:8082"
echo "- Metabase: http://localhost:3333"
echo "- Airflow: http://localhost:8080"