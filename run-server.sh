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

# Each process gets a FIFO as stdin. Closing our writer end (in cleanup)
# delivers EOF to the child, which triggers graceful shutdown (character
# save, socket+DB close). SIGTERM is used as a fallback.
RUN_TMP="$(mktemp -d -t haxecraft-run.XXXXXX)"
ZONE_FIFO="$RUN_TMP/zone.fifo"
GW_FIFO="$RUN_TMP/gw.fifo"
mkfifo "$ZONE_FIFO" "$GW_FIFO"
# Open RW so the open() doesn't block before the child runs; bash holds the
# only writer ends, so closing fds 3/4 drops the writer count to 0 → EOF.
exec 3<>"$ZONE_FIFO" 4<>"$GW_FIFO"

"${ZONE_CMD[@]}" 0<"$ZONE_FIFO" &
ZONE_PID=$!
sleep 0.5
"${GATEWAY_CMD[@]}" 0<"$GW_FIFO" &
GW_PID=$!

cleanup() {
  trap - INT TERM EXIT
  echo ""
  echo "[run-server] shutting down (closing stdin fifos)..."
  exec 3>&- 4>&- || true
  # Wait up to 5s for graceful exit.
  for _ in {1..50}; do
    kill -0 "$ZONE_PID" 2>/dev/null || kill -0 "$GW_PID" 2>/dev/null || break
    sleep 0.1
  done
  # Anyone still alive gets SIGTERM, then SIGKILL.
  kill -TERM "$ZONE_PID" "$GW_PID" 2>/dev/null || true
  sleep 0.3
  kill -KILL "$ZONE_PID" "$GW_PID" 2>/dev/null || true
  rm -rf "$RUN_TMP"
}
trap cleanup INT TERM EXIT

# Wait for either process; if either exits, tear down the other via the trap.
wait -n "$ZONE_PID" "$GW_PID" 2>/dev/null || wait "$GW_PID" 2>/dev/null || true
