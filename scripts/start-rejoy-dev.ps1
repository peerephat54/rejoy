$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$Backend = Join-Path $Root "backend"
$FlutterApp = Join-Path $Root "rejoy"
$Npm = "C:\Program Files\nodejs\npm.cmd"
$Port = 3000

Write-Host "Preparing ReJoy dev workflow..." -ForegroundColor Cyan

$listeners = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue |
  Where-Object { $_.State -eq "Listen" }

if ($listeners) {
  $backendProcessIds = $listeners | Select-Object -ExpandProperty OwningProcess -Unique
  Write-Host "Port $Port is already running. Reusing existing backend process: $($backendProcessIds -join ', ')" -ForegroundColor Yellow
} else {
  Write-Host "Starting backend on port $Port..." -ForegroundColor Cyan
  Start-Process powershell -WindowStyle Hidden -ArgumentList @(
    "-NoExit",
    "-ExecutionPolicy", "Bypass",
    "-Command",
    "& { Set-Location -LiteralPath '$Backend'; & '$Npm' run dev }"
  )
  Start-Sleep -Seconds 4
}

Write-Host "Running API checks..." -ForegroundColor Cyan
& (Join-Path $PSScriptRoot "check-rejoy-api.ps1")

Write-Host ""
Write-Host "Starting Flutter on Chrome..." -ForegroundColor Cyan
cd $FlutterApp
flutter run -d chrome
