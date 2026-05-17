#!/bin/bash
# Quick development runner using HashLink JIT
# For a standalone native binary, use ./build_macos.sh

set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
bash "$HERE/tools/sync-hdll.sh"

if [ ! -f "haxecraft.hl" ]; then
    echo "Building haxecraft.hl..."
    haxe build.hxml
fi

echo "Running Haxecraft..."
hl haxecraft.hl "$@"
