#!/usr/bin/env bash
# =============================================================================
# start.sh — TDS Sentinel API
# =============================================================================
# Usa supervisord para gestionar Flask con reinicio automático (elimina 502).
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
LOG_FILE="/tmp/sentinel_https.log"
SUPERVISORD_LOG="/tmp/supervisord.log"
SUPERVISORD_PID="/tmp/supervisord.pid"
SUPERVISORD_CONF="$SCRIPT_DIR/supervisord.conf"
PORT="${PORT:-5000}"

# Certs en ubicación PERSISTENTE (sobreviven a reinicios del Codespace)
CERTS_DIR="$ROOT_DIR/.certs"
CERT="$CERTS_DIR/sentinel_cert.pem"
KEY="$CERTS_DIR/sentinel_key.pem"

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
    "$VENV_SUPERVISORCTL" -c "$SUPERVISORD_CONF" stop sentinel 2>/dev/null || true
    "$VENV_SUPERVISORCTL" -c "$SUPERVISORD_CONF" shutdown 2>/dev/null || true
  fi
  # Matar supervisord por PID si sigue corriendo
  if [[ -f "$SUPERVISORD_PID" ]]; then
    PID=$(cat "$SUPERVISORD_PID")
    kill "$PID" 2>/dev/null && ok "supervisord detenido (PID $PID)" || true
    rm -f "$SUPERVISORD_PID"
  fi
  pkill -f "supervisord" 2>/dev/null && ok "supervisord detenido" || warn "supervisord ya no corría"
  pkill -f "start_https.py" 2>/dev/null || true
  ok "API detenida"
}

cmd_status() {
  echo ""
  echo "══════════════════════════════════════════"
  echo "  TDS Sentinel — Estado"
  echo "══════════════════════════════════════════"

  # Estado de supervisord
  if pgrep -f "supervisord" > /dev/null 2>&1; then
    ok "supervisord corriendo (gestor de procesos activo)"
  else
    err "supervisord NO está corriendo"
  fi

  # Estado de Flask vía health check
  if curl -sk "https://127.0.0.1:${PORT}/api/health" > /dev/null 2>&1; then
    ok "Flask respondiendo en https://127.0.0.1:${PORT}"
    HEALTH=$(curl -sk "https://127.0.0.1:${PORT}/api/health")
    echo "   → $HEALTH"
  else
    err "Flask NO responde en el puerto ${PORT}"
    echo "   Intenta: bash $SCRIPT_DIR/start.sh"
  fi

  # URL pública de Codespaces
  if [[ -n "${CODESPACE_NAME:-}" ]]; then
    DOMAIN="${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-app.github.dev}"
    echo ""
    info "URL pública: https://${CODESPACE_NAME}-${PORT}.${DOMAIN}"
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
  "") ;;  # arranque normal
  *) echo "Uso: bash start.sh [--stop|--status|--logs|--restart]"; exit 1 ;;
esac

# =============================================================================
# ARRANQUE NORMAL
# =============================================================================

echo ""
echo "══════════════════════════════════════════"
echo "  TDS Sentinel — Iniciando API"
echo "══════════════════════════════════════════"

# ── 1. Detener instancia previa de supervisord ────────────────────────────────
if pgrep -f "supervisord" > /dev/null 2>&1; then
  echo "→ Deteniendo supervisord previo..."
  pkill -f "supervisord" 2>/dev/null || true
  sleep 2
fi
pkill -f "start_https.py" 2>/dev/null || true
sleep 1

# ── 2. Certificados SSL en ubicación PERSISTENTE ──────────────────────────────
# Usa gen_cert.py (Python puro, sin depender del binario openssl)
echo "→ Verificando certificados SSL..."
mkdir -p "$CERTS_DIR"
"$PYTHON" "$SCRIPT_DIR/gen_cert.py" "$CERT" "$KEY"

# ── 3. Verificar que .env existe con SECRET_KEY ───────────────────────────────
if [[ ! -f "$SCRIPT_DIR/.env" ]]; then
  warn ".env no encontrado — copiando desde .env.example"
  if [[ -f "$SCRIPT_DIR/.env.example" ]]; then
    cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
    NEW_KEY=$("$PYTHON" -c "import secrets; print(secrets.token_hex(32))")
    sed -i "s/REEMPLAZA_CON_UN_VALOR_SECRETO_SEGURO/$NEW_KEY/" "$SCRIPT_DIR/.env"
    ok ".env creado con SECRET_KEY generada"
  else
    err ".env.example no encontrado. Crea el archivo .env manualmente."
    exit 1
  fi
fi

# Verificar que SECRET_KEY está definida
if ! grep -q "^SECRET_KEY=.\+" "$SCRIPT_DIR/.env" 2>/dev/null; then
  warn "SECRET_KEY no definida en .env — generando una..."
  NEW_KEY=$("$PYTHON" -c "import secrets; print(secrets.token_hex(32))")
  if grep -q "^SECRET_KEY" "$SCRIPT_DIR/.env"; then
    sed -i "s/^SECRET_KEY=.*/SECRET_KEY=$NEW_KEY/" "$SCRIPT_DIR/.env"
  else
    echo "SECRET_KEY=$NEW_KEY" >> "$SCRIPT_DIR/.env"
  fi
  ok "SECRET_KEY generada y guardada en .env"
fi

# ── 4. Verificar que supervisord está disponible ──────────────────────────────
if [[ ! -f "$VENV_SUPERVISORD" ]]; then
  warn "supervisord no encontrado en .venv — instalando..."
  "$ROOT_DIR/.venv/bin/pip" install supervisor -q
  ok "supervisor instalado"
fi

# ── 5. Lanzar supervisord (gestiona Flask con auto-restart) ───────────────────
echo "→ Lanzando supervisord (Flask con auto-restart)..."
"$VENV_SUPERVISORD" -c "$SUPERVISORD_CONF"
echo "   PID supervisord guardado en $SUPERVISORD_PID"

# ── 6. Esperar y verificar que Flask arrancó ──────────────────────────────────
echo -n "→ Esperando que Flask responda"
for i in $(seq 1 20); do
  sleep 1
  echo -n "."
  if curl -sk "https://127.0.0.1:${PORT}/api/health" > /dev/null 2>&1; then
    echo ""
    ok "Flask respondiendo en https://127.0.0.1:${PORT}"
    break
  fi
  if [[ $i -eq 20 ]]; then
    echo ""
    err "Flask no respondió en 20 segundos"
    echo "   Últimas líneas del log:"
    tail -30 "$LOG_FILE" 2>/dev/null || true
    echo ""
    echo "   Estado supervisord:"
    "$VENV_SUPERVISORCTL" -c "$SUPERVISORD_CONF" status 2>/dev/null || true
    exit 1
  fi
done

# ── 7. Exponer el puerto como público en Codespaces ──────────────────────────
if [[ -n "${CODESPACE_NAME:-}" ]]; then
  echo "→ Configurando visibilidad pública del puerto $PORT..."
  gh codespace ports visibility "${PORT}:public" -c "$CODESPACE_NAME" 2>/dev/null \
    && ok "Puerto $PORT → público" \
    || warn "No se pudo cambiar visibilidad (normal fuera de Codespaces CLI)"

  DOMAIN="${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-app.github.dev}"
  PUBLIC_URL="https://${CODESPACE_NAME}-${PORT}.${DOMAIN}"
  echo ""
  echo "══════════════════════════════════════════"
  ok "API disponible en:"
  echo "   🌐 $PUBLIC_URL"
  echo "══════════════════════════════════════════"
else
  echo ""
  ok "API disponible en: https://localhost:${PORT}"
fi

echo ""
echo "Comandos útiles:"
echo "  bash start.sh --status   → ver estado"
echo "  bash start.sh --logs     → logs en tiempo real"
echo "  bash start.sh --restart  → reiniciar Flask sin bajar supervisord"
echo "  bash start.sh --stop     → detener todo"
echo "  bash start.sh            → relanzar completo"
echo ""
info "supervisord reinicia Flask automáticamente si cae → sin más 502"
