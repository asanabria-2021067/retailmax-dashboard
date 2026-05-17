#!/bin/sh

echo "Waiting for Metabase to start..."

# Wait until the API is up
while ! curl -s http://metabase:3000/api/health | grep -q '"status":"ok"'; do
  echo "Metabase is not up yet, retrying in 5 seconds..."
  sleep 5
done

echo "Metabase is up! Checking setup token..."

# Get the setup token
TOKEN=$(curl -s http://metabase:3000/api/session/properties | jq -r '.["setup-token"]')

if [ "$TOKEN" = "null" ] || [ -z "$TOKEN" ]; then
    echo "Metabase is already set up or token not found."
    exit 0
fi

echo "Got setup token: $TOKEN. Proceeding with setup..."

# Perform setup
RESPONSE=$(curl -s -X POST http://metabase:3000/api/setup \
  -H "Content-Type: application/json" \
  -d '{
    "token": "'"$TOKEN"'",
    "user": {
      "first_name": "Admin",
      "last_name": "Evaluador",
      "email": "evaluador@retailmax.com",
      "password": "Password123!",
      "site_name": "RetailMax Analytics"
    },
    "prefs": {
      "site_name": "RetailMax Analytics",
      "site_locale": "es",
      "allow_tracking": false
    },
    "database": {
      "name": "RetailMax DB",
      "engine": "postgres",
      "details": {
        "host": "postgres",
        "port": 5432,
        "dbname": "retailmax",
        "user": "rm_user",
        "password": "rm_password"
      }
    }
  }')

echo "Setup completed."
echo "Response: $RESPONSE"
