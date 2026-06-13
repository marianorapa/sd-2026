# 05 — cert-manager

cert-manager automatiza la emisión y renovación de certificados TLS. Se integra con Let's Encrypt usando el protocolo ACME y el challenge HTTP-01.

## ¿Cómo funciona ACME HTTP-01?

```
cert-manager solicita cert a Let's Encrypt
         │
         ▼
Let's Encrypt responde con un token de challenge
         │
         ▼
cert-manager crea un pod + Ingress temporal para servir el token en:
http://tu-dominio/.well-known/acme-challenge/<token>
         │
         ▼
Let's Encrypt hace un GET a esa URL y verifica el token
         │
         ▼
Si OK → emite el certificado → cert-manager lo guarda en un Secret
```

nginx-ingress maneja automáticamente el tráfico HTTP del challenge incluso cuando TLS está habilitado en el Ingress.

## Lo instala Terraform

cert-manager se instala con Helm via Terraform. El recurso está en `terraform/argocd.tf`:

```hcl
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  ...
  set {
    name  = "installCRDs"
    value = "true"
  }
}
```

`installCRDs=true` instala los Custom Resource Definitions (Certificate, ClusterIssuer, CertificateRequest, etc.) automáticamente.

## Verificar después del `terraform apply`

```bash
kubectl get pods -n cert-manager
```

Los tres pods (`cert-manager`, `cert-manager-cainjector`, `cert-manager-webhook`) deben estar en `Running`.

## El ClusterIssuer lo aplica ArgoCD

La configuración del ClusterIssuer (`letsencrypt-prod`) no se aplica manualmente — vive en `https-en-k8s/k8s/cluster-issuer.yaml` y ArgoCD lo sincroniza automáticamente.

El archivo `cluster-issuer.yaml` de este directorio es solo la referencia explicativa del recurso.

**Siguiente:** [06 — HTTPS](../06-https/README.md)
