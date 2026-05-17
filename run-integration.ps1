# Windows integration runner — mirror of run-integration.sh
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
New-Item -ItemType Directory -Force -Path out | Out-Null
& "$PSScriptRoot\tools\sync-hdll.ps1"

# Bring up MySQL
docker compose up -d mysql

$healthy = $false
for ($i = 0; $i -lt 60; $i++) {
    if ((docker compose ps mysql --format '{{.Health}}' 2>$null) -eq 'healthy') { $healthy = $true; break }
    Start-Sleep -Seconds 1
}
if (-not $healthy) { throw 'MySQL did not become healthy within 60s' }

# Apply migrations (idempotent)
& "$PSScriptRoot\db\apply-migrations.ps1"

# Build all targets (equivalent of `make all`)
Push-Location shared
try { haxe build-shared-test.hxml } finally { Pop-Location }
Push-Location server
try { haxe build-gateway.hxml; haxe build-zone.hxml; haxe build-server-cli.hxml } finally { Pop-Location }
Push-Location client
try { haxe build-client.hxml } finally { Pop-Location }
Push-Location tools\worldgen-tmx
try { haxe build-worldgen-tmx.hxml } finally { Pop-Location }

# Start zone + gateway in background (zone first so it's listening when the
# client tries to hand off).
$zoneLog = Join-Path $env:TEMP 'integration-zone.log'
$gwLog   = Join-Path $env:TEMP 'integration-gateway.log'
$zone = Start-Process -FilePath hl -ArgumentList 'out/zone.hl' -PassThru -NoNewWindow `
    -RedirectStandardOutput $zoneLog -RedirectStandardError "$zoneLog.err"
$gw = Start-Process -FilePath hl -ArgumentList 'out/gateway.hl' -PassThru -NoNewWindow `
    -RedirectStandardOutput $gwLog -RedirectStandardError "$gwLog.err"
try {
    Start-Sleep -Seconds 1

    # Build and run server tests (includes login-flow integration test)
    Push-Location server
    try {
        haxe build-server-test.hxml
        hl ../out/server-test.hl
    } finally { Pop-Location }
} finally {
    foreach ($p in @($zone, $gw)) {
        if ($p -and -not $p.HasExited) { Stop-Process -Id $p.Id -Force }
    }
}
