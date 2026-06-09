# Demo 3 — HPA: Escalado automático horizontal

**Objetivo:** Generar carga suficiente con k6 para activar el HPA y ver cómo se crean réplicas automáticamente. Detener la carga y observar el cooldown (~5 min) antes de que el HPA reduzca las réplicas.

## Conceptos clave

- **HPA (HorizontalPodAutoscaler):** controlador de K8s que ajusta el número de réplicas de un Deployment según métricas (CPU, memoria, custom).
- **target averageUtilization: 50** — el HPA quiere mantener el uso de CPU promedio en 50% del `request` (200m). Si el promedio sube de 100m, escala.
- **Fórmula de escalado:** `desiredReplicas = ceil(currentReplicas × (currentCPU / targetCPU))`
- **Cooldown de scale-down:** 5 minutos de estabilización antes de reducir réplicas (evita flapping).
- **Requisito del HPA:** el Deployment *debe* tener `resources.requests.cpu` definido.
- **k6** corre dentro del cluster como un Job, atacando `fibonacci-api` via ClusterDNS.

## Paso 1 — Desplegar fibonacci-api y el HPA

```bash
kubectl apply -f fibonacci-api.yaml
kubectl apply -f hpa.yaml
```

Verificar:
```bash
kubectl get hpa
# NAME                  REFERENCE                   TARGETS         MINPODS   MAXPODS   REPLICAS
# fibonacci-api-hpa     Deployment/fibonacci-api    <unknown>/50%   1         5         1
```

Esperar ~30 segundos hasta que `TARGETS` muestre el valor real:
```bash
kubectl get hpa -w
# fibonacci-api-hpa   Deployment/fibonacci-api   2%/50%   1   5   1
```

## Paso 2 — Lanzar el test de k6

```bash
kubectl apply -f k6-load-test.yaml
```

El script sube la carga en tres etapas:

| Etapa | Duración | VUs | Objetivo                                  |
|-------|----------|-----|-------------------------------------------|
| 1     | 2 min    | 40  | Superar el umbral del HPA (50% CPU)       |
| 2     | 5 min    | 40  | Carga sostenida: observar réplicas crearse|
| 3     | 1 min    | 0   | Ramp-down: iniciar cooldown del HPA       |

## Paso 3 — Monitorear el escalado (tres terminales)

**Terminal 1 — Logs de k6:**
```bash
kubectl logs -f job/k6-load-test
```

**Terminal 2 — HPA en tiempo real:**
```bash
kubectl get hpa -w
# fibonacci-api-hpa   ...   120%/50%   1   5   1
# fibonacci-api-hpa   ...   120%/50%   1   5   2
# fibonacci-api-hpa   ...   85%/50%    1   5   3
# fibonacci-api-hpa   ...   60%/50%    1   5   4
```

**Terminal 3 — Pods creándose:**
```bash
kubectl get pods -w
# fibonacci-api-abc   Running
# fibonacci-api-def   ContainerCreating  →  Running
# fibonacci-api-ghi   ContainerCreating  →  Running
```

## Paso 4 — Observar el cooldown y scale-down

Cuando k6 termina (o después del ramp-down), el CPU baja:

```bash
kubectl get hpa -w
# fibonacci-api-hpa   ...   5%/50%    1   5   4   ← CPU bajó, pero HPA espera
# ...5 minutos después...
# fibonacci-api-hpa   ...   2%/50%    1   5   1   ← Scale-down al mínimo
```

El `stabilizationWindowSeconds: 300` evita que el HPA reaccione a bajones momentáneos de carga.

## Resumen de tiempos

| Evento                        | Tiempo estimado desde inicio |
|-------------------------------|------------------------------|
| k6 comienza a generar carga   | 0 min                        |
| HPA detecta CPU alto          | ~1-2 min                     |
| Primera réplica adicional     | ~2-3 min                     |
| Máximo de réplicas (5)        | ~4-5 min                     |
| k6 termina (ramp-down)        | ~8 min                       |
| HPA reduce a 1 réplica        | ~13-14 min (cooldown 5 min)  |

## Limpieza

```bash
kubectl delete -f hpa.yaml
kubectl delete -f fibonacci-api.yaml
kubectl delete -f k6-load-test.yaml  # Si no se eliminó automáticamente (ttl 5 min)
```
