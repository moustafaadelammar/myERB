@echo off
setlocal EnableExtensions EnableDelayedExpansion
title myERP - Update and Start

set "REPO_URL=https://github.com/moustafaadelammar/myERP.git"
set "BRANCH=feature/local-fullstack"
set "PROJECT_DIR=%USERPROFILE%\myERP"
set "COMPOSE_FILE=docker-compose.local.yml"
set "LOG_FILE=%USERPROFILE%\myERP-startup.log"

if /I "%~1"=="RUN_LATEST" goto RUN_LATEST

echo.
echo ============================================================
echo                 myERP UPDATE + START
echo ============================================================
echo [INFO] This file always downloads the latest version first.
echo [INFO] Then it fixes known local startup issues, rebuilds,
echo        checks API/Web health, and opens the ERP.
echo ============================================================
echo.

echo [1/8] Checking Git...
where git >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Git is not installed or not in PATH.
  goto FAIL
)
echo [OK] Git found.

echo.
echo [2/8] Checking Docker...
where docker >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Docker Desktop is not installed or not in PATH.
  goto FAIL
)
docker info >nul 2>&1
if errorlevel 1 (
  echo [INFO] Starting Docker Desktop...
  if exist "%ProgramFiles%\Docker\Docker\Docker Desktop.exe" start "" "%ProgramFiles%\Docker\Docker\Docker Desktop.exe"
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
echo [3/8] Synchronizing from GitHub...
if not exist "%PROJECT_DIR%\.git" (
  if exist "%PROJECT_DIR%" (
    echo [INFO] Existing non-Git folder found. Renaming it safely...
    ren "%PROJECT_DIR%" "myERP_old_%RANDOM%"
    if errorlevel 1 goto FAIL
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
  git clean -fd
)
cd /d "%PROJECT_DIR%"
echo [OK] Project synchronized to:
git rev-parse --short HEAD

echo.
echo [4/8] Loading the newest startup script...
git show "origin/%BRANCH%:START-MYERP.cmd" > "%TEMP%\myERP-start-latest.cmd"
if errorlevel 1 (
  echo [ERROR] Could not load the newest startup script.
  goto FAIL
)
echo [OK] Newest startup script loaded.
call "%TEMP%\myERP-start-latest.cmd" RUN_LATEST
set "RC=%ERRORLEVEL%"
del /q "%TEMP%\myERP-start-latest.cmd" >nul 2>&1
exit /b %RC%

:RUN_LATEST
cd /d "%PROJECT_DIR%"
if errorlevel 1 goto FAIL

echo.
echo [5/8] Applying automatic compatibility repair...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p='backend\src\server.js'; $lines=Get-Content -LiteralPath $p; $idx=-1; for($i=0;$i -lt $lines.Count;$i++){if($lines[$i] -like '*app.get(''/api/inventory/warehouse-balances''*'){$idx=$i;break}}; if($idx -ge 0){$fixed='app.get(''/api/inventory/warehouse-balances'',auth,requirePermission(''inventory.manage''),async(req,res)=>{const {warehouseId,productId}=req.query;const args=[];const w=[];if(warehouseId){args.push(warehouseId);w.push(''sb.warehouse_id=$''+args.length)}if(productId){args.push(productId);w.push(''sb.product_id=$''+args.length)}const q=''select w.name warehouse_name,p.code,p.name,p.unit,p.cost,coalesce(sb.quantity,0) quantity,coalesce(sb.quantity,0)*p.cost value from stock_balances sb join warehouses w on w.id=sb.warehouse_id join products p on p.id=sb.product_id ''+(w.length?''where ''+w.join('' and ''):'')+'' order by w.name,p.name'';const r=await pool.query(q,args);res.json(r.rows)});'; $lines[$idx]=$fixed; [System.IO.File]::WriteAllLines((Resolve-Path $p),$lines,(New-Object System.Text.UTF8Encoding($false))); Write-Host '[OK] Inventory route compatibility repair applied.'}else{Write-Host '[OK] No inventory route repair needed.'}"
if errorlevel 1 (
  echo [ERROR] Automatic compatibility repair failed.
  goto DIAGNOSTICS
)

echo.
echo [6/8] Validating Compose...
docker compose -f "%COMPOSE_FILE%" config > "%TEMP%\myerp-compose-check.txt" 2>&1
if errorlevel 1 (
  echo [ERROR] Docker Compose configuration is invalid.
  type "%TEMP%\myerp-compose-check.txt"
  goto FAIL
)
echo [OK] Compose configuration valid.

echo.
echo [7/8] Rebuilding and starting myERP...
docker compose -f "%COMPOSE_FILE%" pull
if errorlevel 1 goto DIAGNOSTICS
docker compose -f "%COMPOSE_FILE%" up -d --build --remove-orphans
if errorlevel 1 goto DIAGNOSTICS
echo [OK] Containers started.

echo.
echo [8/8] Checking API and Web...
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
echo ============================================================
echo                 myERP IS READY
echo ============================================================
docker compose -f "%COMPOSE_FILE%" ps
echo.
echo Web:      http://localhost:8080
echo API:      http://localhost:4000/health
echo Login:    admin@myerb.local
echo Password: Admin@123
echo Commit:
git rev-parse --short HEAD
echo ============================================================
start "" "http://localhost:8080"
echo.
echo [DONE] Browser opened successfully.
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
echo Run this SAME file again after the displayed error is fixed.
echo It will automatically fetch the newest GitHub version.
echo.
pause
exit /b 1
