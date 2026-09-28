$ErrorActionPreference="Stop"
Set-Location (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
Write-Host "=== myERB Local Bootstrap ===" -ForegroundColor Cyan
function Need($name,$cmd){ if(-not (Get-Command $cmd -ErrorAction SilentlyContinue)){ Write-Host "$name is missing." -ForegroundColor Yellow; return $false }; return $true }
if(-not (Need "Git" "git")){ if(Get-Command winget -ErrorAction SilentlyContinue){winget install --id Git.Git -e --source winget --accept-source-agreements --accept-package-agreements}else{throw "Install Git then rerun."} }
if(-not (Need "Docker" "docker")){ if(Get-Command winget -ErrorAction SilentlyContinue){winget install --id Docker.DockerDesktop -e --source winget --accept-source-agreements --accept-package-agreements; Write-Host "Docker Desktop installed. Start it, then rerun this script." -ForegroundColor Yellow; exit 0}else{throw "Install Docker Desktop then rerun."} }
docker version | Out-Null
docker compose version | Out-Null
Write-Host "Docker OK" -ForegroundColor Green
git fetch origin
$branchName=(git branch --show-current).Trim()
if($branchName -eq ""){git checkout -b feature/local-fullstack}
git pull --ff-only origin $branchName 2>$null
Write-Host "Building myERB..." -ForegroundColor Cyan
docker compose -f docker-compose.local.yml up -d --build
Write-Host "Waiting for services..." -ForegroundColor Cyan
$ok=$false
for($i=0;$i -lt 40;$i++){Start-Sleep -Seconds 3;try{$h=Invoke-RestMethod http://localhost:4000/health -TimeoutSec 3;if($h.status -eq "ok"){$ok=$true;break}}catch{}}
if(-not $ok){docker compose -f docker-compose.local.yml ps;docker compose -f docker-compose.local.yml logs --tail=120 api;throw "API did not become healthy."}
try{Invoke-WebRequest http://localhost:8080 -UseBasicParsing -TimeoutSec 10 | Out-Null}catch{throw "Web container is not reachable."}
Write-Host ""
Write-Host "myERB is READY" -ForegroundColor Green
Write-Host "ERP:  http://localhost:8080"
Write-Host "API:  http://localhost:4000/health"
Write-Host "User: admin@myerb.local"
Write-Host "Pass: Admin@123"
Start-Process "http://localhost:8080"
