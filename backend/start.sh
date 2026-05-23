#!/usr/bin/env bash
# =============================================================================
# start.sh — TDS Sentinel API
# =============================================================================
# Usa supervisord para gestionar Flask con reinicio automático.
# Flask sirve HTTP puro — el proxy de Codespaces provee HTTPS externamente.
#
# Uso:
#   bash start.sh            → arranca (o reinicia) la API
#   bash start.sh --stop     → detiene la API y supervisord
#   bash start.sh --status   → muestra si está corriendo
#   bash start.sh --logs     → tail de los logs en tiempo real
#   bash start.sh --restart  → reinicia solo el proceso Flask
#
# Se ejecuta automáticamente en cada inicio de Codespaces (postStartCommand).
# =============================================================================

set -euo pipefail

# ── Rutas ─────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
VENV_PY="$ROOT_DIR/.venv/bin/python"
VENV_SUPERVISORD="$ROOT_DIR/.venv/bin/supervisord"
VENV_SUPERVISORCTL="$ROOT_DIR/.venv/bin/supervisorctl"
SYS_PY="/usr/bin/python3"
LOG_FILE="/tmp/sentinel.log"
SUPERVISORD_CONF="$SCRIPT_DIR/supervisord.conf"
PORT="${PORT:-5000}"

# Usar venv si existe, sino Python del sistema
if [[ -f "$VENV_PY" ]]; then
  PYTHON="$VENV_PY"
else
  PYTHON="$SYS_PY"
fi

# ── Colores ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✅  $*${NC}"; }
warn() { echo -e "${YELLOW}⚠️   $*${NC}"; }
err()  { echo -e "${RED}❌  $*${NC}"; }
info() { echo -e "${BLUE}ℹ️   $*${NC}"; }

# =============================================================================
# Subcomandos
# =============================================================================

cmd_stop() {
  echo "→ Deteniendo TDS Sentinel..."
  if [[ -f "$VENV_SUPERVISORCTL" ]]; then
    "$VENV_SUPERVISORCTL" -c "$SUPERVISORD_CONF" stop sentinel   2>/dev/null || true
    "$VENV_SUPERVISORCTL" -c "$SUPERVISORD_CONF" shutdown        2>/dev/null || true
  fi
  pkill -f "supervisord" 2>/dev/null && ok "supervisord detenido" || warn "supervisord ya no corría"
  pkill -f "server.py"   2>/dev/null || true
  ok "API detenida"
}

cmd_status() {
  echo ""
  echo "══════════════════════════════════════════"
  echo "  TDS Sentinel — Estado"
  echo "══════════════════════════════════════════"

  if pgrep -f "supervisord" > /dev/null 2>&1; then
    ok "supervisord corriendo (auto-restart activo)"
  else
    err "supervisord NO está corriendo"
  fi

  if curl -s "http://127.0.0.1:${PORT}/api/health" > /dev/null 2>&1; then
    ok "Flask respondiendo en http://127.0.0.1:${PORT}"
    curl -s "http://127.0.0.1:${PORT}/api/health" | "$PYTHON" -m json.tool 2>/dev/null || true
  else
    err "Flask NO responde en el puerto ${PORT}"
    echo "   Intenta: bash $SCRIPT_DIR/start.sh"
  fi

  if [[ -n "${CODESPACE_NAME:-}" ]]; then
    DOMAIN="${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-app.github.dev}"
    echo ""
    info "URL pública (HTTPS via proxy): https://${CODESPACE_NAME}-${PORT}.${DOMAIN}"
  fi
  echo ""
}

cmd_logs() {
  echo "→ Logs de Flask (Ctrl+C para salir):"
  if [[ -f "$LOG_FILE" ]]; then
    tail -f "$LOG_FILE"
  else
    warn "No hay logs en $LOG_FILE aún"
  fi
}

cmd_restart() {
  if pgrep -f "supervisord" > /dev/null 2>&1 && [[ -f "$VENV_SUPERVISORCTL" ]]; then
    echo "→ Reiniciando proceso Flask via supervisorctl..."
    "$VENV_SUPERVISORCTL" -c "$SUPERVISORD_CONF" restart sentinel
    sleep 2
    cmd_status
  else
    warn "supervisord no está corriendo. Lanzando arranque completo..."
    bash "$0"
  fi
}

# ── Manejar subcomandos ───────────────────────────────────────────────────────
case "${1:-}" in
  --stop)    cmd_stop;    exit 0 ;;
  --status)  cmd_status;  exit 0 ;;
  --logs)    cmd_logs;    exit 0 ;;
  --restart) cmd_restart; exit 0 ;;
  "") ;;
  *) echo "Uso: bash start.sh [--stop|--status|--logs|--restart]"; exit 1 ;;
esac

# =============================================================================
# ARRANQUE NORMAL
# =============================================================================

echo ""
echo "══════════════════════════════════════════"
echo "  TDS Sentinel — Iniciando API (HTTP)"
echo "══════════════════════════════════════════"

# ── 1. Detener instancia previa ───────────────────────────────────────────────
if pgrep -f "supervisord" > /dev/null 2>&1; then
  echo "→ Deteniendo supervisord previo..."
  pkill -f "supervisord" 2>/dev/null || true
  sleep 2
fi
pkill -f "server.py" 2>/dev/null || true
sleep 1

# ── 2. Verificar que .env tiene SECRET_KEY ───────────────────────────────────
if [[ ! -f "$SCRIPT_DIR/.env" ]]; then
  warn ".env no encontrado — copiando desde .env.example"
  cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
  NEW_KEY=$("$PYTHON" -c "import secrets; print(secrets.token_hex(32))")
  sed -i "s/REEMPLAZA_CON_UN_VALOR_SECRETO_SEGURO/$NEW_KEY/" "$SCRIPT_DIR/.env"
  ok ".env creado con SECRET_KEY generada"
fi

if ! grep -q "^SECRET_KEY=.\+" "$SCRIPT_DIR/.env" 2>/dev/null; then
  warn "SECRET_KEY no definida — generando..."
  NEW_KEY=$("$PYTHON" -c "import secrets; print(secrets.token_hex(32))")
  if grep -q "^SECRET_KEY" "$SCRIPT_DIR/.env"; then
    sed -i "s/^SECRET_KEY=.*/SECRET_KEY=$NEW_KEY/" "$SCRIPT_DIR/.env"
  else
    echo "SECRET_KEY=$NEW_KEY" >> "$SCRIPT_DIR/.env"
  fi
  ok "SECRET_KEY guardada en .env"
fi

# ── 3. Verificar que supervisord está disponible ──────────────────────────────
if [[ ! -f "$VENV_SUPERVISORD" ]]; then
  warn "supervisord no encontrado — instalando..."
  "$ROOT_DIR/.venv/bin/pip" install supervisor -q
  ok "supervisor instalado"
fi

# ── 4. Lanzar supervisord ────────────────────────────────────────────────────
echo "→ Lanzando supervisord (Flask HTTP con auto-restart)..."
"$VENV_SUPERVISORD" -c "$SUPERVISORD_CONF"

# ── 5. Esperar y verificar que Flask arrancó ──────────────────────────────────
echo -n "→ Esperando que Flask responda"
for i in $(seq 1 20); do
  sleep 1
  echo -n "."
  if curl -s "http://127.0.0.1:${PORT}/api/health" > /dev/null 2>&1; then
    echo ""
    ok "Flask respondiendo en http://127.0.0.1:${PORT}"
    break
  fi
  if [[ $i -eq 20 ]]; then
    echo ""
    err "Flask no respondió en 20 segundos"
    echo "   Últimas líneas del log:"
    tail -30 "$LOG_FILE" 2>/dev/null || true
    "$VENV_SUPERVISORCTL" -c "$SUPERVISORD_CONF" status 2>/dev/null || true
    exit 1
  fi
done

# ── 6. Exponer el puerto como público en Codespaces ──────────────────────────
if [[ -n "${CODESPACE_NAME:-}" ]]; then
  DOMAIN="${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-app.github.dev}"
  echo "→ Configurando visibilidad pública del puerto $PORT..."
  gh codespace ports visibility "${PORT}:public" -c "$CODESPACE_NAME" 2>/dev/null \
    && ok "Puerto $PORT → público" \
    || warn "gh CLI no disponible — marca el puerto como público en la UI de Codespaces"

  echo ""
  echo "══════════════════════════════════════════"
  ok "API disponible (HTTPS via proxy) en:"
  echo "   🌐 https://${CODESPACE_NAME}-${PORT}.${DOMAIN}"
  echo "══════════════════════════════════════════"
else
  echo ""
  ok "API disponible en: http://localhost:${PORT}"
fi

echo ""
echo "Comandos útiles:"
echo "  bash start.sh --status   → ver estado"
echo "  bash start.sh --logs     → logs en tiempo real"
echo "  bash start.sh --restart  → reiniciar Flask"
echo "  bash start.sh --stop     → detener todo"
echo "  bash start.sh            → relanzar"
echo ""
info "Flask HTTP · supervisord reinicia automáticamente si cae · HTTPS via proxy Codespaces"
