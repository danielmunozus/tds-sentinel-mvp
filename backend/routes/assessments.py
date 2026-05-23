"""
routes/assessments.py — TDS Sentinel API
CRUD de evaluaciones de riesgo (schema v3.1).

POST   /assessments                  → crear (client_id debe ser el propio — VULN-02)
GET    /assessments                  → listar las del cliente autenticado
GET    /assessments/<id>             → detalle (solo propias)
DELETE /assessments/<id>             → eliminar (solo propias)
GET    /clients/<id>/assessments     → historial (solo propio client_id)
"""

from __future__ import annotations
import hashlib
import json
import logging
import re
from datetime import datetime, timezone

from flask import Blueprint, g, request

from auth_utils import login_required
from database import get_db_connection
from risk_engine import (
    calculate_risk_score,
    generate_recommendations,
    get_pack_by_id,
    VALID_ANSWERS,
)

logger = logging.getLogger(__name__)
assessments_bp = Blueprint("assessments", __name__)
MAX_TEXT = 200

_SELECT_WITH_CLIENT = """
    SELECT ra.*,
           c.company_name,
           c.contact_name,
           c.email       AS client_email
    FROM   risk_assessments ra
    JOIN   clients c ON c.id = ra.client_id
"""


def _success(data, status: int = 200):
    from app import success_response
    return success_response(data, status)


def _error(msg: str, status: int):
    from app import error_response
    return error_response(msg, status)


def _sanitize(value: str, field: str, required: bool = True) -> tuple[str, str | None]:
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


def _row_to_dict(row) -> dict:
    if row is None:
        return {}
    d = dict(row)
    for field in ("answers_json", "recommendations_json"):
        if field in d and isinstance(d[field], str):
            try:
                d[field] = json.loads(d[field])
            except (json.JSONDecodeError, TypeError):
                pass
    return d


def _validate_answers(pack_id: str, answers) -> str | None:
    if not isinstance(answers, dict) or not answers:
        return "El campo 'answers' debe ser un objeto JSON con al menos una respuesta."
    pack = get_pack_by_id(pack_id)
    if not pack:
        return f"Pack '{pack_id}' no existe en el catálogo."
    valid_ids = {c["id"] for c in pack["controls"]}
    for cid, answer in answers.items():
        if not isinstance(cid, str) or not cid.strip():
            return "Los IDs de controles deben ser texto no vacío."
        if cid not in valid_ids:
            return f"Control '{cid}' no pertenece al pack '{pack_id}'."
        if str(answer).strip().lower() not in VALID_ANSWERS:
            return (f"Respuesta inválida '{answer}' para '{cid}'. "
                    f"Aceptados: {sorted(VALID_ANSWERS)}")
    return None


def _generate_hash(client_id: int, pack_id: str, answers: dict, created_at: str) -> str:
    content = json.dumps(
        {"client_id": client_id, "pack_id": pack_id,
         "answers": answers, "created_at": created_at},
        sort_keys=True, ensure_ascii=False,
    )
    return hashlib.sha256(content.encode()).hexdigest()


# ──────────────────────────────────────────────────────────────────────────────
# POST /assessments
# ──────────────────────────────────────────────────────────────────────────────

@assessments_bp.route("/assessments", methods=["POST"])
@login_required
def create_assessment():
    """
    Body: { "client_id": 1, "pack_id": "infrastructure_basic", "answers": {...} }
    VULN-02: client_id debe coincidir con el cliente autenticado.
    """
    data = request.get_json(silent=True)
    if not data:
        return _error("El cuerpo debe ser JSON válido.", 400)

    client_id = data.get("client_id")
    if not isinstance(client_id, int) or client_id <= 0:
        return _error("'client_id' es requerido y debe ser un entero positivo.", 400)

    # Solo puede crear evaluaciones para su propio client_id
    if client_id != g.current_client["id"]:
        return _error("No autorizado para crear evaluaciones para otro cliente.", 403)

    conn = get_db_connection()
    try:
        client_row = conn.execute(
            "SELECT id, client_status FROM clients WHERE id = ?", (client_id,)
        ).fetchone()
    finally:
        conn.close()

    if not client_row:
        return _error(f"Cliente {client_id} no encontrado.", 404)
    if client_row["client_status"] != "enabled":
        return _error("La cuenta del cliente no está activa.", 403)

    pack_id, err = _sanitize(data.get("pack_id", ""), "pack_id")
    if err: return _error(err, 400)
    if not get_pack_by_id(pack_id):
        return _error(f"Pack '{pack_id}' no existe en el catálogo.", 400)

    answers = data.get("answers")
    answers_error = _validate_answers(pack_id, answers)
    if answers_error:
        return _error(answers_error, 400)

    answers_norm = {k: v.strip().lower() for k, v in answers.items()}

    try:
        score_result = calculate_risk_score(pack_id, answers_norm)
        recommendations = generate_recommendations(pack_id, answers_norm)
    except ValueError as e:
        return _error(str(e), 400)

    created_at = datetime.now(timezone.utc).isoformat()
    assessment_hash = _generate_hash(client_id, pack_id, answers_norm, created_at)

    conn = get_db_connection()
    try:
        cur = conn.execute(
            """INSERT INTO risk_assessments
               (client_id, pack_id, answers_json, score, risk_level,
                recommendations_json, assessment_hash, created_at, updated_at)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL)""",
            (client_id, pack_id,
             json.dumps(answers_norm, ensure_ascii=False),
             score_result["score_display"],
             score_result["risk_level"],
             json.dumps(recommendations, ensure_ascii=False),
             assessment_hash, created_at),
        )
        conn.commit()
        new_id = cur.lastrowid
        row = conn.execute(
            f"{_SELECT_WITH_CLIENT} WHERE ra.id = ?", (new_id,)
        ).fetchone()
    finally:
        conn.close()

    logger.info("Assessment creado — id=%d client_id=%d level=%s",
                new_id, client_id, score_result["risk_level"])
    return _success(_row_to_dict(row), 201)


# ──────────────────────────────────────────────────────────────────────────────
# GET /assessments
# ──────────────────────────────────────────────────────────────────────────────

@assessments_bp.route("/assessments", methods=["GET"])
@login_required
def list_assessments():
    """Solo devuelve las evaluaciones del cliente autenticado."""
    client_id = g.current_client["id"]
    conn = get_db_connection()
    try:
        rows = conn.execute(
            f"{_SELECT_WITH_CLIENT} WHERE ra.client_id = ? ORDER BY ra.created_at DESC",
            (client_id,),
        ).fetchall()
    finally:
        conn.close()
    return _success([_row_to_dict(r) for r in rows])


# ──────────────────────────────────────────────────────────────────────────────
# GET /assessments/<id>
# ──────────────────────────────────────────────────────────────────────────────

@assessments_bp.route("/assessments/<int:assessment_id>", methods=["GET"])
@login_required
def get_assessment(assessment_id: int):
    """Solo permite ver evaluaciones propias."""
    client_id = g.current_client["id"]
    conn = get_db_connection()
    try:
        row = conn.execute(
            f"{_SELECT_WITH_CLIENT} WHERE ra.id = ? AND ra.client_id = ?",
            (assessment_id, client_id),
        ).fetchone()
    finally:
        conn.close()
    if not row:
        return _error(f"Evaluación {assessment_id} no encontrada.", 404)
    return _success(_row_to_dict(row))


# ──────────────────────────────────────────────────────────────────────────────
# DELETE /assessments/<id>
# ──────────────────────────────────────────────────────────────────────────────

@assessments_bp.route("/assessments/<int:assessment_id>", methods=["DELETE"])
@login_required
def delete_assessment(assessment_id: int):
    """Solo permite eliminar evaluaciones propias."""
    client_id = g.current_client["id"]
    conn = get_db_connection()
    try:
        existing = conn.execute(
            "SELECT id FROM risk_assessments WHERE id = ? AND client_id = ?",
            (assessment_id, client_id),
        ).fetchone()
        if not existing:
            return _error(f"Evaluación {assessment_id} no encontrada.", 404)
        conn.execute("DELETE FROM risk_assessments WHERE id = ?", (assessment_id,))
        conn.commit()
    finally:
        conn.close()
    logger.info("Assessment eliminado — id=%d client_id=%d", assessment_id, client_id)
    return _success({"message": f"Evaluación {assessment_id} eliminada correctamente."})


# ──────────────────────────────────────────────────────────────────────────────
# GET /clients/<id>/assessments — historial del cliente
# ──────────────────────────────────────────────────────────────────────────────

@assessments_bp.route("/clients/<int:client_id>/assessments", methods=["GET"])
@login_required
def client_assessments(client_id: int):
    """Solo permite ver el historial del propio cliente."""
    if g.current_client["id"] != client_id:
        return _error("No autorizado para ver evaluaciones de otro cliente.", 403)

    conn = get_db_connection()
    try:
        client = conn.execute(
            "SELECT id FROM clients WHERE id = ?", (client_id,)
        ).fetchone()
        if not client:
            return _error(f"Cliente {client_id} no encontrado.", 404)

        rows = conn.execute(
            f"{_SELECT_WITH_CLIENT} WHERE ra.client_id = ? ORDER BY ra.created_at DESC",
            (client_id,),
        ).fetchall()
    finally:
        conn.close()
    return _success([_row_to_dict(r) for r in rows])
