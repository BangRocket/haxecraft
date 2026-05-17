#!/usr/bin/env bash
# Copies the prebuilt .hdll native libraries for the current OS into the repo
# root, where `hl` loads them at runtime. Idempotent — safe to run every
# launch. The run-*.sh scripts call this automatically.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

case "$(uname -s)" in
  Darwin) OS=macos ;;
  Linux)  OS=linux ;;
  *)      echo "sync-hdll: unsupported OS $(uname -s)" >&2; exit 1 ;;
esac

SRC="$ROOT/prebuilt/$OS"
if [ ! -d "$SRC" ]; then
  echo "sync-hdll: no prebuilt binaries for $OS ($SRC)" >&2
  exit 1
fi

cp "$SRC"/*.hdll "$ROOT/"
