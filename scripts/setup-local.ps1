$ErrorActionPreference="Stop"
Set-Location (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$LogFile = Join-Path (Get-Location) "myERP-startup.log"
Start-Transcript -Path $LogFile -Append | Out-Null
try {
  Write-Host "=== myERP ONE-CLICK LOCAL BOOTSTRAP ===" -ForegroundColor Cyan

  function Need($name,$cmd){
    if(-not (Get-Command $cmd -ErrorAction SilentlyContinue)){
      Write-Host "$name is missing." -ForegroundColor Yellow
      return $false
    }
    return $true
  }

  if(-not (Need "Git" "git")){
    if(Get-Command winget -ErrorAction SilentlyContinue){
      winget install --id Git.Git -e --source winget --accept-source-agreements --accept-package-agreements
    } else { throw "Install Git then rerun." }
  }
  if(-not (Need "Docker" "docker")){
    if(Get-Command winget -ErrorAction SilentlyContinue){
      winget install --id Docker.DockerDesktop -e --source winget --accept-source-agreements --accept-package-agreements
      throw "Docker Desktop was installed. Start Docker Desktop, then rerun this script."
    } else { throw "Install Docker Desktop then rerun." }
  }

  docker version | Out-Null
  docker compose version | Out-Null
  Write-Host "[OK] Git and Docker are available." -ForegroundColor Green

  git fetch origin
  git checkout feature/local-fullstack 2>$null
  if($LASTEXITCODE -ne 0){ git checkout -b feature/local-fullstack origin/feature/local-fullstack }
  git reset --hard origin/feature/local-fullstack
  git clean -fd

  Write-Host "[OK] Synced feature/local-fullstack." -ForegroundColor Green
  docker compose -f docker-compose.local.yml config | Out-Null
  Write-Host "[OK] Docker Compose configuration valid." -ForegroundColor Green

  docker compose -f docker-compose.local.yml up -d --build
  if($LASTEXITCODE -ne 0){ throw "Docker Compose build/start failed." }

  Write-Host "Waiting for API..." -ForegroundColor Cyan
  $apiOk=$false
  for($i=0;$i -lt 40;$i++){
    Start-Sleep -Seconds 3
    try {
      $h=Invoke-RestMethod http://localhost:4000/health -TimeoutSec 3
      if($h.status -eq "ok"){ $apiOk=$true; break }
    } catch {}
  }
  if(-not $apiOk){
    docker compose -f docker-compose.local.yml ps
    docker compose -f docker-compose.local.yml logs --tail=150 api
    throw "API did not become healthy."
  }

  Write-Host "Waiting for Web..." -ForegroundColor Cyan
  $webOk=$false
  for($i=0;$i -lt 20;$i++){
    Start-Sleep -Seconds 2
    try {
      $r=Invoke-WebRequest http://localhost:8080/health -UseBasicParsing -TimeoutSec 3
      if($r.StatusCode -eq 200){ $webOk=$true; break }
    } catch {}
  }
  if(-not $webOk){
    docker compose -f docker-compose.local.yml ps
    docker compose -f docker-compose.local.yml logs --tail=100 web
    throw "Web container is not reachable."
  }

  Write-Host ""
  Write-Host "========================================" -ForegroundColor Green
  Write-Host " myERP IS READY" -ForegroundColor Green
  Write-Host "========================================" -ForegroundColor Green
  Write-Host "ERP:  http://localhost:8080"
  Write-Host "API:  http://localhost:4000/health"
  Write-Host "User: admin@myerb.local"
  Write-Host "Pass: Admin@123"
  Write-Host "Log:  $LogFile"
  Start-Process "http://localhost:8080"
} catch {
  Write-Host ""
  Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
  Write-Host "Diagnostics: docker compose -f docker-compose.local.yml ps" -ForegroundColor Yellow
  Write-Host "Diagnostics: docker compose -f docker-compose.local.yml logs --tail=150 api" -ForegroundColor Yellow
  throw
} finally {
  Stop-Transcript | Out-Null
}
