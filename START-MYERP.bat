@echo off
setlocal
title myERP - START
echo.
echo ============================================================
echo                    STARTING myERP
echo ============================================================
echo.
echo This window will stay open and show every step.
echo Do NOT close it while myERP is starting.
echo.
call "%~dp0myERP-ONE-CLICK.cmd"
set "RC=%ERRORLEVEL%"
echo.
if "%RC%"=="0" (
  echo [OK] myERP startup completed.
) else (
  echo [ERROR] myERP startup failed. Read the diagnostics above.
)
echo.
pause
exit /b %RC%
