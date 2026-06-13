# ─────────────────────────────────────────────────────────────────────────────
# argocd.tf — Instalación de ArgoCD + Applications vía GitOps
#
# Qué crea:
#   - Namespace "argocd"
#   - ArgoCD instalado con Helm (UI expuesta por LoadBalancer)
#   - ArgoCD Application por cada demo en k8s/
#
# Dependencias:
#   - El cluster GKE del main.tf debe existir primero
#   - Los providers kubernetes/helm/kubectl se configuran con las credenciales
#     del cluster creado en este mismo apply
#
# Nota: los recursos de nginx-ingress, cert-manager e IP estática
# están en https.tf — este archivo solo gestiona ArgoCD y sus Applications.
# ─────────────────────────────────────────────────────────────────────────────

# ── Credenciales del cluster ──────────────────────────────────────────────────

data "google_client_config" "default" {}

# ── Providers que apuntan al cluster GKE ─────────────────────────────────────

provider "kubernetes" {
  host  = "https://${google_container_cluster.primary.endpoint}"
  token = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(
    google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  )
}

provider "helm" {
  kubernetes {
    host  = "https://${google_container_cluster.primary.endpoint}"
    token = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(
      google_container_cluster.primary.master_auth[0].cluster_ca_certificate
    )
  }
}

# El provider kubectl no valida CRDs en plan-time, lo que permite
# aplicar los Application manifests en el mismo apply que instala ArgoCD.
provider "kubectl" {
  host  = "https://${google_container_cluster.primary.endpoint}"
  token = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(
    google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  )
  load_config_file = false
}

# ── Namespace argocd ─────────────────────────────────────────────────────────

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }

  depends_on = [google_container_node_pool.nodes]
}

# ── ArgoCD via Helm ───────────────────────────────────────────────────────────

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = "7.3.4"

  # Exponer la UI de ArgoCD con IP externa (conveniente para la clase)
  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }

  timeout    = 600
  wait       = true
  depends_on = [kubernetes_namespace.argocd]
}

# ── ArgoCD Applications ───────────────────────────────────────────────────────
# Cada Application le dice a ArgoCD qué carpeta del repo sincronizar
# y en qué namespace del cluster aplicarla.

resource "kubectl_manifest" "app_demo2_services" {
  yaml_body  = file("${path.module}/../argocd/apps/demo2-services.yaml")
  depends_on = [helm_release.argocd]
}

# cert-manager debe estar listo antes de que ArgoCD intente aplicar el ClusterIssuer
resource "kubectl_manifest" "app_https_stack" {
  yaml_body  = file("${path.module}/../argocd/apps/https-stack.yaml")
  depends_on = [helm_release.argocd, helm_release.cert_manager]
}

