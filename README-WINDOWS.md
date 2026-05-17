# Running Haxecraft on Windows

The game logic is portable (HashLink bytecode is cross-platform). Only the
toolchain, the native `.hdll` libraries, and the dev scripts are
platform-specific. This is the Windows path; see `README-M0.md` for the
macOS/Linux original.

## 1. Install the toolchain

- **Haxe 4.3+** — installer from <https://haxe.org/download/>
- **HashLink 1.15** — Windows release `hashlink-1.15.0-win.zip` from
  <https://github.com/HaxeFoundation/hashlink/releases>. Unzip it somewhere
  stable (e.g. `C:\HashLink`) and add that dir to `PATH` so `hl.exe` resolves.
  The release also ships the Windows `.hdll` native libraries (including
  `mysql.hdll`, used by the server) and the C headers + `libhl.lib` needed
  to build `stbtt.hdll` (step 3).
- **Docker Desktop for Windows** — for the MySQL container.
- Haxe libraries — install them one per command (`haxelib install` treats
  extra arguments as a version, not a second library):

  ```powershell
  haxelib install heaps
  haxelib install hlsdl
  haxelib install hlopenal
  haxelib install utest
  ```

## 2. Native `.hdll` libraries

HashLink loads `.hdll` files as platform-native shared libraries, so two of
them are vendored per-OS under `prebuilt/` — see `prebuilt/README.md`:

```
prebuilt/windows/  ssl.hdll  stbtt.hdll
prebuilt/macos/    ssl.hdll  stbtt.hdll
```

The `run-*.ps1` scripts call `tools/sync-hdll.ps1`, which copies the Windows
copies into the repo root (where `hl` looks) on every launch — so normally
there is nothing to do here. To do it manually: `.\tools\sync-hdll.ps1`.

- **`stbtt.hdll`** — a custom binding; if `prebuilt/windows/stbtt.hdll` is
  missing or stale, rebuild it (step 3).
- `sdl.hdll`, `openal.hdll`, `fmt.hdll`, `ui.hdll`, `uv.hdll`, `mysql.hdll`
  come from the HashLink release (next to `hl.exe`) and need no handling.

## 3. Build `stbtt.hdll` for Windows

The TTF font pipeline binds `stbtt.hdll`. Source lives in `tools/hl-stbtt/`.
Requires **Visual Studio Build Tools 2022** with the "Desktop development
with C++" workload (`VC.Tools.x86.x64`):

```powershell
winget install --id Microsoft.VisualStudio.2022.BuildTools `
  --override "--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
```

Then build (compiles `stbtt_hl.c` directly with `cl` — no CMake needed):

```powershell
cd tools\hl-stbtt
.\build-windows.ps1                          # HashLink assumed at C:\HashLink
# .\build-windows.ps1 -HashlinkDir D:\hl     # or pass a custom location
```

This compiles `stbtt.hdll` and writes it to `prebuilt/windows/`; the
`run-*` scripts then sync it into the repo root. (`CMakeLists.txt` is kept
for the macOS/Linux build path.)

## 4. Database

`docker-compose.yml` is platform-neutral. The `mysql_native_password` caveat
in `README-M0.md` still applies.

## 5. Run

PowerShell equivalents of the `.sh` runners (these call `haxe` directly, so
`make` is not required):

```powershell
.\run-server.ps1      # MySQL + migrations + build + run server
.\run-client.ps1      # build + run client
.\run.ps1             # standalone game build (HashLink JIT)
.\run-integration.ps1 # full build + integration tests
```

Create an account once the server build exists:

```powershell
docker compose up -d mysql
.\db\apply-migrations.ps1
cd server; haxe build-server-cli.hxml; cd ..
hl out\server-cli.hl create-account joshua hunter2
```

## Not ported

`build_macos.sh` (native HLC binary via clang + Cocoa frameworks) has no
Windows equivalent. Running through the `hl` interpreter is cross-platform
and sufficient for development. A native Windows `.exe` would need a separate
HLC + MSVC build script — not yet written.
