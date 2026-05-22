"""
routes/clients.py — TDS Sentinel API
CRUD de clientes con schema v3.

GET    /clients              → listar
POST   /clients              → crear (password_hash, email único, validación formato email)
GET    /clients/<id>         → detalle
PUT    /clients/<id>         → actualizar (no expone password_hash)
DELETE /clients/<id>         → eliminar (409 si tiene assessments)
"""

from __future__ import annotations
import logging
import re
from datetime import datetime, timezone

from flask import Blueprint, request

from database import get_db_connection, hash_password, validate_email, VALID_STATUSES

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


def _public(row: dict) -> dict:
    return {k: v for k, v in row.items() if k != "password_hash"}


# ──────────────────────────────────────────────────────────────────────────────
# GET /clients
# ──────────────────────────────────────────────────────────────────────────────

@clients_bp.route("/clients", methods=["GET"])
def list_clients():
    conn = get_db_connection()
    try:
        rows = conn.execute(
            "SELECT * FROM clients ORDER BY company_name ASC"
        ).fetchall()
    finally:
        conn.close()
    return _success([_public(dict(r)) for r in rows])


# ──────────────────────────────────────────────────────────────────────────────
# POST /clients
# ──────────────────────────────────────────────────────────────────────────────

@clients_bp.route("/clients", methods=["POST"])
def create_client():
    """
    Body:
    {
        "company_name": "Acme Corp",
        "contact_name": "Jane Doe",
        "email":        "jane@acme.com",
        "phone":        "+52 55 1234 5678",
        "password":     "SecurePass123",
        "bs_area":      "Tecnología",
        "client_status": "enabled"          (opcional, default: enabled)
    }
    """
    data = request.get_json(silent=True)
    if not data:
        return _error("El cuerpo debe ser JSON válido.", 400)

    company_name, err = _sanitize(data.get("company_name", ""), "company_name")
    if err: return _error(err, 400)

    contact_name, err = _sanitize(data.get("contact_name", ""), "contact_name")
    if err: return _error(err, 400)

    email, err = _sanitize(data.get("email", ""), "email")
    if err: return _error(err, 400)
    if not validate_email(email):
        return _error("El email no tiene un formato válido.", 400)

    phone, err = _sanitize(data.get("phone", ""), "phone")
    if err: return _error(err, 400)

    password = data.get("password", "")
    if not isinstance(password, str) or len(password.strip()) < 8:
        return _error("La contraseña debe tener al menos 8 caracteres.", 400)

    bs_area, err = _sanitize(data.get("bs_area", ""), "bs_area")
    if err: return _error(err, 400)

    client_status = data.get("client_status", "enabled")
    if client_status not in VALID_STATUSES:
        return _error(f"Estado inválido. Valores aceptados: {sorted(VALID_STATUSES)}", 400)

    now = datetime.now(timezone.utc).isoformat()
    conn = get_db_connection()
    try:
        # Verificar email único
        existing = conn.execute(
            "SELECT id FROM clients WHERE LOWER(email) = LOWER(?)", (email,)
        ).fetchone()
        if existing:
            return _error("Ya existe un cliente con ese email.", 409)

        cur = conn.execute(
            """INSERT INTO clients
               (company_name, contact_name, email, phone, password_hash,
                bs_area, client_status, created_at)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
            (company_name, contact_name, email, phone,
             hash_password(password), bs_area, client_status, now),
        )
        conn.commit()
        row = conn.execute("SELECT * FROM clients WHERE id = ?", (cur.lastrowid,)).fetchone()
    finally:
        conn.close()

    logger.info("Cliente creado — id=%d email=%s", row["id"], email)
    return _success(_public(dict(row)), 201)


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
    return _success(_public(dict(row)))


# ──────────────────────────────────────────────────────────────────────────────
# PUT /clients/<id>
# ──────────────────────────────────────────────────────────────────────────────

@clients_bp.route("/clients/<int:client_id>", methods=["PUT"])
def update_client(client_id: int):
    """Actualiza campos editables. Para cambiar contraseña incluir 'password' en el body."""
    data = request.get_json(silent=True)
    if not data:
        return _error("El cuerpo debe ser JSON válido.", 400)

    conn = get_db_connection()
    try:
        existing = conn.execute(
            "SELECT * FROM clients WHERE id = ?", (client_id,)
        ).fetchone()
    finally:
        conn.close()
    if not existing:
        return _error(f"Cliente {client_id} no encontrado.", 404)

    ex = dict(existing)

    company_name, err = _sanitize(data.get("company_name", ex["company_name"]), "company_name")
    if err: return _error(err, 400)

    contact_name, err = _sanitize(data.get("contact_name", ex["contact_name"]), "contact_name")
    if err: return _error(err, 400)

    email = data.get("email", ex["email"])
    email, err = _sanitize(email, "email")
    if err: return _error(err, 400)
    if not validate_email(email):
        return _error("El email no tiene un formato válido.", 400)

    phone, err = _sanitize(data.get("phone", ex["phone"]), "phone")
    if err: return _error(err, 400)

    bs_area, err = _sanitize(data.get("bs_area", ex["bs_area"]), "bs_area")
    if err: return _error(err, 400)

    client_status = data.get("client_status", ex["client_status"])
    if client_status not in VALID_STATUSES:
        return _error(f"Estado inválido. Valores aceptados: {sorted(VALID_STATUSES)}", 400)

    # Contraseña opcional en update
    new_password = data.get("password")
    if new_password is not None:
        if not isinstance(new_password, str) or len(new_password.strip()) < 8:
            return _error("La contraseña debe tener al menos 8 caracteres.", 400)
        new_hash = hash_password(new_password)
    else:
        new_hash = ex["password_hash"]

    now = datetime.now(timezone.utc).isoformat()
    conn = get_db_connection()
    try:
        # Verificar unicidad de email si cambió
        if email.lower() != ex["email"].lower():
            dup = conn.execute(
                "SELECT id FROM clients WHERE LOWER(email) = LOWER(?) AND id != ?",
                (email, client_id)
            ).fetchone()
            if dup:
                return _error("Ya existe un cliente con ese email.", 409)

        conn.execute(
            """UPDATE clients SET company_name=?, contact_name=?, email=?, phone=?,
               password_hash=?, bs_area=?, client_status=?, updated_at=?
               WHERE id=?""",
            (company_name, contact_name, email, phone,
             new_hash, bs_area, client_status, now, client_id),
        )
        conn.commit()
        row = conn.execute("SELECT * FROM clients WHERE id = ?", (client_id,)).fetchone()
    finally:
        conn.close()

    logger.info("Cliente actualizado — id=%d", client_id)
    return _success(_public(dict(row)))


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
                f"No se puede eliminar: el cliente tiene {count} evaluación(es) asociada(s).", 409
            )

        conn.execute("DELETE FROM clients WHERE id = ?", (client_id,))
        conn.commit()
    finally:
        conn.close()

    logger.info("Cliente eliminado — id=%d", client_id)
    return _success({"message": f"Cliente {client_id} eliminado correctamente."})
