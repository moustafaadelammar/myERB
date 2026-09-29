@echo off
setlocal EnableExtensions EnableDelayedExpansion
title myERP - Full Sync + Verify + Run

set "REPO_URL=https://github.com/moustafaadelammar/myERP.git"
set "BRANCH=feature/local-fullstack"
set "PROJECT_DIR=%USERPROFILE%\myERP"
set "COMPOSE_FILE=docker-compose.local.yml"
set "LOG_FILE=%PROJECT_DIR%\myERP-startup.log"

echo.
echo ============================================================
echo             myERP FULL SYNC + VERIFY + RUN
echo ============================================================
echo Repository: %REPO_URL%
echo Branch:     %BRANCH%
echo Folder:     %PROJECT_DIR%
echo ============================================================
echo.

where winget >nul 2>&1
if errorlevel 1 (set "WINGET=0") else (set "WINGET=1")

echo [1/10] Checking Git...
where git >nul 2>&1
if errorlevel 1 (
    if "!WINGET!"=="1" (
        echo Git not found. Installing Git...
        winget install --id Git.Git -e --source winget --accept-source-agreements --accept-package-agreements
        set "PATH=%PATH%;%ProgramFiles%\Git\cmd;%LocalAppData%\Programs\Git\cmd"
    ) else (
        echo [ERROR] Git is missing and winget is unavailable.
        goto FAIL
    )
)
where git >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Git is still unavailable. Close CMD, reopen it, and run again.
    goto FAIL
)
echo [OK] Git ready.

echo.
echo [2/10] Checking Docker...
where docker >nul 2>&1
if errorlevel 1 (
    if "!WINGET!"=="1" (
        echo Docker Desktop not found. Installing Docker Desktop...
        winget install --id Docker.DockerDesktop -e --source winget --accept-source-agreements --accept-package-agreements
        set "PATH=%PATH%;%ProgramFiles%\Docker\Docker\resources\bin"
    ) else (
        echo [ERROR] Docker Desktop is missing and winget is unavailable.
        goto FAIL
    )
)
where docker >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker command is still unavailable.
    echo Close CMD and run this file again after Docker Desktop installation.
    goto FAIL
)
echo [OK] Docker command ready.

echo.
echo [3/10] Waiting for Docker Engine...
docker info >nul 2>&1
if errorlevel 1 (
    if exist "%ProgramFiles%\Docker\Docker\Docker Desktop.exe" (
        echo Starting Docker Desktop...
        start "" "%ProgramFiles%\Docker\Docker\Docker Desktop.exe"
    )
    set "DOCKER_OK=0"
    for /L %%I in (1,1,60) do (
        docker info >nul 2>&1
        if not errorlevel 1 (
            set "DOCKER_OK=1"
            goto DOCKER_READY
        )
        <nul set /p "=."
        timeout /t 3 /nobreak >nul
    )
    echo.
    if "!DOCKER_OK!"=="0" (
        echo [ERROR] Docker Engine did not become ready.
        goto FAIL
    )
)
:DOCKER_READY
echo.
echo [OK] Docker Engine ready.

echo.
echo [4/10] Syncing ALL repository files and updates...
if exist "%PROJECT_DIR%\.git" (
    cd /d "%PROJECT_DIR%"
    if errorlevel 1 goto FAIL

    echo Fetching remote branches and tags...
    git fetch --all --prune --tags
    if errorlevel 1 (
        echo [ERROR] git fetch failed.
        goto FAIL
    )

    echo Switching to %BRANCH%...
    git checkout "%BRANCH%" >nul 2>&1
    if errorlevel 1 (
        git checkout -b "%BRANCH%" "origin/%BRANCH%"
        if errorlevel 1 (
            echo [ERROR] Could not checkout %BRANCH%.
            goto FAIL
        )
    )

    echo Resetting local files to origin/%BRANCH%...
    git reset --hard "origin/%BRANCH%"
    if errorlevel 1 (
        echo [ERROR] git reset failed.
        goto FAIL
    )

    echo Removing stale untracked files...
    git clean -fd
    if errorlevel 1 (
        echo [ERROR] git clean failed.
        goto FAIL
    )

    echo Pulling latest remote state...
    git pull --ff-only origin "%BRANCH%"
    if errorlevel 1 (
        echo [ERROR] git pull failed.
        goto FAIL
    )
) else (
    if exist "%PROJECT_DIR%" (
        echo Existing non-Git folder found. Renaming it for safety...
        ren "%PROJECT_DIR%" "myERP_old_%RANDOM%"
        if errorlevel 1 (
            echo [ERROR] Could not rename old project folder.
            goto FAIL
        )
    )

    echo Cloning %BRANCH%...
    git clone --branch "%BRANCH%" --single-branch "%REPO_URL%" "%PROJECT_DIR%"
    if errorlevel 1 (
        echo [ERROR] Git clone failed.
        goto FAIL
    )
    cd /d "%PROJECT_DIR%"
)
echo [OK] Repository synchronized.

echo.
echo [5/10] Verifying required project files...
set "MISSING=0"
for %%F in (
    "docker-compose.local.yml"
    "Dockerfile"
    "backend\Dockerfile"
    "backend\package.json"
    "backend\src\server.js"
    "database\init.sql"
    "docker\nginx\default.conf"
    "package.json"
    "src\main.jsx"
    "src\styles.css"
) do (
    if not exist "%%~F" (
        echo [MISSING] %%~F
        set "MISSING=1"
    ) else (
        echo [OK] %%~F
    )
)
if "!MISSING!"=="1" (
    echo [ERROR] One or more required files are missing.
    goto FAIL
)

echo.
echo [6/10] Validating Docker Compose configuration...
docker compose -f "%COMPOSE_FILE%" config > "%TEMP%\myerp-compose-check.txt" 2>&1
if errorlevel 1 (
    echo [ERROR] docker-compose.local.yml is invalid.
    type "%TEMP%\myerp-compose-check.txt"
    goto FAIL
)
echo [OK] Compose configuration valid.

echo.
echo [7/10] Pulling required images and rebuilding EVERYTHING...
docker compose -f "%COMPOSE_FILE%" pull
if errorlevel 1 (
    echo [ERROR] Docker image pull failed.
    goto SHOW_LOGS
)

docker compose -f "%COMPOSE_FILE%" down --remove-orphans
if errorlevel 1 (
    echo [WARNING] Compose down returned an error. Continuing...
)

echo Removing legacy myERB containers if they exist...
for %%C in (myerb-postgres myerb-api myerb-web) do (
    docker rm -f %%C >nul 2>&1
)
echo [OK] Legacy container names cleared.

echo Building fresh application images...
docker compose -f "%COMPOSE_FILE%" build --pull
if errorlevel 1 (
    echo [ERROR] Docker build failed.
    goto SHOW_LOGS
)

echo Starting PostgreSQL + API + Web...
docker compose -f "%COMPOSE_FILE%" up -d --remove-orphans
if errorlevel 1 (
    echo [ERROR] Docker services failed to start.
    goto SHOW_LOGS
)

echo.
echo [8/10] Waiting for containers and API database health...
set "API_OK=0"
for /L %%I in (1,1,60) do (
    curl.exe -fsS http://localhost:4000/health >nul 2>&1
    if not errorlevel 1 (
        set "API_OK=1"
        goto API_READY
    )
    <nul set /p "=."
    timeout /t 3 /nobreak >nul
)
:API_READY
echo.
if "!API_OK!"=="0" (
    echo [ERROR] API health check failed.
    goto SHOW_LOGS
)
echo [OK] API is healthy and database is reachable.

echo.
echo [9/10] Checking Web/Nginx...
set "WEB_OK=0"
for /L %%I in (1,1,30) do (
    curl.exe -fsS http://localhost:8080/health >nul 2>&1
    if not errorlevel 1 (
        set "WEB_OK=1"
        goto WEB_READY
    )
    <nul set /p "=."
    timeout /t 2 /nobreak >nul
)
:WEB_READY
echo.
if "!WEB_OK!"=="0" (
    echo [ERROR] Web health check failed.
    goto SHOW_LOGS
)
echo [OK] Web/Nginx is healthy.

echo.
echo [10/10] Final verification and opening browser...
docker compose -f "%COMPOSE_FILE%" ps
echo.
echo Git commit:
git rev-parse --short HEAD
echo.
echo Verifying ERP page...
curl.exe -fsS http://localhost:8080/ > "%TEMP%\myerp-home.html"
if errorlevel 1 (
    echo [ERROR] ERP page could not be loaded.
    goto SHOW_LOGS
)

echo [OK] ERP page loaded successfully.
echo.
echo Opening browser...
start "" "http://localhost:8080"

echo.
echo ============================================================
echo                    myERP IS READY
echo ============================================================
echo Web:       http://localhost:8080
echo API:       http://localhost:4000/health
echo Login:     admin@myerb.local
echo Password:  Admin@123
echo Project:   %PROJECT_DIR%
echo.
echo Every run will:
echo  - Fetch all Git updates
echo  - Reset to the latest %BRANCH%
echo  - Remove stale untracked files
echo  - Validate required files
echo  - Validate Docker Compose
echo  - Pull latest Docker images
echo  - Rebuild application images
echo  - Start PostgreSQL + API + Web
echo  - Wait for API + Web health
echo  - Open the ERP browser
echo ============================================================
echo.
pause
exit /b 0

:SHOW_LOGS
echo.
echo ============================================================
echo                    DIAGNOSTICS
echo ============================================================
echo Saving diagnostics to: %LOG_FILE%
(
    echo ===== DATE/TIME =====
    echo %date% %time%
    echo.
    echo ===== GIT =====
    git status
    git rev-parse --short HEAD
    echo.
    echo ===== DOCKER PS =====
    docker compose -f "%COMPOSE_FILE%" ps
    echo.
    echo ===== DOCKER LOGS =====
    docker compose -f "%COMPOSE_FILE%" logs --tail=200
) > "%LOG_FILE%" 2>&1
type "%LOG_FILE%"
echo.
echo [ERROR] myERP was NOT opened because verification failed.
echo Full diagnostics:
echo %LOG_FILE%
goto FAIL

:FAIL
echo.
echo ============================================================
echo                    myERP START FAILED
echo ============================================================
echo Check the error above.
echo The window will stay open so you can read the result.
echo.
pause
exit /b 1
