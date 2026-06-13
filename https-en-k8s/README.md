# HTTPS en Kubernetes (GKE) con cert-manager y Let's Encrypt

Guía práctica paso a paso para agregar HTTPS a tu aplicación corriendo en GKE, sin necesidad de registrar un dominio.

## Stack

| Componente | Rol |
|---|---|
| **nginx-ingress** (Helm) | Ingress controller con IP estática de GCP |
| **cert-manager** (Helm) | Emisión y renovación automática de certificados |
| **Let's Encrypt** (ACME HTTP-01) | CA gratuita |
| **sslip.io** | Dominio sin registrar basado en la IP del LB (`34.x.x.x.sslip.io`) |

## Arquitectura

```
Internet
   │
   ▼
GCP LoadBalancer (IP estática)
   │
   ▼
nginx-ingress controller
   │
   ├── /           → frontend-service
   ├── /api/v1     → backend-api-1
   └── /api/v2     → backend-api-2

cert-manager ──→ Let's Encrypt ──→ TLS Secret ──→ Ingress
```

## Pasos

| # | Sección | Qué hace |
|---|---|---|
| 01 | [Prerrequisitos](01-prereqs/README.md) | Herramientas, permisos GCP, variables de entorno |
| 02 | [IP estática](02-static-ip/README.md) | Reservar IP en GCP y obtener el dominio sslip.io |
| 03 | [nginx-ingress](03-nginx-ingress/README.md) | Instalar el Ingress controller con Helm |
| 04 | [Ingress HTTP](04-ingress-http/README.md) | Routing por paths y verificación sin TLS |
| 05 | [cert-manager](05-cert-manager/README.md) | Instalar cert-manager y configurar ClusterIssuer |
| 06 | [HTTPS](06-https/README.md) | Agregar TLS al Ingress y verificar el certificado |
| — | [Troubleshooting](troubleshooting.md) | Errores comunes y cómo resolverlos |

## Supuestos sobre tu app

- Tenés un GKE cluster corriendo con tus apps deployadas.
- Tenés Services de tipo `ClusterIP` o `NodePort` para cada app.
- Tu app tiene 1 o 2 frontends y al menos 2 APIs de backend.
- Tenés `kubectl` y `helm` configurados apuntando al cluster.

> **Tiempo estimado:** 30–45 minutos siguiendo los pasos en orden.
