# ─────────────────────────────────────────────────────────────────────────────
# https.tf — Infraestructura para TLS en GKE
#
# Qué crea:
#   - IP estática de GCP para el LoadBalancer del Ingress controller
#   - nginx-ingress (Helm) apuntando a esa IP
#   - cert-manager (Helm) con CRDs instalados
#
# Lo que NO crea (lo gestiona ArgoCD desde https-en-k8s/k8s/):
#   - ClusterIssuer de Let's Encrypt
#   - Ingress con TLS de la app del alumno
# ─────────────────────────────────────────────────────────────────────────────

# ── IP estática para el LoadBalancer de nginx-ingress ─────────────────────────

resource "google_compute_address" "ingress_ip" {
  name    = var.static_ip_name
  region  = var.region
  project = var.project_id

  depends_on = [google_container_node_pool.nodes]
}

# ── nginx-ingress via Helm ────────────────────────────────────────────────────

resource "helm_release" "nginx_ingress" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  version          = "4.10.1"

  values = [
    <<-EOT
    controller:
      service:
        type: LoadBalancer
        loadBalancerIP: "${google_compute_address.ingress_ip.address}"
        annotations:
          networking.gke.io/load-balancer-type: "External"
      publishService:
        enabled: true
    EOT
  ]

  timeout    = 300
  wait       = true
  depends_on = [google_compute_address.ingress_ip]
}

# ── cert-manager via Helm ─────────────────────────────────────────────────────

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  version          = "v1.15.1"

  set {
    name  = "installCRDs"
    value = "true"
  }

  timeout    = 300
  wait       = true
  depends_on = [google_container_node_pool.nodes]
}
