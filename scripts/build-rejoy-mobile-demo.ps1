param(
  [string]$ApiBaseUrl = "https://rejoy-backend.onrender.com",

  [ValidateSet("apk", "appbundle")]
  [string]$Target = "apk"
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$FlutterApp = Join-Path $Root "rejoy"
$ApiBaseUrl = $ApiBaseUrl.TrimEnd("/")

Write-Host "Building ReJoy mobile demo..." -ForegroundColor Cyan
Write-Host "- Flutter app: $FlutterApp"
Write-Host "- API URL: $ApiBaseUrl"
Write-Host "- Target: $Target"

Set-Location -LiteralPath $FlutterApp
flutter pub get

if ($Target -eq "appbundle") {
  flutter build appbundle --dart-define "REJOY_API_BASE_URL=$ApiBaseUrl"
  Write-Host "Built Android App Bundle:" -ForegroundColor Green
  Write-Host "$FlutterApp\build\app\outputs\bundle\release\app-release.aab"
} else {
  flutter build apk --release --dart-define "REJOY_API_BASE_URL=$ApiBaseUrl"
  Copy-Item -LiteralPath "$FlutterApp\build\app\outputs\flutter-apk\app-release.apk" -Destination "$Root\ReJoy-production.apk" -Force
  Write-Host "Built release APK:" -ForegroundColor Green
  Write-Host "$FlutterApp\build\app\outputs\flutter-apk\app-release.apk"
  Write-Host "Copied installable APK to:" -ForegroundColor Green
  Write-Host "$Root\ReJoy-production.apk"
}
