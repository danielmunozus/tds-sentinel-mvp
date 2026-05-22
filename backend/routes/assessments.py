"""
routes/assessments.py — TDS Sentinel API
Blueprint CRUD para evaluaciones de riesgo.

POST   /assessments         → crear evaluación (calcula score + recomendaciones)
GET    /assessments         → listar todas
GET    /assessments/<id>    → detalle
PUT    /assessments/<id>    → actualizar campos editables
DELETE /assessments/<id>    → eliminar
"""

from __future__ import annotations
import hashlib
import json
import logging
import re
from datetime import datetime, timezone

from flask import Blueprint, request

from database import get_db_connection
from risk_engine import (
    calculate_risk_score,
    generate_recommendations,
    get_pack_by_id,
    VALID_ANSWERS,
)

logger = logging.getLogger(__name__)
assessments_bp = Blueprint("assessments", __name__)

# Longitud máxima para campos de texto libre (evita payloads abusivos)
MAX_TEXT_LENGTH = 200


# ──────────────────────────────────────────────────────────────────────────────
# Helpers locales
# ──────────────────────────────────────────────────────────────────────────────

def _success(data, status: int = 200):
    from app import success_response
    return success_response(data, status)


def _error(msg: str, status: int):
    from app import error_response
    return error_response(msg, status)


def _sanitize_text(value: str, field_name: str, required: bool = True) -> tuple[str, str | None]:
    """
    Limpia y valida un campo de texto.
    Retorna (valor_limpio, mensaje_error_o_None).
    - Strip de espacios
    - Elimina caracteres de control
    - Valida longitud máxima
    - Valida que no esté vacío si es requerido
    """
    if not isinstance(value, str):
        return "", f"El campo '{field_name}' debe ser texto."

    # Eliminar caracteres de control (tab, newline, etc.) excepto espacios normales
    cleaned = re.sub(r"[\x00-\x08\x0b-\x1f\x7f]", "", value).strip()

    if required and not cleaned:
        return "", f"El campo '{field_name}' es requerido."

    if len(cleaned) > MAX_TEXT_LENGTH:
        return "", f"El campo '{field_name}' no puede superar {MAX_TEXT_LENGTH} caracteres."

    return cleaned, None


def _generate_assessment_hash(company_name: str, pack_id: str,
                               answers: dict, created_at: str) -> str:
    """
    Genera SHA-256 del contenido de la evaluación.
    Propósito: integridad y referencia — no es hash de contraseña.
    El hash cambia si cambia cualquier campo relevante del assessment.
    """
    content = json.dumps({
        "company_name": company_name,
        "pack_id":      pack_id,
        "answers":      answers,
        "created_at":   created_at,
    }, sort_keys=True, ensure_ascii=False)
    return hashlib.sha256(content.encode("utf-8")).hexdigest()


def _row_to_dict(row) -> dict:
    """Convierte sqlite3.Row a dict. Deserializa campos JSON."""
    if row is None:
        return {}
    d = dict(row)
    # Deserializar campos JSON almacenados como texto
    for field in ("answers_json", "recommendations_json"):
        if field in d and isinstance(d[field], str):
            try:
                d[field] = json.loads(d[field])
            except (json.JSONDecodeError, TypeError):
                pass
    return d


def _validate_answers(pack_id: str, answers: dict) -> str | None:
    """
    Valida el dict de respuestas contra el pack.
    Retorna mensaje de error o None si todo es válido.
    """
    if not isinstance(answers, dict) or not answers:
        return "El campo 'answers' debe ser un objeto JSON con al menos una respuesta."

    pack = get_pack_by_id(pack_id)
    if not pack:
        return f"Pack '{pack_id}' no existe en el catálogo."

    valid_ids = {c["id"] for c in pack["controls"]}

    for control_id, answer in answers.items():
        if not isinstance(control_id, str) or not control_id.strip():
            return "Los IDs de controles deben ser texto no vacío."
        if control_id not in valid_ids:
            return f"Control '{control_id}' no pertenece al pack '{pack_id}'."
        answer_norm = str(answer).strip().lower()
        if answer_norm not in VALID_ANSWERS:
            return (
                f"Respuesta inválida '{answer}' para control '{control_id}'. "
                f"Valores aceptados: {sorted(VALID_ANSWERS)}"
            )

    return None


# ──────────────────────────────────────────────────────────────────────────────
# POST /assessments — Crear evaluación
# ──────────────────────────────────────────────────────────────────────────────

@assessments_bp.route("/assessments", methods=["POST"])
def create_assessment():
    """
    Recibe respuestas del cliente, calcula score y persiste la evaluación.

    Body esperado:
    {
        "company_name":     "Demo Company",
        "responsible_name": "IT Manager",
        "pack_id":          "infrastructure_basic",
        "answers": {
            "mfa":      "no",
            "backups":  "partial",
            "antivirus":"yes",
            "firewall": "yes",
            "training": "no"
        }
    }
    """
    data = request.get_json(silent=True)
    if not data:
        return _error("El cuerpo de la solicitud debe ser JSON válido.", 400)

    # Validar y sanitizar campos de texto
    company_name, err = _sanitize_text(data.get("company_name", ""), "company_name")
    if err:
        return _error(err, 400)

    responsible_name, err = _sanitize_text(data.get("responsible_name", ""), "responsible_name")
    if err:
        return _error(err, 400)

    pack_id, err = _sanitize_text(data.get("pack_id", ""), "pack_id")
    if err:
        return _error(err, 400)

    # Validar que el pack existe
    if not get_pack_by_id(pack_id):
        return _error(f"Pack '{pack_id}' no existe en el catálogo.", 400)

    # Validar respuestas
    answers = data.get("answers")
    answers_error = _validate_answers(pack_id, answers)
    if answers_error:
        return _error(answers_error, 400)

    # Normalizar respuestas a minúsculas
    answers_normalized = {k: v.strip().lower() for k, v in answers.items()}

    # Calcular score y recomendaciones via risk engine
    try:
        score_result = calculate_risk_score(pack_id, answers_normalized)
        recommendations = generate_recommendations(pack_id, answers_normalized)
    except ValueError as e:
        logger.warning("Error en risk engine: %s", e)
        return _error(str(e), 400)

    # Generar timestamp y hash de integridad
    created_at = datetime.now(timezone.utc).isoformat()
    assessment_hash = _generate_assessment_hash(
        company_name, pack_id, answers_normalized, created_at
    )

    # Persistir en SQLite
    conn = get_db_connection()
    try:
        cursor = conn.execute(
            """
            INSERT INTO risk_assessments
                (company_name, responsible_name, pack_id, answers_json,
                 score, risk_level, recommendations_json,
                 assessment_hash, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
            """,
            (
                company_name,
                responsible_name,
                pack_id,
                json.dumps(answers_normalized, ensure_ascii=False),
                score_result["score_display"],
                score_result["risk_level"],
                json.dumps(recommendations, ensure_ascii=False),
                assessment_hash,
                created_at,
            ),
        )
        conn.commit()
        new_id = cursor.lastrowid
        row = conn.execute(
            "SELECT * FROM risk_assessments WHERE id = ?", (new_id,)
        ).fetchone()
    finally:
        conn.close()

    logger.info(
        "Assessment creado — id=%d company=%s level=%s score=%d",
        new_id, company_name, score_result["risk_level"], score_result["score_display"]
    )

    return _success(_row_to_dict(row), 201)


# ──────────────────────────────────────────────────────────────────────────────
# GET /assessments — Listar todas las evaluaciones
# ──────────────────────────────────────────────────────────────────────────────

@assessments_bp.route("/assessments", methods=["GET"])
def list_assessments():
    """Retorna todas las evaluaciones ordenadas por fecha descendente."""
    conn = get_db_connection()
    try:
        rows = conn.execute(
            "SELECT * FROM risk_assessments ORDER BY created_at DESC"
        ).fetchall()
    finally:
        conn.close()

    return _success([_row_to_dict(r) for r in rows])


# ──────────────────────────────────────────────────────────────────────────────
# GET /assessments/<id> — Detalle de una evaluación
# ──────────────────────────────────────────────────────────────────────────────

@assessments_bp.route("/assessments/<int:assessment_id>", methods=["GET"])
def get_assessment(assessment_id: int):
    """Retorna el detalle completo de una evaluación por ID."""
    conn = get_db_connection()
    try:
        row = conn.execute(
            "SELECT * FROM risk_assessments WHERE id = ?", (assessment_id,)
        ).fetchone()
    finally:
        conn.close()

    if not row:
        return _error(f"Evaluación {assessment_id} no encontrada.", 404)

    return _success(_row_to_dict(row))


# ──────────────────────────────────────────────────────────────────────────────
# PUT /assessments/<id> — Actualizar evaluación
# ──────────────────────────────────────────────────────────────────────────────

@assessments_bp.route("/assessments/<int:assessment_id>", methods=["PUT"])
def update_assessment(assessment_id: int):
    """
    Actualiza campos editables de una evaluación existente.
    Solo permite modificar: company_name, responsible_name.
    El score, risk_level y recommendations NO se recalculan en el update
    para preservar la integridad del registro histórico.
    Si se necesita recalcular, debe crearse una nueva evaluación.
    """
    data = request.get_json(silent=True)
    if not data:
        return _error("El cuerpo de la solicitud debe ser JSON válido.", 400)

    conn = get_db_connection()
    try:
        existing = conn.execute(
            "SELECT * FROM risk_assessments WHERE id = ?", (assessment_id,)
        ).fetchone()
    finally:
        conn.close()

    if not existing:
        return _error(f"Evaluación {assessment_id} no encontrada.", 404)

    existing_dict = _row_to_dict(existing)

    # Solo actualizar campos permitidos; los no enviados se conservan
    company_name = data.get("company_name", existing_dict["company_name"])
    responsible_name = data.get("responsible_name", existing_dict["responsible_name"])

    company_name, err = _sanitize_text(company_name, "company_name")
    if err:
        return _error(err, 400)

    responsible_name, err = _sanitize_text(responsible_name, "responsible_name")
    if err:
        return _error(err, 400)

    updated_at = datetime.now(timezone.utc).isoformat()

    conn = get_db_connection()
    try:
        conn.execute(
            """
            UPDATE risk_assessments
            SET company_name = ?, responsible_name = ?, updated_at = ?
            WHERE id = ?
            """,
            (company_name, responsible_name, updated_at, assessment_id),
        )
        conn.commit()
        updated_row = conn.execute(
            "SELECT * FROM risk_assessments WHERE id = ?", (assessment_id,)
        ).fetchone()
    finally:
        conn.close()

    logger.info("Assessment actualizado — id=%d", assessment_id)
    return _success(_row_to_dict(updated_row))


# ──────────────────────────────────────────────────────────────────────────────
# DELETE /assessments/<id> — Eliminar evaluación
# ──────────────────────────────────────────────────────────────────────────────

@assessments_bp.route("/assessments/<int:assessment_id>", methods=["DELETE"])
def delete_assessment(assessment_id: int):
    """Elimina una evaluación por ID."""
    conn = get_db_connection()
    try:
        existing = conn.execute(
            "SELECT id FROM risk_assessments WHERE id = ?", (assessment_id,)
        ).fetchone()
    finally:
        conn.close()

    if not existing:
        return _error(f"Evaluación {assessment_id} no encontrada.", 404)

    conn = get_db_connection()
    try:
        conn.execute(
            "DELETE FROM risk_assessments WHERE id = ?", (assessment_id,)
        )
        conn.commit()
    finally:
        conn.close()

    logger.info("Assessment eliminado — id=%d", assessment_id)
    return _success({"message": f"Evaluación {assessment_id} eliminada correctamente."})
