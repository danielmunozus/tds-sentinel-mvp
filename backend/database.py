"""
database.py — TDS Sentinel API
Schema v3.1.0
  clients          — autenticación + datos empresariales completos
  risk_assessments — sin company_name/responsible_name, FK a clients
  support_tickets  — tickets de soporte (ej. reset de contraseña)
  contact_requests — solicitudes de cotización de nuevos clientes
  sessions         — tokens de sesión para autenticación Bearer (NUEVO v3.1)
"""

import hashlib
import re
import secrets
import sqlite3
import logging
from datetime import datetime, timezone
from config import Config

logger = logging.getLogger(__name__)

EMAIL_RE = re.compile(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$')
VALID_STATUSES = {"enabled", "blocked", "disabled"}


# ──────────────────────────────────────────────────────────────────────────────
# Conexión
# ──────────────────────────────────────────────────────────────────────────────

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
# Utilidades de contraseña y email
# ──────────────────────────────────────────────────────────────────────────────

def hash_password(password: str) -> str:
    salt = secrets.token_hex(16)
    digest = hashlib.sha256(f"{salt}{password}".encode()).hexdigest()
    return f"{salt}:{digest}"


def verify_password(password: str, stored: str) -> bool:
    try:
        salt, stored_hash = stored.split(":", 1)
        computed = hashlib.sha256(f"{salt}{password}".encode()).hexdigest()
        return secrets.compare_digest(computed, stored_hash)
    except (ValueError, AttributeError):
        return False


def validate_email(email: str) -> bool:
    return bool(EMAIL_RE.match(email.strip()))


# ──────────────────────────────────────────────────────────────────────────────
# Creación de tablas (versión actual 3.0.0)
# ──────────────────────────────────────────────────────────────────────────────

def _create_tables(conn: sqlite3.Connection) -> None:
    conn.execute("""
        CREATE TABLE IF NOT EXISTS schema_version (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            version    TEXT NOT NULL,
            applied_at TEXT NOT NULL
        )
    """)

    conn.execute("""
        CREATE TABLE IF NOT EXISTS clients (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            company_name  TEXT    NOT NULL,
            contact_name  TEXT    NOT NULL,
            email         TEXT    NOT NULL UNIQUE,
            phone         TEXT    NOT NULL,
            password_hash TEXT    NOT NULL,
            bs_area       TEXT    NOT NULL,
            client_status TEXT    NOT NULL DEFAULT 'enabled',
            created_at    TEXT    NOT NULL,
            updated_at    TEXT,
            CHECK (client_status IN ('enabled', 'blocked', 'disabled'))
        )
    """)

    # client_id es NOT NULL para nuevos registros; nullable solo durante migración.
    conn.execute("""
        CREATE TABLE IF NOT EXISTS risk_assessments (
            id                   INTEGER PRIMARY KEY AUTOINCREMENT,
            client_id            INTEGER NOT NULL REFERENCES clients(id) ON DELETE RESTRICT,
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

    conn.execute("""
        CREATE TABLE IF NOT EXISTS support_tickets (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            email      TEXT    NOT NULL,
            client_id  INTEGER REFERENCES clients(id),
            type       TEXT    NOT NULL DEFAULT 'password_reset',
            status     TEXT    NOT NULL DEFAULT 'open',
            created_at TEXT    NOT NULL,
            updated_at TEXT
        )
    """)

    conn.execute("""
        CREATE TABLE IF NOT EXISTS contact_requests (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            company_name  TEXT    NOT NULL,
            contact_name  TEXT    NOT NULL,
            email         TEXT    NOT NULL,
            phone         TEXT    NOT NULL,
            pack_interest TEXT,
            message       TEXT,
            status        TEXT    NOT NULL DEFAULT 'new',
            created_at    TEXT    NOT NULL
        )
    """)

    # ── v3.1: Sesiones de autenticación ───────────────────────────────────────
    conn.execute("""
        CREATE TABLE IF NOT EXISTS sessions (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            token      TEXT    NOT NULL UNIQUE,
            client_id  INTEGER NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
            created_at TEXT    NOT NULL,
            expires_at TEXT    NOT NULL
        )
    """)

    existing = conn.execute("SELECT COUNT(*) FROM schema_version").fetchone()[0]
    if existing == 0:
        conn.execute(
            "INSERT INTO schema_version (version, applied_at) VALUES (?, ?)",
            ("3.1.0", datetime.now(timezone.utc).isoformat()),
        )


# ──────────────────────────────────────────────────────────────────────────────
# Migraciones
# ──────────────────────────────────────────────────────────────────────────────

def _current_version(conn: sqlite3.Connection) -> str:
    try:
        row = conn.execute(
            "SELECT version FROM schema_version ORDER BY id DESC LIMIT 1"
        ).fetchone()
        return row[0] if row else "0.0.0"
    except sqlite3.OperationalError:
        return "0.0.0"


def _run_migrations(conn: sqlite3.Connection) -> None:
    version = _current_version(conn)
    if version in ("1.0.0", "2.0.0"):
        _migrate_to_v3(conn)
        logger.info("Migración %s → 3.0.0 completada.", version)
        version = "3.0.0"
    if version == "3.0.0":
        _migrate_to_v31(conn)
        logger.info("Migración 3.0.0 → 3.1.0 completada.")


def _migrate_to_v3(conn: sqlite3.Connection) -> None:
    """
    Migra cualquier versión anterior (1.x, 2.x) a v3.
    - Recrea clients con nuevo schema completo.
    - Recrea risk_assessments sin company_name/responsible_name.
    - Crea support_tickets y contact_requests si no existen.
    """
    now = datetime.now(timezone.utc).isoformat()

    # ── Migrar clients ────────────────────────────────────────────────────────
    tables = {r[0] for r in conn.execute(
        "SELECT name FROM sqlite_master WHERE type='table'"
    ).fetchall()}

    if "clients" in tables:
        conn.execute("ALTER TABLE clients RENAME TO clients_legacy")

        conn.execute("""
            CREATE TABLE clients (
                id            INTEGER PRIMARY KEY AUTOINCREMENT,
                company_name  TEXT    NOT NULL,
                contact_name  TEXT    NOT NULL,
                email         TEXT    NOT NULL UNIQUE,
                phone         TEXT    NOT NULL,
                password_hash TEXT    NOT NULL,
                bs_area       TEXT    NOT NULL,
                client_status TEXT    NOT NULL DEFAULT 'enabled',
                created_at    TEXT    NOT NULL,
                updated_at    TEXT,
                CHECK (client_status IN ('enabled', 'blocked', 'disabled'))
            )
        """)

        legacy_cols = {
            r[1] for r in conn.execute("PRAGMA table_info(clients_legacy)").fetchall()
        }

        # Columna de nombre: puede llamarse 'name' (v1/v2) o 'company_name' (v2+)
        name_col = "company_name" if "company_name" in legacy_cols else "name"

        rows = conn.execute(f"SELECT * FROM clients_legacy").fetchall()
        placeholder_hash = hash_password("ChangeMe123!")

        for row in rows:
            d = dict(row)
            conn.execute(
                """INSERT INTO clients
                   (id, company_name, contact_name, email, phone,
                    password_hash, bs_area, client_status, created_at, updated_at)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (
                    d["id"],
                    d.get(name_col) or d.get("name", "Cliente migrado"),
                    d.get("contact_name") or "Sin definir",
                    d.get("email") or f"migrado_{d['id']}@pending.local",
                    d.get("phone") or "0000000000",
                    placeholder_hash,
                    d.get("bs_area") or d.get("industry") or "Sin definir",
                    d.get("client_status", "enabled"),
                    d.get("created_at", now),
                    d.get("updated_at"),
                ),
            )
            logger.info(
                "Cliente migrado — id=%d, contraseña temporal: ChangeMe123!", d["id"]
            )

        conn.execute("DROP TABLE clients_legacy")

        # Recrear support_tickets después de renombrar clients para que la FK
        # apunte a la nueva tabla "clients" y no a la eliminada "clients_legacy".
        # SQLite actualiza automáticamente las FKs al hacer RENAME, por lo que
        # hay que recrear manualmente cualquier tabla que la referenciara.
        conn.execute("DROP TABLE IF EXISTS support_tickets")
        conn.execute("""
            CREATE TABLE support_tickets (
                id         INTEGER PRIMARY KEY AUTOINCREMENT,
                email      TEXT    NOT NULL,
                client_id  INTEGER REFERENCES clients(id),
                type       TEXT    NOT NULL DEFAULT 'password_reset',
                status     TEXT    NOT NULL DEFAULT 'open',
                created_at TEXT    NOT NULL,
                updated_at TEXT
            )
        """)

    # ── Migrar risk_assessments ───────────────────────────────────────────────
    if "risk_assessments" in tables:
        conn.execute("ALTER TABLE risk_assessments RENAME TO risk_assessments_legacy")

        conn.execute("""
            CREATE TABLE risk_assessments (
                id                   INTEGER PRIMARY KEY AUTOINCREMENT,
                client_id            INTEGER NOT NULL REFERENCES clients(id) ON DELETE RESTRICT,
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

        rows = conn.execute("SELECT * FROM risk_assessments_legacy").fetchall()
        for row in rows:
            d = dict(row)
            if d.get("client_id") is None:
                continue  # Sin FK válida, se descarta (datos corruptos)
            conn.execute(
                """INSERT INTO risk_assessments
                   (id, client_id, pack_id, answers_json, score, risk_level,
                    recommendations_json, assessment_hash, created_at, updated_at)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (
                    d["id"], d["client_id"], d["pack_id"],
                    d["answers_json"], d["score"], d["risk_level"],
                    d["recommendations_json"], d["assessment_hash"],
                    d["created_at"], d.get("updated_at"),
                ),
            )

        conn.execute("DROP TABLE risk_assessments_legacy")

    # ── Nuevas tablas ─────────────────────────────────────────────────────────
    conn.execute("""
        CREATE TABLE IF NOT EXISTS support_tickets (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            email      TEXT    NOT NULL,
            client_id  INTEGER REFERENCES clients(id),
            type       TEXT    NOT NULL DEFAULT 'password_reset',
            status     TEXT    NOT NULL DEFAULT 'open',
            created_at TEXT    NOT NULL,
            updated_at TEXT
        )
    """)

    conn.execute("""
        CREATE TABLE IF NOT EXISTS contact_requests (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            company_name  TEXT    NOT NULL,
            contact_name  TEXT    NOT NULL,
            email         TEXT    NOT NULL,
            phone         TEXT    NOT NULL,
            pack_interest TEXT,
            message       TEXT,
            status        TEXT    NOT NULL DEFAULT 'new',
            created_at    TEXT    NOT NULL
        )
    """)

    conn.execute(
        "INSERT INTO schema_version (version, applied_at) VALUES (?, ?)",
        ("3.0.0", now),
    )


# ──────────────────────────────────────────────────────────────────────────────
# Migración 3.0.0 → 3.1.0 (agrega tabla sessions)
# ──────────────────────────────────────────────────────────────────────────────

def _migrate_to_v31(conn: sqlite3.Connection) -> None:
    """Crea la tabla sessions si no existe y registra la versión 3.1.0."""
    now = datetime.now(timezone.utc).isoformat()
    conn.execute("""
        CREATE TABLE IF NOT EXISTS sessions (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            token      TEXT    NOT NULL UNIQUE,
            client_id  INTEGER NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
            created_at TEXT    NOT NULL,
            expires_at TEXT    NOT NULL
        )
    """)
    conn.execute(
        "INSERT INTO schema_version (version, applied_at) VALUES (?, ?)",
        ("3.1.0", now),
    )


# ──────────────────────────────────────────────────────────────────────────────
# Gestión de sesiones (autenticación Bearer)
# ──────────────────────────────────────────────────────────────────────────────

def create_session(client_id: int) -> str:
    """
    Crea una nueva sesión para el cliente y devuelve el token Bearer.
    Expira según Config.SESSION_HOURS (default: 24h).
    """
    from datetime import timedelta
    token = secrets.token_urlsafe(32)
    now = datetime.now(timezone.utc)
    expires = now + timedelta(hours=Config.SESSION_HOURS)
    conn = get_db_connection()
    try:
        conn.execute(
            "INSERT INTO sessions (token, client_id, created_at, expires_at) VALUES (?, ?, ?, ?)",
            (token, client_id, now.isoformat(), expires.isoformat()),
        )
        conn.commit()
    finally:
        conn.close()
    return token


def get_client_by_token(token: str) -> dict | None:
    """
    Verifica el token Bearer y devuelve los datos del cliente si es válido y no expiró.
    Devuelve None si el token no existe, expiró o el cliente está deshabilitado.
    """
    now = datetime.now(timezone.utc).isoformat()
    conn = get_db_connection()
    try:
        row = conn.execute(
            """SELECT c.*
               FROM   clients c
               JOIN   sessions s ON s.client_id = c.id
               WHERE  s.token = ?
                 AND  s.expires_at > ?
                 AND  c.client_status = 'enabled'""",
            (token, now),
        ).fetchone()
    finally:
        conn.close()
    return dict(row) if row else None


def delete_session(token: str) -> None:
    """Elimina la sesión activa (logout)."""
    conn = get_db_connection()
    try:
        conn.execute("DELETE FROM sessions WHERE token = ?", (token,))
        conn.commit()
    finally:
        conn.close()


def delete_client_sessions(client_id: int) -> None:
    """Elimina todas las sesiones de un cliente (útil al bloquear/deshabilitar cuenta)."""
    conn = get_db_connection()
    try:
        conn.execute("DELETE FROM sessions WHERE client_id = ?", (client_id,))
        conn.commit()
    finally:
        conn.close()
