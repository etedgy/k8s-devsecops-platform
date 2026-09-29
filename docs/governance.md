# Repo governance & branch protection

`main` is the single source of truth Argo CD reconciles from, so what merges to
`main` is what runs in the cluster. Protect it:

- **No direct pushes to `main`** — all changes land via pull request.
- **≥1 approving review from a Code Owner** (`.github/CODEOWNERS`); stale
  approvals dismissed on new commits.
- **Required status checks**: the `ci` workflow (`test`, `sast`,
  `validate-manifests`, image build+scan) must pass, and the branch must be up
  to date, before merge.
- **Linear history** — merge commits disallowed; PRs merge by **rebase**.
- **No force-push / deletion** of `main`.

## Enable it (GitHub CLI)

```bash
gh api -X PUT repos/etedgy/k8s-devsecops-platform/branches/main/protection \
  -H "Accept: application/vnd.github+json" \
  -f 'required_status_checks[strict]=true' \
  -f 'required_status_checks[contexts][]=test' \
  -f 'required_status_checks[contexts][]=sast' \
  -f 'required_status_checks[contexts][]=validate-manifests' \
  -F 'enforce_admins=true' \
  -F 'required_pull_request_reviews[required_approving_review_count]=1' \
  -F 'required_pull_request_reviews[require_code_owner_reviews]=true' \
  -F 'restrictions=null' -F 'required_linear_history=true' -F 'allow_force_pushes=false'
```

## Developer workflow

```bash
git checkout -b feat/x
# ...work...
git push -u origin feat/x
gh pr create        # CI runs; a code owner reviews
# merge by rebase once green + approved
```
