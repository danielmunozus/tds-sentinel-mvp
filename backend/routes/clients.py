"""
routes/clients.py — TDS Sentinel API
CRUD de clientes con schema v3.1.

GET    /clients              → perfil propio (requiere auth)
POST   /clients              → crear (requiere auth)
GET    /clients/<id>         → detalle (solo propio — FIX-IDOR)
PUT    /clients/<id>         → actualizar (solo propio perfil — FIX-IDOR)
DELETE /clients/<id>         → eliminar (solo propio perfil — FIX-IDOR)

Fixes v3.2:
  FIX-TOCTOU    : IntegrityError en INSERT → 409 en vez de 500
  FIX-IDOR      : GET /clients y GET /clients/<id> ahora solo devuelven el perfil propio
  FIX-SELFLOCKOUT: PUT no permite cambiar client_status (operación de admin)
"""

from __future__ import annotations
import logging
import re
import sqlite3
from datetime import datetime, timezone

from flask import Blueprint, g, request

from auth_utils import login_required
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
    # Elimina caracteres de control
    cleaned = re.sub(r"[\x00-\x08\x0b-\x1f\x7f]", "", value).strip()
    # VULN-03: eliminar tags HTML para prevenir XSS stored
    cleaned = re.sub(r"<[^>]*>", "", cleaned)
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
@login_required
def list_clients():
    """
    FIX-IDOR: En el MVP no existe rol admin — devolver todos los clientes
    expone datos de terceros a cualquier usuario autenticado.
    Ahora devuelve exclusivamente el perfil del cliente autenticado.
    """
    conn = get_db_connection()
    try:
        row = conn.execute(
            "SELECT * FROM clients WHERE id = ?", (g.current_client["id"],)
        ).fetchone()
    finally:
        conn.close()
    if not row:
        return _success([])
    return _success([_public(dict(row))])


# ──────────────────────────────────────────────────────────────────────────────
# POST /clients
# ──────────────────────────────────────────────────────────────────────────────

@clients_bp.route("/clients", methods=["POST"])
@login_required
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
        existing = conn.execute(
            "SELECT id FROM clients WHERE LOWER(email) = LOWER(?)", (email,)
        ).fetchone()
        if existing:
            return _error("Ya existe un cliente con ese email.", 409)

        try:
            cur = conn.execute(
                """INSERT INTO clients
                   (company_name, contact_name, email, phone, password_hash,
                    bs_area, client_status, created_at)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
                (company_name, contact_name, email, phone,
                 hash_password(password), bs_area, client_status, now),
            )
            conn.commit()
        except sqlite3.IntegrityError:
            # FIX-TOCTOU: la SELECT previa pudo pasar pero el INSERT falló por
            # UNIQUE constraint (race condition entre dos requests concurrentes).
            return _error("Ya existe un cliente con ese email.", 409)
        row = conn.execute("SELECT * FROM clients WHERE id = ?", (cur.lastrowid,)).fetchone()
    finally:
        conn.close()

    logger.info("Cliente creado — id=%d", row["id"])
    return _success(_public(dict(row)), 201)


# ──────────────────────────────────────────────────────────────────────────────
# GET /clients/<id>
# ──────────────────────────────────────────────────────────────────────────────

@clients_bp.route("/clients/<int:client_id>", methods=["GET"])
@login_required
def get_client(client_id: int):
    """
    FIX-IDOR: sin este check cualquier usuario autenticado podía leer el
    perfil (email, teléfono, empresa) de cualquier otro cliente.
    """
    if g.current_client["id"] != client_id:
        return _error("No autorizado para ver este perfil.", 403)

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
@login_required
def update_client(client_id: int):
    """
    VULN-02: solo el cliente autenticado puede modificar su propio perfil.
    """
    # Verificar que solo modifica su propio perfil
    if g.current_client["id"] != client_id:
        return _error("No autorizado para modificar este perfil.", 403)

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

    # FIX-SELFLOCKOUT: client_status es una operación de administrador.
    # Un cliente autenticado NO puede modificar su propio estado — haría
    # un self-lockout permanente (blocked/disabled) sin posibilidad de recuperación
    # a través de la API (no hay endpoint de recuperación en el MVP).
    client_status = ex["client_status"]                     # forzamos el valor actual
    if "client_status" in data and data["client_status"] != ex["client_status"]:
        return _error("No puede modificar el estado de su propia cuenta.", 403)

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
@login_required
def delete_client(client_id: int):
    """
    VULN-02: solo el cliente autenticado puede eliminar su propio perfil.
    """
    if g.current_client["id"] != client_id:
        return _error("No autorizado para eliminar este perfil.", 403)

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
