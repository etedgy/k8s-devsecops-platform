# Troubleshooting / runbook

**Nodes stay `NotReady` after `terraform apply`.**
Expected until Cilium is up (default CNI is disabled). If it persists:
`kubectl -n kube-system rollout status ds/cilium`. Cilium must be Ready before
any other addon schedules.

**Pod can't reach anything / DNS fails.** Default-deny NetworkPolicy is working.
Egress is DNS-only by design; add an explicit allow policy for any new
dependency. Verify enforcement:
`kubectl -n web-dev exec deploy/... -- wget -qO- http://example.com` should hang,
while ingress from `ingress-nginx`/`monitoring` is allowed.

**Canary never promotes.** Check the AnalysisRun:
`kubectl argo rollouts get rollout web -n web-dev`. If success-rate is `NaN`,
there's no traffic — generate some (`hey`/`curl` loop) so Prometheus has data.
Prometheus must be scraping pods (`prometheus.io/scrape` annotation).

**`http://localhost` returns 404/connection refused.** ingress-nginx must run on
the `ingress-ready` control-plane node with hostPort 80. Confirm:
`kubectl -n ingress-nginx get pods -o wide`. The `Host:` header must match the
env ingress host (`web.<env>.localtest.me`).

**Image pull fails (private GHCR).** The `ghcr-cred` pull secret must exist in the
app namespace. For a fully local run, `make load` side-steps the registry by
loading the image into kind directly.

**Changing kind pod/service subnet forces a cluster REPLACE.** Don't
`-target=module.addons` afterward — it recreates the cluster but leaves addons in
state as existing, yielding a bare cluster. Run a full `terraform apply`.
