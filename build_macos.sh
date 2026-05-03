#!/bin/bash
set -e

# Build script for macOS using HashLink/C (HLC)
# Produces a native binary that does not require the hl interpreter.
#
# Works on both Intel (x86_64) and Apple Silicon (ARM64) Macs.
# NOTE: Homebrew's hashlink bottle is missing HLC symbols on some builds.
#       This script will auto-rebuild libhl.dylib from source if needed.

ARCH=$(uname -m)
PLATFORM=$(uname -s)

if [ "$PLATFORM" != "Darwin" ]; then
    echo "Error: This script is for macOS only."
    exit 1
fi

echo "Building for macOS ($ARCH)..."

# Auto-detect Homebrew prefix
if command -v brew &> /dev/null; then
    BREW_PREFIX=$(brew --prefix)
else
    echo "Error: Homebrew is required."
    exit 1
fi

HASHLINK=$(brew --prefix hashlink)
if [ ! -d "$HASHLINK" ]; then
    echo "Error: hashlink not found via Homebrew. Install with: brew install hashlink"
    exit 1
fi

HDLL="$HASHLINK/lib"

echo "HashLink: $HASHLINK"
echo "HDLL dir: $HDLL"

# Check if system libhl.dylib has HLC symbols
HAS_HLC_SYMBOLS=false
if nm -g "$HASHLINK/lib/libhl.dylib" 2>/dev/null | grep -q "hl_setup_callbacks"; then
    HAS_HLC_SYMBOLS=true
fi

LIBHL_PATH="$HASHLINK/lib"
if [ "$HAS_HLC_SYMBOLS" = false ]; then
    echo ""
    echo "WARNING: Homebrew's libhl.dylib is missing HLC symbols."
    echo "Rebuilding libhl.dylib from HashLink source..."
    
    CACHE_DIR="$HOME/.cache/haxecraft"
    mkdir -p "$CACHE_DIR"
    
    # Use HashLink 1.15 source (matches current Homebrew formula)
    HL_VERSION="1.15"
    HL_SRC="$CACHE_DIR/hashlink-$HL_VERSION"
    
    if [ ! -d "$HL_SRC" ]; then
        echo "Downloading HashLink $HL_VERSION source..."
        curl -sL "https://github.com/HaxeFoundation/hashlink/archive/refs/tags/$HL_VERSION.tar.gz" -o "$CACHE_DIR/hashlink-$HL_VERSION.tar.gz"
        tar -xzf "$CACHE_DIR/hashlink-$HL_VERSION.tar.gz" -C "$CACHE_DIR"
    fi
    
    if [ ! -f "$HL_SRC/libhl.dylib" ] || [ ! -f "$HL_SRC/.libhl_built" ]; then
        echo "Compiling libhl.dylib from source..."
        pushd "$HL_SRC" > /dev/null
        make clean 2>/dev/null || true
        # Build ONLY libhl target (skip extension libs that may fail on dependency mismatches)
        make libhl PREFIX="$BREW_PREFIX" -j$(sysctl -n hw.ncpu)
        touch .libhl_built
        popd > /dev/null
    fi
    
    LIBHL_PATH="$HL_SRC"
    echo "Using rebuilt libhl.dylib from: $LIBHL_PATH"
fi

echo ""
echo "Generating C code..."
mkdir -p out
haxe -lib heaps -lib hlsdl -lib hlopenal -D hlopenal -cp src -main Game -D resourcesPath=res -hl out/main.c

echo "Compiling native binary..."
clang -O2 -o haxecraft out/main.c \
    -Iout \
    -I"$HASHLINK/include" \
    -L"$LIBHL_PATH" \
    -L"$BREW_PREFIX/lib" \
    -Wl,-rpath,"$LIBHL_PATH" \
    -Wl,-rpath,"$BREW_PREFIX/lib" \
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
    -framework OpenAL \
    -lpthread -lm

echo ""
echo "Build complete: ./haxecraft"
