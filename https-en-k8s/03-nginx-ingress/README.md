# 03 — nginx-ingress

El Ingress controller recibe el tráfico externo y lo enruta a los Services internos. En GKE necesita un Service de tipo `LoadBalancer` para que GCP le asigne la IP estática reservada en el paso anterior.

## Lo instala Terraform

nginx-ingress se instala con Helm via Terraform. El recurso está en `terraform/argocd.tf`:

```hcl
resource "helm_release" "nginx_ingress" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  ...
}
```

La configuración relevante (IP estática, tipo LoadBalancer, publishService) se inyecta desde el output de `google_compute_address.ingress_ip`. No hay nada que tocar manualmente.

## Verificar después del `terraform apply`

```bash
# Pods del controller
kubectl get pods -n ingress-nginx

# Service — la EXTERNAL-IP debe coincidir con tu IP estática
kubectl get service ingress-nginx-controller -n ingress-nginx
```

Ejemplo de salida esperada:
```
NAME                       TYPE           CLUSTER-IP   EXTERNAL-IP   PORT(S)
ingress-nginx-controller   LoadBalancer   10.96.0.1    34.x.x.x      80:.../TCP,443:.../TCP
```

```bash
# Test rápido — debe responder 404 (correcto, aún no hay Ingress)
curl http://$(terraform output -raw static_ip)
```

Si obtenés `404 Not Found` de nginx, el controller está activo.

**Siguiente:** [04 — Ingress HTTP (opcional)](../04-ingress-http/README.md)
