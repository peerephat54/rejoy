param(
  [Parameter(Mandatory = $true)]
  [string]$ApiBaseUrl,

  [string]$OutputDir = "C:\Users\User\Documents\New project\demo-package"
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$FlutterApp = Join-Path $Root "rejoy"
$ApiBaseUrl = $ApiBaseUrl.TrimEnd("/")

if (Test-Path -LiteralPath $OutputDir) {
  Remove-Item -LiteralPath $OutputDir -Recurse -Force
}
New-Item -ItemType Directory -Path $OutputDir | Out-Null

Write-Host "Preparing ReJoy demo package..." -ForegroundColor Cyan
Write-Host "- API URL: $ApiBaseUrl"
Write-Host "- Output: $OutputDir"

& (Join-Path $PSScriptRoot "build-rejoy-mobile-demo.ps1") -ApiBaseUrl $ApiBaseUrl -Target apk
& (Join-Path $PSScriptRoot "build-rejoy-web-demo.ps1") -ApiBaseUrl $ApiBaseUrl

$apkSource = Join-Path $FlutterApp "build\app\outputs\flutter-apk\app-release.apk"
$apkTarget = Join-Path $OutputDir "ReJoy-release-demo.apk"
Copy-Item -LiteralPath $apkSource -Destination $apkTarget -Force

$webSource = Join-Path $FlutterApp "build\web"
$webTarget = Join-Path $OutputDir "web"
Copy-Item -LiteralPath $webSource -Destination $webTarget -Recurse -Force

$readme = @"
ReJoy Demo Package
==================

API URL:
$ApiBaseUrl

Files:
- ReJoy-release-demo.apk = install on Android phone for demo
- web/ = Flutter web backup build

Before presentation:
1. Open backend URL once to wake Render Free:
   $ApiBaseUrl/api/health
2. Test app login/register.
3. Keep local backend ready as final backup.
"@

Set-Content -LiteralPath (Join-Path $OutputDir "README.txt") -Value $readme -Encoding UTF8

Write-Host ""
Write-Host "Demo package is ready:" -ForegroundColor Green
Write-Host $OutputDir
