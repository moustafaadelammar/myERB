$ErrorActionPreference="Stop"
Set-Location (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
docker compose -f docker-compose.local.yml down
docker volume rm myerb_myerb_pgdata 2>$null
docker compose -f docker-compose.local.yml up -d --build
Start-Sleep -Seconds 8
Start-Process "http://localhost:8080"
