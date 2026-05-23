"""
conftest.py — TDS Sentinel API — Fixtures de prueba
Configura la app Flask con una base de datos SQLite temporal (archivo)
para que cada test corra aislado y sin tocar la BD de desarrollo.
"""
from __future__ import annotations

import os
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

import pytest

# ── 1. Agregar backend/ al PYTHONPATH antes de importar la app ──────────────
BACKEND_DIR = Path(__file__).parent.parent
sys.path.insert(0, str(BACKEND_DIR))

# ── 2. Variables de entorno de prueba (ANTES de importar la app) ────────────
os.environ.setdefault("SECRET_KEY", "clave-secreta-de-testing-2026")
os.environ.setdefault("FLASK_DEBUG", "false")

# Base de datos temporal — un archivo por sesión de pytest
_tmp_db = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
_tmp_db.close()
os.environ["DB_PATH"] = _tmp_db.name

# ── 3. Importar después de configurar el entorno ────────────────────────────
from config import Config  # noqa: E402
Config.DB_PATH = _tmp_db.name  # garantía doble

import app as flask_module  # noqa: E402  (importación tardía intencional)
from database import get_db_connection, hash_password  # noqa: E402


# ─────────────────────────────────────────────────────────────────────────────
# Fixtures de sesión
# ─────────────────────────────────────────────────────────────────────────────

@pytest.fixture(scope="session")
def app():
    """App Flask configurada para pruebas."""
    flask_module.app.config.update({
        "TESTING": True,
        "WTF_CSRF_ENABLED": False,
    })
    yield flask_module.app


@pytest.fixture
def client(app):
    """Cliente HTTP de prueba (Flask test client)."""
    return app.test_client()


# ─────────────────────────────────────────────────────────────────────────────
# Limpieza entre tests
# ─────────────────────────────────────────────────────────────────────────────

@pytest.fixture(autouse=True)
def reset_db():
    """Vacía las tablas relevantes antes de cada test para aislamiento total."""
    conn = get_db_connection()
    conn.execute("DELETE FROM support_tickets")
    conn.execute("DELETE FROM clients")
    conn.commit()
    conn.close()
    yield


# ─────────────────────────────────────────────────────────────────────────────
# Helpers de base de datos
# ─────────────────────────────────────────────────────────────────────────────

def _insert_client(
    email: str,
    password: str,
    status: str = "enabled",
    company: str = "Empresa Test SA",
) -> dict:
    """Inserta un cliente directamente en la BD de prueba y devuelve sus datos."""
    now = datetime.now(timezone.utc).isoformat()
    conn = get_db_connection()
    cur = conn.execute(
        """INSERT INTO clients
           (company_name, contact_name, email, phone,
            password_hash, bs_area, client_status, created_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
        (company, "Contacto Test", email, "+52 55 0000 0000",
         hash_password(password), "Tecnología", status, now),
    )
    conn.commit()
    client_id = cur.lastrowid
    conn.close()
    return {"id": client_id, "email": email, "password": password, "status": status}


# ─────────────────────────────────────────────────────────────────────────────
# Fixtures de clientes de prueba
# ─────────────────────────────────────────────────────────────────────────────

@pytest.fixture
def usuario_activo():
    """Cliente con estado 'enabled' listo para hacer login."""
    return _insert_client(
        email="activo@tdsinnovate.com",
        password="Password123!",
        status="enabled",
    )


@pytest.fixture
def usuario_bloqueado():
    """Cliente con estado 'blocked'."""
    return _insert_client(
        email="bloqueado@tdsinnovate.com",
        password="Password123!",
        status="blocked",
    )


@pytest.fixture
def usuario_deshabilitado():
    """Cliente con estado 'disabled'."""
    return _insert_client(
        email="disabled@tdsinnovate.com",
        password="Password123!",
        status="disabled",
    )
