# myERB — نظام تشغيل الشركة

myERB هو نظام ERP عربي RTL مصمم ليصبح منصة تشغيل الشركة بالكامل، مع هندسة قابلة للتوسع وDevOps من البداية.

## المكونات الحالية

- React + Vite
- Arabic RTL responsive UI
- Dashboard, Sales, Purchases, Inventory, Customers, Suppliers, Finance, Reports
- GitHub source control
- GitHub Actions CI
- ESLint quality gate
- npm audit + Trivy security scanning
- Docker production image
- Docker Compose local runtime
- GitHub Container Registry publishing
- Kubernetes manifests
- Helm chart
- Terraform infrastructure boundary
- Dependabot

## DevOps workflow

```
Feature branch
    ↓
Pull Request
    ↓
GitHub Actions
    ├── lint
    ├── tests
    ├── build
    ├── Docker build
    └── security checks
    ↓
main
    ↓
GHCR container
    ↓
Staging
    ↓
Production Kubernetes
```

## Local full-stack development

### One-command local bootstrap (recommended)
**Windows PowerShell:**
```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\setup-local.ps1
```
The script checks/installs Git and Docker Desktop through `winget` when available, builds the complete stack, waits for PostgreSQL/API health, verifies the web app, and opens the browser.

**Linux/macOS:**
```bash
bash scripts/setup-local.sh
```

### Docker manually
```bash
docker compose -f docker-compose.local.yml up -d --build
```

Open ERP at http://localhost:8080 and API health at http://localhost:4000/health.

Default local login: admin@myerb.local / Admin@123.

### Direct development
```bash
docker compose -f docker-compose.local.yml up -d postgres
cd backend && npm install && npm run dev
```
In another terminal: `npm install && npm run dev`.

This local stack is intentionally independent of Supabase/cloud services; PostgreSQL is the local source of truth.

## Docker

```bash
docker compose up -d --build
```

Then open `http://localhost:8080`.

## Kubernetes

The `k8s/` directory contains the baseline namespace, deployment, service, ingress and autoscaling resources.

## Helm

```bash
helm lint helm/myerb
helm upgrade --install myerb ./helm/myerb -n myerb --create-namespace
```

The production cluster, DNS, TLS, managed PostgreSQL and secrets will be wired after the target infrastructure is selected. No credentials are stored in Git.

## Roadmap

1. Backend API + PostgreSQL
2. Authentication + RBAC
3. ERP database migrations and audit log
4. Staging environment
5. Kubernetes cluster
6. Terraform
7. Helm + GitOps/Argo CD
8. Prometheus + Grafana + centralized logs
9. Backups + disaster recovery
10. Production hardening and load testing
