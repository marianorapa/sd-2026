#!/usr/bin/env bash
# scripts/2-terraform.sh
# ─────────────────────────────────────────────────────────────────────────────
# DEMO 1 — Crear el cluster con Terraform
#
# Muestra en clase:
#   - terraform init   → descarga providers
#   - terraform plan   → qué va a crear (mostrar el output)
#   - terraform apply  → crear cluster (~8 min, dejar corriendo)
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
section() { echo -e "\n${GREEN}══════════════════════════════════════${NC}"; \
            echo -e "${GREEN}  $*${NC}"; \
            echo -e "${GREEN}══════════════════════════════════════${NC}"; }

cd "$(dirname "$0")/../terraform"

# ── Verificar credenciales ────────────────────────────────────────────────────
if [ -z "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]; then
  if [ -f "sa-key.json" ]; then
    export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/sa-key.json"
    warn "GOOGLE_APPLICATION_CREDENTIALS no estaba seteada — usando ./terraform/sa-key.json"
  else
    echo -e "\n❌  Faltan credenciales. Ejecutar primero:"
    echo "    export GOOGLE_APPLICATION_CREDENTIALS=\"\$(pwd)/terraform/sa-key.json\""
    exit 1
  fi
fi

info "Credenciales: $GOOGLE_APPLICATION_CREDENTIALS"

# ── Verificar tfvars ──────────────────────────────────────────────────────────
if [ ! -f "terraform.tfvars" ]; then
  echo "❌  Falta terraform/terraform.tfvars"
  echo "    Ejecutar primero: bash scripts/1-setup.sh"
  exit 1
fi

# ── terraform init ────────────────────────────────────────────────────────────
section "terraform init"
terraform init

# ── terraform plan ────────────────────────────────────────────────────────────
section "terraform plan"
echo ""
echo "  ↓ Esto muestra QUÉ va a crear Terraform antes de hacerlo."
echo "  ↓ En clase: leer en voz alta los recursos principales."
echo ""
terraform plan -out=clase.tfplan

# ── terraform apply ───────────────────────────────────────────────────────────
section "terraform apply"
echo ""
echo "  ↓ Crear el cluster tarda ~8 minutos."
echo "  ↓ Mientras corre: explicar qué está pasando en GCP."
echo ""
terraform apply clase.tfplan

# ── Mostrar outputs ───────────────────────────────────────────────────────────
section "Outputs del cluster"
terraform output

echo ""
info "Cluster creado ✓"
echo ""
echo "  Próximo paso:"
echo "    bash scripts/3-kubeconfig.sh"
echo ""
