# TDS Sentinel — Cybersecurity Risk Intelligence Platform

> **Built secure. Built to scale.**  
> Plataforma de evaluación de riesgos de ciberseguridad para PYMEs.

**Versión:** 3.2.0 · **QA:** ✅ Aprobado · **Fecha:** Mayo 2026

---

## ¿Qué es TDS Sentinel?

TDS Sentinel permite a empresas evaluar su nivel de riesgo de ciberseguridad mediante cuestionarios de controles ponderados. El sistema calcula un score automatizado, determina el nivel de riesgo y genera recomendaciones priorizadas por consultores de TDS Innovate LLC.

---

## Stack

```
Flutter Web  →  Flask (static + API)  →  SQLite
  (Dart)           (Python 3)            (schema v3)
```

Flask actúa como servidor único: sirve el build de Flutter Web como archivos estáticos y expone la REST API bajo `/api/*`. Todos los endpoints sensibles requieren autenticación Bearer token.

---

## Correr en 3 pasos (local / Codespaces)

### 1. Backend

```bash
cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# Completar SECRET_KEY en .env:
# python3 -c "import secrets; print(secrets.token_hex(32))"
python3 app.py
```

Verificar: `curl http://127.0.0.1:5000/api/health`

### 2. Flutter Web (recompilar build)

```bash
bash rebuild_web.sh
```

> El script descarga Flutter SDK si no está disponible, compila en modo release y Flask sirve el build automáticamente.

### 3. Correr en Codespaces

Abre el repositorio en GitHub → **Code → Codespaces → Create codespace**.  
El entorno instala dependencias automáticamente.  
Corre `cd backend && python3 app.py` para levantar la API + frontend.  
El puerto 5000 se expone públicamente con HTTPS automático de Codespaces.

---

## Estructura del proyecto

```
tds-sentinel-mvp/
├── .devcontainer/
│   └── devcontainer.json           ← Codespaces config
├── backend/
│   ├── app.py                      ← Flask app + blueprints + static serving + security headers
│   ├── auth_utils.py               ← login_required decorator + Bearer token validation
│   ├── config.py                   ← Configuración via .env (v3.2.0)
│   ├── database.py                 ← SQLite schema v3 + sessions + migraciones automáticas
│   ├── risk_engine.py              ← Motor de scoring y recomendaciones
│   ├── server.py                   ← Entrada alternativa (gunicorn-ready)
│   ├── routes/
│   │   ├── auth.py                 ← /auth/login · /auth/logout · /auth/forgot-password · /auth/contact
│   │   ├── clients.py              ← CRUD /api/clients (solo perfil propio)
│   │   ├── packs.py                ← GET /api/packs
│   │   └── assessments.py          ← CRUD /api/assessments (solo propias)
│   ├── tests/
│   │   ├── conftest.py
│   │   └── test_auth_login.py      ← 23 tests de autenticación
│   ├── .env.example
│   ├── requirements.txt
│   └── .gitignore
├── mobile/sentinel_mobile/
│   ├── lib/
│   │   ├── main.dart
│   │   ├── config/api_config.dart  ← URLs centralizadas (same-origin en web)
│   │   ├── theme/app_theme.dart
│   │   ├── models/                 ← risk_assessment, client, assessment_pack, app_state
│   │   ├── services/api_service.dart ← HTTP con Bearer token en todas las requests
│   │   ├── screens/
│   │   │   ├── login_screen.dart
│   │   │   ├── forgot_password_screen.dart
│   │   │   ├── contact_form_screen.dart
│   │   │   ├── home_screen.dart
│   │   │   ├── pack_selection_screen.dart
│   │   │   ├── assessment_form_screen.dart
│   │   │   ├── assessment_result_screen.dart
│   │   │   └── assessment_history_screen.dart
│   │   └── widgets/
│   └── pubspec.yaml
├── docs/
│   ├── README-dev.md               ← Guía para desarrolladores
│   ├── architecture/system-context.md
│   ├── flows/risk-evaluation-flow.md
│   └── security/security-controls.md
├── rebuild_web.sh                  ← Recompila Flutter Web y actualiza el build
└── README.md
```

---

## Endpoints API

### Públicos (sin autenticación)

| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | `/api/health` | Estado y versión de la API |
| GET | `/api/packs` | Catálogo de assessment packs |
| POST | `/api/auth/login` | Login → devuelve `{ token, client }` |
| POST | `/api/auth/forgot-password` | Solicitar reset (devuelve UUID de ticket) |
| POST | `/api/auth/contact` | Solicitud de cotización (devuelve UUID) |

### Protegidos (requieren `Authorization: Bearer <token>`)

| Método | Ruta | Restricción | Descripción |
|--------|------|-------------|-------------|
| POST | `/api/auth/logout` | — | Invalida el token actual |
| GET | `/api/clients` | Propio | Devuelve el perfil del cliente autenticado |
| POST | `/api/clients` | — | Crear cliente nuevo |
| GET | `/api/clients/<id>` | Solo propio | Detalle del propio perfil |
| PUT | `/api/clients/<id>` | Solo propio | Actualizar perfil (status no modificable) |
| DELETE | `/api/clients/<id>` | Solo propio | Eliminar (409 si tiene evaluaciones) |
| GET | `/api/clients/<id>/assessments` | Solo propio | Historial de evaluaciones propias |
| POST | `/api/assessments` | Solo propio | Crear evaluación (`client_id` debe ser el propio) |
| GET | `/api/assessments` | Solo propias | Listar evaluaciones del cliente autenticado |
| GET | `/api/assessments/<id>` | Solo propia | Detalle de evaluación propia |
| DELETE | `/api/assessments/<id>` | Solo propia | Eliminar evaluación propia |

---

## Schema de base de datos v3.0.0

| Tabla | Descripción |
|-------|-------------|
| `clients` | Empresas registradas — autenticación + datos empresariales |
| `sessions` | Tokens Bearer activos con expiración configurable (`SESSION_HOURS`) |
| `risk_assessments` | Evaluaciones con FK obligatoria a `clients` |
| `support_tickets` | Tickets de soporte (reset de contraseña, etc.) |
| `contact_requests` | Solicitudes de cotización de prospectos |
| `schema_version` | Versión actual del schema (`3.0.0`) |

La base de datos incluye migración automática desde schemas v1.x y v2.x al iniciar.

---

## Flujo principal

```
1. Login
   Flutter Web → POST /api/auth/login
   Flask valida credenciales (SHA-256 + salt + secrets.compare_digest)
   Retorna { token, client } — sin password_hash

2. Requests autenticadas
   Flutter incluye:  Authorization: Bearer <token>
   Flask valida token en tabla sessions (expiry + client_status = enabled)
   Cualquier token inválido / expirado → 401

3. Evaluación de riesgo
   POST /api/assessments { client_id, pack_id, answers }
   Flask verifica client_id == token owner (ownership check)
   Risk Engine calcula score ponderado + recomendaciones priorizadas
   SHA-256 assessment_hash de integridad
   SQLite persiste con FK a clients

4. Logout
   POST /api/auth/logout
   Token invalidado en la tabla sessions
   AppState limpiado en Flutter
```

---

## Seguridad implementada

| Control | Implementación |
|---------|---------------|
| **Autenticación Bearer** | `login_required` en todos los endpoints sensibles; token de 32 bytes URL-safe, expiración configurable |
| **Ownership enforcement** | Todos los recursos (clientes, evaluaciones) solo accesibles por su propietario |
| **IDOR prevention** | GET /clients y GET /clients/\<id\> filtrados al cliente autenticado; cualquier otro → 403 |
| **Logout activo** | `DELETE /auth/logout` invalida el token en la tabla `sessions` |
| **Self-lockout prevention** | `PUT /clients/<id>` rechaza cambios de `client_status` (operación de admin) |
| **TOCTOU race condition** | `INSERT` envuelto en `try/except IntegrityError` → 409 determinista |
| SQL Injection | Queries parametrizadas en todos los endpoints |
| Contraseñas | SHA-256 + salt aleatorio por usuario + `secrets.compare_digest` |
| Secrets | Variables de entorno via `.env` (nunca hardcoded); fail-fast si falta `SECRET_KEY` |
| CORS | Lista blanca de orígenes; auto-detecta URLs de Codespaces |
| Errores | JSON limpio — sin stack traces expuestos al cliente |
| Input sanitization | Strip + chars de control + strip HTML tags + longitud máxima |
| Security headers | `X-Frame-Options`, `X-Content-Type-Options`, `Referrer-Policy`, `Permissions-Policy`, `CSP` |
| Enumeración | Login devuelve mensaje genérico para email inexistente y password incorrecto |
| Estado cliente | `client_status` (enabled / blocked / disabled) — bloqueo antes de verificar password |
| Integridad | SHA-256 hash por evaluación (`assessment_hash`) |
| UUID references | Tickets y solicitudes usan UUIDs v4 — sin IDs secuenciales expuestos |
| FK enforcement | `PRAGMA foreign_keys = ON` + `PRAGMA journal_mode = WAL` |
| Debug | `False` por defecto; solo activable via `FLASK_DEBUG=true` en `.env` |

---

## Tests

```bash
# Desde la raíz del proyecto
/workspaces/tds-sentinel-mvp/.venv/bin/python3 -m pytest backend/tests/ -v
```

Suite actual: **23 tests** cubriendo login, validación de campos, credenciales incorrectas, estados de cuenta y métodos HTTP.

---

## Equipo

**Empresa:** TDS Innovate LLC — *Built secure. Built to scale.*  
**Desarrollador:** Daniel Munoz · hello@danielmunoz.us  
**Asignatura:** Taller de Desarrollo Web y Móvil · Sumativa 4  
**Stack:** Flask + SQLite + Flutter Web
