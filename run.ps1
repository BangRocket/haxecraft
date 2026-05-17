# Windows dev runner using HashLink JIT — mirror of run.sh
# For a standalone native binary, a separate HLC+MSVC build is required.
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
& "$PSScriptRoot\tools\sync-hdll.ps1"

if (-not (Test-Path 'haxecraft.hl')) {
    Write-Host 'Building haxecraft.hl...'
    haxe build.hxml
}

Write-Host 'Running Haxecraft...'
hl haxecraft.hl @args
