#!/bin/sh

echo "Waiting for Metabase to start..."
while ! curl -s http://metabase:3000/api/health | grep -q '"status":"ok"'; do
  echo "Metabase not up yet, retrying in 5s..."
  sleep 5
done

echo "Waiting for Postgres to accept connections..."
while ! nc -z postgres 5432; do
  echo "Postgres not ready yet, retrying in 3s..."
  sleep 3
done
echo "Postgres is up! Waiting 5 more seconds to be safe..."
sleep 5

echo "Checking setup token..."
TOKEN=$(curl -s http://metabase:3000/api/session/properties | jq -r '.["setup-token"]')

if [ "$TOKEN" = "null" ] || [ -z "$TOKEN" ]; then
    echo "Token already consumed. Logging in to add DB..."
    SESSION=$(curl -s -X POST http://metabase:3000/api/session \
      -H "Content-Type: application/json" \
      -d '{"username":"calificar@uvg.edu.gt","password":"secret123+"}')
    TOKEN_SESSION=$(echo "$SESSION" | jq -r '.id')

    curl -s -X POST http://metabase:3000/api/database \
      -H "Content-Type: application/json" \
      -H "X-Metabase-Session: $TOKEN_SESSION" \
      -d '{
        "name": "RetailMax DB",
        "engine": "postgres",
        "details": {
          "host": "postgres",
          "port": 5432,
          "dbname": "retailmax",
          "user": "rm_user",
          "password": "rm_password"
        }
      }'
    echo "DB added. Done."
    exit 0
fi

echo "Got setup token: $TOKEN. Running full setup..."
RESPONSE=$(curl -s -X POST http://metabase:3000/api/setup \
  -H "Content-Type: application/json" \
  -d '{
    "token": "'"$TOKEN"'",
    "user": {
      "first_name": "Admin",
      "last_name": "Calificador",
      "email": "calificar@uvg.edu.gt",
      "password": "secret123+",
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

echo "Response: $RESPONSE"
echo "Setup complete."