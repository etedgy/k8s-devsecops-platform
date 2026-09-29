# Environments

Each environment is a **thin wiring** of the reusable modules
(`../modules/kind-cluster`, `../modules/addons`) plus its own `terraform.tfvars`.
That's the seam: swap `modules/kind-cluster` for an EKS/AKS/GKE module and the
rest of the stack (addons, app, GitOps) is unchanged.

| Env      | Cluster        | Workers | Notes                            |
|----------|----------------|---------|----------------------------------|
| dev      | rafael-dev     | 1       | auto-sync, canary analysis demo  |
| staging  | rafael-staging | 1       | manual sync                      |
| prod     | rafael-prod    | 2       | manual sync, remote state        |

```bash
cd dev && terraform init && terraform apply   # ~4 min: cluster + addons
```
