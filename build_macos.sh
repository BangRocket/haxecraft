#!/bin/bash
set -e

# Build script for ARM macOS using HashLink/C (HLC)
# The hl JIT VM is not available on ARM, so we compile to native C instead.

export HAXE_STD_PATH="/opt/homebrew/lib/haxe/std"

HASHLINK="/opt/homebrew/Cellar/hashlink/1.15_1"
HDLL="$HASHLINK/lib"

echo "Generating C code..."
mkdir -p out
haxe -lib heaps -lib hlsdl -lib hlopenal -D hlopenal -cp src -main com.mojang.ld22.Game -D resourcesPath=res -hl out/main.c

echo "Compiling native binary..."
clang -O2 -o minicraft out/main.c \
    -Iout \
    -I"$HASHLINK/include" \
    -L"$HASHLINK/lib" \
    -L/opt/homebrew/lib \
    -lhl -luv \
    "$HDLL/ui.hdll" \
    "$HDLL/openal.hdll" \
    "$HDLL/uv.hdll" \
    "$HDLL/fmt.hdll" \
    "$HDLL/sdl.hdll" \
    -framework CoreFoundation \
    -framework Security \
    -framework OpenGL \
    -framework Cocoa \
    -framework IOKit \
    -framework CoreVideo \
    -lpthread -lm

echo "Build complete: ./minicraft"
