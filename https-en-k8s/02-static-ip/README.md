# 02 — IP Estática

La IP estática la crea Terraform automáticamente. Este paso explica qué es y cómo configurarla.

## Por qué necesitamos una IP estática

El dominio sslip.io está basado en la IP del LoadBalancer (`34.x.x.x.sslip.io`). Si la IP cambia entre reinicios del cluster, el dominio cambia y el certificado TLS queda inválido. Con una IP estática el dominio es estable.

## Configurar en Terraform

En `terraform/terraform.tfvars`, el nombre de la IP ya tiene un valor por defecto (`ingress-ip`). Podés cambiarlo si querés:

```hcl
static_ip_name = "ingress-ip"
```

Eso es todo. `terraform apply` crea la IP estática en GCP, instala nginx-ingress apuntando a ella y expone los outputs listos para usar.

## Obtener la IP y el dominio

Después del `terraform apply`:

```bash
terraform output static_ip
terraform output ingress_domain
```

El segundo output da directamente el dominio `34.x.x.x.sslip.io` que vas a usar en los manifests del paso 06.

## Qué es sslip.io

[sslip.io](https://sslip.io) es un servicio DNS público que resuelve `<IP>.sslip.io` a esa IP sin necesidad de registrar nada. Por ejemplo, `34.72.155.10.sslip.io` → `34.72.155.10`.

**Siguiente:** [03 — nginx-ingress](../03-nginx-ingress/README.md)
