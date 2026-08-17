$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$propertiesPath = Join-Path $projectRoot "android\key.properties"

if (-not (Test-Path -LiteralPath $propertiesPath)) {
    throw "Release signing is missing. Run tool/create_android_keystore.ps1 first."
}

Push-Location $projectRoot
try {
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed" }
    # Existing deprecation notices should not block a signed build; real errors still fail.
    flutter analyze --no-fatal-infos --no-fatal-warnings
    if ($LASTEXITCODE -ne 0) { throw "flutter analyze failed" }
    flutter test
    if ($LASTEXITCODE -ne 0) { throw "flutter test failed" }
    flutter build appbundle --release `
        --dart-define=API_BASE_URL=https://rejoy-backend.onrender.com
    if ($LASTEXITCODE -ne 0) { throw "release build failed" }
} finally {
    Pop-Location
}

Write-Host "AAB ready at build\app\outputs\bundle\release\app-release.aab"
