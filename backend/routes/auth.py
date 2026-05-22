"""
routes/auth.py — TDS Sentinel API
Autenticación de clientes.

POST /auth/login           → login con email + contraseña
POST /auth/forgot-password → crea ticket de soporte para reset de contraseña
POST /auth/contact         → solicitud de cotización (nuevo cliente potencial)
"""

from __future__ import annotations
import logging
import re
from datetime import datetime, timezone

from flask import Blueprint, request

from database import get_db_connection, verify_password, validate_email, hash_password

logger = logging.getLogger(__name__)
auth_bp = Blueprint("auth", __name__)

MAX_TEXT = 500


def _success(data, status: int = 200):
    from app import success_response
    return success_response(data, status)


def _error(msg: str, status: int):
    from app import error_response
    return error_response(msg, status)


def _clean(value, field: str, required: bool = True) -> tuple[str, str | None]:
    if not isinstance(value, str):
        return "", f"El campo '{field}' debe ser texto."
    cleaned = re.sub(r"[\x00-\x08\x0b-\x1f\x7f]", "", value).strip()
    if required and not cleaned:
        return "", f"El campo '{field}' es requerido."
    if len(cleaned) > MAX_TEXT:
        return "", f"El campo '{field}' supera el límite de {MAX_TEXT} caracteres."
    return cleaned, None


def _client_public(row: dict) -> dict:
    """Retorna datos del cliente sin el password_hash."""
    return {k: v for k, v in row.items() if k != "password_hash"}


# ──────────────────────────────────────────────────────────────────────────────
# POST /auth/login
# ──────────────────────────────────────────────────────────────────────────────

@auth_bp.route("/auth/login", methods=["POST"])
def login():
    """
    Body: { "email": "...", "password": "..." }
    Respuesta exitosa: datos del cliente (sin password_hash).
    """
    data = request.get_json(silent=True)
    if not data:
        return _error("El cuerpo debe ser JSON válido.", 400)

    email, err = _clean(data.get("email", ""), "email")
    if err:
        return _error(err, 400)
    if not validate_email(email):
        return _error("Formato de email inválido.", 400)

    password, err = _clean(data.get("password", ""), "password")
    if err:
        return _error(err, 400)

    conn = get_db_connection()
    try:
        row = conn.execute(
            "SELECT * FROM clients WHERE LOWER(email) = LOWER(?)", (email,)
        ).fetchone()
    finally:
        conn.close()

    if not row:
        return _error("Email o contraseña incorrectos.", 401)

    client = dict(row)

    if client["client_status"] == "blocked":
        return _error("La cuenta está bloqueada. Contacte a soporte.", 403)
    if client["client_status"] == "disabled":
        return _error("La cuenta está deshabilitada.", 403)

    if not verify_password(password, client["password_hash"]):
        return _error("Email o contraseña incorrectos.", 401)

    logger.info("Login exitoso — client_id=%d email=%s", client["id"], email)
    return _success(_client_public(client))


# ──────────────────────────────────────────────────────────────────────────────
# POST /auth/forgot-password
# ──────────────────────────────────────────────────────────────────────────────

@auth_bp.route("/auth/forgot-password", methods=["POST"])
def forgot_password():
    """
    Body: { "email": "..." }
    Crea un ticket de soporte tipo 'password_reset'.
    Responde con éxito siempre (no revela si el email existe).
    """
    data = request.get_json(silent=True)
    if not data:
        return _error("El cuerpo debe ser JSON válido.", 400)

    email, err = _clean(data.get("email", ""), "email")
    if err:
        return _error(err, 400)
    if not validate_email(email):
        return _error("Formato de email inválido.", 400)

    now = datetime.now(timezone.utc).isoformat()
    conn = get_db_connection()
    try:
        client_row = conn.execute(
            "SELECT id FROM clients WHERE LOWER(email) = LOWER(?)", (email,)
        ).fetchone()
        client_id = client_row["id"] if client_row else None

        cur = conn.execute(
            """INSERT INTO support_tickets (email, client_id, type, status, created_at)
               VALUES (?, ?, 'password_reset', 'open', ?)""",
            (email, client_id, now),
        )
        conn.commit()
        ticket_id = cur.lastrowid
    finally:
        conn.close()

    logger.info("Ticket de reset creado — ticket_id=%d email=%s", ticket_id, email)
    return _success({
        "message": "Se ha generado un ticket de soporte. "
                   "Un agente de TDS Innovate se pondrá en contacto a la brevedad.",
        "ticket_id": ticket_id,
    })


# ──────────────────────────────────────────────────────────────────────────────
# POST /auth/contact  — solicitud de cotización
# ──────────────────────────────────────────────────────────────────────────────

@auth_bp.route("/auth/contact", methods=["POST"])
def contact_request():
    """
    Body:
    {
        "company_name":  "Acme Corp",
        "contact_name":  "Jane Doe",
        "email":         "jane@acme.com",
        "phone":         "+52 55 1234 5678",
        "pack_interest": "infrastructure_basic",   (opcional)
        "message":       "..."                      (opcional)
    }
    """
    data = request.get_json(silent=True)
    if not data:
        return _error("El cuerpo debe ser JSON válido.", 400)

    company_name, err = _clean(data.get("company_name", ""), "company_name")
    if err: return _error(err, 400)

    contact_name, err = _clean(data.get("contact_name", ""), "contact_name")
    if err: return _error(err, 400)

    email, err = _clean(data.get("email", ""), "email")
    if err: return _error(err, 400)
    if not validate_email(email):
        return _error("Formato de email inválido.", 400)

    phone, err = _clean(data.get("phone", ""), "phone")
    if err: return _error(err, 400)

    pack_interest, _ = _clean(data.get("pack_interest", ""), "pack_interest", required=False)
    message, _      = _clean(data.get("message", ""), "message", required=False)

    now = datetime.now(timezone.utc).isoformat()
    conn = get_db_connection()
    try:
        cur = conn.execute(
            """INSERT INTO contact_requests
               (company_name, contact_name, email, phone, pack_interest, message, created_at)
               VALUES (?, ?, ?, ?, ?, ?, ?)""",
            (company_name, contact_name, email, phone,
             pack_interest or None, message or None, now),
        )
        conn.commit()
        req_id = cur.lastrowid
    finally:
        conn.close()

    logger.info("Solicitud de contacto — id=%d empresa=%s", req_id, company_name)
    return _success({
        "message": "Su solicitud ha sido recibida. "
                   "El equipo comercial de TDS Innovate se pondrá en contacto pronto.",
        "request_id": req_id,
    }, 201)
