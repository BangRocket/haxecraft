#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
for f in "$HERE"/migrations/*.sql; do
  echo "applying $(basename "$f")"
  docker exec -i haxecraft-mysql mysql -uhaxecraft -pdev_local_only haxecraft < "$f"
done
