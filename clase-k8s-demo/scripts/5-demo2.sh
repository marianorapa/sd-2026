#!/usr/bin/env bash
# scripts/5-demo2.sh
# ─────────────────────────────────────────────────────────────────────────────
# DEMO 2 — Deployments + Services internos
#
# Guión sugerido:
#   1. Aplicar los manifiestos → mostrar el YAML en pantalla primero
#   2. kubectl get pods -w → ver cómo los Pods van apareciendo
#   3. kubectl get services → ver que son ClusterIP (sin IP pública)
#   4. Port-forward para mostrar que la app funciona pero está "encerrada"
#   5. Hacer curl al DNS interno para mostrar balanceo entre Pods
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
show()    { echo -e "${CYAN}[CMD]${NC}   $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
section() { echo -e "\n${GREEN}══════════════════════════════════════${NC}"; \
            echo -e "${GREEN}  $*${NC}"; \
            echo -e "${GREEN}══════════════════════════════════════${NC}"; }
pause()   { echo ""; read -rp "  ↵ Enter para continuar…"; echo ""; }

ROOT="$(dirname "$0")/.."
cd "$ROOT"

# ── 1. Mostrar los YAMLs antes de aplicar ────────────────────────────────────
section "Los manifiestos que vamos a aplicar"
echo ""
echo "  → Antes de aplicar, mostremos QUÉ describe cada archivo."
echo ""
pause

echo "── users-api.yaml ──────────────────────────────────────"
cat k8s/demo2-services/users-api.yaml
echo ""
pause

echo "── products-api.yaml ───────────────────────────────────"
cat k8s/demo2-services/products-api.yaml
echo ""
pause

echo "── frontend.yaml ───────────────────────────────────────"
cat k8s/demo2-services/frontend.yaml
echo ""
pause

# ── 2. Aplicar manifiestos ────────────────────────────────────────────────────
section "kubectl apply — crear Deployments y Services"

show "kubectl apply -f k8s/demo2-services/"
kubectl apply -f k8s/demo2-services/

echo ""
info "Manifiestos aplicados ✓"

# ── 3. Ver Pods levantando ────────────────────────────────────────────────────
section "Ver los Pods iniciando"

echo ""
echo "  → ContainerCreating → Running"
echo "  → Nota: hay 3 réplicas de cada API (9 Pods de API en total)"
echo ""
show "kubectl get pods -w   (Ctrl+C para continuar)"
echo ""

# Watch por 20s automáticamente o hasta que el usuario haga Ctrl+C
timeout 20 kubectl get pods -w || true

echo ""
show "kubectl get pods -o wide"
kubectl get pods -o wide

# ── 4. Ver Services ───────────────────────────────────────────────────────────
section "Ver los Services — todos son ClusterIP"

echo ""
echo "  → CLUSTER-IP: IP interna del cluster"
echo "  → EXTERNAL-IP: <none> → todavía no hay acceso desde Internet"
echo ""
show "kubectl get services"
kubectl get services

pause

# ── 5. Port-forward para mostrar que funciona internamente ────────────────────
section "Port-forward — la app funciona pero está encerrada"

echo ""
echo "  → kubectl port-forward no es routing real de K8s"
echo "  → Es un túnel SSH para que NOSOTROS podamos acceder"
echo "  → Los usuarios reales no pueden hacer esto"
echo ""
echo "  Ejecutá en otra terminal:"
echo ""
echo "    kubectl port-forward svc/frontend-service 8080:80"
echo ""
echo "  Luego abrí: http://localhost:8080"
echo ""
pause

# ── 6. Mostrar DNS interno y balanceo ─────────────────────────────────────────
section "Comunicación interna — DNS de K8s"

echo ""
echo "  → Los Services tienen un nombre DNS dentro del cluster:"
echo "    http://users-api-service.default.svc.cluster.local/users"
echo "    http://products-api-service.default.svc.cluster.local/products"
echo ""
echo "  → Vamos a hacer curl desde dentro del cluster para mostrar"
echo "    que cada request puede ir a un Pod distinto (balanceo)"
echo ""
show "kubectl run curl-test --image=curlimages/curl --restart=Never --rm -it -- \\"
echo "       curl http://users-api-service/users"
echo ""

kubectl run curl-test \
  --image=curlimages/curl \
  --restart=Never \
  --rm -it \
  -- curl -s http://users-api-service/users | python3 -m json.tool 2>/dev/null || \
kubectl run curl-test \
  --image=curlimages/curl \
  --restart=Never \
  --rm -it \
  -- curl http://users-api-service/users

echo ""
echo "  → Observar el campo 'served_by' — indica qué Pod respondió"
echo "  → Repetir varias veces para ver que cambia (balanceo round-robin)"
echo ""
pause

section "✅ Demo 2 completa"
echo ""
echo "  La aplicación funciona dentro del cluster."
echo "  Los Services descubren los Pods automáticamente."
echo "  Pero todavía no hay acceso desde Internet."
echo ""
echo "  Pregunta para la clase:"
echo "    ¿Cómo llega una request desde el browser hasta acá?"
echo ""
echo "  Próximo paso (Demo 3):"
echo "    bash scripts/6-demo3.sh"
echo ""
