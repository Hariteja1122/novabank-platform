# NovaBank one-command developer environment for Windows PowerShell.
#   .\dev.ps1 up | db | status | logs [service] | down | reset
param([string]$Command = "up", [string]$Service = "")
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$Repos = "novabank-auth-service","novabank-account-service","novabank-transaction-service","novabank-api-gateway","novabank-ui"

function Preflight {
  if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { throw "Docker is not installed. Install Docker Desktop first." }
  docker info *> $null; if ($LASTEXITCODE -ne 0) { throw "Docker is not running. Start Docker Desktop and try again." }
  if (-not (Test-Path .env)) { Copy-Item .env.example .env; Write-Host "Created .env from .env.example" }
}

function Wait-Healthy([string]$svc, [int]$timeout = 900) {
  Write-Host -NoNewline "    waiting for $svc "
  $waited = 0
  while ($true) {
    $id = docker compose ps -q $svc
    $state = if ($id) { docker inspect -f "{{.State.Health.Status}}" $id 2>$null } else { "starting" }
    if ($state -eq "healthy") { Write-Host " ready"; return }
    if ($waited -ge $timeout) { throw "$svc did not become healthy. Check: .\dev.ps1 logs $svc" }
    Write-Host -NoNewline "."; Start-Sleep 5; $waited += 5
  }
}

switch ($Command) {
  "up" {
    Preflight
    $missing = $Repos | Where-Object { -not (Test-Path "..\$_") }
    if ($missing) { throw "Missing sibling repos: $($missing -join ', '). Put all six repos in one folder." }
    Write-Host "Building and starting NovaBank (first Db2 start takes 3 to 6 minutes)"
    docker compose up -d --build
    Wait-Healthy db2 900
    foreach ($s in "account-service","auth-service","transaction-service","api-gateway") { Wait-Healthy $s 300 }
    Write-Host ""
    Write-Host "  UI          http://localhost:4200"
    Write-Host "  Gateway     http://localhost:8080"
    Write-Host "  Customer    john.carter@example.com / Password@123"
    Write-Host "  Admin       admin@novabank.dev / Admin@123"
  }
  "db"     { Preflight; docker compose up -d --build db2; Wait-Healthy db2 900; Write-Host "Db2 ready on localhost:50000" }
  "status" { docker compose ps }
  "logs"   { if ($Service) { docker compose logs -f --tail=200 $Service } else { docker compose logs -f --tail=200 } }
  "down"   { docker compose down }
  "reset"  {
    $ok = Read-Host "This deletes all Db2 data. Type yes to continue"
    if ($ok -eq "yes") { docker compose down -v } else { Write-Host "Cancelled." }
  }
  default  { Write-Host "Usage: .\dev.ps1 up|db|status|logs [service]|down|reset" }
}
