#!/usr/bin/env bash
# scripts/4-build-push.sh
# ─────────────────────────────────────────────────────────────────────────────
# Prepara las imágenes Docker para Demo 2 y 3
# Ejecutar ANTES de la Demo 2 (idealmente ya corrido antes de clase)
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
show()    { echo -e "${CYAN}[CMD]${NC}   $*"; }
section() { echo -e "\n${GREEN}══════════════════════════════════════${NC}"; \
            echo -e "${GREEN}  $*${NC}"; \
            echo -e "${GREEN}══════════════════════════════════════${NC}"; }

ROOT="$(dirname "$0")/.."
cd "$ROOT"

# Leer project_id y region del tfvars
PROJECT_ID=$(grep 'project_id' terraform/terraform.tfvars | cut -d'"' -f2)
REGION=$(grep '^region' terraform/terraform.tfvars | cut -d'"' -f2)
REGISTRY="${REGION}-docker.pkg.dev/${PROJECT_ID}/clase-demos"

info "Registry: $REGISTRY"

# Autenticar Docker con Artifact Registry
section "Autenticar Docker con Artifact Registry"
show "gcloud auth configure-docker ${REGION}-docker.pkg.dev"
gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet

APPS=("frontend" "users-api" "products-api")

for app in "${APPS[@]}"; do
  section "Build + Push: $app"

  show "docker build -t ${REGISTRY}/${app}:latest apps/${app}/"
  docker build \
    --platform linux/amd64 \
    -t "${REGISTRY}/${app}:latest" \
    "apps/${app}/"

  show "docker push ${REGISTRY}/${app}:latest"
  docker push "${REGISTRY}/${app}:latest"

  info "$app ✓"
done

# ── Reemplazar REGISTRY_URL en los manifiestos ────────────────────────────────
section "Actualizar URLs de imágenes en manifiestos K8s"

for yaml in k8s/demo2-services/*.yaml; do
  sed -i.bak "s|REGISTRY_URL|${REGISTRY}|g" "$yaml"
  rm -f "${yaml}.bak"
  info "Actualizado: $yaml"
done

echo ""
info "Imágenes publicadas y manifiestos actualizados ✓"
echo ""
echo "  Registry: $REGISTRY"
echo ""
echo "  Próximo paso:"
echo "    bash scripts/5-demo2.sh"
echo ""
