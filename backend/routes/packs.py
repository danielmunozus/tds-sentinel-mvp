"""
routes/packs.py — TDS Sentinel API
Blueprint para el catálogo de Assessment Packs.
"""

from flask import Blueprint
from risk_engine import get_assessment_packs

packs_bp = Blueprint("packs", __name__)


@packs_bp.route("/packs", methods=["GET"])
def list_packs():
    """
    Retorna el catálogo de assessment packs disponibles.
    El cliente Flutter usa esto para renderizar el formulario dinámicamente.
    """
    from app import success_response
    packs = get_assessment_packs()
    return success_response(packs)
