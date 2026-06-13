# Troubleshooting

## Flujo de diagnóstico general

Cuando el certificado no se emite, estos tres comandos cubren el 90% de los problemas:

```bash
# 1. Ver el estado del certificado
kubectl describe certificate mi-app-tls -n default

# 2. Ver el CertificateRequest generado por cert-manager
kubectl describe certificaterequest -n default

# 3. Ver el challenge ACME en progreso
kubectl describe challenge -n default
```

---

## EXTERNAL-IP queda en `<pending>`

**Síntoma:** `kubectl get service ingress-nginx-controller -n ingress-nginx` muestra `<pending>` en la columna `EXTERNAL-IP` por más de 5 minutos.

**Causas comunes:**

1. La IP estática fue creada en una región distinta a la del cluster:
   ```bash
   # Ver la región de la IP
   gcloud compute addresses list --filter="name=$STATIC_IP_NAME"

   # Ver la región del cluster
   gcloud container clusters describe $CLUSTER_NAME --region $REGION --format="get(location)"
   ```
   Deben coincidir. Si no, borrá la IP y volvé a crearla en la región correcta.

2. Billing no habilitado en el proyecto (los LBs de GCP son un recurso de pago).

3. La IP ya está en uso por otro recurso.

---

## Certificado en estado `False` o no aparece

**Síntoma:** `kubectl get certificate -n default` muestra `READY=False` o el recurso Certificate no existe.

**Diagnóstico:**
```bash
kubectl describe certificate mi-app-tls -n default
```

Buscá la sección `Events` al final. Los mensajes más comunes:

| Mensaje | Causa |
|---|---|
| `Failed to create Order` | cert-manager no puede llegar a Let's Encrypt (revisar conectividad) |
| `Waiting for challenge...` | El challenge HTTP-01 está pendiente (ver sección siguiente) |
| `Certificate issued successfully` | OK — el Secret debería existir |

---

## Challenge HTTP-01 falla

**Síntoma:** `kubectl describe challenge -n default` muestra que el challenge no se completa.

El challenge requiere que Let's Encrypt pueda acceder a:
```
http://TU_DOMINIO/.well-known/acme-challenge/<token>
```

**Verificar que el puerto 80 es accesible:**
```bash
curl http://$DOMAIN/.well-known/acme-challenge/test
# Debe devolver 404, no timeout
```

Si hay timeout:
- El Ingress de nginx no está funcionando → revisá el paso 03.
- La IP estática no está asignada al LB → revisá el paso 02.
- Un firewall de GCP bloquea el puerto 80 → revisá las reglas de firewall:
  ```bash
  gcloud compute firewall-rules list --filter="network=default"
  ```

**Verificar que hay un Ingress temporal del challenge:**
```bash
kubectl get ingress -n default
```
Debe aparecer un Ingress con nombre del tipo `cm-acme-http-solver-xxxxx`. Si no existe, cert-manager no pudo crearlo.

---

## Rate limits de Let's Encrypt

**Síntoma:** El certificado falla con un mensaje que menciona "too many certificates" o "rate limit".

**Causa:** Usaste el issuer de producción directamente (o lo intentaste varias veces) y superaste el límite de 5 certificados por dominio por semana.

**Solución:**
- Cambiá a `letsencrypt-staging` en el Ingress y esperá que funcione.
- Para producción, esperá 7 días o probá con un subdominio diferente del sslip.io.
- Los dominios sslip.io permiten usar diferentes IPs como workaround (podés crear otra IP estática temporalmente).

---

## 502 Bad Gateway

**Síntoma:** curl devuelve `502 Bad Gateway` para uno o más paths.

**Diagnóstico:**
```bash
# Verificar que el Service existe y tiene el puerto correcto
kubectl get service NOMBRE_DEL_SERVICE -n default

# Verificar que los pods del Service están corriendo
kubectl get pods -n default -l app=LABEL_DE_TU_APP

# Ver los endpoints del Service (deben tener IPs de pods)
kubectl get endpoints NOMBRE_DEL_SERVICE -n default
```

**Causas comunes:**
- El nombre del Service en `ingress.yaml` no coincide exactamente con el nombre real.
- El puerto en `ingress.yaml` no coincide con el puerto del Service.
- Los pods no están corriendo (`kubectl get pods` muestra `CrashLoopBackOff` o `Error`).

---

## Certificado válido pero el browser sigue mostrando advertencia

**Causa:** Estás usando el issuer de staging. El certificado de staging está firmado por una CA de prueba (`Fake LE Intermediate X1`) que los browsers no reconocen.

**Solución:** Seguí los pasos de "Pasar a producción" en [06-https/README.md](06-https/README.md).

---

## El certificado vence sin renovarse

cert-manager renueva automáticamente los certificados cuando les queda menos del 30% del tiempo de vida (para certificados de 90 días de LE, renueva a los 60 días). Si no se renueva:

```bash
# Ver la fecha de vencimiento
kubectl describe certificate mi-app-tls -n default | grep "Not After"

# Forzar renovación manual
kubectl delete secret mi-app-tls -n default
# cert-manager detecta la ausencia del Secret y emite uno nuevo automáticamente
```

---

## Ingress no enruta al path correcto

**Síntoma:** Paths como `/api/v1/health` devuelven 404.

**Verificar:**
```bash
kubectl describe ingress mi-app-ingress -n default
```

Revisá la sección `Rules` y comparala con el path que estás probando. Los paths de tipo `Prefix` hacen match exacto del prefijo — `/api/v1` no hace match a `/api/v10`.

Si tu backend no maneja el prefijo del path (ej: espera `/health` en vez de `/api/v1/health`), necesitás configurar rewrite-target. Ver la [documentación de nginx-ingress](https://kubernetes.github.io/ingress-nginx/examples/rewrite/).
