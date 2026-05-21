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

# Both server binaries watch stdin for EOF (see Main.hx shutdown thread).
# An unattached stdin EOFs immediately and they'd shut down before the
# tests can connect. Give each one a fifo whose writer end this script
# holds; closing fds 3/4 on EXIT delivers EOF and triggers graceful shutdown.
RUN_TMP="$(mktemp -d -t haxecraft-integration.XXXXXX)"
ZONE_FIFO="$RUN_TMP/zone.fifo"
GW_FIFO="$RUN_TMP/gw.fifo"
mkfifo "$ZONE_FIFO" "$GW_FIFO"
exec 3<>"$ZONE_FIFO" 4<>"$GW_FIFO"

"${ZONE_CMD[@]}" 0<"$ZONE_FIFO" > /tmp/integration-zone.log 2>&1 &
ZONE_PID=$!
"${GATEWAY_CMD[@]}" 0<"$GW_FIFO" > /tmp/integration-gateway.log 2>&1 &
GW_PID=$!
cleanup() {
  trap - EXIT
  exec 3>&- 4>&- || true
  for _ in {1..20}; do
    kill -0 "$ZONE_PID" 2>/dev/null || kill -0 "$GW_PID" 2>/dev/null || break
    sleep 0.1
  done
  kill "$ZONE_PID" "$GW_PID" 2>/dev/null || true
  rm -rf "$RUN_TMP"
}
trap cleanup EXIT
sleep 1

# Run server tests (includes login-flow integration test)
"${RUN_SERVER_TEST[@]}"
