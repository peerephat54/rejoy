param(
  [Parameter(Mandatory = $true)]
  [string]$GitRemoteUrl,

  [string]$Branch = "main"
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root

if ($GitRemoteUrl -notmatch "^https://github\.com/.+/.+\.git$|^git@github\.com:.+/.+\.git$") {
  Write-Host "Please use a GitHub repository URL, for example:" -ForegroundColor Red
  Write-Host "https://github.com/YOUR_NAME/rejoy.git"
  exit 1
}

if (-not (git rev-parse --is-inside-work-tree 2>$null)) {
  git init
}

git branch -M $Branch

$existingRemote = git remote get-url origin 2>$null
if ($LASTEXITCODE -eq 0 -and $existingRemote) {
  git remote set-url origin $GitRemoteUrl
} else {
  git remote add origin $GitRemoteUrl
}

git add .gitignore render.yaml .vscode scripts docs backend rejoy README.md
git commit -m "Prepare ReJoy cloud demo deploy" 2>$null
if ($LASTEXITCODE -ne 0) {
  Write-Host "No new commit was created. Continuing to push current branch..." -ForegroundColor Yellow
}

git push -u origin $Branch

Write-Host ""
Write-Host "Pushed ReJoy to GitHub." -ForegroundColor Green
Write-Host "Next: create a Render Blueprint or Web Service from this repository."
