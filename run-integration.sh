#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

# Bring up MySQL
docker compose up -d mysql
for _ in {1..60}; do
  if docker inspect haxecraft-mysql 2>/dev/null | grep -q '"Status": "healthy"'; then break; fi
  sleep 1
done

# Apply migrations (idempotent)
./db/apply-migrations.sh

# Build
make all

# Start server in background
hl out/server.hl > /tmp/integration-server.log 2>&1 &
SERVER_PID=$!
trap "kill $SERVER_PID 2>/dev/null || true" EXIT
sleep 1  # give server a moment to listen

# Run server tests (includes login-flow integration test)
make server-test
