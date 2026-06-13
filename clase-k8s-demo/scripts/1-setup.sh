#!/usr/bin/env bash
# scripts/1-setup.sh
# ─────────────────────────────────────────────────────────────────────────────
# DEMO 1 — Paso 0: Preparar el proyecto GCP
#
# Qué hace:
#   1. Crea el proyecto GCP
#   2. Vincula billing account
#   3. Habilita las APIs necesarias
#   4. Crea la Service Account de Terraform y descarga la key
#
# Ejecutar UNA VEZ antes de clase.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Configuración — editar estos valores ─────────────────────────────────────
PROJECT_ID="handy-droplet-498116-c3"     # debe ser único globalmente
PROJECT_NAME="project-pre-class"
BILLING_ACCOUNT=""                        # dejar vacío si ya está vinculado
REGION="us-central1"
SA_NAME="terraform-sa"
KEY_FILE="terraform/sa-key.json"
# ─────────────────────────────────────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
section() { echo -e "\n${GREEN}══════════════════════════════════════${NC}"; \
            echo -e "${GREEN}  $*${NC}"; \
            echo -e "${GREEN}══════════════════════════════════════${NC}"; }

# ── 1. Crear el proyecto ──────────────────────────────────────────────────────
section "1. Crear proyecto GCP"

if gcloud projects describe "$PROJECT_ID" &>/dev/null; then
  warn "El proyecto $PROJECT_ID ya existe — salteando creación"
else
  info "Creando proyecto: $PROJECT_ID"
  gcloud projects create "$PROJECT_ID" \
    --name="$PROJECT_NAME" \
    --set-as-default
fi

gcloud config set project "$PROJECT_ID"
info "Proyecto activo: $PROJECT_ID"

# ── 2. Vincular billing ───────────────────────────────────────────────────────
section "2. Billing"

if [ -n "$BILLING_ACCOUNT" ]; then
  info "Vinculando billing account: $BILLING_ACCOUNT"
  gcloud billing projects link "$PROJECT_ID" \
    --billing-account="$BILLING_ACCOUNT"
else
  warn "BILLING_ACCOUNT vacío — asegurate de tener billing vinculado manualmente"
  warn "Sin billing las APIs no se pueden habilitar"
  echo ""
  echo "  → Consola: https://console.cloud.google.com/billing/linkedaccount?project=$PROJECT_ID"
  echo ""
  read -rp "Presioná Enter cuando esté vinculado el billing..."
fi

# ── 3. Habilitar APIs ─────────────────────────────────────────────────────────
section "3. Habilitar APIs (puede tardar 1-2 min)"

APIS=(
  "container.googleapis.com"          # GKE
  "compute.googleapis.com"            # Compute Engine (VMs / Load Balancer)
  "artifactregistry.googleapis.com"   # Artifact Registry (imágenes Docker)
  "iam.googleapis.com"                # IAM
  "cloudresourcemanager.googleapis.com"
)

for api in "${APIS[@]}"; do
  info "Habilitando: $api"
  gcloud services enable "$api" --project="$PROJECT_ID"
done

info "APIs habilitadas ✓"

# ── 4. Service Account para Terraform ────────────────────────────────────────
section "4. Service Account de Terraform"

SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

if gcloud iam service-accounts describe "$SA_EMAIL" --project="$PROJECT_ID" &>/dev/null; then
  warn "La SA $SA_EMAIL ya existe — salteando creación"
else
  info "Creando service account: $SA_NAME"
  gcloud iam service-accounts create "$SA_NAME" \
    --display-name="Terraform — Clase K8s" \
    --project="$PROJECT_ID"
fi

# Roles necesarios para que Terraform pueda crear el cluster y sus recursos
ROLES=(
  "roles/container.admin"          # Crear/gestionar clusters GKE
  "roles/compute.networkAdmin"     # Crear VPC y subnets
  "roles/iam.serviceAccountAdmin"  # Crear SA para los nodos
  "roles/iam.serviceAccountUser"   # Usar SA al crear recursos
  "roles/artifactregistry.admin"   # Crear el registry de imágenes
  "roles/resourcemanager.projectIamAdmin"  # Asignar roles a SA de nodos
)

for role in "${ROLES[@]}"; do
  info "Asignando: $role"
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="$role" \
    --quiet
done

# ── 5. Descargar la key ───────────────────────────────────────────────────────
section "5. Descargar key JSON"

if [ -f "$KEY_FILE" ]; then
  warn "Ya existe $KEY_FILE — no se sobreescribe"
  warn "Si necesitás regenerarla, borrala primero"
else
  info "Descargando key → $KEY_FILE"
  gcloud iam service-accounts keys create "$KEY_FILE" \
    --iam-account="$SA_EMAIL" \
    --project="$PROJECT_ID"
  chmod 600 "$KEY_FILE"
  info "Key guardada en $KEY_FILE ✓"
fi

# ── 6. Configurar tfvars ──────────────────────────────────────────────────────
section "6. Crear terraform.tfvars"

TFVARS="terraform/terraform.tfvars"
if [ -f "$TFVARS" ]; then
  warn "$TFVARS ya existe — no se sobreescribe"
else
  cat > "$TFVARS" << EOF
project_id   = "${PROJECT_ID}"
region       = "${REGION}"
zone         = "${REGION}-a"
cluster_name = "clase-k8s"
EOF
  info "terraform.tfvars creado ✓"
fi

# ── Resumen ───────────────────────────────────────────────────────────────────
section "✅ Setup completo"
echo ""
echo "  Proyecto:    $PROJECT_ID"
echo "  SA:          $SA_EMAIL"
echo "  Key:         $KEY_FILE"
echo "  tfvars:      $TFVARS"
echo ""
echo "  Próximo paso:"
echo "    export GOOGLE_APPLICATION_CREDENTIALS=\"\$(pwd)/$KEY_FILE\""
echo "    bash scripts/2-terraform.sh"
echo ""
