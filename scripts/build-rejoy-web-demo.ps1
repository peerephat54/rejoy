param(
  [Parameter(Mandatory = $true)]
  [string]$ApiBaseUrl
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$FlutterApp = Join-Path $Root "rejoy"
$ApiBaseUrl = $ApiBaseUrl.TrimEnd("/")

Write-Host "Building ReJoy Flutter web backup..." -ForegroundColor Cyan
Write-Host "- Flutter app: $FlutterApp"
Write-Host "- API URL: $ApiBaseUrl"

Set-Location -LiteralPath $FlutterApp
flutter pub get
flutter build web --release --dart-define "REJOY_API_BASE_URL=$ApiBaseUrl"

Write-Host ""
Write-Host "Built web demo folder:" -ForegroundColor Green
Write-Host "$FlutterApp\build\web"
Write-Host ""
Write-Host "Tip: You can zip this folder or host it on a free static host as backup."
