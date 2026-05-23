"""
config.py — TDS Sentinel API
Configuración centralizada usando variables de entorno.
Nunca hardcodear secretos en el código fuente.
"""

import os
from dotenv import load_dotenv

# Carga variables desde .env si existe (solo desarrollo local)
load_dotenv()


class Config:
    """Configuración base de la aplicación."""

    # ── Flask ──────────────────────────────────────────────────────────────
    # DEBUG debe ser False en producción. Se lee desde el entorno.
    DEBUG: bool = os.getenv("FLASK_DEBUG", "false").lower() == "true"

    # Clave secreta para firmar sesiones y tokens futuros
    SECRET_KEY: str = os.getenv("SECRET_KEY", "")

    # ── Base de datos ──────────────────────────────────────────────────────
    # Ruta absoluta al archivo SQLite. Por defecto, junto al backend.
    DB_PATH: str = os.getenv(
        "DB_PATH",
        os.path.join(os.path.dirname(__file__), "sentinel.db")
    )

    # ── Flutter Web ────────────────────────────────────────────────────────
    # Ruta al build release de Flutter. Se puede sobreescribir con FLUTTER_BUILD_DIR.
    FLUTTER_BUILD_DIR: str = os.getenv(
        "FLUTTER_BUILD_DIR",
        os.path.join(os.path.dirname(__file__), "..", "mobile", "sentinel_mobile", "build", "web")
    )

    # ── CORS ───────────────────────────────────────────────────────────────
    # Lista blanca de orígenes permitidos. Separados por coma en el .env.
    # Ejemplo: CORS_ORIGINS=http://localhost:3000,http://127.0.0.1:5001
    # En desarrollo local Flutter usa el mismo host, se acepta localhost.
    _cors_raw: str = os.getenv("CORS_ORIGINS", "http://localhost:5000,http://127.0.0.1:5000")
    CORS_ORIGINS: list[str] = [o.strip() for o in _cors_raw.split(",") if o.strip()]

    # Auto-detectar URLs de GitHub Codespaces (se añaden automáticamente
    # sin necesidad de hardcodearlas en .env — sobreviven a cambios de nombre).
    _codespace: str = os.getenv("CODESPACE_NAME", "")
    _cs_domain: str = os.getenv(
        "GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN", "app.github.dev"
    )
    if _codespace:
        for _port in [5000, 8080, 3000]:
            _cs_url = f"https://{_codespace}-{_port}.{_cs_domain}"
            if _cs_url not in CORS_ORIGINS:
                CORS_ORIGINS.append(_cs_url)

    # ── Sesiones ───────────────────────────────────────────────────────────
    # Duración de las sesiones en horas. Configurable via SESSION_HOURS en .env.
    SESSION_HOURS: int = int(os.getenv("SESSION_HOURS", "24"))

    # ── API ────────────────────────────────────────────────────────────────
    API_PREFIX: str = "/api"
    API_VERSION: str = "3.2.0"
    APP_NAME: str = "TDS Sentinel API"

    @classmethod
    def validate(cls) -> None:
        """
        Valida la configuración mínima requerida al arrancar.
        Lanza un error explícito si falta algo crítico.
        """
        if not cls.SECRET_KEY:
            raise RuntimeError(
                "[Sentinel] SECRET_KEY no está definida. "
                "Agrega SECRET_KEY en tu archivo .env antes de correr la aplicación."
            )
        if cls.DEBUG:
            print("[Sentinel] ⚠️  Modo DEBUG activo — no usar en producción.")
