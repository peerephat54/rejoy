$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$androidDir = Join-Path $projectRoot "android"
$keystorePath = Join-Path $androidDir "rejoy-upload-key.jks"
$propertiesPath = Join-Path $androidDir "key.properties"

if (Test-Path -LiteralPath $keystorePath) {
    throw "Keystore already exists at $keystorePath. Back it up; do not overwrite it."
}

$alias = Read-Host "Key alias (recommended: rejoy-upload)"
if ([string]::IsNullOrWhiteSpace($alias)) { $alias = "rejoy-upload" }

$securePassword = Read-Host "Create a strong keystore password" -AsSecureString
$credential = [System.Management.Automation.PSCredential]::new("rejoy", $securePassword)
$password = $credential.GetNetworkCredential().Password
if ($password.Length -lt 12) {
    throw "Use a password with at least 12 characters."
}

& keytool -genkeypair -v `
    -keystore $keystorePath `
    -storetype JKS `
    -keyalg RSA `
    -keysize 2048 `
    -validity 10000 `
    -alias $alias `
    -storepass $password `
    -keypass $password `
    -dname "CN=ReJoy, OU=ReJoy, O=ReJoy, L=Songkhla, ST=Songkhla, C=TH"

if ($LASTEXITCODE -ne 0) { throw "keytool failed with exit code $LASTEXITCODE" }

@(
    "storePassword=$password"
    "keyPassword=$password"
    "keyAlias=$alias"
    "storeFile=rejoy-upload-key.jks"
) | Set-Content -LiteralPath $propertiesPath -Encoding Ascii

Write-Host "Release signing created. Back up these two files securely:"
Write-Host "  $keystorePath"
Write-Host "  $propertiesPath"
Write-Host "Never commit or share either file. Losing the key can prevent future app updates."
