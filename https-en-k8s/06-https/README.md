# 06 — HTTPS con TLS

Con Terraform ya corriendo, la infraestructura está lista. Este paso es 100% GitOps: editás dos archivos, los commitás, y ArgoCD los aplica automáticamente al cluster.

## Flujo completo

```
Editás k8s/cluster-issuer.yaml  +  k8s/ingress-tls.yaml
         │
         ▼
git commit && git push
         │
         ▼
ArgoCD detecta el cambio en https-en-k8s/k8s/ y sincroniza
         │
         ▼
kubectl aplica ClusterIssuer + Ingress en el cluster
         │
         ▼
cert-manager ve la anotación cert-manager.io/cluster-issuer en el Ingress
         │
         ▼
cert-manager ejecuta el challenge HTTP-01 con Let's Encrypt
         │
         ▼
certificado emitido → guardado en el Secret 'mi-app-tls'
         │
         ▼
nginx-ingress sirve HTTPS usando ese Secret
```

## Paso 1 — Obtener el dominio

```bash
terraform -chdir=../clase-k8s-demo/terraform output ingress_domain
# → 34.x.x.x.sslip.io
```

## Paso 2 — Editar los manifests

Abrí `https-en-k8s/k8s/cluster-issuer.yaml` y reemplazá `TU_EMAIL` con tu email real.

Abrí `https-en-k8s/k8s/ingress-tls.yaml` y reemplazá:
- `TU_DOMINIO` (dos veces) con tu dominio `34.x.x.x.sslip.io`
- `backend-api-1`, `backend-api-2`, `frontend-service` con los nombres reales de tus Services
- Los puertos, si difieren de los del template

## Paso 3 — Commit y push

```bash
git add https-en-k8s/k8s/
git commit -m "https: configurar ingress y ClusterIssuer para mi app"
git push
```

## Paso 4 — Verificar sync en ArgoCD

En la UI de ArgoCD (IP obtenida con `kubectl -n argocd get svc argocd-server`), la Application `https-stack` debe pasar a `Synced` y `Healthy`.

O desde la terminal:
```bash
kubectl get application https-stack -n argocd
```

## Paso 5 — Monitorear el certificado

```bash
# Estado resumido
kubectl get certificate -n default

# Detalle (útil si tarda o falla)
kubectl describe certificate mi-app-tls -n default
```

Esperá hasta que `READY` sea `True`:
```
NAME         READY   SECRET       AGE
mi-app-tls   True    mi-app-tls   2m
```

El proceso tarda entre 30 segundos y 5 minutos.

## Paso 6 — Probar HTTPS

```bash
export DOMAIN=$(terraform -chdir=../clase-k8s-demo/terraform output -raw ingress_domain)

curl https://$DOMAIN/
curl https://$DOMAIN/api/v1/health
curl https://$DOMAIN/api/v2/health
```

Abrí `https://$DOMAIN` en el browser — el candado debe aparecer en verde.

Si algo no funciona: [troubleshooting](../troubleshooting.md)
