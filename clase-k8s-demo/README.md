# Demos — Ingress y Load Balancers en Kubernetes sobre GCP

Repo de trabajo para las tres demos de la clase de Sistemas Distribuidos.
Cada demo es un paso incremental sobre el mismo cluster GKE.

```
clase-k8s-demo/
├── terraform/            Demo 1 — Infraestructura como código
├── apps/                 Código fuente de los tres servicios
│   ├── frontend/         Nginx sirviendo HTML estático
│   ├── users-api/        Flask — GET /users
│   └── products-api/     Flask — GET /products
├── k8s/
│   ├── demo2-services/   Demo 2 — Deployments + Services (ClusterIP)
│   └── demo3-ingress/    Demo 3 — Ingress + BackendConfig
└── scripts/
    ├── 1-setup.sh        Crear proyecto GCP, SA, habilitar APIs
    ├── 2-terraform.sh    terraform init + plan + apply
    ├── 3-kubeconfig.sh   Obtener credenciales y verificar Nodes
    ├── 4-build-push.sh   Build Docker + push a Artifact Registry
    ├── 5-demo2.sh        kubectl apply demo 2
    └── 6-demo3.sh        kubectl apply demo 3 + failover
```

---

## Prerequisitos

### 1. Cuenta de Google Cloud

Necesitás una cuenta de GCP con billing habilitado.

Si no tenés una:

1. Ir a [https://cloud.google.com](https://cloud.google.com) y crear una cuenta.
2. GCP ofrece **USD 300 de crédito gratuito** por 90 días para cuentas nuevas.
   Esto es más que suficiente para correr las demos.
3. Para usar la mayoría de los servicios (incluyendo GKE) necesitás
   agregar un método de pago, pero **no se cobra nada** mientras estés
   dentro del crédito gratuito.

> ⚠️ Acordate de ejecutar `terraform destroy` al final de la clase
> para no consumir crédito innecesariamente.
> Un cluster GKE Standard con 2 nodos `e2-medium` cuesta aprox USD 1,50/hora.

---

### 2. gcloud CLI

La herramienta de línea de comandos de Google Cloud.

**macOS (Homebrew):**
```bash
brew install --cask google-cloud-sdk
```

**Linux (apt):**
```bash
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
```

**Windows:**
Descargar el instalador desde [https://cloud.google.com/sdk/docs/install](https://cloud.google.com/sdk/docs/install)

**Verificar instalación:**
```bash
gcloud version
# Google Cloud SDK 460.x.x
```

**Iniciar sesión:**
```bash
gcloud auth login
# Abre el browser para autenticarse con tu cuenta de Google
```

---

### 3. Terraform

**macOS (Homebrew):**
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

**Linux (apt):**
```bash
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

**Windows (Chocolatey):**
```bash
choco install terraform
```

**Verificar instalación:**
```bash
terraform version
# Terraform v1.7.x
```

---

### 4. Docker

Necesario para buildear y pushear las imágenes de las apps.

- **macOS / Windows:** instalar [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- **Linux:** seguir la [guía oficial](https://docs.docker.com/engine/install/)

```bash
docker version
# Docker version 25.x.x
```

Asegurate de que el daemon esté corriendo antes de ejecutar el script 4.

---

### 5. kubectl

**macOS:**
```bash
brew install kubectl
```

**Linux:**
```bash
curl -LO "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/bin/
```

**Windows:**
```bash
choco install kubernetes-cli
```

```bash
kubectl version --client
# Client Version: v1.29.x
```

> `kubectl` también se puede instalar como componente de `gcloud`:
> ```bash
> gcloud components install kubectl
> ```

---

## Orden de ejecución

```
ANTES DE CLASE          EN CLASE
─────────────────       ──────────────────────────────────────────────────
1-setup.sh         →    3-kubeconfig.sh  (Demo 1)
2-terraform.sh          5-demo2.sh       (Demo 2)
4-build-push.sh         6-demo3.sh       (Demo 3)
```

Los primeros tres pasos tardan ~15 minutos en total y conviene
tenerlos listos antes de que arranque la clase.

---

## Paso a paso

### Paso 0 — Clonar el repo y configurar variables

```bash
git clone <repo-url>
cd clase-k8s-demo
```

Copiar el archivo de variables de Terraform:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Editar `terraform/terraform.tfvars` con los valores reales:

```hcl
project_id   = "clase-distribuidos-2025"   # elegí un nombre único global
region       = "us-central1"
zone         = "us-central1-a"
cluster_name = "clase-k8s"
```

> El `project_id` tiene que ser único en todo GCP. Si el que elegiste
> ya existe, Terraform va a fallar en el paso de creación del proyecto.
> Agregale un sufijo, por ejemplo: `clase-distribuidos-2025-abc`.

---

### Paso 1 — Crear proyecto, Service Account y habilitar APIs

```bash
bash scripts/1-setup.sh
```

**Qué hace este script:**

1. **Crea el proyecto GCP** con el `project_id` definido en `terraform.tfvars`.
   Un proyecto es el contenedor lógico de todos los recursos en GCP.

2. **Vincula el billing account** al proyecto.
   Sin billing, las APIs de GCP no se pueden habilitar (ni GKE ni Compute Engine).

3. **Habilita las APIs necesarias:**
   - `container.googleapis.com` — GKE (crear y gestionar clusters)
   - `compute.googleapis.com` — Compute Engine (las VMs de los Nodes)
   - `artifactregistry.googleapis.com` — guardar las imágenes Docker
   - `iam.googleapis.com` — gestión de identidades y permisos
   - `cloudresourcemanager.googleapis.com` — gestionar el proyecto vía API

4. **Crea una Service Account** llamada `terraform-sa` con los permisos
   mínimos necesarios para que Terraform pueda crear recursos en GCP.
   Una Service Account es una identidad para aplicaciones (no para humanos).

5. **Descarga la key JSON** de la Service Account en `terraform/sa-key.json`.
   Esta key es como la contraseña de Terraform para hablar con GCP.

6. **Genera el archivo `terraform.tfvars`** con el `project_id` real.

**Tiempo estimado:** 2-3 minutos.

> ⚠️ El archivo `sa-key.json` contiene credenciales. Está en `.gitignore`
> y nunca debe commitearse al repositorio.

**Después de correr este script**, exportar la variable de credenciales:

```bash
export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/terraform/sa-key.json"
```

Conviene agregarlo al `.bashrc` / `.zshrc` para no tener que repetirlo:

```bash
echo 'export GOOGLE_APPLICATION_CREDENTIALS="'$(pwd)'/terraform/sa-key.json"' >> ~/.zshrc
```

---

### Paso 2 — Crear el cluster con Terraform

```bash
bash scripts/2-terraform.sh
```

**Qué hace este script:**

1. **`terraform init`** — descarga el provider de Google y prepara el directorio
   de trabajo. Crea la carpeta `.terraform/` con los plugins necesarios.

2. **`terraform plan`** — calcula qué recursos va a crear, modificar o eliminar,
   sin hacer ningún cambio real. Muestra el plan en pantalla.
   **En clase: leer los recursos en voz alta antes de continuar.**

3. **`terraform apply`** — ejecuta el plan y crea los recursos en GCP.
   Terraform va mostrando el progreso de cada recurso.

**Qué crea Terraform:**

| Recurso Terraform | Recurso GCP | Para qué sirve |
|---|---|---|
| `google_compute_network` | VPC | Red privada del cluster |
| `google_compute_subnetwork` | Subnet | Rango de IPs para Nodes y Pods |
| `google_container_cluster` | GKE Cluster | El control plane de Kubernetes |
| `google_container_node_pool` | Node Pool | Las VMs donde corren los Pods |
| `google_service_account` | Service Account | Identidad de los Nodes |
| `google_artifact_registry_repository` | Artifact Registry | Registro de imágenes Docker |

**Tiempo estimado:** 8-10 minutos (la mayoría es el cluster GKE).

> El cluster GKE Standard provisiona el control plane (etcd, API server,
> scheduler, controller manager) de forma administrada. GCP se encarga
> de eso. Los Nodes (las VMs donde corren los Pods) son los que aparecen
> en la consola de Compute Engine.

---

### Paso 3 — Conectarse al cluster (Demo 1 en clase)

```bash
bash scripts/3-kubeconfig.sh
```

**Qué hace este script:**

1. **`gcloud container clusters get-credentials`** — obtiene las credenciales
   del cluster y actualiza el archivo `~/.kube/config` de la laptop.
   A partir de acá, todos los comandos `kubectl` van a hablar con este cluster.

2. **`kubectl get nodes`** — lista los Nodes del cluster.
   Cada línea es una VM real corriendo en GCP.

3. **`kubectl get nodes -o wide`** — muestra más detalle:
   IP interna, sistema operativo, zona, versión del kernel.

4. **`kubectl describe node <nombre>`** — detalle completo de un Node:
   CPU, memoria, Pods corriendo, conditions, eventos.
   **En clase: buscar `machine-type`, `zone`, `OS Image`, `Capacity`.**

**Lo que queremos mostrar en Demo 1:**

```
NAME                STATUS   ROLES    AGE   VERSION
gke-clase-k8s-...   Ready    <none>   2m    v1.28.x
gke-clase-k8s-...   Ready    <none>   2m    v1.28.x
```

Cada uno de esos Nodes es una VM `e2-medium` corriendo en
`us-central1-a`. Se pueden ver también en:
**Consola GCP → Compute Engine → VM Instances**

---

### Paso 4 — Buildear y pushear imágenes Docker

```bash
bash scripts/4-build-push.sh
```

**Qué hace este script:**

1. **Autentica Docker** con Artifact Registry usando las credenciales de `gcloud`.

2. **Buildea las tres imágenes** (para arquitectura `linux/amd64`,
   que es la de los Nodes de GKE):
   - `frontend` — Nginx sirviendo el HTML estático
   - `users-api` — Flask con `GET /users`
   - `products-api` — Flask con `GET /products`

3. **Pushea las imágenes** al Artifact Registry creado por Terraform.

4. **Reemplaza `REGISTRY_URL`** en los manifiestos YAML por la URL real
   del registry (`us-central1-docker.pkg.dev/<project>/clase-demos`).

**Tiempo estimado:** 3-5 minutos dependiendo de la conexión.

> Conviene correr este paso antes de clase para no depender de la
> velocidad de Internet del aula.

---

### Paso 5 — Demo 2: Deployments + Services internos

```bash
bash scripts/5-demo2.sh
```

El script tiene pausas interactivas (↵ Enter) para que puedas ir
comentando cada paso con la clase.

**Qué hace este script:**

1. **Muestra los YAMLs** de los tres recursos antes de aplicarlos.
   Para cada uno, señalar: `replicas`, `selector`, `type: ClusterIP`.

2. **`kubectl apply -f k8s/demo2-services/`** — crea los tres Deployments
   y los tres Services de una sola vez.

3. **`kubectl get pods -w`** — muestra los Pods pasando de
   `ContainerCreating` a `Running` en tiempo real.

4. **`kubectl get services`** — muestra que todos tienen `EXTERNAL-IP: <none>`.
   La aplicación existe pero no es accesible desde afuera.

5. **Port-forward** — muestra que la app funciona pero requiere un túnel
   manual. Esto **no es** cómo acceden los usuarios reales.

6. **Curl desde dentro del cluster** — lanza un Pod temporal con `curl`
   para hacer requests al DNS interno y mostrar el balanceo:
   ```
   http://users-api-service.default.svc.cluster.local/users
   ```
   Cada request puede mostrar un `served_by` diferente.

**Punto clave de Demo 2:**
> Los Services resuelven la comunicación *interna* entre Pods.
> El problema de exponer la aplicación hacia afuera todavía no está resuelto.

---

### Paso 6 — Demo 3: Ingress + IP pública + failover

```bash
bash scripts/6-demo3.sh
```

**Qué hace este script:**

1. **Muestra el YAML del Ingress** antes de aplicarlo.
   Señalar: `annotations`, `rules`, `pathType: Prefix`, los tres `backend`.

2. **`kubectl apply -f k8s/demo3-ingress/`** — crea el Ingress y el BackendConfig.

3. **Espera la IP pública** haciendo polling a `kubectl get ingress`.
   Mientras espera (~3-4 min): ir a la consola de GCP y mostrar el
   Load Balancer apareciendo en **Network Services → Load Balancing**.

4. **Verifica el routing** con `curl` desde la laptop:
   - `curl http://<IP>/api/users`
   - `curl http://<IP>/api/products`
   - Repite 5 veces para mostrar el `served_by` cambiando entre Pods.

5. **Abre la aplicación en el browser** — mostrar el frontend consumiendo
   ambas APIs. Recargar para ver el balanceo.

6. **MOMENTO CLAVE — eliminar una réplica:**
   ```bash
   kubectl delete pod <nombre-pod>
   ```
   El script sigue mandando requests mientras el Pod se elimina
   y muestra que no hay downtime. El Deployment crea un nuevo Pod
   automáticamente.

**Punto clave de Demo 3:**
> Kubernetes no creó el Load Balancer. El Cloud Controller observó
> el recurso Ingress y llamó a las APIs de GCP. El cluster declaró
> el estado deseado; GCP convergió hacia él.

---

## Cleanup — destruir el cluster al terminar

Para no seguir consumiendo crédito después de la clase:

```bash
cd terraform
terraform destroy
```

Terraform va a mostrar todos los recursos que va a eliminar y pedirá
confirmación. Escribir `yes` y Enter.

**Tiempo estimado:** 5-8 minutos.

> Verificar en la consola de GCP que no queden recursos huérfanos:
> - Compute Engine → VM Instances (deben estar todas eliminadas)
> - Network Services → Load Balancing (el LB del Ingress debe haberse ido)
> - Artifact Registry → clase-demos (este sí queda si no se borra manualmente)

---

## Troubleshooting

**`terraform apply` falla con "project already exists"**

El `project_id` ya existe en GCP (son únicos globalmente).
Cambiar el `project_id` en `terraform.tfvars` por uno diferente.

---

**`terraform apply` falla con "billing account not found"**

La cuenta de billing no está vinculada al proyecto.
Ir a: [https://console.cloud.google.com/billing](https://console.cloud.google.com/billing)
y vincularla manualmente, luego volver a correr el script.

---

**`kubectl` no encuentra el cluster después de `get-credentials`**

Verificar que `GOOGLE_APPLICATION_CREDENTIALS` apunta al `sa-key.json`:
```bash
echo $GOOGLE_APPLICATION_CREDENTIALS
cat $GOOGLE_APPLICATION_CREDENTIALS | python3 -m json.tool | grep project_id
```

---

**Los Pods quedan en `ImagePullBackOff`**

La imagen no se encontró en el registry. Causas comunes:
- El script `4-build-push.sh` no terminó de correr
- El `project_id` en `terraform.tfvars` no coincide con el del registry

Verificar:
```bash
kubectl describe pod <nombre-pod> | grep -A5 Events
```

---

**El Ingress se queda en `<pending>` por más de 10 minutos**

Verificar el BackendConfig y los health checks:
```bash
kubectl describe ingress clase-ingress
kubectl get events --sort-by='.lastTimestamp' | tail -20
```

Los health checks de GCP pueden tardar en volverse `Healthy`.
Verificar en la consola: **Network Services → Load Balancing → Backends**.

---

**`docker build` falla en Mac con Apple Silicon (M1/M2/M3)**

Los Nodes de GKE son `amd64`. El script ya incluye `--platform linux/amd64`,
pero si Docker Desktop no tiene habilitada la emulación:

```bash
docker run --privileged --rm tonistiigi/binfmt --install all
```

---

## Costos estimados

| Recurso | Tipo | Costo aprox. |
|---|---|---|
| GKE Control Plane | Standard (zonal) | USD 0.10/hora |
| 2× Node `e2-medium` | 2 vCPU, 4GB | USD 0.067/hora c/u |
| Artifact Registry | < 1 GB | < USD 0.10/mes |
| Load Balancer (Demo 3) | HTTP(S) | USD 0.025/hora |
| **Total clase (2 horas)** | | **~USD 0.55** |

Con los USD 300 de crédito gratuito de GCP, alcanza para correr
estas demos decenas de veces sin costo real.
