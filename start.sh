!/bin/sh
set -e

echo "==============================="
echo " Starting Next.js Application"
echo " Port: $PORT"
echo " User: $(whoami)"
echo "==============================="

# Check if build output exists
if [ ! -f ".next/standalone/server.js" ]; then
  echo "ERROR: .next/standalone/server.js not found!"
  exit 1
fi

echo "Build output verified. Starting server..."

exec node .next/standalone/server.js