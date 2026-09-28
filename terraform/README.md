# Terraform

This directory is reserved for infrastructure-as-code.

The first production target should be selected before adding provider-specific resources. Keep cloud credentials out of Git and inject them through the CI/CD secret store.

Planned layers:
- network
- container registry
- Kubernetes cluster
- DNS/TLS
- managed PostgreSQL
- object storage
- monitoring
