"""
test_auth_login.py — TDS Sentinel API
Tests de la ruta POST /api/auth/login.

Cubre:
  ✓ Login exitoso → devuelve { token, client }
  ✓ Token es string no vacío
  ✓ Email case-insensitive
  ✓ No devuelve password_hash en la respuesta
  ✓ Body sin JSON / malformado
  ✓ Email vacío
  ✓ Email con formato inválido
  ✓ Contraseña vacía
  ✓ Usuario no encontrado  → 401 (mensaje genérico)
  ✓ Contraseña incorrecta  → 401 (mismo mensaje genérico, no revela cuál falló)
  ✓ Cuenta bloqueada       → 403
  ✓ Cuenta deshabilitada   → 403
  ✓ Método GET no permitido → 405
"""
from __future__ import annotations

import pytest


URL = "/api/auth/login"


def post_login(client, email: str | None = None, password: str | None = None, **extra):
    """Atajo para hacer POST /api/auth/login con JSON."""
    body = {}
    if email is not None:
        body["email"] = email
    if password is not None:
        body["password"] = password
    body.update(extra)
    return client.post(URL, json=body)


def get_client_data(response) -> dict:
    """
    Extrae los datos del cliente de la respuesta de login.
    v3.1: respuesta es { "token": "...", "client": { ... } }
    """
    return response.get_json()["client"]


# ─────────────────────────────────────────────────────────────────────────────
# Casos exitosos
# ─────────────────────────────────────────────────────────────────────────────

class TestLoginExitoso:
    """El usuario ingresa credenciales correctas y obtiene token + datos."""

    def test_retorna_200_con_token_y_cliente(self, client, usuario_activo):
        r = post_login(client, usuario_activo["email"], usuario_activo["password"])
        assert r.status_code == 200
        data = r.get_json()
        # Debe tener token y cliente en la respuesta
        assert "token" in data, "Falta el campo 'token' en la respuesta"
        assert "client" in data, "Falta el campo 'client' en la respuesta"
        assert isinstance(data["token"], str) and len(data["token"]) > 10

    def test_retorna_datos_correctos_del_cliente(self, client, usuario_activo):
        r = post_login(client, usuario_activo["email"], usuario_activo["password"])
        assert r.status_code == 200
        cliente = get_client_data(r)
        assert cliente["email"] == usuario_activo["email"]
        assert cliente["company_name"] == "Empresa Test SA"
        assert cliente["client_status"] == "enabled"

    def test_no_devuelve_password_hash(self, client, usuario_activo):
        """La respuesta nunca debe exponer el hash de la contraseña."""
        r = post_login(client, usuario_activo["email"], usuario_activo["password"])
        assert r.status_code == 200
        data = r.get_json()
        assert "password_hash" not in data
        assert "password_hash" not in data.get("client", {})

    def test_email_case_insensitive(self, client, usuario_activo):
        """El login funciona aunque el email venga en mayúsculas."""
        r = post_login(client, usuario_activo["email"].upper(), usuario_activo["password"])
        assert r.status_code == 200
        assert get_client_data(r)["email"] == usuario_activo["email"]

    def test_respuesta_contiene_campos_obligatorios(self, client, usuario_activo):
        r = post_login(client, usuario_activo["email"], usuario_activo["password"])
        cliente = get_client_data(r)
        for campo in ("id", "company_name", "contact_name", "email",
                      "phone", "client_status", "created_at"):
            assert campo in cliente, f"Falta el campo '{campo}' en client"


# ─────────────────────────────────────────────────────────────────────────────
# Validación de campos
# ─────────────────────────────────────────────────────────────────────────────

class TestValidacionDeCampos:
    """Errores 400 cuando el cuerpo o los campos son inválidos."""

    def test_sin_body_retorna_400(self, client):
        r = client.post(URL, data="esto-no-es-json", content_type="text/plain")
        assert r.status_code == 400

    def test_body_json_vacio_retorna_400(self, client):
        r = client.post(URL, json={})
        assert r.status_code == 400

    def test_email_vacio_retorna_400(self, client):
        r = post_login(client, email="", password="algo123")
        assert r.status_code == 400
        error = r.get_json()["error"].lower()
        assert "email" in error

    def test_email_sin_arroba_retorna_400(self, client):
        r = post_login(client, email="no-es-un-email", password="algo123")
        assert r.status_code == 400
        error = r.get_json()["error"].lower()
        assert "email" in error

    def test_email_solo_dominio_retorna_400(self, client):
        r = post_login(client, email="@dominio.com", password="algo123")
        assert r.status_code == 400

    def test_password_vacia_retorna_400(self, client):
        r = post_login(client, email="valid@test.com", password="")
        assert r.status_code == 400
        error = r.get_json()["error"].lower()
        assert "password" in error

    def test_sin_campo_email_retorna_400(self, client):
        r = client.post(URL, json={"password": "algo123"})
        assert r.status_code == 400

    def test_sin_campo_password_retorna_400(self, client):
        r = client.post(URL, json={"email": "valid@test.com"})
        assert r.status_code == 400


# ─────────────────────────────────────────────────────────────────────────────
# Credenciales incorrectas
# ─────────────────────────────────────────────────────────────────────────────

class TestCredencialesIncorrectas:
    """401 cuando el usuario no existe o la contraseña es incorrecta."""

    def test_usuario_no_existente_retorna_401(self, client):
        r = post_login(client, email="noexiste@test.com", password="cualquier")
        assert r.status_code == 401

    def test_password_incorrecta_retorna_401(self, client, usuario_activo):
        r = post_login(client, email=usuario_activo["email"], password="WrongPass!")
        assert r.status_code == 401

    def test_mensaje_generico_no_revela_que_fallo(self, client, usuario_activo):
        """
        Seguridad: el mensaje de error debe ser el mismo tanto si el email
        no existe como si la contraseña es incorrecta (evitar enumeración).
        """
        r_sin_usuario = post_login(client, "noexiste@test.com", "cualquiera")
        r_pass_wrong = post_login(client, usuario_activo["email"], "Incorrecta!")

        msg_sin_usuario = r_sin_usuario.get_json()["error"]
        msg_pass_wrong = r_pass_wrong.get_json()["error"]

        assert msg_sin_usuario == msg_pass_wrong, (
            "El mensaje de error debe ser idéntico para no revelar cuál campo falló"
        )

    def test_mensaje_error_401_es_correcto(self, client):
        r = post_login(client, "noexiste@test.com", "cualquier")
        assert r.get_json()["error"] == "Email o contraseña incorrectos."


# ─────────────────────────────────────────────────────────────────────────────
# Estados de cuenta
# ─────────────────────────────────────────────────────────────────────────────

class TestEstadosDeCuenta:
    """403 cuando la cuenta está bloqueada o deshabilitada."""

    def test_cuenta_bloqueada_retorna_403(self, client, usuario_bloqueado):
        r = post_login(client, usuario_bloqueado["email"], usuario_bloqueado["password"])
        assert r.status_code == 403
        assert "bloqueada" in r.get_json()["error"].lower()

    def test_cuenta_deshabilitada_retorna_403(self, client, usuario_deshabilitado):
        r = post_login(client, usuario_deshabilitado["email"], usuario_deshabilitado["password"])
        assert r.status_code == 403
        assert "deshabilitada" in r.get_json()["error"].lower()

    def test_cuenta_bloqueada_no_verifica_password(self, client, usuario_bloqueado):
        """
        Una cuenta bloqueada debe rechazarse ANTES de verificar la contraseña
        (evitar fuerza bruta silenciosa sobre cuentas bloqueadas).
        """
        r = post_login(client, usuario_bloqueado["email"], "WrongPassword!")
        # Sigue siendo 403, no 401 — el bloqueo tiene prioridad
        assert r.status_code == 403


# ─────────────────────────────────────────────────────────────────────────────
# Método HTTP
# ─────────────────────────────────────────────────────────────────────────────

class TestMetodoHTTP:
    def test_get_retorna_error(self, client):
        """
        GET /api/auth/login devuelve 404 (el catch-all de la SPA intercepta
        antes de que Flask pueda emitir 405 para la ruta POST-only).
        En cualquier caso, no debe retornar 200.
        """
        r = client.get(URL)
        assert r.status_code in (404, 405)

    def test_put_no_permitido_retorna_405(self, client):
        r = client.put(URL, json={})
        assert r.status_code == 405

    def test_delete_no_permitido_retorna_405(self, client):
        r = client.delete(URL)
        assert r.status_code == 405
