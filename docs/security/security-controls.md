# TDS Sentinel — Security Controls (v3.2.0)

## Controles de seguridad implementados

### Backend (Flask + SQLite)

| Control | Implementación | Archivo |
|---------|---------------|---------|
| **Autenticación Bearer** | `login_required` decorator en todos los endpoints sensibles; token de 32 bytes URL-safe con expiración configurable (`SESSION_HOURS`) | `auth_utils.py`, `database.py` |
| **Ownership enforcement** | PUT/DELETE/POST de evaluaciones y clientes verifican que `g.current_client["id"] == resource_id` | `routes/clients.py`, `routes/assessments.py` |
| **IDOR prevention** | `GET /clients` y `GET /clients/<id>` solo devuelven el perfil del cliente autenticado; cualquier acceso a otro id → 403 | `routes/clients.py` |
| **Self-lockout prevention** | `PUT /clients/<id>` rechaza cualquier cambio de `client_status` con 403 — operación reservada para admin | `routes/clients.py` |
| **TOCTOU race condition** | `INSERT INTO clients` envuelto en `try/except sqlite3.IntegrityError` → 409 determinista en lugar de 500 por UNIQUE constraint | `routes/clients.py` |
| **Logout activo** | `POST /auth/logout` invalida el token en la tabla `sessions`; token expirado o revocado devuelve 401 | `routes/auth.py`, `database.py` |
| SQL Injection | Queries parametrizadas con `?` en todos los endpoints | `routes/*.py`, `database.py` |
| Contraseñas | SHA-256 + salt aleatorio (`secrets.token_hex(16)`) almacenado como `salt:digest` | `database.py` |
| Timing attacks | `secrets.compare_digest` en verificación de contraseña | `database.py` |
| Secrets | Variables de entorno via `.env` + `python-dotenv`; nunca hardcodeados | `config.py` |
| Config fail-fast | `Config.validate()` lanza `RuntimeError` si falta `SECRET_KEY` al arrancar | `config.py` |
| CORS | Lista blanca de orígenes (`CORS_ORIGINS`), nunca `*`; auto-detecta Codespaces | `app.py`, `config.py` |
| Stack traces | Errores logueados internamente, JSON limpio al cliente (4 handlers globales) | `app.py` |
| Input sanitization | Strip + eliminación de chars de control (0x00–0x1f) + **strip de tags HTML** (`<[^>]*>`) + longitud máxima 200 chars | `routes/*.py` |
| **Security headers** | `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer`, `Permissions-Policy`, `Content-Security-Policy` | `app.py` |
| **Server header** | Sobrescrito a `TDS-Sentinel` (suprime versión de Werkzeug/Python) | `app.py` |
| **UUID references** | `ticket_reference` y `request_reference` son UUIDs v4 — no revelan IDs secuenciales | `routes/auth.py` |
| Integridad evaluaciones | SHA-256 hash por evaluación (`assessment_hash`) | `routes/assessments.py` |
| Debug mode | `False` por defecto; solo activable via `FLASK_DEBUG=true` en `.env` | `config.py` |
| FK enforcement | `PRAGMA foreign_keys = ON` — impide assessments sin cliente válido | `database.py` |
| WAL mode | `PRAGMA journal_mode = WAL` — mejora concurrencia y reduce bloqueos | `database.py` |
| JSON only | Todos los error handlers devuelven JSON (nunca HTML con info interna) | `app.py` |
| Enumeración de usuarios | Login devuelve mensaje genérico tanto para email inexistente como password incorrecto | `routes/auth.py` |
| Estado de cuenta | `client_status` (enabled/blocked/disabled) — bloqueo antes de verificar password; también invalida tokens activos | `routes/auth.py`, `database.py` |
| Email único | `UNIQUE` constraint en DB + verificación en capa de aplicación (409) | `database.py`, `routes/clients.py` |
| Validación de email | Regex `^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$` en capa de app | `database.py` |
| Password mínimo | 8 caracteres mínimos en creación y actualización de clientes | `routes/clients.py` |
| Sanitización respuestas | `password_hash` nunca incluido en respuestas JSON al cliente | `routes/clients.py`, `routes/auth.py` |
| Schema migrations | Migración automática v1/v2 → v3 → v3.1 con preservación de datos | `database.py` |

### Flutter Web

| Control | Implementación | Archivo |
|---------|---------------|---------|
| **Bearer token** | `_authHeaders` incluye `Authorization: Bearer $token` en todas las requests protegidas | `api_service.dart` |
| Same-origin API | En web, `baseUrl` se deriva de `Uri.base` — sin URLs hardcodeadas que exponer | `api_config.dart` |
| Validación formulario | Campos requeridos + trim antes de enviar al servidor | `assessment_form_screen.dart`, `login_screen.dart` |
| Sin datos sensibles locales | No se persiste `password_hash` ni tokens en almacenamiento permanente del dispositivo | `api_service.dart` |
| Errores amigables | `ApiException` abstrae errores HTTP — el usuario no ve mensajes internos | `api_service.dart` |
| Timeout | `Duration(seconds: 15)` en todos los requests | `api_config.dart` |
| Confirmación de borrado | `AlertDialog` antes de ejecutar DELETE | `assessment_history_screen.dart` |
| Sin logging de payloads | No hay `print` de responses completas en producción | `api_service.dart` |

---

## Pendiente para producción (fuera del MVP)

| Control | Prioridad | Nota |
|---------|-----------|------|
| HTTPS obligatorio (nginx + Let's Encrypt) | Alta | Codespaces ya provee HTTPS; local usa HTTP |
| Rate limiting en login y contact | Alta | Previene fuerza bruta y spam |
| Migrar a `bcrypt` o `argon2` para contraseñas | Media | SHA-256 es insuficiente para producción a largo plazo |
| Endpoint de administración para `client_status` | Media | Actualmente solo modificable directo en DB; necesita rol admin |
| Audit log de operaciones sensibles | Media | Registro de quién creó/eliminó evaluaciones |
| Rotación de `SECRET_KEY` | Media | Procedimiento documentado |
| Migración SQLite → PostgreSQL | Media | Para concurrencia en multi-usuario real |
| SSTI prevention (campos de texto libre) | Baja | `{{...}}` se almacena pero no se evalúa; sin riesgo en la arquitectura actual |
| CSP reforzado vía nginx | Baja | Headers ya en app.py; reforzar con nginx en producción para evitar que Werkzeug los sobreescriba |

---

## Historial de vulnerabilidades corregidas

| Versión | Vulnerabilidad | Severidad | Fix aplicado |
|---------|---------------|-----------|--------------|
| v3.1.0 | Sin autenticación en ningún endpoint | Crítica | Bearer token + `login_required` decorator |
| v3.1.0 | Account takeover via PUT sin auth | Crítica | `@login_required` + ownership check en PUT/DELETE |
| v3.1.0 | XSS stored (HTML tags en campos de texto) | Alta | `re.sub(r"<[^>]*>", "", value)` en todos los `_sanitize()` |
| v3.1.0 | Server header disclosure (Werkzeug versión) | Baja | `response.headers["Server"] = "TDS-Sentinel"` |
| v3.1.0 | IDs secuenciales en tickets y solicitudes | Baja | UUID v4 para `ticket_reference` y `request_reference` |
| v3.1.0 | Sin security headers | Media | `X-Frame-Options`, `X-Content-Type-Options`, `Referrer-Policy`, `Permissions-Policy`, `CSP` |
| v3.2.0 | IDOR en GET /clients y GET /clients/\<id\> | Alta | Ownership check: 403 si `id != g.current_client["id"]` |
| v3.2.0 | Self-lockout via PUT client_status=blocked | Media | PUT /clients/\<id\> rechaza cambios de `client_status` con 403 |
| v3.2.0 | TOCTOU race condition → 500 en email duplicado | Media | `try/except sqlite3.IntegrityError` → 409 determinista |

---

## Guía para HTTPS en Codespaces

Codespaces expone el puerto 5000 automáticamente con HTTPS a través de su proxy inverso.  
La URL pública del Codespace ya usa `https://` — no se requiere configuración adicional.

El `CORS` de Flask auto-detecta la URL del Codespace via:
```python
CODESPACE_NAME = os.getenv("CODESPACE_NAME", "")
# → https://{CODESPACE_NAME}-5000.app.github.dev
```

Para desarrollo local con certificado autofirmado (solo demos offline):

```bash
# Generar certificado autofirmado
openssl req -x509 -newkey rsa:4096 -nodes \
  -keyout backend/certs/key.pem \
  -out backend/certs/cert.pem \
  -days 365 -subj '/CN=localhost'

# En app.py, cambiar app.run() a:
app.run(host='127.0.0.1', port=5000, debug=False,
        ssl_context=('certs/cert.pem', 'certs/key.pem'))
```

> ⚠️ Los certificados autofirmados generan advertencias en el navegador.  
> Para producción real, usar Let's Encrypt o un certificado de una CA reconocida.
