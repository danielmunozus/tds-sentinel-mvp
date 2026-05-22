"""
database.py — TDS Sentinel API
Gestión de conexión y ciclo de vida de la base de datos SQLite.
"""

import sqlite3
import logging
from config import Config

logger = logging.getLogger(__name__)


def get_db_connection() -> sqlite3.Connection:
    """
    Abre y retorna una conexión segura a SQLite.
    - row_factory permite acceso por nombre de columna
    - WAL mode mejora concurrencia en lectura
    - foreign_keys ON activa integridad referencial
    """
    conn = sqlite3.connect(Config.DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    conn.execute("PRAGMA journal_mode = WAL")
    return conn


def init_db() -> None:
    """
    Inicializa la base de datos.
    Crea tablas si no existen. Seguro de llamar múltiples veces.
    """
    conn = get_db_connection()
    try:
        _create_tables(conn)
        conn.commit()
        logger.info("Base de datos inicializada → %s", Config.DB_PATH)
        print(f"[Sentinel] Base de datos lista → {Config.DB_PATH}")
    except Exception as exc:
        logger.error("Error al inicializar la base de datos: %s", exc)
        raise
    finally:
        conn.close()


def _create_tables(conn: sqlite3.Connection) -> None:
    """Schema completo de TDS Sentinel MVP."""

    # Versión del schema para migraciones futuras
    conn.execute("""
        CREATE TABLE IF NOT EXISTS schema_version (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            version    TEXT NOT NULL,
            applied_at TEXT NOT NULL
        )
    """)

    # Tabla principal de evaluaciones de riesgo
    # assessment_hash: SHA-256 del contenido — integridad, no seguridad de contraseña
    conn.execute("""
        CREATE TABLE IF NOT EXISTS risk_assessments (
            id                   INTEGER PRIMARY KEY AUTOINCREMENT,
            company_name         TEXT    NOT NULL,
            responsible_name     TEXT    NOT NULL,
            pack_id              TEXT    NOT NULL,
            answers_json         TEXT    NOT NULL,
            score                REAL    NOT NULL,
            risk_level           TEXT    NOT NULL,
            recommendations_json TEXT    NOT NULL,
            assessment_hash      TEXT    NOT NULL,
            created_at           TEXT    NOT NULL,
            updated_at           TEXT
        )
    """)

    # Registrar versión inicial si la tabla está vacía
    existing = conn.execute("SELECT COUNT(*) FROM schema_version").fetchone()[0]
    if existing == 0:
        from datetime import datetime, timezone
        conn.execute(
            "INSERT INTO schema_version (version, applied_at) VALUES (?, ?)",
            ("1.0.0", datetime.now(timezone.utc).isoformat())
        )
