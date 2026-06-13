# 01 — Prerrequisitos

## Herramientas necesarias

Verificá que tenés instaladas estas herramientas:

```bash
kubectl version --client
helm version
gcloud version
```

Si alguna falta:
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [helm](https://helm.sh/docs/intro/install/)
- [gcloud CLI](https://cloud.google.com/sdk/docs/install)

## Acceso al cluster

```bash
# Ver el contexto activo
kubectl config current-context

# Si necesitás obtener las credenciales del cluster:
gcloud container clusters get-credentials NOMBRE_DEL_CLUSTER \
  --region REGION \
  --project ID_DEL_PROYECTO

# Verificar que llegás al cluster
kubectl get nodes
```

Los nodos deben aparecer con status `Ready`.

## Variables de entorno

Definí estas variables una vez; los comandos del resto de la guía las usan directamente:

```bash
export PROJECT_ID="tu-proyecto-gcp"
export CLUSTER_NAME="nombre-de-tu-cluster"
export REGION="us-central1"           # región o zona de tu cluster
export STATIC_IP_NAME="ingress-ip"    # nombre para la IP estática a crear

# Verificar
echo "Proyecto: $PROJECT_ID | Cluster: $CLUSTER_NAME | Región: $REGION"
```

> Las variables se pierden al cerrar la terminal. Si abrís una sesión nueva, volvé a este paso y re-ejecutalas antes de continuar.

## Permisos en GCP

Necesitás estos roles en tu proyecto:

| Rol | Para qué |
|---|---|
| `roles/compute.networkAdmin` | Crear IPs estáticas |
| `roles/container.admin` | Administrar el cluster GKE |

Verificar tus roles:
```bash
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:$(gcloud config get-value account)" \
  --format="table(bindings.role)"
```

## Verificar los Services de tu app

```bash
# Ver los Services en tu namespace (cambiá 'default' si usás otro)
kubectl get services -n default
```

Anotate los nombres y puertos de tus Services — los vas a necesitar en los pasos 04 y 06.

**Siguiente:** [02 — IP estática](../02-static-ip/README.md)
