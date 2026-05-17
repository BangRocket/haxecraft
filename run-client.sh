#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"
bash "$HERE/tools/sync-hdll.sh"

# Apple Silicon Macs have no `hl` JIT VM — fall back to native HLC binary.
if command -v hl >/dev/null 2>&1; then
  make client
  exec hl out/client.hl
else
  ./build_native.sh client
  exec ./bin/client
fi
