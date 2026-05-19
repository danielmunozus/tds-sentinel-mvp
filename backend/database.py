import os
import sqlite3

# Ruta configurable de la base de datos.
# En desarrollo usa sentinel.db; en producción podría venir desde variable de entorno.
DATABASE_NAME = os.getenv("DATABASE_NAME", "sentinel.db")


def get_db_connection():
    """
    Retorna una conexión segura a SQLite.
    row_factory permite acceder a las columnas por nombre.
    """
    conn = sqlite3.connect(DATABASE_NAME)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    """
    Crea la tabla principal si no existe.
    La estructura evita campos nulos en datos críticos.
    """
    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute("""
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
    conn.close()