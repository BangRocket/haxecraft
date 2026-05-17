#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"
bash "$HERE/tools/sync-hdll.sh"
docker compose up -d mysql
for _ in {1..60}; do
  if [ "$(docker compose ps mysql --format '{{.Health}}' 2>/dev/null)" = "healthy" ]; then break; fi
  sleep 1
done
./db/apply-migrations.sh

# Apple Silicon Macs have no `hl` JIT VM — fall back to native HLC binaries.
if command -v hl >/dev/null 2>&1; then
  make gateway zone
  ZONE_CMD=(hl out/zone.hl); GATEWAY_CMD=(hl out/gateway.hl)
else
  ./build_native.sh gateway zone
  ZONE_CMD=(./bin/zone); GATEWAY_CMD=(./bin/gateway)
fi

# Start zone in background, gateway in foreground.
"${ZONE_CMD[@]}" &
ZONE_PID=$!
trap "kill $ZONE_PID 2>/dev/null || true" EXIT
sleep 0.5
exec "${GATEWAY_CMD[@]}"
