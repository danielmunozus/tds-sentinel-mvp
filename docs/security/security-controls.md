# TDS Sentinel — Security Controls (v3.0.0)

## Controles de seguridad implementados

### Backend (Flask + SQLite)

| Control | Implementación | Archivo |
|---------|---------------|---------|
| SQL Injection | Queries parametrizadas con `?` en todos los endpoints | `routes/*.py`, `database.py` |
| Contraseñas | SHA-256 + salt aleatorio (`secrets.token_hex(16)`) almacenado como `salt:digest` | `database.py` |
| Timing attacks | `secrets.compare_digest` en verificación de contraseña | `database.py` |
| Secrets | Variables de entorno via `.env` + `python-dotenv`; nunca hardcodeados | `config.py` |
| Config fail-fast | `Config.validate()` lanza `RuntimeError` si falta `SECRET_KEY` al arrancar | `config.py` |
| CORS | Lista blanca de orígenes (`CORS_ORIGINS`), nunca `*`; auto-detecta Codespaces | `app.py`, `config.py` |
| Stack traces | Errores logueados internamente, JSON limpio al cliente (4 handlers globales) | `app.py` |
| Input sanitization | Strip + eliminación de chars de control (0x00-0x1f) + longitud máxima | `routes/*.py` |
| Integridad evaluaciones | SHA-256 hash por evaluación (`assessment_hash`) | `routes/assessments.py` |
| Debug mode | `False` por defecto; solo activable via `FLASK_DEBUG=true` en `.env` | `config.py` |
| FK enforcement | `PRAGMA foreign_keys = ON` — impide assessments sin cliente válido | `database.py` |
| WAL mode | `PRAGMA journal_mode = WAL` — mejora concurrencia y reduce bloqueos | `database.py` |
| JSON only | Todos los error handlers devuelven JSON (nunca HTML con info interna) | `app.py` |
| Enumeración de usuarios | Login devuelve mensaje genérico tanto para email inexistente como password incorrecto | `routes/auth.py` |
| Estado de cuenta | `client_status` (enabled/blocked/disabled) — bloqueo antes de verificar password | `routes/auth.py` |
| Email único | `UNIQUE` constraint en DB + verificación en capa de aplicación (409) | `database.py`, `routes/clients.py` |
| Validación de email | Regex `^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$` en capa de app | `database.py` |
| Password mínimo | 8 caracteres mínimos en creación y actualización de clientes | `routes/clients.py` |
| Sanitización respuestas | `password_hash` nunca incluido en respuestas JSON al cliente | `routes/clients.py`, `routes/auth.py` |
| Schema migrations | Migración automática v1/v2 → v3 con preservación de datos | `database.py` |

### Flutter Web

| Control | Implementación | Archivo |
|---------|---------------|---------|
| Same-origin API | En web, `baseUrl` se deriva de `Uri.base` — sin URLs hardcodeadas que exponer | `api_config.dart` |
| Validación formulario | Campos requeridos + trim antes de enviar al servidor | `assessment_form_screen.dart`, `login_screen.dart` |
| Sin datos sensibles locales | No se persiste `password_hash` ni datos sensibles en el dispositivo | `api_service.dart` |
| Errores amigables | `ApiException` abstrae errores HTTP — el usuario no ve mensajes internos | `api_service.dart` |
| Timeout | `Duration(seconds: 15)` en todos los requests | `api_config.dart` |
| Confirmación de borrado | `AlertDialog` antes de ejecutar DELETE | `assessment_history_screen.dart` |
| Sin logging de payloads | No hay `print` de responses completas en producción | `api_service.dart` |

---

## Pendiente para producción (fuera del MVP)

| Control | Prioridad | Nota |
|---------|-----------|------|
| JWT / sesiones con expiración | Alta | Actualmente el login retorna datos del cliente pero no hay token de sesión |
| HTTPS obligatorio (nginx + Let's Encrypt) | Alta | Codespaces ya provee HTTPS; local usa HTTP |
| Rate limiting en login y contact | Alta | Previene fuerza bruta y spam |
| Migrar a `bcrypt` o `argon2` para contraseñas | Media | SHA-256 es insuficiente para producción a largo plazo |
| Audit log de operaciones sensibles | Media | Registro de quién creó/eliminó evaluaciones |
| Rotación de `SECRET_KEY` | Media | Procedimiento documentado |
| Migración SQLite → PostgreSQL | Media | Para concurrencia en multi-usuario real |
| CSP / Security headers | Baja | `Content-Security-Policy`, `X-Frame-Options`, etc. |

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
