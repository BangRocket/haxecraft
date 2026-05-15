#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$HERE/.." && pwd)"
for f in "$HERE"/migrations/*.sql; do
  echo "applying $(basename "$f")"
  (cd "$PROJECT_ROOT" && docker compose exec -T mysql mysql --protocol=tcp -h 127.0.0.1 -uhaxecraft -pdev_local_only haxecraft) < "$f"
done
