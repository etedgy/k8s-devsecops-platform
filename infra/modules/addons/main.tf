variable "ingress_nginx_version" {
  type    = string
  default = "4.11.2"
}
variable "metrics_server_version" {
  type    = string
  default = "3.12.1"
}
variable "argocd_version" {
  type    = string
  default = "7.6.12"
}
variable "argo_rollouts_version" {
  type    = string
  default = "2.37.3"
}
variable "prometheus_version" {
  type    = string
  default = "25.27.0"
}
variable "cilium_version" {
  type    = string
  default = "1.16.3"
}
variable "metallb_version" {
  type    = string
  default = "0.14.8"
}
variable "kubeconfig_path" {
  description = "Kubeconfig used to apply the MetalLB address pool."
  type        = string
}
variable "lb_address_pool" {
  description = "L2 range MetalLB hands out (inside the kind docker network, clear of node IPs)."
  type        = string
  default     = "172.18.255.200-172.18.255.250"
}

# CNI + NetworkPolicy enforcement. Installed first: nodes are NotReady without
# it (default CNI disabled), so every other addon depends on it.
resource "helm_release" "cilium" {
  name       = "cilium"
  repository = "https://helm.cilium.io"
  chart      = "cilium"
  version    = var.cilium_version
  namespace  = "kube-system"

  values = [yamlencode({
    ipam     = { mode = "kubernetes" }
    image    = { pullPolicy = "IfNotPresent" }
    operator = { replicas = 1 }
  })]
}

# Bare-metal load balancer: real external IPs for Service type=LoadBalancer.
resource "helm_release" "metallb" {
  name             = "metallb"
  repository       = "https://metallb.github.io/metallb"
  chart            = "metallb"
  version          = var.metallb_version
  namespace        = "metallb-system"
  create_namespace = true
  depends_on       = [helm_release.cilium]
}

resource "local_file" "metallb_pool" {
  filename = "${path.module}/.metallb-pool.yaml"
  content  = <<-YAML
    apiVersion: metallb.io/v1beta1
    kind: IPAddressPool
    metadata:
      name: default
      namespace: metallb-system
    spec:
      addresses:
        - ${var.lb_address_pool}
    ---
    apiVersion: metallb.io/v1beta1
    kind: L2Advertisement
    metadata:
      name: default
      namespace: metallb-system
    spec:
      ipAddressPools:
        - default
  YAML
}

resource "null_resource" "metallb_pool" {
  depends_on = [helm_release.metallb, local_file.metallb_pool]
  triggers   = { pool = var.lb_address_pool }
  provisioner "local-exec" {
    environment = { KUBECONFIG = var.kubeconfig_path }
    command     = "kubectl -n metallb-system rollout status deploy/metallb-controller --timeout=120s && kubectl apply -f ${local_file.metallb_pool.filename}"
  }
}

resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = var.ingress_nginx_version
  namespace        = "ingress-nginx"
  create_namespace = true
  depends_on       = [null_resource.metallb_pool]

  # Real LoadBalancer service (MetalLB assigns the IP) AND host-port 80/443 on
  # the control-plane node so the app is also reachable at http://localhost.
  values = [yamlencode({
    controller = {
      service      = { type = "LoadBalancer" }
      hostPort     = { enabled = true }
      nodeSelector = { "ingress-ready" = "true" }
      tolerations  = [{ key = "node-role.kubernetes.io/control-plane", operator = "Exists", effect = "NoSchedule" }]
      # expose request metrics for the canary AnalysisTemplate
      metrics = { enabled = true }
    }
  })]
}

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = var.metrics_server_version
  namespace  = "kube-system"
  depends_on = [helm_release.cilium]

  values = [yamlencode({ args = ["--kubelet-insecure-tls"] })] # kind: self-signed kubelet certs
}

# GitOps CD controller.
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_version
  namespace        = "argocd"
  create_namespace = true
  depends_on       = [helm_release.cilium]
}

# Progressive-delivery controller (drives the Rollout canary).
resource "helm_release" "argo_rollouts" {
  name             = "argo-rollouts"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-rollouts"
  version          = var.argo_rollouts_version
  namespace        = "argo-rollouts"
  create_namespace = true
  depends_on       = [helm_release.cilium]
}

# Metrics backend the canary AnalysisTemplate queries.
resource "helm_release" "prometheus" {
  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "prometheus"
  version          = var.prometheus_version
  namespace        = "monitoring"
  create_namespace = true
  depends_on       = [helm_release.cilium]

  # Slim it down for a local kind box; 15s scrape so the canary AnalysisRun has
  # enough samples for rate() over a 1m window.
  values = [yamlencode({
    alertmanager           = { enabled = false }
    prometheus-pushgateway = { enabled = false }
    kube-state-metrics     = { enabled = true }
    server                 = { global = { scrape_interval = "15s" } }
  })]
}
