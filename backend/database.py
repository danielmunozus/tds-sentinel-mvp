"""
database.py — TDS Sentinel API
Gestión de conexión y ciclo de vida de la base de datos SQLite.
Schema v2.0.0: tabla clients + FK client_id en risk_assessments.
"""

import sqlite3
import logging
from datetime import datetime, timezone
from config import Config

logger = logging.getLogger(__name__)


def get_db_connection() -> sqlite3.Connection:
    conn = sqlite3.connect(Config.DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    conn.execute("PRAGMA journal_mode = WAL")
    return conn


def init_db() -> None:
    conn = get_db_connection()
    try:
        _create_tables(conn)
        _run_migrations(conn)
        conn.commit()
        logger.info("Base de datos inicializada → %s", Config.DB_PATH)
        print(f"[Sentinel] Base de datos lista → {Config.DB_PATH}")
    except Exception as exc:
        logger.error("Error al inicializar la base de datos: %s", exc)
        raise
    finally:
        conn.close()


# ──────────────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────────────

def _current_version(conn: sqlite3.Connection) -> str:
    try:
        row = conn.execute(
            "SELECT version FROM schema_version ORDER BY id DESC LIMIT 1"
        ).fetchone()
        return row[0] if row else "0.0.0"
    except sqlite3.OperationalError:
        return "0.0.0"


# ──────────────────────────────────────────────────────────────────────────────
# Creación de tablas (versión actual: 2.0.0)
# ──────────────────────────────────────────────────────────────────────────────

def _create_tables(conn: sqlite3.Connection) -> None:
    """Crea todas las tablas si no existen. Seguro de llamar múltiples veces."""

    conn.execute("""
        CREATE TABLE IF NOT EXISTS schema_version (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            version    TEXT NOT NULL,
            applied_at TEXT NOT NULL
        )
    """)

    conn.execute("""
        CREATE TABLE IF NOT EXISTS clients (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            name         TEXT    NOT NULL,
            contact_name TEXT,
            email        TEXT,
            industry     TEXT,
            created_at   TEXT    NOT NULL,
            updated_at   TEXT
        )
    """)

    # client_id es nullable en DDL para compatibilidad con ALTER TABLE en migraciones.
    # La capa de aplicación (routes/assessments.py) exige que no sea NULL en nuevos registros.
    conn.execute("""
        CREATE TABLE IF NOT EXISTS risk_assessments (
            id                   INTEGER PRIMARY KEY AUTOINCREMENT,
            client_id            INTEGER REFERENCES clients(id) ON DELETE RESTRICT,
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

    existing = conn.execute("SELECT COUNT(*) FROM schema_version").fetchone()[0]
    if existing == 0:
        conn.execute(
            "INSERT INTO schema_version (version, applied_at) VALUES (?, ?)",
            ("2.0.0", datetime.now(timezone.utc).isoformat()),
        )


# ──────────────────────────────────────────────────────────────────────────────
# Migraciones
# ──────────────────────────────────────────────────────────────────────────────

def _run_migrations(conn: sqlite3.Connection) -> None:
    version = _current_version(conn)
    if version == "1.0.0":
        _migrate_1_to_2(conn)
        logger.info("Migración 1.0.0 → 2.0.0 completada.")


def _migrate_1_to_2(conn: sqlite3.Connection) -> None:
    """
    v1 → v2: introduce tabla clients y FK client_id en risk_assessments.
    Preserva todos los registros existentes asignándolos a un cliente 'Legado'.
    """
    now = datetime.now(timezone.utc).isoformat()

    conn.execute("""
        CREATE TABLE IF NOT EXISTS clients (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            name         TEXT    NOT NULL,
            contact_name TEXT,
            email        TEXT,
            industry     TEXT,
            created_at   TEXT    NOT NULL,
            updated_at   TEXT
        )
    """)

    # ADD COLUMN solo si no existe (SQLite no soporta IF NOT EXISTS en ADD COLUMN)
    existing_cols = [
        row[1] for row in conn.execute("PRAGMA table_info(risk_assessments)").fetchall()
    ]
    if "client_id" not in existing_cols:
        conn.execute(
            "ALTER TABLE risk_assessments ADD COLUMN "
            "client_id INTEGER REFERENCES clients(id) ON DELETE RESTRICT"
        )

    # Asignar registros huérfanos a un cliente "Legado"
    orphans = conn.execute(
        "SELECT COUNT(*) FROM risk_assessments WHERE client_id IS NULL"
    ).fetchone()[0]

    if orphans > 0:
        cur = conn.execute(
            "INSERT INTO clients (name, contact_name, created_at) VALUES (?, ?, ?)",
            ("Legado (migrado)", None, now),
        )
        legacy_id = cur.lastrowid
        conn.execute(
            "UPDATE risk_assessments SET client_id = ? WHERE client_id IS NULL",
            (legacy_id,),
        )
        logger.info(
            "Migración: %d assessment(s) asignados al cliente 'Legado' (id=%d)",
            orphans, legacy_id,
        )

    conn.execute(
        "INSERT INTO schema_version (version, applied_at) VALUES (?, ?)",
        ("2.0.0", now),
    )
