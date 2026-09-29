@echo off
setlocal EnableExtensions EnableDelayedExpansion
title myERP - One Click Installer

set "REPO_URL=https://github.com/moustafaadelammar/myERP.git"
set "BRANCH=feature/local-fullstack"
set "PROJECT_DIR=%USERPROFILE%\myERP"
set "COMPOSE_FILE=docker-compose.local.yml"

echo.
echo ============================================================
echo                    myERP ONE CLICK
echo ============================================================
echo.

where winget >nul 2>&1 && (set "WINGET=1") || (set "WINGET=0")
where git >nul 2>&1
if errorlevel 1 (
  if "!WINGET!"=="1" winget install --id Git.Git -e --source winget --accept-source-agreements --accept-package-agreements
  where git >nul 2>&1 || (echo [ERROR] Git is unavailable.&pause&exit /b 1)
)
echo [1/7] Git OK.

where docker >nul 2>&1
if errorlevel 1 (
  if "!WINGET!"=="1" winget install --id Docker.DockerDesktop -e --source winget --accept-source-agreements --accept-package-agreements
  where docker >nul 2>&1 || (echo [ERROR] Docker Desktop is unavailable.&pause&exit /b 1)
)
echo [2/7] Docker command OK.

docker info >nul 2>&1
if errorlevel 1 (
  if exist "%ProgramFiles%\Docker\Docker\Docker Desktop.exe" start "" "%ProgramFiles%\Docker\Docker\Docker Desktop.exe"
  echo [3/7] Waiting for Docker Desktop...
  set "READY=0"
  for /L %%I in (1,1,45) do (
    docker info >nul 2>&1
    if not errorlevel 1 (set "READY=1"&goto DOCKER_READY)
    timeout /t 4 /nobreak >nul
  )
  if "!READY!"=="0" (echo [ERROR] Docker engine is not ready.&pause&exit /b 1)
)
:DOCKER_READY
echo [3/7] Docker engine OK.

if exist "%PROJECT_DIR%\.git" (
  cd /d "%PROJECT_DIR%"
  echo [4/7] Updating project...
  git fetch origin --prune
  git checkout "%BRANCH%" >nul 2>&1
  if errorlevel 1 git checkout -b "%BRANCH%" "origin/%BRANCH%"
  git reset --hard "origin/%BRANCH%"
  git clean -fd
) else (
  if exist "%PROJECT_DIR%" ren "%PROJECT_DIR%" "myERP_old_%RANDOM%"
  echo [4/7] Downloading project...
  git clone --branch "%BRANCH%" --single-branch "%REPO_URL%" "%PROJECT_DIR%"
  if errorlevel 1 (echo [ERROR] Download failed.&pause&exit /b 1)
  cd /d "%PROJECT_DIR%"
)
echo [4/7] Project OK.

if not exist "%COMPOSE_FILE%" (echo [ERROR] docker-compose.local.yml not found.&pause&exit /b 1)
echo [5/7] Building and starting PostgreSQL + API + Web...
docker compose -f "%COMPOSE_FILE%" up -d --build --remove-orphans
if errorlevel 1 (docker compose -f "%COMPOSE_FILE%" logs --tail=120&pause&exit /b 1)

echo [6/7] Checking API...
set "API_OK=0"
for /L %%I in (1,1,40) do (
  curl.exe -fsS http://localhost:4000/health >nul 2>&1
  if not errorlevel 1 (set "API_OK=1"&goto HEALTH_OK)
  timeout /t 3 /nobreak >nul
)
:HEALTH_OK
if "!API_OK!"=="0" (echo [ERROR] API health check failed.&docker compose -f "%COMPOSE_FILE%" ps&docker compose -f "%COMPOSE_FILE%" logs --tail=100 api&pause&exit /b 1)

echo [7/7] Opening myERP...
start "" "http://localhost:8080"
echo.
echo ============================================================
echo                    myERP IS READY
echo ============================================================
echo Web:      http://localhost:8080
echo API:      http://localhost:4000/health
echo Login:    admin@myerb.local
echo Password: Admin@123
echo Folder:   %PROJECT_DIR%
echo.
echo Stop: docker compose -f "%COMPOSE_FILE%" down
echo Logs: docker compose -f "%COMPOSE_FILE%" logs -f
echo ============================================================
echo.
pause
exit /b 0
