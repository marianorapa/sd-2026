#!/usr/bin/env bash
# scripts/6-demo3.sh
# ─────────────────────────────────────────────────────────────────────────────
# DEMO 3 — Ingress, IP pública, Cloud Controller, failover
#
# Guión sugerido:
#   1. Aplicar el Ingress → mostrar YAML antes
#   2. kubectl get ingress -w → esperar que aparezca la IP (2-4 min)
#   3. Mientras espera: explicar qué está pasando en GCP
#   4. Mostrar el Load Balancer en la consola de GCP
#   5. Curl desde la laptop → verificar routing
#   6. Abrir en browser → mostrar la app funcionando
#   7. MOMENTO CLAVE: eliminar una réplica → mostrar que sigue funcionando
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
show()    { echo -e "${CYAN}[CMD]${NC}   $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
key()     { echo -e "${RED}[🔑 CLAVE]${NC} $*"; }
section() { echo -e "\n${GREEN}══════════════════════════════════════${NC}"; \
            echo -e "${GREEN}  $*${NC}"; \
            echo -e "${GREEN}══════════════════════════════════════${NC}"; }
pause()   { echo ""; read -rp "  ↵ Enter para continuar…"; echo ""; }

ROOT="$(dirname "$0")/.."
cd "$ROOT"

# ── 1. Mostrar el YAML del Ingress ────────────────────────────────────────────
section "El Ingress — routing HTTP declarativo"

echo ""
key "Este es el concepto más importante de la clase."
echo ""
echo "  → Al aplicar este YAML, el Cloud Controller va a:"
echo "    1. Observar el nuevo recurso Ingress"
echo "    2. Llamar a las APIs de GCP"
echo "    3. Crear un Load Balancer HTTP(S) externo"
echo "    4. Asignar una IP pública"
echo ""
cat k8s/demo3-ingress/ingress.yaml
echo ""
pause

# ── 2. Aplicar Ingress ────────────────────────────────────────────────────────
section "kubectl apply — crear el Ingress"

show "kubectl apply -f k8s/demo3-ingress/"
kubectl apply -f k8s/demo3-ingress/

# ── 3. Esperar la IP pública ──────────────────────────────────────────────────
section "Esperando IP pública del Load Balancer (~3-4 min)"

echo ""
echo "  → Mientras esperamos, ir a la consola de GCP y mostrar:"
echo "    Network Services → Load Balancing"
echo "    Se va a ver el Load Balancer apareciendo"
echo ""
echo "  → Explicar: Kubernetes no creó esto."
echo "    El Cloud Controller leyó el Ingress y llamó a la API de GCP."
echo ""
warn "Esperando que EXTERNAL-IP deje de ser <pending>…"
echo ""
show "kubectl get ingress -w"
echo ""

# Esperar hasta que haya IP
while true; do
  IP=$(kubectl get ingress clase-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
  if [ -n "$IP" ]; then
    break
  fi
  echo "  $(date +%H:%M:%S) — Esperando… (esto es normal, GCP está provisionando el LB)"
  sleep 15
done

echo ""
info "¡IP pública asignada! → $IP"
echo ""
key "Esta IP la creó GCP automáticamente. No está en ningún YAML."

pause

# ── 4. Mostrar en consola GCP ─────────────────────────────────────────────────
section "Ir a la consola de GCP"

echo ""
echo "  → Network Services → Load Balancing"
echo "  → Mostrar: Frontend (IP), Backend Services, URL Map, Health Checks"
echo "  → Los Health Checks van a estar en 'Healthy'"
echo ""
pause

# ── 5. Verificar routing con curl ─────────────────────────────────────────────
section "Verificar routing desde la laptop"

echo ""
echo "  → Vamos a probar los tres paths del Ingress"
echo ""

show "curl http://$IP/api/users"
echo ""
curl -s "http://$IP/api/users" | python3 -m json.tool 2>/dev/null || curl "http://$IP/api/users"
echo ""
pause

show "curl http://$IP/api/products"
echo ""
curl -s "http://$IP/api/products" | python3 -m json.tool 2>/dev/null || curl "http://$IP/api/products"
echo ""
pause

echo "  → Repetir varias veces /api/users para ver el 'served_by' cambiar:"
echo ""
for i in 1 2 3 4 5; do
  echo -n "  Request $i → "
  curl -s "http://$IP/api/users" | python3 -c "import sys,json; d=json.load(sys.stdin); print('served_by:', d['served_by'])" 2>/dev/null || \
  curl -s "http://$IP/api/users"
  sleep 1
done
echo ""
key "Cada request puede ir a un Pod distinto → Load Balancer distribuyendo tráfico"

pause

# ── 6. Abrir en browser ───────────────────────────────────────────────────────
section "Abrir la aplicación en el browser"

echo ""
echo "  → Abrir: http://$IP"
echo ""
echo "  → Mostrar que:"
echo "    - El frontend consume ambas APIs"
echo "    - Recargar varias veces → el 'served_by' cambia"
echo "    - Todo pasa por la misma IP pública"
echo ""
pause

# ── 7. MOMENTO CLAVE: eliminar una réplica ────────────────────────────────────
section "🔑 MOMENTO CLAVE — Eliminar una réplica"

echo ""
key "Preguntar a la clase: ¿Qué creen que va a pasar si eliminamos un Pod?"
echo ""
pause

# Obtener un Pod de users-api para eliminar
POD_TO_DELETE=$(kubectl get pods -l app=users-api -o jsonpath='{.items[0].metadata.name}')

echo ""
show "kubectl delete pod $POD_TO_DELETE"
echo ""
kubectl delete pod "$POD_TO_DELETE" &

echo ""
echo "  → El Pod se está eliminando…"
echo "  → Mientras tanto, seguimos mandando requests:"
echo ""

for i in $(seq 1 8); do
  sleep 2
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$IP/api/users" 2>/dev/null || echo "ERR")
  POD=$(curl -s "http://$IP/api/users" 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['served_by'])" 2>/dev/null || echo "…")
  echo "  t+${i}s → HTTP $STATUS   pod: $POD"
done

wait
echo ""
key "La aplicación siguió funcionando."
echo "  → El Load Balancer dejó de enviarle tráfico al Pod eliminado."
echo "  → El Deployment creó un nuevo Pod automáticamente."
echo ""
show "kubectl get pods -l app=users-api"
kubectl get pods -l app=users-api

pause

# ── Resumen final ─────────────────────────────────────────────────────────────
section "✅ Demo 3 completa — Recorrido de una request"

echo ""
echo "  Browser"
echo "    ↓   DNS → $IP"
echo "  Load Balancer (GCP)"
echo "    ↓   URL Map: /api/users → users-api-service"
echo "  Ingress Controller"
echo "    ↓   Service selector: app=users-api"
echo "  Service"
echo "    ↓   Round-robin entre Pods"
echo "  Pod"
echo "    ↓   Flask responde con served_by: \$POD_NAME"
echo ""
echo "  IP pública: $IP"
echo ""
echo "  Pregunta para el ejercicio:"
echo "    ¿Qué recurso cloud apareció automáticamente y quién lo creó?"
echo ""

# ── Cleanup opcional ──────────────────────────────────────────────────────────
echo ""
warn "Para destruir el cluster al final de la clase:"
echo ""
echo "  cd terraform && terraform destroy"
echo ""
