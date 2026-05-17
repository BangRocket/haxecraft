# Copies the Windows prebuilt .hdll native libraries into the repo root,
# where `hl` loads them at runtime. Idempotent — safe to run every launch.
# The run-*.ps1 scripts call this automatically.
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$src  = Join-Path $root 'prebuilt\windows'

if (-not (Test-Path $src)) { throw "missing prebuilt dir: $src" }

Get-ChildItem $src -Filter '*.hdll' | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $root $_.Name) -Force
}
