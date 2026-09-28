@echo off
setlocal EnableExtensions EnableDelayedExpansion
title myERB - One Click Installer

set "REPO_URL=https://github.com/moustafaadelammar/myERB.git"
set "BRANCH=feature/local-fullstack"
set "PROJECT_DIR=%USERPROFILE%\myERB"
set "COMPOSE_FILE=docker-compose.local.yml"
set "WEB_URL=http://localhost:8080"
set "API_URL=http://localhost:4000/health"

echo.
echo ============================================================
echo                 myERB ONE-CLICK SETUP
echo ============================================================
echo.
echo This file downloads/updates the project, installs Git and
echo Docker Desktop when possible, builds the full stack, checks
echo the API, and opens the ERP in your browser.
echo.
echo Project folder: %PROJECT_DIR%
echo.

where winget >nul 2>&1
if errorlevel 1 (
  set "WINGET=0"
  echo [WARN] winget not found. Automatic installation of missing
  echo        prerequisites will not be possible.
) else (
  set "WINGET=1"
  echo [OK] winget detected.
)

where git >nul 2>&1
if errorlevel 1 (
  echo.
  echo [INFO] Git is missing.
  if "!WINGET!"=="1" (
    echo [INFO] Installing Git...
    winget install --id Git.Git -e --source winget --accept-source-agreements --accept-package-agreements
    where git >nul 2>&1
    if errorlevel 1 (
      echo [ERROR] Git is installed but is not available in this CMD yet.
      echo Close this window, open a new CMD, and run this file again.
      pause
      exit /b 1
    )
  ) else (
    echo [ERROR] Install Git for Windows and run this file again.
    pause
    exit /b 1
  )
)
echo [OK] Git is available.

where docker >nul 2>&1
if errorlevel 1 (
  echo.
  echo [INFO] Docker is missing.
  if "!WINGET!"=="1" (
    echo [INFO] Installing Docker Desktop...
    winget install --id Docker.DockerDesktop -e --source winget --accept-source-agreements --accept-package-agreements
    where docker >nul 2>&1
    if errorlevel 1 (
      echo.
      echo [WARN] Docker Desktop was installed, but this CMD session
      echo        cannot see Docker yet.
      echo Start Docker Desktop. If Windows requests a restart,
      echo restart Windows, then run this file again.
      pause
      exit /b 0
    )
  ) else (
    echo [ERROR] Install Docker Desktop and run this file again.
    pause
    exit /b 1
  )
)
echo [OK] Docker command is available.

docker info >nul 2>&1
if errorlevel 1 (
  echo.
  echo [INFO] Docker engine is not running.
  if exist "%ProgramFiles%\Docker\Docker\Docker Desktop.exe" (
    echo [INFO] Starting Docker Desktop...
    start "" "%ProgramFiles%\Docker\Docker\Docker Desktop.exe"
  )
  echo [INFO] Waiting for Docker engine...
  set "DOCKER_READY=0"
  for /L %%I in (1,1,30) do (
    docker info >nul 2>&1
    if not errorlevel 1 (
      set "DOCKER_READY=1"
      goto DOCKER_OK
    )
    timeout /t 4 /nobreak >nul
  )
  if "!DOCKER_READY!"=="0" (
    echo [ERROR] Docker engine did not become ready.
    echo Start Docker Desktop and run this file again.
    pause
    exit /b 1
  )
)
:DOCKER_OK
echo [OK] Docker engine is running.

echo.
echo ============================================================
echo                 PROJECT DOWNLOAD / UPDATE
echo ============================================================
echo.

if exist "%PROJECT_DIR%\.git" (
  cd /d "%PROJECT_DIR%"
  echo [INFO] Existing repository found.
  echo [INFO] Fetching latest %BRANCH%...
  git fetch origin --prune
  if errorlevel 1 (
    echo [ERROR] Git fetch failed.
    pause
    exit /b 1
  )
  git checkout "%BRANCH%" >nul 2>&1
  if errorlevel 1 (
    git checkout -b "%BRANCH%" "origin/%BRANCH%"
    if errorlevel 1 (
      echo [ERROR] Cannot checkout %BRANCH%.
      pause
      exit /b 1
    )
  )
  git reset --hard "origin/%BRANCH%"
  if errorlevel 1 (
    echo [ERROR] Cannot update the project.
    pause
    exit /b 1
  )
  git clean -fd
) else (
  if exist "%PROJECT_DIR%" (
    echo [INFO] Existing non-Git folder found.
    echo [INFO] Renaming it to a backup...
    for /f "tokens=1-3 delims=/ " %%a in ("%date%") do set "DATESTAMP=%%c-%%a-%%b"
    set "BACKUP_DIR=%PROJECT_DIR%_backup_%RANDOM%"
    ren "%PROJECT_DIR%" "myERB_backup_%RANDOM%" >nul 2>&1
  )
  echo [INFO] Cloning myERB from GitHub...
  git clone --branch "%BRANCH%" --single-branch "%REPO_URL%" "%PROJECT_DIR%"
  if errorlevel 1 (
    echo [ERROR] Git clone failed.
    pause
    exit /b 1
  )
  cd /d "%PROJECT_DIR%"
)

if not exist "%PROJECT_DIR%\%COMPOSE_FILE%" (
  echo [ERROR] %COMPOSE_FILE% was not found.
  pause
  exit /b 1
)

echo [OK] Project files are ready.
echo [INFO] Commit:
git rev-parse --short HEAD

echo.
echo ============================================================
echo                 BUILDING FULL STACK
echo ============================================================
echo.

docker compose -f "%COMPOSE_FILE%" down --remove-orphans >nul 2>&1
docker compose -f "%COMPOSE_FILE%" up -d --build --remove-orphans
if errorlevel 1 (
  echo.
  echo [ERROR] Docker Compose failed.
  docker compose -f "%COMPOSE_FILE%" logs --tail=150
  pause
  exit /b 1
)

echo.
echo [INFO] Waiting for API health...
set "API_READY=0"
for /L %%I in (1,1,40) do (
  curl.exe -fsS "%API_URL%" >nul 2>&1
  if not errorlevel 1 (
    set "API_READY=1"
    goto API_OK
  )
  timeout /t 3 /nobreak >nul
)
:API_OK
if "!API_READY!"=="0" (
  echo [ERROR] API did not become healthy.
  docker compose -f "%COMPOSE_FILE%" ps
  docker compose -f "%COMPOSE_FILE%" logs --tail=120 api
  pause
  exit /b 1
)

echo [OK] API is healthy.
echo [INFO] Checking web application...
set "WEB_READY=0"
for /L %%I in (1,1,20) do (
  curl.exe -fsS "%WEB_URL%" >nul 2>&1
  if not errorlevel 1 (
    set "WEB_READY=1"
    goto WEB_OK
  )
  timeout /t 2 /nobreak >nul
)
:WEB_OK

echo.
echo ============================================================
echo                    myERB IS READY
echo ============================================================
echo.
echo Web:        %WEB_URL%
echo API:        %API_URL%
echo Project:    %PROJECT_DIR%
echo.
echo Login:
echo   Email:    admin@myerb.local
echo   Password: Admin@123
echo.
echo Useful commands:
echo   Start:  docker compose -f %COMPOSE_FILE% up -d
echo   Stop:   docker compose -f %COMPOSE_FILE% down
echo   Logs:   docker compose -f %COMPOSE_FILE% logs -f
echo   Status: docker compose -f %COMPOSE_FILE% ps
echo.
echo ============================================================
echo.

start "" "%WEB_URL%"
echo Browser opened.
echo.
pause
exit /b 0
