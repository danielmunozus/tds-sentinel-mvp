"""
app.py — TDS Sentinel API
Punto de entrada principal. Flask + Blueprints + SQLite.
Arquitectura: Flutter Mobile → REST API → Flask → SQLite
"""

import logging
import os
from flask import Flask, jsonify, request
from config import Config
from database import init_db

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
app = Flask(__name__)
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
    response.headers["Access-Control-Allow-Headers"] = "Content-Type, Accept"
    response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
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
    return error_response("Recurso no encontrado.", 404)

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

app.register_blueprint(packs_bp,       url_prefix=Config.API_PREFIX)
app.register_blueprint(assessments_bp, url_prefix=Config.API_PREFIX)

# ── Health Check ──────────────────────────────────────────────────────────────
@app.route(f"{Config.API_PREFIX}/health", methods=["GET"])
def health_check():
    return success_response({
        "status":  "ok",
        "message": f"{Config.APP_NAME} is running",
        "version": Config.API_VERSION,
    })

# ── Punto de entrada ──────────────────────────────────────────────────────────
if __name__ == "__main__":
    port = int(os.getenv("PORT", 5000))
    logger.info("Iniciando %s en http://127.0.0.1:%d", Config.APP_NAME, port)
    app.run(host="127.0.0.1", port=port, debug=Config.DEBUG)
