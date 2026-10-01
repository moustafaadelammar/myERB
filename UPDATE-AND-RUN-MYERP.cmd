@echo off
setlocal EnableExtensions EnableDelayedExpansion
title myERP - Update & Run

echo ============================================================
echo                  myERP UPDATE ^& RUN
echo ============================================================
echo.

set "REPO_URL=https://github.com/moustafaadelammar/myERP.git"
set "BRANCH=feature/local-fullstack"
set "SCRIPT_DIR=%~dp0"
if exist "%SCRIPT_DIR%.git" (set "PROJECT=%SCRIPT_DIR:~0,-1%") else (set "PROJECT=%USERPROFILE%\myERP")
set "COMPOSE=docker-compose.local.yml"

echo [1/7] Checking Git...
where git >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Git is not installed or not in PATH.
  echo Install Git, then run this file again.
  pause
  exit /b 1
)
echo [OK] Git found.

echo.
echo [2/7] Checking Docker...
where docker >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Docker is not installed or not in PATH.
  echo Install Docker Desktop, start it, then run this file again.
  pause
  exit /b 1
)

docker info >nul 2>&1
if errorlevel 1 (
  echo [INFO] Docker Desktop is not running. Trying to start it...
  start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe" >nul 2>&1
  if errorlevel 1 start "" "%LOCALAPPDATA%\Programs\Docker\Docker\Docker Desktop.exe" >nul 2>&1
  echo [INFO] Waiting for Docker...
  set /a WAIT=0
  :docker_wait
  timeout /t 2 /nobreak >nul
  docker info >nul 2>&1
  if not errorlevel 1 goto docker_ready
  set /a WAIT+=2
  if !WAIT! GEQ 90 (
    echo [ERROR] Docker engine did not become ready.
    pause
    exit /b 1
  )
  goto docker_wait
)
:docker_ready
echo [OK] Docker engine is running.

echo.
echo [3/7] Getting the latest myERP code...
if not exist "%PROJECT%\.git" (
  if exist "%PROJECT%" (
    echo [ERROR] %PROJECT% exists but is not a Git repository.
    echo Rename/delete that folder, then run this file again.
    pause
    exit /b 1
  )
  echo [INFO] First download...
  git clone --branch "%BRANCH%" "%REPO_URL%" "%PROJECT%"
  if errorlevel 1 goto fail
) else (
  cd /d "%PROJECT%"
  git fetch origin --prune
  if errorlevel 1 goto fail
  git checkout "%BRANCH%" >nul 2>&1
  if errorlevel 1 git checkout -b "%BRANCH%" "origin/%BRANCH%"
  git reset --hard "origin/%BRANCH%"
  if errorlevel 1 goto fail
  git clean -fd
)
cd /d "%PROJECT%"
echo [OK] Code is up to date.
for /f "delims=" %%G in ('git rev-parse --short HEAD') do set "COMMIT=%%G"
echo [INFO] Commit: !COMMIT!

echo.
echo [4/7] Validating Docker Compose...
docker compose -f "%COMPOSE%" config >nul
if errorlevel 1 goto fail
echo [OK] Compose configuration is valid.

echo.
echo [5/7] Rebuilding and starting myERP...
docker compose -f "%COMPOSE%" down --remove-orphans
docker compose -f "%COMPOSE%" pull
docker compose -f "%COMPOSE%" up -d --build
if errorlevel 1 goto fail

echo.
echo [6/7] Checking services...
set /a WAIT=0
:api_wait
powershell -NoProfile -Command "try { $r=Invoke-WebRequest -UseBasicParsing http://localhost:4000/health -TimeoutSec 3; if($r.StatusCode -eq 200){exit 0}else{exit 1} } catch { exit 1 }" >nul 2>&1
if not errorlevel 1 goto api_ready
timeout /t 2 /nobreak >nul
set /a WAIT+=2
if !WAIT! GEQ 90 (
  echo [ERROR] API did not become healthy.
  docker compose -f "%COMPOSE%" ps
  echo.
  echo -------- API LOG --------
  docker compose -f "%COMPOSE%" logs --tail=120 api
  echo -------------------------
  pause
  exit /b 1
)
goto api_wait

:api_ready
echo [OK] API is healthy.

powershell -NoProfile -Command "try { $r=Invoke-WebRequest -UseBasicParsing http://localhost:8080/health -TimeoutSec 5; if($r.StatusCode -eq 200){exit 0}else{exit 1} } catch { exit 1 }" >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Web service is not healthy.
  docker compose -f "%COMPOSE%" ps
  pause
  exit /b 1
)
echo [OK] Web is healthy.

echo.
echo [7/7] Opening myERP...
start "" "http://localhost:8080"

echo.
echo ============================================================
echo                    myERP IS READY
echo ============================================================
echo URL:    http://localhost:8080
echo API:    http://localhost:4000/health
echo Commit: !COMMIT!
echo.
echo Login:
echo Email:    admin@myerb.local
echo Password: Admin@123
echo.
echo Every time you change the project:
echo 1. Push the change to GitHub.
echo 2. Run this same CMD file.
echo 3. It fetches the latest code, rebuilds, and runs it.
echo ============================================================
pause
exit /b 0

:fail
echo.
echo [ERROR] Operation failed.
echo.
echo -------- SERVICES --------
docker compose -f "%COMPOSE%" ps
echo.
echo -------- API LOG --------
docker compose -f "%COMPOSE%" logs --tail=120 api
echo -------------------------
echo.
pause
exit /b 1
