# TDS Sentinel — Developer Guide

**TDS Sentinel** es una plataforma de evaluación de riesgos de ciberseguridad para PYMEs.  
**Versión:** 3.2.0 · **Schema DB:** v3.0.0 · **QA:** ✅ Aprobado (Mayo 2026)

Stack: Flutter Web → Flask (static + API) → SQLite

---

## Estructura del proyecto

```
tds-sentinel-mvp/
├── backend/
│   ├── app.py              Punto de entrada — Flask + blueprints + SPA serving + security headers
│   ├── auth_utils.py       login_required decorator + validación de Bearer tokens
│   ├── config.py           Configuración via variables de entorno (v3.2.0)
│   ├── database.py         Schema v3 + tabla sessions + migraciones automáticas
│   ├── risk_engine.py      Motor de scoring y recomendaciones
│   ├── server.py           Entrada alternativa (gunicorn-ready)
│   ├── routes/
│   │   ├── auth.py         POST /auth/login · POST /auth/logout · /auth/forgot-password · /auth/contact
│   │   ├── clients.py      CRUD /clients (solo perfil propio — IDOR fix, self-lockout fix, TOCTOU fix)
│   │   ├── packs.py        GET /packs
│   │   └── assessments.py  CRUD /assessments (solo propias)
│   ├── tests/
│   │   ├── conftest.py     Fixtures pytest
│   │   └── test_auth_login.py  23 tests de autenticación
│   ├── .env.example
│   ├── requirements.txt
│   └── .gitignore
├── mobile/sentinel_mobile/
│   ├── lib/
│   │   ├── config/api_config.dart    URLs centralizadas (same-origin en web) + endpoint logout
│   │   ├── models/                   DTOs: client, risk_assessment, assessment_pack, app_state
│   │   ├── services/api_service.dart Capa HTTP centralizada con Bearer token
│   │   ├── screens/                  8 pantallas (login → historial)
│   │   └── widgets/                  Componentes reutilizables
│   └── pubspec.yaml
├── docs/                   Documentación técnica (esta carpeta)
├── rebuild_web.sh          Script para recompilar Flutter Web
└── README.md
```

---

## Setup local — Backend

### 1. Prerequisitos

- Python 3.11+
- pip
- (Recomendado) virtualenv

### 2. Entorno virtual

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate    # macOS/Linux
```

### 3. Instalar dependencias

```bash
pip install -r requirements.txt
```

### 4. Configurar variables de entorno

```bash
cp .env.example .env
```

Editar `.env`:

```env
FLASK_DEBUG=true
SECRET_KEY=<genera_uno_con_el_comando_abajo>
PORT=5000
CORS_ORIGINS=http://localhost:5000,http://127.0.0.1:5000
# SESSION_HOURS=24       (opcional — duración de tokens Bearer)
# DB_PATH=./sentinel.db  (opcional — default: junto al backend)
```

Generar `SECRET_KEY` segura:

```bash
python3 -c "import secrets; print(secrets.token_hex(32))"
```

### 5. Correr la API

```bash
python3 app.py
```

Output esperado:

```
[Sentinel] Base de datos lista → /ruta/al/sentinel.db
```

### 6. Verificar health check

```bash
curl http://127.0.0.1:5000/api/health
```

Respuesta esperada:

```json
{
  "status": "ok",
  "message": "TDS Sentinel API is running",
  "version": "3.2.0"
}
```

---

## Setup — Flutter Web

### Recompilar build

```bash
bash rebuild_web.sh
```

El script:
1. Verifica Flutter SDK en `/tmp/flutter` (lo descarga si no existe).
2. Ejecuta `flutter build web --release`.
3. Flask sirve el build automáticamente — no hay que copiar archivos.

> **Nota Codespaces:** el build compilado está incluido en el repo. Solo es necesario recompilar si se modifica código Flutter.

### Desarrollo Flutter

```bash
cd mobile/sentinel_mobile
flutter pub get
flutter run -d chrome    # web en navegador
# o
flutter run              # móvil/emulador (apunta a localhost:5000)
```

En emulador Android cambiar `api_config.dart` a `http://10.0.2.2:5000/api`.

---

## Autenticación Bearer Token

A partir de v3.1, todos los endpoints salvo los públicos requieren el header:

```
Authorization: Bearer <token>
```

El token se obtiene en `POST /api/auth/login` y expira tras `SESSION_HOURS` horas (default: 24h).

**Endpoints públicos** (sin token): `GET /health`, `GET /packs`, `POST /auth/login`, `POST /auth/forgot-password`, `POST /auth/contact`

**Flujo Flutter:**
```dart
// 1. Login → AppState almacena el token automáticamente
final client = await ApiService.instance.login(email, password);

// 2. Todas las requests siguientes incluyen el token vía _authHeaders
final assessments = await ApiService.instance.fetchAssessments();

// 3. Logout → invalida el token en servidor y limpia AppState
await ApiService.instance.logout();
```

---

## Endpoints disponibles — v3.2

### Autenticación (`routes/auth.py`)

| Método | Ruta | Auth | Body requerido | Descripción |
|--------|------|------|----------------|-------------|
| POST | `/api/auth/login` | ❌ | `email`, `password` | Login → devuelve `{ token, client }` |
| POST | `/api/auth/logout` | ✅ | — | Invalida el token actual en la DB |
| POST | `/api/auth/forgot-password` | ❌ | `email` | Crea ticket → devuelve `ticket_reference` (UUID v4) |
| POST | `/api/auth/contact` | ❌ | `company_name`, `contact_name`, `email`, `phone` | Solicitud de cotización → devuelve `request_reference` (UUID v4) |

### Clientes (`routes/clients.py`)

| Método | Ruta | Auth | Descripción |
|--------|------|------|-------------|
| GET | `/api/clients` | ✅ | Devuelve solo el perfil del cliente autenticado |
| POST | `/api/clients` | ✅ | Crear cliente nuevo |
| GET | `/api/clients/<id>` | ✅ solo propio | Detalle del propio perfil (403 si intenta acceder a otro) |
| PUT | `/api/clients/<id>` | ✅ solo propio | Actualizar perfil (client_status no modificable vía API) |
| DELETE | `/api/clients/<id>` | ✅ solo propio | Eliminar (409 si tiene evaluaciones) |
| GET | `/api/clients/<id>/assessments` | ✅ solo propio | Historial de evaluaciones propias |

### Evaluaciones (`routes/assessments.py`)

| Método | Ruta | Auth | Descripción |
|--------|------|------|-------------|
| GET | `/api/health` | ❌ | Estado y versión de la API |
| GET | `/api/packs` | ❌ | Catálogo de assessment packs |
| POST | `/api/assessments` | ✅ solo propio | Crear evaluación (`client_id` debe ser el propio) |
| GET | `/api/assessments` | ✅ | Listar solo las evaluaciones del cliente autenticado |
| GET | `/api/assessments/<id>` | ✅ solo propia | Detalle (solo propias, 404 si no pertenece) |
| DELETE | `/api/assessments/<id>` | ✅ solo propia | Eliminar (solo propias) |

---

## Schema de base de datos v3.0.0

### Tablas

```sql
clients (
    id, company_name, contact_name, email UNIQUE,
    phone, password_hash, bs_area,
    client_status CHECK (enabled|blocked|disabled),
    created_at, updated_at
)

sessions (
    id, token UNIQUE, client_id FK→clients(id) ON DELETE CASCADE,
    created_at, expires_at
)

risk_assessments (
    id, client_id FK→clients(id),
    pack_id, answers_json, score, risk_level,
    recommendations_json, assessment_hash,
    created_at, updated_at
)

support_tickets (
    id, email, client_id FK→clients(id),
    type, status, created_at, updated_at
)

contact_requests (
    id, company_name, contact_name, email, phone,
    pack_interest, message, status, created_at
)

schema_version (id, version, applied_at)
```

### Migración automática

`database.py` detecta schemas v1.x y v2.x al arrancar y los migra a v3.0.0 → v3.1 (agrega tabla `sessions`):
- Recrea `clients` con los nuevos campos (`password_hash`, `bs_area`, `client_status`).
- Recrea `risk_assessments` eliminando `company_name`/`responsible_name`, forzando FK.
- Crea `support_tickets` y `contact_requests` si no existen.
- Crea `sessions` si no existe (migración v3.0 → v3.1).
- Clientes migrados desde v1/v2 reciben contraseña temporal `ChangeMe123!` (logueado en nivel INFO).

---

## Seguridad implementada

### Backend

| Control | Detalle | Archivo |
|---------|---------|---------|
| **Autenticación Bearer** | `login_required` en todos los endpoints; token de 32 bytes URL-safe; expiry en DB | `auth_utils.py`, `database.py` |
| **Ownership enforcement** | Todos los recursos verifican `g.current_client["id"] == resource_owner_id` | `routes/clients.py`, `routes/assessments.py` |
| **IDOR prevention** | GET /clients y GET /clients/\<id\> filtrados al propio id → 403 para cualquier otro | `routes/clients.py` |
| **Self-lockout prevention** | PUT /clients/\<id\> rechaza cambios de `client_status` con 403 | `routes/clients.py` |
| **TOCTOU race condition** | INSERT de clientes en try/except IntegrityError → 409 determinista | `routes/clients.py` |
| **Logout activo** | DELETE /auth/logout invalida el token en sessions; 401 si token expirado | `routes/auth.py`, `database.py` |
| SQL Injection | Queries parametrizadas con `?` en todos los endpoints | `routes/*.py`, `database.py` |
| Contraseñas | SHA-256 + salt aleatorio (`secrets.token_hex(16)`) + `secrets.compare_digest` | `database.py` |
| Secrets | Variables de entorno via `.env` + `python-dotenv`; fail-fast si falta `SECRET_KEY` | `config.py` |
| CORS | Lista blanca de orígenes (`CORS_ORIGINS`); auto-detecta Codespaces; nunca `*` | `app.py`, `config.py` |
| Stack traces | Errores logueados internamente, JSON limpio al cliente (4 handlers globales) | `app.py` |
| Input sanitization | Strip + chars de control (0x00–0x1f) + strip HTML tags (`<[^>]*>`) + longitud máxima | `routes/*.py` |
| Security headers | `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, `Referrer-Policy`, `Permissions-Policy`, `CSP` | `app.py` |
| Server header | Sobrescrito a `TDS-Sentinel` (suprime Werkzeug/Python en producción) | `app.py` |
| Enumeración | Login devuelve mensaje genérico para email inexistente y password incorrecto | `routes/auth.py` |
| Estado cliente | `blocked`/`disabled` bloquean login con 403 antes de verificar password | `routes/auth.py` |
| UUID references | `ticket_reference` y `request_reference` son UUIDs v4 — no revelan IDs secuenciales | `routes/auth.py` |
| Integridad | SHA-256 hash por evaluación (`assessment_hash`) | `routes/assessments.py` |
| FK enforcement | `PRAGMA foreign_keys = ON` + `PRAGMA journal_mode = WAL` | `database.py` |
| Debug | `False` por defecto; solo activable via `FLASK_DEBUG=true` | `config.py` |

### Flutter

| Control | Detalle | Archivo |
|---------|---------|---------|
| Bearer token | `_authHeaders` incluye `Authorization: Bearer $token` en todas las requests protegidas | `api_service.dart` |
| Same-origin API | En web, `baseUrl` se deriva de `Uri.base` — sin URLs hardcodeadas | `api_config.dart` |
| Validación formulario | Campos requeridos + trim antes de enviar al servidor | `assessment_form_screen.dart` |
| Sin datos sensibles locales | No se persiste `password_hash` ni tokens en almacenamiento permanente | `api_service.dart` |
| Errores amigables | `ApiException` abstrae errores HTTP — el usuario no ve mensajes internos | `api_service.dart` |
| Timeout | `Duration(seconds: 15)` en todos los requests | `api_config.dart` |
| Confirmación de borrado | `AlertDialog` antes de ejecutar DELETE | `assessment_history_screen.dart` |
| Sin logging de payloads | No hay `print` de responses completas en producción | `api_service.dart` |

---

## Convenciones de código

- Variables, funciones y clases: **inglés**
- Comentarios explicativos: **español**
- Respuestas JSON: siempre, sin excepciones (error handlers globales en `app.py`)
- HTTP status codes: correctos y semánticos
- Logs: nivel INFO para operaciones normales, ERROR para excepciones

---

## Correr tests

```bash
cd /workspaces/tds-sentinel-mvp
.venv/bin/python3 -m pytest backend/tests/ -v
```

Test suite actual: `tests/test_auth_login.py` — **23 tests** que cubren login exitoso (con token), credenciales inválidas, estados de cuenta y métodos HTTP.

---

## Git workflow

```bash
git add .
git commit -m "feat: descripción del cambio"
git push origin dev
```

Rama principal de trabajo: **`dev`**

---

## Hitos completados

- [x] Hito 1 — Project Foundation + Backend Base
- [x] Hito 2 — Security Assessment Packs + Risk Engine
- [x] Hito 3 — SQLite Persistence + REST API CRUD
- [x] Hito 4 — Flutter Foundation
- [x] Hito 5 — Flutter Models + API Service
- [x] Hito 6 — Assessment Form UI
- [x] Hito 7 — Results Screen
- [x] Hito 8 — History + CRUD UX
- [x] Hito 9 — TDS Branding + Polish
- [x] Hito 10 — Testing + Docs + Packaging
- [x] **v3.0.0** — Schema v3: clients auth, support tickets, contact requests, Flutter Web served by Flask
- [x] **v3.1.0** — Autenticación Bearer token: sessions table, login_required decorator, ownership checks, security headers, HTML stripping, UUID ticket references
- [x] **v3.2.0** — Hardening post-pentest: IDOR fix (GET /clients), self-lockout prevention (PUT /clients), TOCTOU race condition → 409 determinista (POST /clients)
