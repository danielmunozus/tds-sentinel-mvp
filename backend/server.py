"""
server.py — TDS Sentinel API
Punto de entrada HTTP para producción/Codespaces.

Por qué HTTP y no HTTPS:
  El proxy de GitHub Codespaces termina SSL externamente.
  El flujo real es:
    Browser → HTTPS → Codespaces proxy → HTTP → Flask (este proceso)
  Flask no necesita gestionar certificados SSL. Hacerlo sólo añade
  complejidad y es la raíz del problema 502 histórico.

  Flutter Web usa same-origin (Uri.base), por lo que el esquema
  del browser es siempre HTTPS via el proxy — independientemente de
  lo que sirva Flask internamente.

Uso:
  python server.py              → arranca Flask en HTTP
  Via supervisord:  bash start.sh
"""
from __future__ import annotations

import os
import sys

# ── Directorio de trabajo = backend/ ────────────────────────────────────────
BACKEND_DIR = os.path.dirname(os.path.abspath(__file__))
os.chdir(BACKEND_DIR)
sys.path.insert(0, BACKEND_DIR)

# ── Variables de entorno ─────────────────────────────────────────────────────
from dotenv import load_dotenv
load_dotenv(os.path.join(BACKEND_DIR, ".env"))

PORT = int(os.getenv("PORT", 5000))

# ── Importar la app ──────────────────────────────────────────────────────────
from app import app  # noqa: E402

print(f"[Sentinel] 🚀 HTTP activo  →  http://0.0.0.0:{PORT}", flush=True)
print(f"[Sentinel] 🌐 Acceso externo via proxy Codespaces → HTTPS", flush=True)

app.run(
    host="0.0.0.0",
    port=PORT,
    debug=False,        # NUNCA debug=True con supervisord (fork issues)
    use_reloader=False, # supervisord gestiona los reinicios
    threaded=True,
)
