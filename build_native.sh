#!/usr/bin/env bash
#
# Native build via HashLink/C (HLC) for macOS and Linux.
#
# Transpiles each Haxe target to C and compiles a native binary into `bin/`.
# Detects OS (Darwin/Linux) and CPU arch (x86_64/arm64) and links the right
# libraries for the host.
#
#   macOS arm64 (M1/M2/M3) : REQUIRED — Homebrew ships no `hl` JIT on ARM.
#   macOS x86_64           : optional — the `hl` JIT also works on Intel.
#   Linux x86_64/arm64     : optional — the `hl` JIT also works on Linux.
#
# Windows: use build_native.ps1 instead (this is a bash script).
#
# Usage:
#   ./build_native.sh [target ...]
#
# Targets: worldgen-tmx server-cli gateway zone shared-test server-test client
# With no args, builds everything.
#
# Env overrides:
#   HASHLINK  Linux only — root of a HashLink install (expects lib/ + include/).
#   CC        compiler to use (default: clang on macOS, cc on Linux).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

# ---- OS / arch detection ---------------------------------------------------
OS_RAW="$(uname -s)"
ARCH_RAW="$(uname -m)"

case "$ARCH_RAW" in
  arm64|aarch64) ARCH=arm64 ;;
  x86_64|amd64)  ARCH=x86_64 ;;
  *) echo "build_native.sh: unsupported CPU arch '$ARCH_RAW'." >&2; exit 1 ;;
esac

case "$OS_RAW" in
  Darwin) PLATFORM=macos ;;
  Linux)  PLATFORM=linux ;;
  MINGW*|MSYS*|CYGWIN*)
    echo "build_native.sh: this is the POSIX builder. On Windows run build_native.ps1." >&2
    exit 1 ;;
  *) echo "build_native.sh: unsupported OS '$OS_RAW'." >&2; exit 1 ;;
esac

echo "Native build target: $PLATFORM/$ARCH"

# ---- platform setup --------------------------------------------------------
# Each branch populates:
#   HL_INCLUDE  dir containing hlc.h
#   HL_LIB      dir containing libhl + the .hdll native libs
#   CC          compiler
#   LDFLAGS_COMMON   array — link flags shared by every target
#   SYS_HEADLESS     array — extra system libs for headless targets
#   SYS_CLIENT       array — extra system libs for the GUI client

setup_macos() {
  command -v brew >/dev/null || { echo "Homebrew required on macOS." >&2; exit 1; }
  local brew_prefix; brew_prefix="$(brew --prefix)"
  local h; h="$(brew --prefix hashlink)"
  [ -d "$h" ] || { echo "hashlink not found: brew install hashlink" >&2; exit 1; }

  # NB: capture nm output first — piping into `grep -q` under `set -o pipefail`
  # trips a SIGPIPE false-negative when grep exits before nm finishes.
  local syms; syms="$(nm -g "$h/lib/libhl.dylib" 2>/dev/null || true)"
  if ! printf '%s' "$syms" | grep -q hl_setup_callbacks; then
    echo "ERROR: $h/lib/libhl.dylib is missing HLC symbols." >&2
    echo "Reinstall hashlink or rebuild libhl from source." >&2
    exit 1
  fi

  HL_INCLUDE="$h/include"
  HL_LIB="$h/lib"
  CC="${CC:-clang}"
  LDFLAGS_COMMON=( -L"$h/lib" -L"$brew_prefix/lib"
                   -Wl,-rpath,"$h/lib" -Wl,-rpath,"$brew_prefix/lib" -lhl )
  SYS_HEADLESS=( -lpthread -lm )
  SYS_CLIENT=( -luv -lpthread -lm
               -framework CoreFoundation -framework Security -framework OpenGL
               -framework Cocoa -framework IOKit -framework CoreVideo
               -framework OpenAL )
}

setup_linux() {
  local root="${HASHLINK:-}"
  if [ -z "$root" ]; then
    for c in /usr/local /usr; do
      if [ -f "$c/include/hlc.h" ] && [ -f "$c/lib/libhl.so" ]; then root="$c"; break; fi
    done
  fi
  [ -n "$root" ] || {
    echo "ERROR: HashLink not found. Install it (lib/libhl.so + include/hlc.h)" >&2
    echo "or set HASHLINK=/path/to/hashlink." >&2
    exit 1
  }
  [ -f "$root/include/hlc.h" ] || { echo "ERROR: $root/include/hlc.h missing." >&2; exit 1; }

  HL_INCLUDE="$root/include"
  HL_LIB="$root/lib"
  CC="${CC:-cc}"
  LDFLAGS_COMMON=( -L"$root/lib" -Wl,-rpath,"$root/lib" -lhl )
  SYS_HEADLESS=( -lm -lpthread -ldl )
  SYS_CLIENT=( -luv -lGL -lm -lpthread -ldl )
}

case "$PLATFORM" in
  macos) setup_macos ;;
  linux) setup_linux ;;
esac

mkdir -p bin out/c

# ---- build helpers ---------------------------------------------------------

# gen_c <name> <build-dir> <hxml-flags...>  -- transpile Haxe -> C.
gen_c() {
  local name="$1"; shift
  local dir="$1"; shift
  mkdir -p "out/c/$name"
  echo "  haxe -> out/c/$name/$name.c"
  ( cd "$dir" && haxe "$@" -hl "$HERE/out/c/$name/$name.c" )
}

# hdll <name>  -- absolute path to a HashLink native lib.
hdll() { printf '%s/%s.hdll' "$HL_LIB" "$1"; }

# compile <name> <extra link args...>
compile() {
  local name="$1"; shift
  echo "  $CC -> bin/$name"
  "$CC" -O2 -I"$HL_INCLUDE" -I"out/c/$name" \
    -o "bin/$name" "out/c/$name/$name.c" \
    "${LDFLAGS_COMMON[@]}" "$@"
}

# ---- targets ---------------------------------------------------------------

build_worldgen_tmx() {
  echo "[worldgen-tmx]"
  gen_c worldgen-tmx tools/worldgen-tmx -cp src -cp ../../shared/src -main Main
  compile worldgen-tmx "${SYS_HEADLESS[@]}"
}

build_server_cli() {
  echo "[server-cli]"
  gen_c server-cli server -cp src -cp ../shared/src -main server.ServerCliMain
  compile server-cli "$(hdll mysql)" "$(hdll fmt)" "${SYS_HEADLESS[@]}"
}

build_gateway() {
  echo "[gateway]"
  gen_c gateway server -cp src -cp ../shared/src -lib utest -main server.gateway.Main -D analyzer-optimize
  compile gateway "$(hdll mysql)" "$(hdll fmt)" "${SYS_HEADLESS[@]}"
}

build_zone() {
  echo "[zone]"
  gen_c zone server -cp src -cp ../shared/src -lib utest -main server.zone.Main -D analyzer-optimize
  compile zone "$(hdll mysql)" "$(hdll fmt)" "${SYS_HEADLESS[@]}"
}

build_shared_test() {
  echo "[shared-test]"
  gen_c shared-test shared -cp src -cp test -lib utest -main TestMain -D analyzer-optimize
  compile shared-test "$(hdll fmt)" "${SYS_HEADLESS[@]}"
}

build_server_test() {
  echo "[server-test]"
  gen_c server-test server -cp src -cp test -cp ../shared/src -cp ../client/src/headless -lib utest -main TestMain
  compile server-test "$(hdll mysql)" "$(hdll fmt)" "${SYS_HEADLESS[@]}"
}

build_client() {
  echo "[client]"
  gen_c client client -cp src -cp ../shared/src -cp ../engine/src -lib heaps -lib hlsdl \
    -main client.Main -D resourcesPath=../res -D analyzer-optimize
  compile client \
    "$(hdll sdl)" "$(hdll ui)" "$(hdll fmt)" "$(hdll openal)" "$(hdll uv)" \
    "${SYS_CLIENT[@]}"
}

# ---- dispatch --------------------------------------------------------------

ALL=(worldgen-tmx server-cli gateway zone shared-test server-test client)
TARGETS=("$@")
[ ${#TARGETS[@]} -eq 0 ] && TARGETS=("${ALL[@]}")

for t in "${TARGETS[@]}"; do
  case "$t" in
    worldgen-tmx) build_worldgen_tmx ;;
    server-cli)   build_server_cli ;;
    gateway)      build_gateway ;;
    zone)         build_zone ;;
    shared-test)  build_shared_test ;;
    server-test)  build_server_test ;;
    client)       build_client ;;
    *) echo "unknown target: $t" >&2; exit 1 ;;
  esac
done

echo ""
echo "Done ($PLATFORM/$ARCH). Native binaries in bin/:"
ls -1 bin/
