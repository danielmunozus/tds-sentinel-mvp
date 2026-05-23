"""
app.py — TDS Sentinel API
Punto de entrada principal. Flask + Blueprints + SQLite.
Arquitectura: Flutter Web → Flask (static + API) → SQLite
"""

import logging
import os
from flask import Flask, jsonify, request, send_from_directory
from config import Config
from database import init_db

FLUTTER_DIR = os.path.abspath(Config.FLUTTER_BUILD_DIR)

# ── Logging ───────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.DEBUG if Config.DEBUG else logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s — %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
logger = logging.getLogger(__name__)

# ── Validación temprana de configuración ─────────────────────────────────────
Config.validate()

# ── App ───────────────────────────────────────────────────────────────────────
app = Flask(__name__, static_folder=FLUTTER_DIR, static_url_path="")
app.config["SECRET_KEY"] = Config.SECRET_KEY
app.config["DEBUG"] = Config.DEBUG

# ── CORS ──────────────────────────────────────────────────────────────────────
try:
    from flask_cors import CORS
    CORS(app, origins=Config.CORS_ORIGINS, supports_credentials=False,
         allow_headers=["Content-Type", "Accept"],
         methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"])
    logger.info("CORS via flask-cors → %s", Config.CORS_ORIGINS)
except ImportError:
    logger.warning("flask-cors no disponible — CORS manual activo.")

@app.after_request
def apply_cors_headers(response):
    origin = request.headers.get("Origin", "")
    if origin in Config.CORS_ORIGINS:
        response.headers["Access-Control-Allow-Origin"] = origin
        response.headers["Vary"] = "Origin"
    response.headers["Access-Control-Allow-Headers"] = "Content-Type, Accept, Authorization"
    response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
    return response


@app.after_request
def apply_security_headers(response):
    # VULN-04: suprimir versión exacta del servidor
    response.headers["Server"] = "TDS-Sentinel"
    # VULN-06: cabeceras de seguridad estándar
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["Permissions-Policy"] = "geolocation=(), camera=(), microphone=()"
    # CSP permisiva para Flutter Web (requiere unsafe-inline/eval para CanvasKit)
    # Para producción con nginx, configurar CSP más restrictiva por ruta /api vs /
    response.headers.setdefault(
        "Content-Security-Policy",
        "default-src 'self' blob: data:; "
        "script-src 'self' 'unsafe-inline' 'unsafe-eval' blob:; "
        "style-src 'self' 'unsafe-inline'; "
        "img-src 'self' data: blob:; "
        "font-src 'self' data:; "
        "connect-src 'self'; "
        "worker-src 'self' blob:;"
    )
    return response

# ── Base de datos ─────────────────────────────────────────────────────────────
init_db()

# ── Utilidades de respuesta ───────────────────────────────────────────────────
def success_response(data, status_code: int = 200):
    return jsonify(data), status_code

def error_response(message: str, status_code: int):
    return jsonify({"error": message}), status_code

# ── Error handlers globales (siempre JSON, nunca HTML) ────────────────────────
@app.errorhandler(400)
def bad_request(e):
    return error_response("Solicitud inválida.", 400)

@app.errorhandler(404)
def not_found(e):
    # Las rutas /api/* devuelven JSON; el resto sirve Flutter SPA.
    if request.path.startswith(Config.API_PREFIX):
        return error_response("Recurso no encontrado.", 404)
    return send_from_directory(FLUTTER_DIR, "index.html")

@app.errorhandler(405)
def method_not_allowed(e):
    return error_response("Método no permitido.", 405)

@app.errorhandler(500)
def internal_error(e):
    logger.error("Error interno: %s", e)
    return error_response("Error interno del servidor.", 500)

# ── Blueprints ────────────────────────────────────────────────────────────────
from routes.packs import packs_bp
from routes.assessments import assessments_bp
from routes.clients import clients_bp
from routes.auth import auth_bp

app.register_blueprint(packs_bp,       url_prefix=Config.API_PREFIX)
app.register_blueprint(assessments_bp, url_prefix=Config.API_PREFIX)
app.register_blueprint(clients_bp,     url_prefix=Config.API_PREFIX)
app.register_blueprint(auth_bp,        url_prefix=Config.API_PREFIX)

# ── Health Check ──────────────────────────────────────────────────────────────
@app.route(f"{Config.API_PREFIX}/health", methods=["GET"])
def health_check():
    return success_response({
        "status":  "ok",
        "message": f"{Config.APP_NAME} is running",
        "version": Config.API_VERSION,
    })

# ── Flutter Web — ruta raíz y catch-all para SPA ─────────────────────────────
@app.route("/")
def serve_flutter():
    return send_from_directory(FLUTTER_DIR, "index.html")

@app.route("/<path:path>")
def serve_flutter_assets(path):
    # Archivos estáticos que existan se sirven directamente.
    # Rutas de la SPA que no sean archivos devuelven index.html.
    if path.startswith("api/"):
        return error_response("Recurso no encontrado.", 404)
    full = os.path.join(FLUTTER_DIR, path)
    if os.path.isfile(full):
        return send_from_directory(FLUTTER_DIR, path)
    return send_from_directory(FLUTTER_DIR, "index.html")

# ── Punto de entrada ──────────────────────────────────────────────────────────
if __name__ == "__main__":
    port = int(os.getenv("PORT", 5000))
    logger.info("Iniciando %s en http://0.0.0.0:%d", Config.APP_NAME, port)
    app.run(host="0.0.0.0", port=port, debug=Config.DEBUG)
