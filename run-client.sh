#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"
bash "$HERE/tools/sync-hdll.sh"
make client
exec hl out/client.hl
