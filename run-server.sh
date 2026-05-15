#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"
docker compose up -d mysql
for _ in {1..60}; do
  if [ "$(docker compose ps mysql --format '{{.Health}}' 2>/dev/null)" = "healthy" ]; then break; fi
  sleep 1
done
./db/apply-migrations.sh
make gateway zone

# Start zone in background, gateway in foreground.
hl out/zone.hl &
ZONE_PID=$!
trap "kill $ZONE_PID 2>/dev/null || true" EXIT
sleep 0.5
exec hl out/gateway.hl
