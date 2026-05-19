import os
import sqlite3

# Ruta anclada al directorio del archivo, independiente del CWD del proceso.
_BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATABASE_PATH = os.path.join(_BASE_DIR, os.getenv("DATABASE_NAME", "sentinel.db"))


def get_db_connection():
    conn = sqlite3.connect(DATABASE_PATH, timeout=10)
    conn.row_factory = sqlite3.Row
    # WAL permite lecturas concurrentes sin bloquear escrituras.
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    return conn


def init_db():
    conn = get_db_connection()
    try:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS risk_assessments (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                company_name TEXT NOT NULL,
                asset_name TEXT NOT NULL,
                risk_level TEXT NOT NULL CHECK (
                    risk_level IN ('Low', 'Medium', 'High', 'Critical')
                ),
                recommendation TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        conn.commit()
    finally:
        conn.close()
