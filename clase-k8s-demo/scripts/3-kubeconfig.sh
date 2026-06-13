#!/usr/bin/env bash
# scripts/3-kubeconfig.sh
# ─────────────────────────────────────────────────────────────────────────────
# DEMO 1 — Conectarse al cluster y verificar que los Nodes son VMs reales
#
# Muestra en clase:
#   - Cómo obtener credenciales con gcloud
#   - kubectl get nodes → cada Node es una VM
#   - kubectl describe node → CPU, memoria, zona, imagen del OS
#   - kubectl get nodes -o wide → más detalles
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
show()    { echo -e "${CYAN}[CMD]${NC}   $*"; }
section() { echo -e "\n${GREEN}══════════════════════════════════════${NC}"; \
            echo -e "${GREEN}  $*${NC}"; \
            echo -e "${GREEN}══════════════════════════════════════${NC}"; }

cd "$(dirname "$0")/../terraform"

# Leer variables del tfvars
PROJECT_ID=$(grep 'project_id' terraform.tfvars | cut -d'"' -f2)
ZONE=$(grep 'zone' terraform.tfvars | cut -d'"' -f2)
CLUSTER_NAME=$(grep 'cluster_name' terraform.tfvars | cut -d'"' -f2)

# ── Obtener credenciales ──────────────────────────────────────────────────────
section "Obtener credenciales del cluster"
show "gcloud container clusters get-credentials $CLUSTER_NAME --zone $ZONE --project $PROJECT_ID"
echo ""

gcloud container clusters get-credentials "$CLUSTER_NAME" \
  --zone "$ZONE" \
  --project "$PROJECT_ID"

info "kubeconfig actualizado ✓"

# ── Ver los Nodes ─────────────────────────────────────────────────────────────
section "Los Nodes son máquinas reales"

echo ""
echo "  → Cada línea es una VM en GCP."
echo "  → STATUS=Ready significa que el kubelet está corriendo."
echo ""
show "kubectl get nodes"
kubectl get nodes
echo ""

show "kubectl get nodes -o wide"
kubectl get nodes -o wide
echo ""

# ── Inspeccionar un Node ──────────────────────────────────────────────────────
section "Inspeccionar un Node (mostrar CPU, RAM, OS, zona)"

NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
echo ""
echo "  → Vamos a inspeccionar el node: $NODE"
echo "  → Buscar: Capacity, Allocatable, OS Image, zona, machine-type"
echo ""
show "kubectl describe node $NODE"
kubectl describe node "$NODE" | grep -A5 "Capacity:\|Allocatable:\|OS Image:\|kubernetes.io/arch\|failure-domain\|node.kubernetes.io/instance-type" | head -40

echo ""
section "✅ Demo 1 completa"
echo ""
echo "  Cluster: $CLUSTER_NAME"
echo "  Zona:    $ZONE"
echo "  Nodes:   $(kubectl get nodes --no-headers | wc -l | tr -d ' ')"
echo ""
echo "  Próximo paso (Demo 2):"
echo "    bash scripts/4-build-push.sh"
echo "    bash scripts/5-demo2.sh"
echo ""
