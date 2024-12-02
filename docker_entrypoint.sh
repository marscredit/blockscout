#!/bin/bash
set -e

echo "Checking database setup..."

echo "Waiting for database to be ready..."
until psql $DATABASE_URL -c '\q'; do
  >&2 echo "Postgres is unavailable - sleeping"
  sleep 2
done

# Check if the database is already initialized by looking for a key table
if psql "${DATABASE_URL}" -c '\dt' | grep -q 'blocks'; then
  echo "Database already initialized. Skipping migrations."
else
  echo "Database not initialized. Running setup..."
  mix ecto.create
  mix ecto.migrate
fi

# Start the application
echo "Starting the application..."
exec mix phx.server