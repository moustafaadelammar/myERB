#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
LOG_FILE="$PWD/myERP-startup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== myERP ONE-CLICK LOCAL BOOTSTRAP ==="
command -v git >/dev/null || { echo "[ERROR] Git is required."; exit 1; }
command -v docker >/dev/null || { echo "[ERROR] Docker is required."; exit 1; }
docker compose version >/dev/null

git fetch origin
git checkout feature/local-fullstack 2>/dev/null || git checkout -b feature/local-fullstack origin/feature/local-fullstack
git reset --hard origin/feature/local-fullstack
git clean -fd

echo "[OK] Synced feature/local-fullstack."
docker compose -f docker-compose.local.yml config >/dev/null
echo "[OK] Docker Compose configuration valid."

docker compose -f docker-compose.local.yml up -d --build

echo "Waiting for API..."
for i in $(seq 1 40); do
  if curl -fsS http://localhost:4000/health >/dev/null 2>&1; then break; fi
  sleep 3
done
curl -fsS http://localhost:4000/health >/dev/null

echo "Waiting for Web..."
for i in $(seq 1 20); do
  if curl -fsS http://localhost:8080/health >/dev/null 2>&1; then break; fi
  sleep 2
done
curl -fsS http://localhost:8080/health >/dev/null

echo
echo "========================================"
echo " myERP IS READY"
echo "========================================"
echo "ERP:  http://localhost:8080"
echo "API:  http://localhost:4000/health"
echo "User: admin@myerb.local"
echo "Pass: Admin@123"
echo "Log:  $LOG_FILE"
