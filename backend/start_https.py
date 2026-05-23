"""
start_https.py — TDS Sentinel API
Lanza Flask con SSL/HTTPS para que funcione con el proxy de GitHub Codespaces.

Uso directo:  python start_https.py
Via script:   bash start.sh          (genera cert + lanza + expone puerto)

Variables de entorno opcionales:
  SSL_CERT   Ruta al certificado PEM  (default: /tmp/sentinel_cert.pem)
  SSL_KEY    Ruta a la clave PEM      (default: /tmp/sentinel_key.pem)
  PORT       Puerto de escucha        (default: 5000)
"""
from __future__ import annotations

import os
import ssl
import sys

# ── Directorio de trabajo = backend/ ────────────────────────────────────────
BACKEND_DIR = os.path.dirname(os.path.abspath(__file__))
os.chdir(BACKEND_DIR)
sys.path.insert(0, BACKEND_DIR)

# ── Variables de entorno ─────────────────────────────────────────────────────
from dotenv import load_dotenv
load_dotenv(os.path.join(BACKEND_DIR, ".env"))

# Primero busca las variables de entorno; si no hay, usa la ubicación
# PERSISTENTE en el workspace (no /tmp que se borra al reiniciar).
_default_certs = os.path.join(BACKEND_DIR, "..", ".certs")
CERT = os.getenv("SSL_CERT", os.path.join(_default_certs, "sentinel_cert.pem"))
KEY  = os.getenv("SSL_KEY",  os.path.join(_default_certs, "sentinel_key.pem"))
PORT = int(os.getenv("PORT", 5000))

# ── Validar que existen los certificados ─────────────────────────────────────
if not os.path.isfile(CERT) or not os.path.isfile(KEY):
    print(
        f"[Sentinel] ❌  Certificado SSL no encontrado:\n"
        f"   CERT → {CERT}\n"
        f"   KEY  → {KEY}\n"
        f"   Ejecuta: bash {BACKEND_DIR}/start.sh",
        flush=True,
    )
    sys.exit(1)

# ── Importar la app DESPUÉS de configurar el entorno ────────────────────────
from app import app  # noqa: E402

# ── Contexto SSL ─────────────────────────────────────────────────────────────
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.load_cert_chain(CERT, KEY)

print(f"[Sentinel] 🔒 HTTPS activo  →  https://0.0.0.0:{PORT}", flush=True)
print(f"[Sentinel] 📄 Cert: {CERT}", flush=True)

app.run(
    host="0.0.0.0",
    port=PORT,
    debug=False,
    use_reloader=False,
    threaded=True,
    ssl_context=ctx,
)
