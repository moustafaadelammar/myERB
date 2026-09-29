@echo off
setlocal EnableExtensions
title myERP - Update and Run

set "REPO=moustafaadelammar/myERP"
set "BRANCH=feature/local-fullstack"
set "APP=%USERPROFILE%\myERP"
set "COMPOSE=docker-compose.local.yml"
set "LOG=%APP%\myERP-update.log"

echo.
echo ============================================================
echo                    myERP UPDATE + RUN
echo ============================================================
echo.
echo [INFO] Project: %APP%
echo [INFO] Branch : %BRANCH%
echo.

if not exist "%APP%" (
  echo [INFO] Project folder not found. Cloning...
  git clone -b %BRANCH% https://github.com/%REPO%.git "%APP%"
  if errorlevel 1 goto :error
) else (
  cd /d "%APP%"
  echo [INFO] Downloading latest changes...
  git fetch origin --prune
  if errorlevel 1 goto :error
  git checkout %BRANCH% >nul 2>&1
  if errorlevel 1 git checkout -b %BRANCH% origin/%BRANCH%
  git reset --hard origin/%BRANCH%
  if errorlevel 1 goto :error
)

cd /d "%APP%"
echo [OK] Source code updated.
echo [INFO] Commit:
git rev-parse --short HEAD
echo.

if not exist "%COMPOSE%" (
  echo [ERROR] %COMPOSE% not found.
  goto :error
)

docker version >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Docker Desktop/Engine is not running.
  echo [INFO] Start Docker Desktop, then run this file again.
  goto :error
)

echo [STEP 1/5] Validating Docker Compose...
docker compose -f "%COMPOSE%" config >nul
if errorlevel 1 goto :error
echo [OK] Compose configuration valid.
echo.

echo [STEP 2/5] Stopping old containers...
docker compose -f "%COMPOSE%" down
if errorlevel 1 goto :error
echo.

echo [STEP 3/5] Building latest version...
docker compose -f "%COMPOSE%" build --pull
if errorlevel 1 goto :error
echo.

echo [STEP 4/5] Starting myERP...
docker compose -f "%COMPOSE%" up -d
if errorlevel 1 goto :error
echo.

echo [STEP 5/5] Checking API...
set "API_OK="
for /L %%N in (1,1,30) do (
  powershell -NoProfile -Command "try { $r=Invoke-WebRequest -UseBasicParsing http://127.0.0.1:4000/health -TimeoutSec 2; if($r.StatusCode -eq 200){exit 0}else{exit 1} } catch { exit 1 }" >nul 2>&1
  if not errorlevel 1 (
    set "API_OK=1"
    goto :api_done
  )
  timeout /t 2 /nobreak >nul
)
:api_done

if not defined API_OK (
  echo [ERROR] API did not become healthy.
  echo.
  docker compose -f "%COMPOSE%" ps
  echo.
  echo ---------------- API LOG ----------------
  docker compose -f "%COMPOSE%" logs --tail=100 api
  goto :error
)

echo [OK] API is healthy.
echo [OK] myERP is running.
echo.
echo ============================================================
echo                 OPENING myERP
echo ============================================================
echo.
start "" "http://localhost:8080"
echo [OK] Browser opened: http://localhost:8080
echo.
echo [INFO] Every time you change code and push to GitHub:
echo        run this same START-MYERP.cmd
echo        It will fetch, replace local code, rebuild and run.
echo.
echo [INFO] Log file: %LOG%
echo.
git rev-parse --short HEAD > "%LOG%"
echo Update completed successfully. >> "%LOG%"
echo.
pause
exit /b 0

:error
echo.
echo ============================================================
echo                         FAILED
echo ============================================================
echo.
echo [ERROR] The update/startup process failed.
echo [INFO] Project: %APP%
echo [INFO] Check the messages above.
echo.
echo [INFO] Current containers:
docker compose -f "%COMPOSE%" ps 2>nul
echo.
echo [INFO] Full recent API log:
docker compose -f "%COMPOSE%" logs --tail=100 api 2>nul
echo.
echo Failed. >> "%LOG%" 2>nul
pause
exit /b 1
