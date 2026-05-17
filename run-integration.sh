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

# Build. Apple Silicon Macs have no `hl` JIT VM — fall back to native HLC.
if command -v hl >/dev/null 2>&1; then
  make all
  ZONE_CMD=(hl out/zone.hl); GATEWAY_CMD=(hl out/gateway.hl)
  RUN_SERVER_TEST=(make server-test)
else
  ./build_native.sh zone gateway server-test
  ZONE_CMD=(./bin/zone); GATEWAY_CMD=(./bin/gateway)
  RUN_SERVER_TEST=(./bin/server-test)
fi

# Start zone + gateway in background (zone first so it's listening when client tries to handoff)
"${ZONE_CMD[@]}" > /tmp/integration-zone.log 2>&1 &
ZONE_PID=$!
"${GATEWAY_CMD[@]}" > /tmp/integration-gateway.log 2>&1 &
GW_PID=$!
trap "kill $ZONE_PID $GW_PID 2>/dev/null || true" EXIT
sleep 1

# Run server tests (includes login-flow integration test)
"${RUN_SERVER_TEST[@]}"
