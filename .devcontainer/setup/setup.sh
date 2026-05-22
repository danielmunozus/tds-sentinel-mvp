#!/bin/bash
# .devcontainer/setup.sh — TDS Sentinel
set -e

echo "╔══════════════════════════════════════╗"
echo "║  TDS Sentinel — Setup Codespace      ║"
echo "╚══════════════════════════════════════╝"

# ── Python / Backend ──────────────────────────────────────────
echo "→ Instalando Python y dependencias del backend..."
pip install -r /workspaces/tds-sentinel-mvp/backend/requirements.txt --quiet

# Crear .env desde .env.example si no existe
cd /workspaces/tds-sentinel-mvp/backend
if [ ! -f .env ]; then
  cp .env.example .env
  SECRET=$(python3 -c "import secrets; print(secrets.token_hex(32))")
  sed -i "s/REEMPLAZA_CON_UN_VALOR_SECRETO_SEGURO/$SECRET/" .env
  echo "→ .env creado con SECRET_KEY generada."
fi

# ── Flutter ───────────────────────────────────────────────────
echo "→ Instalando dependencias Flutter..."
cd /workspaces/tds-sentinel-mvp/mobile/sentinel_mobile
flutter pub get

echo ""
echo "╔══════════════════════════════════════╗"
echo "║  ✅ Setup completado                 ║"
echo "║                                      ║"
echo "║  Backend:                            ║"
echo "║  cd backend && python3 app.py        ║"
echo "║                                      ║"
echo "║  Flutter web:                        ║"
echo "║  cd mobile/sentinel_mobile           ║"
echo "║  flutter run -d web-server           ║"
echo "║         --web-port 8080              ║"
echo "╚══════════════════════════════════════╝"
