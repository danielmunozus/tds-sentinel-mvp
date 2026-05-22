#!/bin/bash
# .devcontainer/setup.sh — TDS Sentinel
# Script de configuración automática para GitHub Codespaces.
# Se ejecuta una vez al crear el Codespace.

set -e
echo "╔══════════════════════════════════════╗"
echo "║  TDS Sentinel — Setup Codespace      ║"
echo "╚══════════════════════════════════════╝"

# ── Python / Backend ──────────────────────────────────────────────────────────
echo ""
echo "→ Instalando dependencias del backend..."
cd /workspaces/tds-sentinel-mvp/backend
pip install -r requirements.txt --quiet

# Crear .env desde .env.example si no existe
if [ ! -f .env ]; then
  cp .env.example .env
  SECRET=$(python3 -c "import secrets; print(secrets.token_hex(32))")
  sed -i "s/REEMPLAZA_CON_UN_VALOR_SECRETO_SEGURO/$SECRET/" .env
  echo "→ .env creado con SECRET_KEY generada automáticamente."
fi

# ── Flutter ───────────────────────────────────────────────────────────────────
echo ""
echo "→ Instalando Flutter SDK..."

FLUTTER_VERSION="3.19.6"
FLUTTER_DIR="/home/vscode/flutter"

if [ ! -d "$FLUTTER_DIR" ]; then
  cd /tmp
  curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" -o flutter.tar.xz
  tar xf flutter.tar.xz -C /home/vscode/
  rm flutter.tar.xz
  echo "→ Flutter $FLUTTER_VERSION instalado."
else
  echo "→ Flutter ya está instalado."
fi

# Agregar Flutter al PATH
echo 'export PATH="$PATH:/home/vscode/flutter/bin"' >> /home/vscode/.bashrc
export PATH="$PATH:/home/vscode/flutter/bin"

# Pre-download Flutter dependencies
flutter precache --web --no-android --no-ios 2>/dev/null || true

# Instalar dependencias del proyecto Flutter
echo ""
echo "→ Instalando dependencias Flutter del proyecto..."
cd /workspaces/tds-sentinel-mvp/mobile/sentinel_mobile
/home/vscode/flutter/bin/flutter pub get

echo ""
echo "╔══════════════════════════════════════╗"
echo "║  Setup completado. ¡Listo!           ║"
echo "║                                      ║"
echo "║  Backend:                            ║"
echo "║  cd backend && python3 app.py        ║"
echo "║                                      ║"
echo "║  Flutter web:                        ║"
echo "║  cd mobile/sentinel_mobile           ║"
echo "║  flutter run -d web-server           ║"
echo "║    --web-port 8080                   ║"
echo "╚══════════════════════════════════════╝"
