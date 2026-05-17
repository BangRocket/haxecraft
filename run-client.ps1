# Windows client runner — mirror of run-client.sh
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
New-Item -ItemType Directory -Force -Path out | Out-Null
& "$PSScriptRoot\tools\sync-hdll.ps1"

Push-Location client
try { haxe build-client.hxml } finally { Pop-Location }

hl out/client.hl
