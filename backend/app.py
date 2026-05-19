import os
from flask import Flask, request, jsonify
from flask_cors import CORS
from database import get_db_connection, init_db

app = Flask(__name__)

# En producción, fijar CORS_ORIGINS a los dominios permitidos.
_cors_origins = os.getenv("CORS_ORIGINS", "*")
CORS(app, origins=_cors_origins)

init_db()

_VALID_RISK_LEVELS = {"Low", "Medium", "High", "Critical"}
_MAX_FIELD_LEN = 500


def _validate_payload(data):
    """
    Valida el cuerpo JSON de creación/actualización.
    Retorna (mensaje_error, None) o (None, datos_limpios).
    """
    if not data or not isinstance(data, dict):
        return "Request body must be a JSON object", None

    required = ["company_name", "asset_name", "risk_level", "recommendation"]
    missing = [f for f in required if f not in data]
    if missing:
        return f"Missing required fields: {', '.join(missing)}", None

    for field in ("company_name", "asset_name", "recommendation"):
        value = data[field]
        if not isinstance(value, str) or not value.strip():
            return f"Field '{field}' must be a non-empty string", None
        if len(value) > _MAX_FIELD_LEN:
            return f"Field '{field}' exceeds maximum length of {_MAX_FIELD_LEN}", None

    if data["risk_level"] not in _VALID_RISK_LEVELS:
        levels = ", ".join(sorted(_VALID_RISK_LEVELS))
        return f"risk_level must be one of: {levels}", None

    return None, {
        "company_name": data["company_name"].strip(),
        "asset_name": data["asset_name"].strip(),
        "risk_level": data["risk_level"],
        "recommendation": data["recommendation"].strip(),
    }


@app.route("/api/health", methods=["GET"])
def health_check():
    return jsonify({"status": "ok", "message": "Sentinel API is running"}), 200


@app.route("/api/assessments", methods=["GET"])
def get_assessments():
    conn = get_db_connection()
    try:
        rows = conn.execute(
            "SELECT * FROM risk_assessments ORDER BY created_at DESC"
        ).fetchall()
        return jsonify([dict(row) for row in rows]), 200
    except Exception:
        app.logger.exception("GET /api/assessments failed")
        return jsonify({"error": "Internal server error"}), 500
    finally:
        conn.close()


@app.route("/api/assessments", methods=["POST"])
def create_assessment():
    data = request.get_json(silent=True)
    error, clean = _validate_payload(data)
    if error:
        return jsonify({"error": error}), 400

    conn = get_db_connection()
    try:
        cursor = conn.execute(
            """
            INSERT INTO risk_assessments (company_name, asset_name, risk_level, recommendation)
            VALUES (?, ?, ?, ?)
            """,
            (clean["company_name"], clean["asset_name"], clean["risk_level"], clean["recommendation"]),
        )
        conn.commit()
        row = conn.execute(
            "SELECT * FROM risk_assessments WHERE id = ?", (cursor.lastrowid,)
        ).fetchone()
        return jsonify(dict(row)), 201
    except Exception:
        app.logger.exception("POST /api/assessments failed")
        return jsonify({"error": "Internal server error"}), 500
    finally:
        conn.close()


@app.route("/api/assessments/<int:assessment_id>", methods=["PUT"])
def update_assessment(assessment_id):
    data = request.get_json(silent=True)
    error, clean = _validate_payload(data)
    if error:
        return jsonify({"error": error}), 400

    conn = get_db_connection()
    try:
        if not conn.execute(
            "SELECT id FROM risk_assessments WHERE id = ?", (assessment_id,)
        ).fetchone():
            return jsonify({"error": "Assessment not found"}), 404

        conn.execute(
            """
            UPDATE risk_assessments
            SET company_name = ?, asset_name = ?, risk_level = ?, recommendation = ?
            WHERE id = ?
            """,
            (clean["company_name"], clean["asset_name"], clean["risk_level"], clean["recommendation"], assessment_id),
        )
        conn.commit()
        row = conn.execute(
            "SELECT * FROM risk_assessments WHERE id = ?", (assessment_id,)
        ).fetchone()
        return jsonify(dict(row)), 200
    except Exception:
        app.logger.exception("PUT /api/assessments/%s failed", assessment_id)
        return jsonify({"error": "Internal server error"}), 500
    finally:
        conn.close()


@app.route("/api/assessments/<int:assessment_id>", methods=["DELETE"])
def delete_assessment(assessment_id):
    conn = get_db_connection()
    try:
        if not conn.execute(
            "SELECT id FROM risk_assessments WHERE id = ?", (assessment_id,)
        ).fetchone():
            return jsonify({"error": "Assessment not found"}), 404

        conn.execute("DELETE FROM risk_assessments WHERE id = ?", (assessment_id,))
        conn.commit()
        return jsonify({"message": "Assessment deleted successfully"}), 200
    except Exception:
        app.logger.exception("DELETE /api/assessments/%s failed", assessment_id)
        return jsonify({"error": "Internal server error"}), 500
    finally:
        conn.close()


if __name__ == "__main__":
    debug_mode = os.getenv("FLASK_DEBUG", "false").lower() == "true"
    app.run(debug=debug_mode)
