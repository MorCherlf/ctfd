output "kubernetes_cluster_id" {
  description = "The ID of the created Kubernetes cluster."
  value       = yandex_kubernetes_cluster.ctf_k8s_cluster.id
}

output "kubernetes_cluster_endpoint" {
  description = "The external endpoint of the Kubernetes cluster API."
  value       = yandex_kubernetes_cluster.ctf_k8s_cluster.master[0].external_v4_endpoint
}

output "container_registry_name" {
  description = "The name of the container registry."
  value       = yandex_container_registry.ctf_registry.name
}