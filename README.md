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

## Local development

```bash
npm install
npm run dev
```

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
