#!/bin/sh
set -e
 
echo "Starting Next.js (standalone)..."
node /app/server.js &
 
echo "Starting Nginx..."
exec nginx -g "daemon off;"