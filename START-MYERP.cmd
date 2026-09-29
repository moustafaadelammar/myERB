@echo off
setlocal EnableExtensions EnableDelayedExpansion
title myERP - Update and Start

set "REPO_URL=https://github.com/moustafaadelammar/myERP.git"
set "BRANCH=feature/local-fullstack"
set "PROJECT_DIR=%USERPROFILE%\myERP"
set "COMPOSE_FILE=docker-compose.local.yml"
set "LOG_FILE=%USERPROFILE%\myERP-startup.log"

echo.
echo ============================================================
echo                 myERP UPDATE + START
echo ============================================================
echo [INFO] Every time you run this file:
echo        1. Downloads the latest GitHub changes
echo        2. Rebuilds the application
echo        3. Starts PostgreSQL + API + Web
echo        4. Checks API and Web health
echo        5. Opens the ERP
echo ============================================================
echo.

echo [1/7] Checking Git...
where git >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Git is not installed or not in PATH.
  goto FAIL
)
echo [OK] Git found.

echo.
echo [2/7] Checking Docker...
where docker >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Docker Desktop is not installed or not in PATH.
  goto FAIL
)
docker info >nul 2>&1
if errorlevel 1 (
  echo [INFO] Starting Docker Desktop...
  if exist "%ProgramFiles%\Docker\Docker\Docker Desktop.exe" start "" "%ProgramFiles%\Docker\Docker\Docker Desktop.exe"
  echo [INFO] Waiting for Docker Engine...
  set "DOCKER_OK=0"
  for /L %%I in (1,1,60) do (
    docker info >nul 2>&1
    if not errorlevel 1 (
      set "DOCKER_OK=1"
      goto DOCKER_READY
    )
    <nul set /p "=. "
    timeout /t 2 /nobreak >nul
  )
  echo.
  if "!DOCKER_OK!"=="0" (
    echo [ERROR] Docker Engine did not start.
    goto FAIL
  )
)
:DOCKER_READY
echo [OK] Docker Engine ready.

echo.
echo [3/7] Synchronizing project from GitHub...
if not exist "%PROJECT_DIR%\.git" (
  if exist "%PROJECT_DIR%" (
    echo [INFO] Existing non-Git folder found.
    ren "%PROJECT_DIR%" "myERP_old_%RANDOM%"
    if errorlevel 1 (
      echo [ERROR] Cannot rename old project folder.
      goto FAIL
    )
  )
  git clone --branch "%BRANCH%" --single-branch "%REPO_URL%" "%PROJECT_DIR%"
  if errorlevel 1 (
    echo [ERROR] Clone failed.
    goto FAIL
  )
) else (
  cd /d "%PROJECT_DIR%"
  if errorlevel 1 goto FAIL
  git fetch origin --prune
  if errorlevel 1 (
    echo [ERROR] Git fetch failed.
    goto FAIL
  )
  git checkout "%BRANCH%" >nul 2>&1
  if errorlevel 1 git checkout -b "%BRANCH%" "origin/%BRANCH%"
  if errorlevel 1 (
    echo [ERROR] Cannot switch to %BRANCH%.
    goto FAIL
  )
  git reset --hard "origin/%BRANCH%"
  if errorlevel 1 (
    echo [ERROR] Git reset failed.
    goto FAIL
  )
)
cd /d "%PROJECT_DIR%"
echo [OK] Project updated to:
git rev-parse --short HEAD

echo.
echo [4/7] Validating Docker Compose...
docker compose -f "%COMPOSE_FILE%" config > "%TEMP%\myerp-compose-check.txt" 2>&1
if errorlevel 1 (
  echo [ERROR] Docker Compose configuration is invalid.
  type "%TEMP%\myerp-compose-check.txt"
  goto FAIL
)
echo [OK] Compose configuration valid.

echo.
echo [5/7] Rebuilding and starting myERP...
docker compose -f "%COMPOSE_FILE%" pull
if errorlevel 1 (
  echo [ERROR] Docker image pull failed.
  goto DIAGNOSTICS
)
docker compose -f "%COMPOSE_FILE%" up -d --build --remove-orphans
if errorlevel 1 (
  echo [ERROR] Containers failed to start.
  goto DIAGNOSTICS
)
echo [OK] Containers started.

echo.
echo [6/7] Checking API...
set "API_OK=0"
for /L %%I in (1,1,60) do (
  curl.exe -fsS http://127.0.0.1:4000/health >nul 2>&1
  if not errorlevel 1 (
    set "API_OK=1"
    goto API_READY
  )
  <nul set /p "=. "
  timeout /t 2 /nobreak >nul
)
:API_READY
echo.
if "!API_OK!"=="0" (
  echo [ERROR] API is not healthy.
  goto DIAGNOSTICS
)
echo [OK] API is healthy.

echo.
echo [7/7] Checking Web...
set "WEB_OK=0"
for /L %%I in (1,1,30) do (
  curl.exe -fsS http://127.0.0.1:8080/health >nul 2>&1
  if not errorlevel 1 (
    set "WEB_OK=1"
    goto WEB_READY
  )
  <nul set /p "=. "
  timeout /t 2 /nobreak >nul
)
:WEB_READY
echo.
if "!WEB_OK!"=="0" (
  echo [ERROR] Web is not healthy.
  goto DIAGNOSTICS
)

echo.
echo [OK] myERP is READY.
echo.
docker compose -f "%COMPOSE_FILE%" ps
echo.
echo ============================================================
echo Web:      http://localhost:8080
echo API:      http://localhost:4000/health
echo Login:    admin@myerb.local
echo Password: Admin@123
echo Commit:
git rev-parse --short HEAD
echo ============================================================
echo.
start "" "http://localhost:8080"
echo.
echo [DONE] Browser opened.
echo [INFO] Close this window or press any key.
pause >nul
exit /b 0

:DIAGNOSTICS
echo.
echo ============================================================
echo                    DIAGNOSTICS
echo ============================================================
(
  echo ===== DATE/TIME =====
  echo %date% %time%
  echo.
  echo ===== GIT COMMIT =====
  git rev-parse --short HEAD
  echo.
  echo ===== DOCKER STATUS =====
  docker compose -f "%COMPOSE_FILE%" ps
  echo.
  echo ===== API LOG =====
  docker compose -f "%COMPOSE_FILE%" logs --tail=200 api
  echo.
  echo ===== ALL LOGS =====
  docker compose -f "%COMPOSE_FILE%" logs --tail=100
) > "%LOG_FILE%" 2>&1
type "%LOG_FILE%"
echo.
echo [ERROR] myERP did not start successfully.
echo Log saved to: %LOG_FILE%
goto FAIL

:FAIL
echo.
echo ============================================================
echo                 myERP START FAILED
echo ============================================================
echo Fix the error shown above, then run this SAME file again.
echo It will automatically fetch the newest GitHub version.
echo.
pause
exit /b 1
