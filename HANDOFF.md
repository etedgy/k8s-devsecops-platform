# Handoff

Status of this DevSecOps take-home and how to pick it up. Detail lives in the
[README](README.md) and [docs/](docs/); live evidence in [docs/DEMO.md](docs/DEMO.md).

## TL;DR
Sample Node.js app on Kubernetes, reproducible on `kind` at **zero cloud cost**:
IaC (Terraform) → security-gated CI (Semgrep SAST + Trivy, both **blocking**) →
private GHCR → GitOps CD (Argo CD app-of-apps) → progressive delivery (Argo
Rollouts canary, Prometheus-gated) behind default-deny networking (Cilium) with a
real LoadBalancer (MetalLB).

## Reproduce
```bash
make all ENV=dev            # cluster + addons + build + deploy + smoke
make gitops ENV=dev         # hand CD to Argo CD
make down ENV=dev           # tear down
```

## Repos / images
- Platform monorepo: https://github.com/etedgy/k8s-devsecops-platform
- App image: ghcr.io/etedgy/rafael-web (private GHCR)
- App fork (origin): https://github.com/etedgy/sample-nodejs

## Known gaps (honest)
- Cloud target not built — kind only, by design. `modules/kind-cluster` is the seam.
- Argo Image Updater not installed locally; CI does the git tag write-back instead
  (annotations for the cloud alternative are documented).
- Branch protection is a one-command apply (docs/governance.md), enable on the repo.
