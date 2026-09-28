@echo off
setlocal
cd /d "%~dp0.."
echo === myERB PostgreSQL Backup ===
where docker >nul 2>nul || (echo Docker not found.&exit /b 1)
if not exist backups mkdir backups
for /f "tokens=1-3 delims=/- " %%a in ("%date%") do set D=%%c-%%a-%%b
for /f "tokens=1-2 delims=: " %%a in ("%time%") do set T=%%a%%b
set FILE=backups\myerb-%D%-%T%.sql
docker compose -f docker-compose.local.yml exec -T postgres pg_dump -U myerb -d myerb --clean --if-exists > "%FILE%"
if errorlevel 1 (echo Backup failed.&exit /b 1)
echo Backup created: %FILE%
