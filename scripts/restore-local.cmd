@echo off
setlocal
cd /d "%~dp0.."
if "%~1"=="" (echo Usage: scripts\restore-local.cmd backups\file.sql&exit /b 1)
if not exist "%~1" (echo Backup file not found.&exit /b 1)
echo === myERB PostgreSQL Restore ===
where docker >nul 2>nul || (echo Docker not found.&exit /b 1)
echo WARNING: this replaces database contents.
set /p OK=Continue? [Y/N]:
if /I not "%OK%"=="Y" exit /b 0
docker compose -f docker-compose.local.yml exec -T postgres psql -U myerb -d myerb < "%~1"
if errorlevel 1 (echo Restore failed.&exit /b 1)
echo Restore completed.
