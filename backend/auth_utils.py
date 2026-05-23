"""
auth_utils.py — TDS Sentinel API
Decorador login_required para proteger endpoints con Bearer token.

Uso:
    from auth_utils import login_required

    @bp.route("/recurso", methods=["GET"])
    @login_required
    def mi_endpoint():
        cliente = g.current_client   # dict con datos del cliente autenticado
        ...
"""

from functools import wraps

from flask import g, request


def login_required(f):
    """
    Exige un token Bearer válido en el header Authorization.
    Si el token es válido, inyecta el cliente en flask.g.current_client.
    Si no, responde con 401 y no ejecuta la función decorada.
    """
    @wraps(f)
    def decorated(*args, **kwargs):
        from app import error_response
        from database import get_client_by_token

        auth_header = request.headers.get("Authorization", "")

        if not auth_header.startswith("Bearer "):
            return error_response("Token de acceso requerido.", 401)

        token = auth_header[7:].strip()
        if not token:
            return error_response("Token de acceso requerido.", 401)

        client = get_client_by_token(token)
        if client is None:
            return error_response("Token inválido o expirado.", 401)

        g.current_client = client
        return f(*args, **kwargs)

    return decorated
