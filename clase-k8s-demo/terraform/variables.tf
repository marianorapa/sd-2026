variable "project_id" {
  description = "ID del proyecto GCP (ej: clase-distribuidos-2025)"
  type        = string
}

variable "region" {
  description = "Región de GCP donde se crea el cluster"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zona dentro de la región (cluster de zona única para clase)"
  type        = string
  default     = "us-central1-a"
}

variable "cluster_name" {
  description = "Nombre del cluster GKE"
  type        = string
  default     = "clase-k8s"
}

variable "static_ip_name" {
  description = "Nombre de la IP estática de GCP para el Ingress controller"
  type        = string
  default     = "ingress-ip"
}
