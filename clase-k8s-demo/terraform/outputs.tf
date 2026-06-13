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

output "argocd_password_command" {
  description = "Comando para obtener la contraseña inicial del admin de ArgoCD"
  value       = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

output "argocd_ui_command" {
  description = "Comando para obtener la IP externa de la UI de ArgoCD"
  value       = "kubectl -n argocd get svc argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"
}

output "static_ip" {
  description = "IP estática del LoadBalancer de nginx-ingress"
  value       = google_compute_address.ingress_ip.address
}

output "ingress_domain" {
  description = "Dominio sslip.io listo para usar en el Ingress"
  value       = "${google_compute_address.ingress_ip.address}.sslip.io"
}
