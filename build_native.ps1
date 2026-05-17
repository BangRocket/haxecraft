<#
.SYNOPSIS
  Native build via HashLink/C (HLC) for Windows.

.DESCRIPTION
  Transpiles each Haxe target to C and compiles a native .exe into bin\.
  This is the Windows counterpart of build_native.sh.

  On Windows the `hl` JIT works fine, so a native build is OPTIONAL here -- it
  is provided for parity (standalone .exe with no `hl.exe` dependency).

  Requirements:
    * Haxe 4.3+ on PATH.
    * A HashLink install (hl.exe, *.hdll, libhl.lib, include\hlc.h). Point to it
      with -HashlinkDir or the HASHLINK env var; defaults to C:\HashLink.
    * MSVC build tools: run this from a "x64 Native Tools Command Prompt for VS"
      (or ARM64 equivalent) so cl.exe / lib.exe / dumpbin.exe are on PATH.

  NOTE: this script is UNVERIFIED on a real Windows host. Treat the first run as
  a bring-up exercise; the macOS/Linux path (build_native.sh) is the tested one.

.PARAMETER Targets
  Targets to build. Default: all.
  Valid: worldgen-tmx server-cli gateway zone shared-test server-test client

.PARAMETER HashlinkDir
  Root of the HashLink install. Default: $env:HASHLINK or C:\HashLink.

.EXAMPLE
  .\build_native.ps1
  .\build_native.ps1 zone gateway
  .\build_native.ps1 -HashlinkDir D:\hl client
#>
[CmdletBinding()]
param(
  [string[]]$Targets,
  [string]$HashlinkDir = $(if ($env:HASHLINK) { $env:HASHLINK } else { 'C:\HashLink' })
)

$ErrorActionPreference = 'Stop'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Here

# ---- OS / arch detection ---------------------------------------------------
$archRaw = $env:PROCESSOR_ARCHITECTURE
switch ($archRaw) {
  'AMD64' { $Arch = 'x86_64'; $Machine = 'X64' }
  'ARM64' { $Arch = 'arm64';  $Machine = 'ARM64' }
  'x86'   { throw 'build_native.ps1: 32-bit Windows is not supported.' }
  default { throw "build_native.ps1: unsupported arch '$archRaw'." }
}
Write-Host "Native build target: windows/$Arch"

# ---- toolchain checks ------------------------------------------------------
foreach ($tool in 'haxe', 'cl', 'lib', 'dumpbin') {
  if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
    throw "Required tool '$tool' not found on PATH. Run from a VS Native Tools prompt."
  }
}

if (-not (Test-Path $HashlinkDir)) {
  throw "HashLink not found at '$HashlinkDir'. Pass -HashlinkDir or set `$env:HASHLINK."
}
$HlInclude = Join-Path $HashlinkDir 'include'
if (-not (Test-Path (Join-Path $HlInclude 'hlc.h'))) {
  throw "hlc.h not found in '$HlInclude'."
}
# libhl.lib ships either in the root or under include\.
$LibHl = @(
  (Join-Path $HashlinkDir 'libhl.lib'),
  (Join-Path $HlInclude  'libhl.lib')
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $LibHl) { throw "libhl.lib not found in '$HashlinkDir' or its include\ dir." }

New-Item -ItemType Directory -Force -Path bin, out\c, out\implib | Out-Null

# ---- import libraries for .hdll natives ------------------------------------
# The HashLink release ships .hdll files as DLLs but no import .lib files, so
# HLC-generated code can't link their native symbols directly. Synthesize an
# import lib from each DLL's export table.
$ImportLibCache = @{}
function Get-ImportLib([string]$HdllName) {
  if ($ImportLibCache.ContainsKey($HdllName)) { return $ImportLibCache[$HdllName] }

  $hdll = Join-Path $HashlinkDir "$HdllName.hdll"
  if (-not (Test-Path $hdll)) { throw "missing native lib: $hdll" }

  $def = Join-Path 'out\implib' "$HdllName.def"
  $lib = Join-Path 'out\implib' "$HdllName.lib"

  # dumpbin /exports columns: ordinal hint RVA name -- the name is the 4th field.
  $names = & dumpbin /nologo /exports $hdll |
    Where-Object { $_ -match '^\s+\d+\s+[0-9A-Fa-f]+\s+[0-9A-Fa-f]+\s+(\S+)' } |
    ForEach-Object { ($_ -split '\s+', 5)[4] }
  if (-not $names) { throw "no exports found in $hdll" }

  Set-Content -Path $def -Value (@('EXPORTS') + $names) -Encoding ASCII
  & lib /nologo "/def:$def" "/out:$lib" "/machine:$Machine" | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "lib.exe failed for $HdllName" }

  $ImportLibCache[$HdllName] = $lib
  return $lib
}

# ---- build helpers ---------------------------------------------------------
function Invoke-Checked([string]$Exe, [string[]]$ArgList, [string]$WorkDir = $Here) {
  Push-Location $WorkDir
  try {
    & $Exe @ArgList
    if ($LASTEXITCODE -ne 0) { throw "$Exe exited with $LASTEXITCODE" }
  } finally { Pop-Location }
}

# Gen-C <name> <build-dir> <hxml flags...>  -- transpile Haxe -> C.
function Gen-C([string]$Name, [string]$Dir, [string[]]$HxmlArgs) {
  $cdir = Join-Path 'out\c' $Name
  New-Item -ItemType Directory -Force -Path $cdir | Out-Null
  $cfile = Join-Path $Here "$cdir\$Name.c"
  Write-Host "  haxe -> $cdir\$Name.c"
  Invoke-Checked 'haxe' ($HxmlArgs + @('-hl', $cfile)) (Join-Path $Here $Dir)
}

# Compile-Target <name> <hdll names[]> <extra .lib syslibs[]>
function Compile-Target([string]$Name, [string[]]$Hdlls, [string[]]$SysLibs) {
  $cdir = Join-Path 'out\c' $Name
  $exe  = Join-Path 'bin' "$Name.exe"
  Write-Host "  cl -> $exe"

  $importLibs = $Hdlls | ForEach-Object { Get-ImportLib $_ }
  $clArgs = @(
    '/nologo', '/O2', '/MD',
    "/I$HlInclude", "/I$cdir",
    "$cdir\$Name.c",
    "/Fo$cdir\", "/Fe:$exe",
    '/link', $LibHl
  ) + $importLibs + $SysLibs
  Invoke-Checked 'cl' $clArgs
}

# Copy the HashLink runtime DLLs/hdlls next to the freshly built binaries so
# the .exe can start without HashLink on PATH.
function Sync-Runtime {
  Get-ChildItem $HashlinkDir -Filter *.dll  | Copy-Item -Destination bin -Force
  Get-ChildItem $HashlinkDir -Filter *.hdll | Copy-Item -Destination bin -Force
}

# ---- targets ---------------------------------------------------------------
$HeadlessSys = @('ws2_32.lib')
$ClientSys   = @('opengl32.lib', 'user32.lib', 'gdi32.lib', 'shell32.lib',
                 'ole32.lib', 'winmm.lib', 'imm32.lib', 'version.lib',
                 'setupapi.lib', 'ws2_32.lib')

function Build-WorldgenTmx {
  Write-Host '[worldgen-tmx]'
  Gen-C 'worldgen-tmx' 'tools\worldgen-tmx' @('-cp','src','-cp','..\..\shared\src','-main','Main')
  Compile-Target 'worldgen-tmx' @() $HeadlessSys
}
function Build-ServerCli {
  Write-Host '[server-cli]'
  Gen-C 'server-cli' 'server' @('-cp','src','-cp','..\shared\src','-main','server.ServerCliMain')
  Compile-Target 'server-cli' @('mysql','fmt') $HeadlessSys
}
function Build-Gateway {
  Write-Host '[gateway]'
  Gen-C 'gateway' 'server' @('-cp','src','-cp','..\shared\src','-lib','utest','-main','server.gateway.Main','-D','analyzer-optimize')
  Compile-Target 'gateway' @('mysql','fmt') $HeadlessSys
}
function Build-Zone {
  Write-Host '[zone]'
  Gen-C 'zone' 'server' @('-cp','src','-cp','..\shared\src','-lib','utest','-main','server.zone.Main','-D','analyzer-optimize')
  Compile-Target 'zone' @('mysql','fmt') $HeadlessSys
}
function Build-SharedTest {
  Write-Host '[shared-test]'
  Gen-C 'shared-test' 'shared' @('-cp','src','-cp','test','-lib','utest','-main','TestMain','-D','analyzer-optimize')
  Compile-Target 'shared-test' @('fmt') $HeadlessSys
}
function Build-ServerTest {
  Write-Host '[server-test]'
  Gen-C 'server-test' 'server' @('-cp','src','-cp','test','-cp','..\shared\src','-cp','..\client\src\headless','-lib','utest','-main','TestMain')
  Compile-Target 'server-test' @('mysql','fmt') $HeadlessSys
}
function Build-Client {
  Write-Host '[client]'
  Gen-C 'client' 'client' @('-cp','src','-cp','..\shared\src','-cp','..\engine\src','-lib','heaps','-lib','hlsdl','-main','client.Main','-D','resourcesPath=..\res','-D','analyzer-optimize')
  Compile-Target 'client' @('sdl','ui','fmt','openal','uv') $ClientSys
}

# ---- dispatch --------------------------------------------------------------
$All = @('worldgen-tmx','server-cli','gateway','zone','shared-test','server-test','client')
if (-not $Targets -or $Targets.Count -eq 0) { $Targets = $All }

foreach ($t in $Targets) {
  switch ($t) {
    'worldgen-tmx' { Build-WorldgenTmx }
    'server-cli'   { Build-ServerCli }
    'gateway'      { Build-Gateway }
    'zone'         { Build-Zone }
    'shared-test'  { Build-SharedTest }
    'server-test'  { Build-ServerTest }
    'client'       { Build-Client }
    default        { throw "unknown target: $t" }
  }
}

Sync-Runtime
Write-Host ''
Write-Host "Done (windows/$Arch). Native binaries in bin\:"
Get-ChildItem bin -Filter *.exe | ForEach-Object { Write-Host "  $($_.Name)" }
