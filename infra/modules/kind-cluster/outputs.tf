output "kubeconfig_path" {
  description = "Path to the generated kubeconfig."
  value       = kind_cluster.this.kubeconfig_path
}

output "endpoint" {
  description = "Kubernetes API server endpoint."
  value       = kind_cluster.this.endpoint
}
