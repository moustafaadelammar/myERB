@echo off
setlocal
title myERB - One Click Local Setup
cd /d "%~dp0.."

echo.
echo ==========================================
echo          myERB LOCAL SETUP
echo ==========================================
echo.

where docker >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Docker is not installed or not in PATH.
  echo Install Docker Desktop, start it, then run this file again.
  pause
  exit /b 1
)

docker info >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Docker Desktop is not running.
  echo Please start Docker Desktop and run this file again.
  pause
  exit /b 1
)

echo [1/4] Docker detected.
echo [2/4] Building and starting myERB...
docker compose -f docker-compose.local.yml up -d --build
if errorlevel 1 (
  echo.
  echo [ERROR] Failed to start myERB.
  echo Showing recent logs...
  docker compose -f docker-compose.local.yml logs --tail=100
  pause
  exit /b 1
)

echo [3/4] Waiting for API...
set /a RETRIES=0
:WAIT_API
set /a RETRIES+=1
curl.exe -fsS http://localhost:4000/health >nul 2>&1
if not errorlevel 1 goto API_OK
if %RETRIES% GEQ 40 goto API_FAIL
timeout /t 3 /nobreak >nul
goto WAIT_API

:API_OK
echo API is healthy.

echo [4/4] Opening myERB...
start "" "http://localhost:8080"

echo.
echo ==========================================
echo             myERB IS READY
echo ==========================================
echo.
echo Web:      http://localhost:8080
echo API:      http://localhost:4000/health
echo.
echo Login:
echo Email:    admin@myerb.local
echo Password: Admin@123
echo.
echo To stop:
echo docker compose -f docker-compose.local.yml down
echo.
pause
exit /b 0

:API_FAIL
echo.
echo [ERROR] API did not become healthy.
docker compose -f docker-compose.local.yml ps
docker compose -f docker-compose.local.yml logs --tail=100 api
pause
exit /b 1
