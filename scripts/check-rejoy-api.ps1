param(
  [switch]$FullSmoke,
  [string]$HealthCheckKey = $env:REJOY_HEALTH_CHECK_KEY
)

$ErrorActionPreference = "Stop"

$BaseUrl = if ($env:REJOY_API_BASE_URL) { $env:REJOY_API_BASE_URL.TrimEnd("/") } else { "http://localhost:3000" }

if ($BaseUrl -match "YOUR-REJOY-BACKEND|YOUR-CLOUD|your-backend") {
  Write-Host "Please replace the sample backend URL with your real Render URL first." -ForegroundColor Red
  Write-Host "Example:" -ForegroundColor Yellow
  Write-Host '$env:REJOY_API_BASE_URL="https://rejoy-backend-xxxx.onrender.com"'
  exit 1
}

Write-Host "Checking ReJoy API at $BaseUrl" -ForegroundColor Cyan

function Invoke-ReJoyCheck {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Path,
    [hashtable]$Headers = @{}
  )

  $uri = "$BaseUrl$Path"
  $started = Get-Date
  try {
    $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $Headers -TimeoutSec 10
    $elapsed = [int]((Get-Date) - $started).TotalMilliseconds
    Write-Host "[OK] $Name ($elapsed ms)" -ForegroundColor Green
    return $response
  } catch {
    Write-Host "[FAIL] $Name -> $($_.Exception.Message)" -ForegroundColor Red
    throw
  }
}

$health = Invoke-ReJoyCheck -Name "Health" -Path "/api/health"
$deep = $null
if ($HealthCheckKey) {
  $deep = Invoke-ReJoyCheck -Name "Deep health" -Path "/api/health/deep" -Headers @{ "x-health-check-key" = $HealthCheckKey }
} elseif ($BaseUrl -like "http://localhost*") {
  $deep = Invoke-ReJoyCheck -Name "Deep health" -Path "/api/health/deep"
} else {
  Write-Host "[SKIP] Deep health (set REJOY_HEALTH_CHECK_KEY to check production deep health)" -ForegroundColor Yellow
}
$quests = Invoke-ReJoyCheck -Name "Quest list" -Path "/api/quests?limit=10"

if ($FullSmoke) {
  Write-Host ""
  Write-Host "Running full authenticated smoke test..." -ForegroundColor Cyan

  $email = "rejoy.smoke+$([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())@example.com"
  $password = "ReJoySmoke123"
  $authBody = @{
    email = $email
    password = $password
    firstName = "Smoke"
    surname = "Tester"
    age = 18
  } | ConvertTo-Json

  $auth = Invoke-RestMethod -Uri "$BaseUrl/api/auth/register" -Method Post -ContentType "application/json" -Body $authBody -TimeoutSec 10
  $headers = @{ Authorization = "Bearer $($auth.token)" }
  Write-Host "[OK] Auth register smoke user" -ForegroundColor Green

  $profile = Invoke-RestMethod -Uri "$BaseUrl/api/users/active/profile" -Headers $headers -Method Get -TimeoutSec 10
  Write-Host "[OK] Active clinical profile for $($profile.user.email)" -ForegroundColor Green

  $reportBody = @{
    phq9Score = 4
    dailyMood = "smoke-test"
    diaryNote = "Smoke test report"
    cbtCompletionRate = "3/3"
    symptomMatrix = @{
      mood_score = 1
      somatic_score = 1
      behavioral_score = 1
    }
  } | ConvertTo-Json -Depth 4
  $report = Invoke-RestMethod -Uri "$BaseUrl/api/reports" -Headers $headers -Method Post -ContentType "application/json" -Body $reportBody -TimeoutSec 10
  Write-Host "[OK] Report create smoke id=$($report._id)" -ForegroundColor Green
}

Write-Host ""
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "- service: $($health.service)"
Write-Host "- database: $($health.database)"
if ($deep) {
  Write-Host "- active quests: $($deep.activeQuestCount)"
  Write-Host "- quest seed ready: $($deep.questSeedReady)"
  Write-Host "- Gemini configured: $($deep.geminiConfigured)"
}
Write-Host "- API URL for Flutter: $BaseUrl"
Write-Host "- full smoke: $FullSmoke"

if ($deep -and -not $deep.questSeedReady) {
  Write-Host "Quest seed is not ready. Restart backend once to seed default quests." -ForegroundColor Yellow
  exit 2
}

if ($quests.Count -lt 10) {
  Write-Host "Quest API returned fewer than 10 quests." -ForegroundColor Yellow
  exit 3
}

Write-Host ""
Write-Host "ReJoy API is ready for demo." -ForegroundColor Green
