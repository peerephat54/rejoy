param(
  [int]$Port = 3000
)

$ErrorActionPreference = "Stop"

$listeners = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if (-not $listeners) {
  Write-Host "No process is listening on port $Port." -ForegroundColor Green
  exit 0
}

$processIds = $listeners | Select-Object -ExpandProperty OwningProcess -Unique
foreach ($processId in $processIds) {
  $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
  if (-not $process) {
    continue
  }

  Write-Host "Stopping process $($process.ProcessName) (PID $processId) on port $Port..." -ForegroundColor Yellow
  Stop-Process -Id $processId -Force
}

Write-Host "Port $Port is free now." -ForegroundColor Green
