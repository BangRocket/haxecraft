#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"
docker compose up -d mysql
for _ in {1..60}; do
  if docker inspect haxecraft-mysql 2>/dev/null | grep -q '"Status": "healthy"'; then break; fi
  sleep 1
done
./db/apply-migrations.sh
make server
exec hl out/server.hl
