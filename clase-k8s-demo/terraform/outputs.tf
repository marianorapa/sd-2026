output "cluster_name" {
  description = "Nombre del cluster GKE"
  value       = google_container_cluster.primary.name
}

output "cluster_location" {
  description = "Zona donde corre el cluster"
  value       = google_container_cluster.primary.location
}

output "cluster_endpoint" {
  description = "Endpoint del API server de Kubernetes"
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "node_pool_name" {
  description = "Nombre del Node Pool"
  value       = google_container_node_pool.nodes.name
}

output "registry_url" {
  description = "URL del Artifact Registry para las imágenes Docker"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/clase-demos"
}

output "kubeconfig_command" {
  description = "Comando para obtener las credenciales del cluster"
  value       = "gcloud container clusters get-credentials ${var.cluster_name} --zone ${var.zone} --project ${var.project_id}"
}
