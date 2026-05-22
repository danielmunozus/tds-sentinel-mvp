"""
routes/clients.py — TDS Sentinel API
Blueprint CRUD para gestión de clientes.

GET    /clients          → listar todos (orden alfabético)
POST   /clients          → crear cliente
GET    /clients/<id>     → detalle
PUT    /clients/<id>     → actualizar campos
DELETE /clients/<id>     → eliminar (409 si tiene assessments asociados)
"""

from __future__ import annotations
import logging
import re
from datetime import datetime, timezone

from flask import Blueprint, request

from database import get_db_connection

logger = logging.getLogger(__name__)
clients_bp = Blueprint("clients", __name__)

MAX_TEXT = 200


def _success(data, status: int = 200):
    from app import success_response
    return success_response(data, status)


def _error(msg: str, status: int):
    from app import error_response
    return error_response(msg, status)


def _sanitize(value, field: str, required: bool = True) -> tuple[str, str | None]:
    if not isinstance(value, str):
        return "", f"El campo '{field}' debe ser texto."
    cleaned = re.sub(r"[\x00-\x08\x0b-\x1f\x7f]", "", value).strip()
    if required and not cleaned:
        return "", f"El campo '{field}' es requerido."
    if len(cleaned) > MAX_TEXT:
        return "", f"El campo '{field}' no puede superar {MAX_TEXT} caracteres."
    return cleaned, None


def _row_to_dict(row) -> dict:
    return dict(row) if row else {}


# ──────────────────────────────────────────────────────────────────────────────
# GET /clients
# ──────────────────────────────────────────────────────────────────────────────

@clients_bp.route("/clients", methods=["GET"])
def list_clients():
    conn = get_db_connection()
    try:
        rows = conn.execute(
            "SELECT * FROM clients ORDER BY name ASC"
        ).fetchall()
    finally:
        conn.close()
    return _success([_row_to_dict(r) for r in rows])


# ──────────────────────────────────────────────────────────────────────────────
# POST /clients
# ──────────────────────────────────────────────────────────────────────────────

@clients_bp.route("/clients", methods=["POST"])
def create_client():
    """
    Body esperado:
    {
        "name":         "Acme Corp",           (requerido)
        "contact_name": "Jane Doe",            (opcional)
        "email":        "jane@acme.com",       (opcional)
        "industry":     "Manufactura"          (opcional)
    }
    """
    data = request.get_json(silent=True)
    if not data:
        return _error("El cuerpo de la solicitud debe ser JSON válido.", 400)

    name, err = _sanitize(data.get("name", ""), "name")
    if err:
        return _error(err, 400)

    contact_name, err = _sanitize(data.get("contact_name", ""), "contact_name", required=False)
    if err:
        return _error(err, 400)

    email, err = _sanitize(data.get("email", ""), "email", required=False)
    if err:
        return _error(err, 400)

    industry, err = _sanitize(data.get("industry", ""), "industry", required=False)
    if err:
        return _error(err, 400)

    now = datetime.now(timezone.utc).isoformat()
    conn = get_db_connection()
    try:
        cur = conn.execute(
            """INSERT INTO clients (name, contact_name, email, industry, created_at)
               VALUES (?, ?, ?, ?, ?)""",
            (name, contact_name or None, email or None, industry or None, now),
        )
        conn.commit()
        row = conn.execute("SELECT * FROM clients WHERE id = ?", (cur.lastrowid,)).fetchone()
    finally:
        conn.close()

    logger.info("Cliente creado — id=%d name=%s", row["id"], name)
    return _success(_row_to_dict(row), 201)


# ──────────────────────────────────────────────────────────────────────────────
# GET /clients/<id>
# ──────────────────────────────────────────────────────────────────────────────

@clients_bp.route("/clients/<int:client_id>", methods=["GET"])
def get_client(client_id: int):
    conn = get_db_connection()
    try:
        row = conn.execute(
            "SELECT * FROM clients WHERE id = ?", (client_id,)
        ).fetchone()
    finally:
        conn.close()

    if not row:
        return _error(f"Cliente {client_id} no encontrado.", 404)
    return _success(_row_to_dict(row))


# ──────────────────────────────────────────────────────────────────────────────
# PUT /clients/<id>
# ──────────────────────────────────────────────────────────────────────────────

@clients_bp.route("/clients/<int:client_id>", methods=["PUT"])
def update_client(client_id: int):
    data = request.get_json(silent=True)
    if not data:
        return _error("El cuerpo de la solicitud debe ser JSON válido.", 400)

    conn = get_db_connection()
    try:
        existing = conn.execute(
            "SELECT * FROM clients WHERE id = ?", (client_id,)
        ).fetchone()
    finally:
        conn.close()

    if not existing:
        return _error(f"Cliente {client_id} no encontrado.", 404)

    ex = _row_to_dict(existing)

    name, err = _sanitize(data.get("name", ex["name"]), "name")
    if err:
        return _error(err, 400)

    contact_name, err = _sanitize(
        data.get("contact_name", ex.get("contact_name") or ""), "contact_name", required=False
    )
    if err:
        return _error(err, 400)

    email, err = _sanitize(
        data.get("email", ex.get("email") or ""), "email", required=False
    )
    if err:
        return _error(err, 400)

    industry, err = _sanitize(
        data.get("industry", ex.get("industry") or ""), "industry", required=False
    )
    if err:
        return _error(err, 400)

    now = datetime.now(timezone.utc).isoformat()
    conn = get_db_connection()
    try:
        conn.execute(
            """UPDATE clients
               SET name=?, contact_name=?, email=?, industry=?, updated_at=?
               WHERE id=?""",
            (name, contact_name or None, email or None, industry or None, now, client_id),
        )
        conn.commit()
        row = conn.execute("SELECT * FROM clients WHERE id = ?", (client_id,)).fetchone()
    finally:
        conn.close()

    logger.info("Cliente actualizado — id=%d", client_id)
    return _success(_row_to_dict(row))


# ──────────────────────────────────────────────────────────────────────────────
# DELETE /clients/<id>
# ──────────────────────────────────────────────────────────────────────────────

@clients_bp.route("/clients/<int:client_id>", methods=["DELETE"])
def delete_client(client_id: int):
    conn = get_db_connection()
    try:
        existing = conn.execute(
            "SELECT id FROM clients WHERE id = ?", (client_id,)
        ).fetchone()
        if not existing:
            return _error(f"Cliente {client_id} no encontrado.", 404)

        count = conn.execute(
            "SELECT COUNT(*) FROM risk_assessments WHERE client_id = ?", (client_id,)
        ).fetchone()[0]
        if count > 0:
            return _error(
                f"No se puede eliminar: el cliente tiene {count} evaluación(es) asociada(s).",
                409,
            )

        conn.execute("DELETE FROM clients WHERE id = ?", (client_id,))
        conn.commit()
    finally:
        conn.close()

    logger.info("Cliente eliminado — id=%d", client_id)
    return _success({"message": f"Cliente {client_id} eliminado correctamente."})
