# ─────────────────────────────────────────────────────────────────────────────
# main.tf — Cluster GKE Standard + Node Pool explícito
#
# Qué crea:
#   - VPC dedicada con subnet para el cluster
#   - Cluster GKE Standard (control plane administrado por Google)
#   - Node Pool con e2-medium, autoescalado 1–3 nodos
#
# Lo que NO crea (se hace en demos posteriores):
#   - Deployments, Services, Ingress (eso es Demo 2 y 3)
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.14"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# ── VPC ──────────────────────────────────────────────────────────────────────

resource "google_compute_network" "vpc" {
  name                    = "${var.cluster_name}-vpc"
  auto_create_subnetworks = false

  description = "VPC dedicada para el cluster de la clase"
}

resource "google_compute_subnetwork" "subnet" {
  name          = "${var.cluster_name}-subnet"
  network       = google_compute_network.vpc.id
  ip_cidr_range = "10.0.0.0/18"
  region        = var.region

  # Rangos secundarios requeridos por GKE para Pods y Services
  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.48.0.0/14"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.52.0.0/20"
  }
}

# ── Cluster GKE Standard ─────────────────────────────────────────────────────

resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.zone   # zona única (más barato para clase)

  # Desacoplamos el node pool del cluster
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  # Deshabilitar shielded nodes para simplificar (clase, no prod)
  release_channel {
    channel = "REGULAR"
  }

  # Logging y monitoring mínimos (reduce costo en clase)
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
  }

  deletion_protection = false
}

# ── Node Pool ─────────────────────────────────────────────────────────────────
#
# Este recurso separado es el punto didáctico de Demo 1:
# muestra que los Nodes son máquinas reales con tipo, disco y SO.

resource "google_container_node_pool" "nodes" {
  name       = "${var.cluster_name}-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.primary.name

  # Autoescalado: arranca con 2 nodos, sube hasta 3 si hay carga
  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }

  initial_node_count = 2

  node_config {
    machine_type = "e2-medium"  # 2 vCPU, 4 GB RAM
    disk_size_gb = 30
    disk_type    = "pd-standard"
    image_type   = "COS_CONTAINERD"  # Container-Optimized OS

    # Service account mínima para los nodos
    service_account = google_service_account.gke_nodes.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    labels = {
      env     = "clase"
      managed = "terraform"
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

# ── Service Account para los nodos ───────────────────────────────────────────

resource "google_service_account" "gke_nodes" {
  account_id   = "${var.cluster_name}-nodes-sa"
  display_name = "GKE Nodes — ${var.cluster_name}"
}

# Permisos mínimos: leer de Container Registry
resource "google_project_iam_member" "nodes_artifact_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# Permisos para escribir logs y métricas
resource "google_project_iam_member" "nodes_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "nodes_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# ── Artifact Registry — para las imágenes Docker de las demos ────────────────

resource "google_artifact_registry_repository" "clase" {
  location      = var.region
  repository_id = "clase-demos"
  format        = "DOCKER"
  description   = "Imágenes Docker para las demos de la clase"
}
