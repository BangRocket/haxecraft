#!/bin/bash
# Quick development runner using HashLink JIT
# For a standalone native binary, use ./build_macos.sh

set -e

if [ ! -f "haxecraft.hl" ]; then
    echo "Building haxecraft.hl..."
    haxe build.hxml
fi

echo "Running Haxecraft..."
hl haxecraft.hl "$@"
