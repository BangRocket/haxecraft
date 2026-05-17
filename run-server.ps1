# Windows server runner — mirror of run-server.sh
# The M1 server is two processes: zone (background) + gateway (foreground).
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
New-Item -ItemType Directory -Force -Path out | Out-Null
& "$PSScriptRoot\tools\sync-hdll.ps1"

docker compose up -d mysql

$healthy = $false
for ($i = 0; $i -lt 60; $i++) {
    if ((docker compose ps mysql --format '{{.Health}}' 2>$null) -eq 'healthy') { $healthy = $true; break }
    Start-Sleep -Seconds 1
}
if (-not $healthy) { throw 'MySQL did not become healthy within 60s' }

& "$PSScriptRoot\db\apply-migrations.ps1"

Push-Location server
try {
    haxe build-gateway.hxml
    haxe build-zone.hxml
} finally { Pop-Location }

# Start zone in background, gateway in foreground.
$zone = Start-Process -FilePath hl -ArgumentList 'out/zone.hl' -PassThru -NoNewWindow
try {
    Start-Sleep -Milliseconds 500
    hl out/gateway.hl
} finally {
    if ($zone -and -not $zone.HasExited) { Stop-Process -Id $zone.Id -Force }
}
