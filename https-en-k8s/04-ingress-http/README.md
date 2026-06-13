# 04 — Ingress HTTP (paso opcional de verificación)

> **Este paso es opcional.** En el flujo normal, ArgoCD aplica directamente el Ingress con TLS del paso 06. Usá este paso solo si querés verificar el routing de forma aislada antes de agregar certificados.

## Cuándo usarlo

- El certificado TLS no se emite y querés descartar que el problema sea de routing.
- Querés verificar que los nombres de Service y puertos son correctos antes de commitear.

## Cómo usarlo (debug manual, fuera de ArgoCD)

Editá `ingress.yaml` con tus valores reales y aplicalo directamente:

```bash
# Obtener el dominio desde Terraform
export DOMAIN=$(terraform -chdir=../clase-k8s-demo/terraform output -raw ingress_domain)

# Reemplazar placeholder y aplicar manualmente
sed "s/TU_DOMINIO/$DOMAIN/" ingress.yaml | kubectl apply -f -
```

Verificar:
```bash
curl http://$DOMAIN/
curl http://$DOMAIN/api/v1/health
curl http://$DOMAIN/api/v2/health
```

- `200 OK` → routing correcto.
- `502 Bad Gateway` → nombre o puerto del Service incorrecto.
- `404` de nginx → el path no coincide con ninguna regla.

## Limpiar antes de continuar

Este Ingress HTTP no lo gestiona ArgoCD — borralo antes de aplicar el TLS para evitar conflictos:

```bash
kubectl delete ingress mi-app-ingress -n default
```

**Siguiente:** [05 — cert-manager](../05-cert-manager/README.md)
