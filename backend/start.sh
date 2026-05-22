#!/usr/bin/env bash
# =============================================================================
# start.sh — TDS Sentinel API — Script de arranque
# =============================================================================
# Uso:
#   bash start.sh          → arranca la API (genera cert si hace falta)
#   bash start.sh --stop   → detiene la API
#   bash start.sh --status → muestra si está corriendo
#   bash start.sh --logs   → tail de los logs
#
# Se ejecuta automáticamente en cada inicio de Codespaces (postStartCommand).
# También se puede lanzar manualmente cuando sea necesario.
# =============================================================================

set -euo pipefail

# ── Rutas ────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
VENV_PY="$ROOT_DIR/.venv/bin/python"
SYS_PY="/usr/bin/python3"
LOG_FILE="/tmp/sentinel_https.log"
PID_FILE="/tmp/sentinel.pid"
CERT="/tmp/sentinel_cert.pem"
KEY="/tmp/sentinel_key.pem"
PORT="${PORT:-5000}"

# Usar venv si existe, sino Python del sistema
if [[ -f "$VENV_PY" ]]; then
  PYTHON="$VENV_PY"
else
  PYTHON="$SYS_PY"
fi

# ── Colores ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✅  $*${NC}"; }
warn() { echo -e "${YELLOW}⚠️   $*${NC}"; }
err()  { echo -e "${RED}❌  $*${NC}"; }

# ─────────────────────────────────────────────────────────────────────────────
# Subcomandos
# ─────────────────────────────────────────────────────────────────────────────

cmd_stop() {
  if [[ -f "$PID_FILE" ]]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
      kill "$PID" && ok "Flask detenido (PID $PID)" || err "No se pudo detener PID $PID"
    else
      warn "PID $PID ya no está corriendo"
    fi
    rm -f "$PID_FILE"
  else
    pkill -f "start_https.py" 2>/dev/null && ok "Flask detenido" || warn "Flask no estaba corriendo"
  fi
}

cmd_status() {
  if curl -sk "https://127.0.0.1:${PORT}/api/health" > /dev/null 2>&1; then
    ok "Flask corriendo en https://127.0.0.1:${PORT}"
    [[ -n "${CODESPACE_NAME:-}" ]] && \
      echo "   🔗 https://${CODESPACE_NAME}-${PORT}.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-app.github.dev}"
  else
    err "Flask NO está corriendo en el puerto ${PORT}"
    echo "   Intenta: bash $SCRIPT_DIR/start.sh"
  fi
}

cmd_logs() {
  if [[ -f "$LOG_FILE" ]]; then
    tail -50 "$LOG_FILE"
  else
    warn "No hay logs en $LOG_FILE"
  fi
}

# ── Manejar subcomandos ───────────────────────────────────────────────────────
case "${1:-}" in
  --stop)   cmd_stop;   exit 0 ;;
  --status) cmd_status; exit 0 ;;
  --logs)   cmd_logs;   exit 0 ;;
  "")       ;;  # arranque normal
  *) echo "Uso: bash start.sh [--stop|--status|--logs]"; exit 1 ;;
esac

# =============================================================================
# ARRANQUE NORMAL
# =============================================================================

echo ""
echo "══════════════════════════════════════════"
echo "  TDS Sentinel — Iniciando API"
echo "══════════════════════════════════════════"

# ── 1. Detener instancia previa ───────────────────────────────────────────────
if [[ -f "$PID_FILE" ]]; then
  OLD_PID=$(cat "$PID_FILE")
  if kill -0 "$OLD_PID" 2>/dev/null; then
    echo "→ Deteniendo instancia previa (PID $OLD_PID)..."
    kill "$OLD_PID" 2>/dev/null || true
    sleep 1
  fi
  rm -f "$PID_FILE"
fi
pkill -f "start_https.py" 2>/dev/null || true
sleep 1

# ── 2. Generar certificado SSL (siempre, /tmp se borra en cada reinicio) ──────
echo "→ Generando certificado SSL auto-firmado..."
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "$KEY" -out "$CERT" \
  -days 365 \
  -subj "/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" \
  2>/dev/null
ok "Certificado generado → $CERT"

# ── 3. Verificar que .env existe ─────────────────────────────────────────────
if [[ ! -f "$SCRIPT_DIR/.env" ]]; then
  warn ".env no encontrado — copiando desde .env.example"
  if [[ -f "$SCRIPT_DIR/.env.example" ]]; then
    cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
    # Generar SECRET_KEY automáticamente
    NEW_KEY=$("$PYTHON" -c "import secrets; print(secrets.token_hex(32))")
    sed -i "s/REEMPLAZA_CON_UN_VALOR_SECRETO_SEGURO/$NEW_KEY/" "$SCRIPT_DIR/.env"
    ok ".env creado con SECRET_KEY generada"
  else
    err ".env.example no encontrado. Crea el archivo .env manualmente."
    exit 1
  fi
fi

# ── 4. Lanzar Flask HTTPS en background ──────────────────────────────────────
echo "→ Iniciando Flask HTTPS en puerto $PORT..."
SSL_CERT="$CERT" SSL_KEY="$KEY" PORT="$PORT" \
  "$PYTHON" "$SCRIPT_DIR/start_https.py" > "$LOG_FILE" 2>&1 &
FLASK_PID=$!
disown "$FLASK_PID"          # desacoplar del shell para sobrevivir a su cierre
echo "$FLASK_PID" > "$PID_FILE"
echo "   PID: $FLASK_PID  |  Log: $LOG_FILE"

# ── 5. Esperar y verificar que arrancó ───────────────────────────────────────
echo -n "→ Esperando que Flask responda"
for i in $(seq 1 12); do
  sleep 1
  echo -n "."
  if curl -sk "https://127.0.0.1:${PORT}/api/health" > /dev/null 2>&1; then
    echo ""
    ok "Flask respondiendo en https://127.0.0.1:${PORT}"
    break
  fi
  if [[ $i -eq 12 ]]; then
    echo ""
    err "Flask no respondió en 12 segundos"
    echo "   Últimas líneas del log:"
    tail -20 "$LOG_FILE"
    exit 1
  fi
done

# ── 6. Exponer el puerto como público en Codespaces ──────────────────────────
if [[ -n "${CODESPACE_NAME:-}" ]]; then
  echo "→ Configurando visibilidad pública del puerto $PORT..."
  gh codespace ports visibility "${PORT}:public" -c "$CODESPACE_NAME" 2>/dev/null \
    && ok "Puerto $PORT → público" \
    || warn "No se pudo cambiar visibilidad (es normal fuera de Codespaces)"

  PUBLIC_URL="https://${CODESPACE_NAME}-${PORT}.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-app.github.dev}"
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
echo "  bash start.sh --status  → ver si está corriendo"
echo "  bash start.sh --logs    → ver logs en tiempo real"
echo "  bash start.sh --stop    → detener la API"
echo "  bash start.sh           → relanzar"
