@echo off
setlocal EnableExtensions EnableDelayedExpansion
title myERP - FIX OLD INSTALL + START
echo.
echo ============================================================
echo              myERP FIX + ONE-CLICK START
echo ============================================================
echo.
echo This fixes the old myERB installation and starts the current
echo myERP feature/local-fullstack version.
echo.

set "REPO_URL=https://github.com/moustafaadelammar/myERP.git"
set "BRANCH=feature/local-fullstack"
set "PROJECT_DIR=%USERPROFILE%\myERP"

echo [1/5] Checking Git...
where git >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Git is not installed.
  echo Install Git, then run this file again.
  goto FAIL
)
echo [OK] Git found.

echo.
echo [2/5] Preparing current myERP folder...
if exist "%PROJECT_DIR%\.git" (
  cd /d "%PROJECT_DIR%"
  git fetch origin "%BRANCH%"
  if errorlevel 1 goto FAIL
  git checkout "%BRANCH%" >nul 2>&1
  if errorlevel 1 git checkout -b "%BRANCH%" "origin/%BRANCH%"
  if errorlevel 1 goto FAIL
  git reset --hard "origin/%BRANCH%"
  if errorlevel 1 goto FAIL
  git clean -fd
) else (
  if exist "%PROJECT_DIR%" (
    echo [INFO] Existing non-Git myERP folder found.
    ren "%PROJECT_DIR%" "myERP_old_%RANDOM%"
    if errorlevel 1 goto FAIL
  )
  git clone --branch "%BRANCH%" --single-branch "%REPO_URL%" "%PROJECT_DIR%"
  if errorlevel 1 goto FAIL
)
echo [OK] Current myERP version is ready.

echo.
echo [3/5] Starting the official myERP one-click installer...
cd /d "%PROJECT_DIR%"
call "%PROJECT_DIR%\myERP-ONE-CLICK.cmd"
set "RC=%ERRORLEVEL%"

echo.
if not "%RC%"=="0" (
  echo [ERROR] myERP startup failed.
  goto FAIL
)

echo [OK] myERP is running.
echo.
pause
exit /b 0

:FAIL
echo.
echo ============================================================
echo                    START FAILED
echo ============================================================
echo.
echo The old myERB folder was NOT used.
echo Current project folder: %PROJECT_DIR%
echo.
pause
exit /b 1
