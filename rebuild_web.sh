#!/usr/bin/env bash
# =============================================================================
# rebuild_web.sh — TDS Sentinel
# Recompila Flutter Web y copia el build donde Flask lo sirve.
#
# Uso: bash rebuild_web.sh
# =============================================================================
set -euo pipefail

FLUTTER="/tmp/flutter/bin/flutter"
PROJECT="/workspaces/tds-sentinel-mvp/mobile/sentinel_mobile"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✅  $*${NC}"; }
warn() { echo -e "${YELLOW}⚠️   $*${NC}"; }
err()  { echo -e "${RED}❌  $*${NC}"; exit 1; }

echo ""
echo "══════════════════════════════════════════"
echo "  TDS Sentinel — Recompilando Flutter Web"
echo "══════════════════════════════════════════"

# 1. Verificar que Flutter esté disponible
if [[ ! -f "$FLUTTER" ]]; then
  warn "Flutter SDK no encontrado en /tmp/flutter — descargando..."
  FLUTTER_URL=$(curl -s "https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json" | \
    python3 -c "
import json,sys
data = json.load(sys.stdin)
stable_hash = data['current_release']['stable']
for r in data['releases']:
    if r['hash'] == stable_hash:
        print('https://storage.googleapis.com/flutter_infra_release/releases/' + r['archive'])
        break
")
  echo "→ Descargando Flutter SDK ($FLUTTER_URL)..."
  curl -L -o /tmp/flutter_sdk.tar.xz "$FLUTTER_URL"
  tar -xf /tmp/flutter_sdk.tar.xz -C /tmp/

  # Instalar compatibilidad glibc si hace falta (Alpine usa musl)
  if [[ ! -f "/lib/libgcompat.so.0" ]]; then
    echo "→ Instalando gcompat (compatibilidad glibc para Alpine)..."
    sudo apk add --no-cache gcompat libc6-compat 2>/dev/null || true
  fi
  ok "Flutter SDK listo"
fi

export PATH="/tmp/flutter/bin:$PATH"
flutter --version 2>&1 | head -1

# 2. Compilar
echo ""
echo "→ Compilando Flutter Web (modo release)..."
cd "$PROJECT"
flutter pub get -q
flutter build web --release --no-tree-shake-icons

ok "Build completado → $PROJECT/build/web/"
echo ""
echo "→ El servidor Flask ya sirve el nuevo build automáticamente."
echo "   Recarga la página (Ctrl+Shift+R) para ver los cambios."
echo ""
ok "Listo"
