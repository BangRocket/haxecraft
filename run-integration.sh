#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"
bash "$HERE/tools/sync-hdll.sh"

# Bring up MySQL
docker compose up -d mysql
for _ in {1..60}; do
  if [ "$(docker compose ps mysql --format '{{.Health}}' 2>/dev/null)" = "healthy" ]; then break; fi
  sleep 1
done

# Apply migrations (idempotent)
./db/apply-migrations.sh

# Build
make all

# Start zone + gateway in background (zone first so it's listening when client tries to handoff)
hl out/zone.hl > /tmp/integration-zone.log 2>&1 &
ZONE_PID=$!
hl out/gateway.hl > /tmp/integration-gateway.log 2>&1 &
GW_PID=$!
trap "kill $ZONE_PID $GW_PID 2>/dev/null || true" EXIT
sleep 1

# Run server tests (includes login-flow integration test)
make server-test
