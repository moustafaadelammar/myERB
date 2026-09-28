#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
echo "=== myERB Local Bootstrap ==="
command -v git >/dev/null || { echo "Git is required."; exit 1; }
command -v docker >/dev/null || { echo "Docker Desktop/Engine is required."; exit 1; }
docker compose version >/dev/null
git fetch origin
BRANCH="$(git branch --show-current)"
[ -n "$BRANCH" ] && git pull --ff-only origin "$BRANCH" || true
docker compose -f docker-compose.local.yml up -d --build
for i in $(seq 1 40); do
  if curl -fsS http://localhost:4000/health >/dev/null 2>&1; then break; fi
  sleep 3
done
curl -fsS http://localhost:4000/health >/dev/null
curl -fsS http://localhost:8080 >/dev/null
echo "myERB is READY"
echo "ERP: http://localhost:8080"
echo "API: http://localhost:4000/health"
echo "User: admin@myerb.local"
echo "Pass: Admin@123"
