from flask import Flask, request, jsonify
from flask_cors import CORS
from database import get_db_connection, init_db

app = Flask(__name__)

# CORS controlado (en producción se restringe a dominios específicos)
CORS(app)

# Inicializa base de datos al arrancar
init_db()


@app.route("/api/health", methods=["GET"])
def health_check():
    """
    Endpoint de prueba de salud de la API.
    """
    return jsonify({
        "status": "ok",
        "message": "Sentinel API is running"
    }), 200


@app.route("/api/assessments", methods=["GET"])
def get_assessments():
    """
    Retorna todas las evaluaciones de riesgo.
    """
    try:
        conn = get_db_connection()
        rows = conn.execute("SELECT * FROM risk_assessments").fetchall()
        conn.close()

        assessments = [dict(row) for row in rows]

        return jsonify(assessments), 200

    except Exception:
        return jsonify({
            "error": "Internal server error"
        }), 500


@app.route("/api/assessments", methods=["POST"])
def create_assessment():
    """
    Crea una nueva evaluación de riesgo.
    """
    try:
        data = request.get_json()

        required_fields = [
            "company_name",
            "asset_name",
            "risk_level",
            "recommendation"
        ]

        # Validación de campos obligatorios
        if not data or not all(field in data for field in required_fields):
            return jsonify({
                "error": "Missing required fields"
            }), 400

        # Validación de nivel de riesgo
        valid_risk_levels = ["Low", "Medium", "High", "Critical"]
        if data["risk_level"] not in valid_risk_levels:
            return jsonify({
                "error": "Invalid risk level"
            }), 400

        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute("""
            INSERT INTO risk_assessments
            (company_name, asset_name, risk_level, recommendation)
            VALUES (?, ?, ?, ?)
        """, (
            data["company_name"],
            data["asset_name"],
            data["risk_level"],
            data["recommendation"]
        ))

        conn.commit()
        new_id = cursor.lastrowid
        conn.close()

        return jsonify({
            "message": "Assessment created successfully",
            "id": new_id
        }), 201

    except Exception:
        return jsonify({
            "error": "Internal server error"
        }), 500


@app.route("/api/assessments/<int:assessment_id>", methods=["PUT"])
def update_assessment(assessment_id):
    """
    Actualiza una evaluación existente.
    """
    try:
        data = request.get_json()

        required_fields = [
            "company_name",
            "asset_name",
            "risk_level",
            "recommendation"
        ]

        if not data or not all(field in data for field in required_fields):
            return jsonify({
                "error": "Missing required fields"
            }), 400

        valid_risk_levels = ["Low", "Medium", "High", "Critical"]
        if data["risk_level"] not in valid_risk_levels:
            return jsonify({
                "error": "Invalid risk level"
            }), 400

        conn = get_db_connection()
        cursor = conn.cursor()

        existing = cursor.execute(
            "SELECT * FROM risk_assessments WHERE id = ?",
            (assessment_id,)
        ).fetchone()

        if not existing:
            conn.close()
            return jsonify({
                "error": "Assessment not found"
            }), 404

        cursor.execute("""
            UPDATE risk_assessments
            SET company_name = ?,
                asset_name = ?,
                risk_level = ?,
                recommendation = ?
            WHERE id = ?
        """, (
            data["company_name"],
            data["asset_name"],
            data["risk_level"],
            data["recommendation"],
            assessment_id
        ))

        conn.commit()
        conn.close()

        return jsonify({
            "message": "Assessment updated successfully"
        }), 200

    except Exception:
        return jsonify({
            "error": "Internal server error"
        }), 500


@app.route("/api/assessments/<int:assessment_id>", methods=["DELETE"])
def delete_assessment(assessment_id):
    """
    Elimina una evaluación existente.
    """
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        existing = cursor.execute(
            "SELECT * FROM risk_assessments WHERE id = ?",
            (assessment_id,)
        ).fetchone()

        if not existing:
            conn.close()
            return jsonify({
                "error": "Assessment not found"
            }), 404

        cursor.execute(
            "DELETE FROM risk_assessments WHERE id = ?",
            (assessment_id,)
        )

        conn.commit()
        conn.close()

        return jsonify({
            "message": "Assessment deleted successfully"
        }), 200

    except Exception:
        return jsonify({
            "error": "Internal server error"
        }), 500


if __name__ == "__main__":
    app.run(debug=True)