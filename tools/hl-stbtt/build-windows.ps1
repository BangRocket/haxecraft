# Builds stbtt.hdll for Windows with MSVC and installs it to the repo root,
# replacing the vendored macOS binary.
#
# Requires: Visual Studio Build Tools 2022 with the "Desktop development with
# C++" / VC.Tools.x86.x64 workload, and a HashLink release (for hl.h +
# libhl.lib). No CMake needed — this compiles stbtt_hl.c directly.
#
# Usage:
#   .\build-windows.ps1                       # HashLink assumed at C:\HashLink
#   .\build-windows.ps1 -HashlinkDir D:\hl    # custom HashLink location
param(
    [string]$HashlinkDir = 'C:\HashLink'
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

if (-not (Test-Path "$HashlinkDir\include\hl.h")) {
    throw "hl.h not found under '$HashlinkDir\include' — pass -HashlinkDir <path>"
}
if (-not (Test-Path "$HashlinkDir\libhl.lib")) {
    throw "libhl.lib not found in '$HashlinkDir' — pass -HashlinkDir <path>"
}

# Locate the MSVC environment script via vswhere.
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $vswhere)) {
    throw 'vswhere.exe not found — install Visual Studio Build Tools 2022 with the C++ workload'
}
$vsPath = & $vswhere -latest -products * `
    -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
    -property installationPath
if (-not $vsPath) { throw 'No MSVC C++ toolset found — install the VC.Tools.x86.x64 workload' }
$vcvars = Join-Path $vsPath 'VC\Auxiliary\Build\vcvars64.bat'

# Compile in a child cmd that has the MSVC environment loaded.
$cl = "cl /nologo /O2 /LD /I`"$HashlinkDir\include`" stbtt_hl.c " +
      "/Fe:stbtt.hdll /link /LIBPATH:`"$HashlinkDir`" libhl.lib"
cmd /c "call `"$vcvars`" && cd /d `"$PSScriptRoot`" && $cl"
if ($LASTEXITCODE -ne 0) { throw "cl failed with exit code $LASTEXITCODE" }
if (-not (Test-Path "$PSScriptRoot\stbtt.hdll")) { throw 'build produced no stbtt.hdll' }

# Install to prebuilt/windows/ (the tracked canonical location) and drop
# intermediates. `tools/sync-hdll.ps1` copies it into the repo root at run time.
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$dest = Join-Path $repoRoot 'prebuilt\windows\stbtt.hdll'
New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
Copy-Item "$PSScriptRoot\stbtt.hdll" $dest -Force
Remove-Item "$PSScriptRoot\stbtt.obj","$PSScriptRoot\stbtt_hl.obj", `
            "$PSScriptRoot\stbtt.exp","$PSScriptRoot\stbtt.lib", `
            "$PSScriptRoot\stbtt.hdll" -Force -ErrorAction SilentlyContinue
Write-Host "stbtt.hdll -> $dest"
