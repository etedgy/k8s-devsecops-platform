# One-command local workflows (kind + Helm + Argo CD).
ENV     ?= dev
IMAGE   ?= rafael-web
TAG     ?= local
CLUSTER  = rafael-$(ENV)
NS       = web-$(ENV)
TFDIR    = infra/environments/$(ENV)
HOST     = web.$(ENV).localtest.me
export KUBECONFIG = $(abspath $(TFDIR)/.kube/config)

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

.PHONY: test
test: ## Run app unit/smoke tests
	cd app && npm ci && npm test

.PHONY: build
build: ## Build the app image
	docker build -t $(IMAGE):$(TAG) app

.PHONY: up
up: ## Provision the ENV cluster + addons (Terraform)
	cd $(TFDIR) && terraform init && terraform apply -auto-approve

.PHONY: load
load: build ## Load the locally-built image into the kind cluster
	kind load docker-image $(IMAGE):$(TAG) --name $(CLUSTER)

.PHONY: deploy
deploy: ## Imperative Helm install pinned to the local image (quick local test)
	helm upgrade --install web deploy/web -n $(NS) --create-namespace \
		-f deploy/web/values.yaml -f deploy/web/values-$(ENV).yaml \
		--set image.repository=$(IMAGE) --set image.tag=$(TAG) \
		--set-json 'imagePullSecrets=[]'
	kubectl argo rollouts status rollout/web -n $(NS) --timeout 180s || true

.PHONY: gitops
gitops: ## GitOps path: hand the cluster to Argo CD (project + app-of-apps root)
	kubectl apply -f argocd/project.yaml
	kubectl apply -f argocd/root.yaml

.PHONY: smoke
smoke: ## Curl the app through the ingress
	curl -fsS -H "Host: $(HOST)" http://localhost/my-app && echo

.PHONY: all
all: up load deploy smoke ## Full local path: cluster -> image -> deploy -> verify

.PHONY: down
down: ## Destroy the ENV cluster
	cd $(TFDIR) && terraform destroy -auto-approve || kind delete cluster --name $(CLUSTER)
