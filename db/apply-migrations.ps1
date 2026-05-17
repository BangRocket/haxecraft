# Windows migration runner — mirror of db/apply-migrations.sh
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$projectRoot = Split-Path $here -Parent

Get-ChildItem -Path (Join-Path $here 'migrations') -Filter '*.sql' | Sort-Object Name | ForEach-Object {
    Write-Host "applying $($_.Name)"
    Push-Location $projectRoot
    try {
        Get-Content -Raw $_.FullName | docker compose exec -T mysql mysql -uhaxecraft -pdev_local_only haxecraft
    } finally { Pop-Location }
}
