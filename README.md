# TDS Sentinel — Cybersecurity Risk Intelligence Platform

> **Built secure. Built to scale.**  
> Plataforma de evaluación de riesgos de ciberseguridad para PYMEs.

**Versión:** 3.0.0 · **QA:** ✅ Aprobado · **Fecha:** Mayo 2026

---

## ¿Qué es TDS Sentinel?

TDS Sentinel permite a empresas evaluar su nivel de riesgo de ciberseguridad mediante cuestionarios de controles ponderados. El sistema calcula un score automatizado, determina el nivel de riesgo y genera recomendaciones priorizadas por consultores de TDS Innovate LLC.

---

## Stack

```
Flutter Web  →  Flask (static + API)  →  SQLite
  (Dart)           (Python 3)            (schema v3)
```

Flask actúa como servidor único: sirve el build de Flutter Web como archivos estáticos y expone la REST API bajo `/api/*`.

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
│   ├── app.py                      ← Flask app + blueprints + static serving
│   ├── config.py                   ← Configuración via .env
│   ├── database.py                 ← SQLite schema v3 + migraciones
│   ├── risk_engine.py              ← Motor de scoring
│   ├── server.py                   ← Entrada alternativa (gunicorn-ready)
│   ├── routes/
│   │   ├── auth.py                 ← /auth/login · /auth/forgot-password · /auth/contact
│   │   ├── clients.py              ← CRUD /api/clients
│   │   ├── packs.py                ← GET /api/packs
│   │   └── assessments.py          ← CRUD /api/assessments
│   ├── tests/
│   │   ├── conftest.py
│   │   └── test_auth_login.py
│   ├── .env.example
│   ├── requirements.txt
│   └── .gitignore
├── mobile/sentinel_mobile/
│   ├── lib/
│   │   ├── main.dart
│   │   ├── config/api_config.dart  ← URLs centralizadas (same-origin en web)
│   │   ├── theme/app_theme.dart
│   │   ├── models/                 ← risk_assessment, client, assessment_pack, app_state
│   │   ├── services/api_service.dart
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
│   ├── README-dev.md
│   ├── architecture/system-context.md
│   ├── flows/risk-evaluation-flow.md
│   └── security/security-controls.md
├── rebuild_web.sh                  ← Recompila Flutter Web y actualiza el build
└── README.md
```

---

## Endpoints API

### Autenticación

| Método | Ruta | Descripción |
|--------|------|-------------|
| POST | `/api/auth/login` | Login con email + contraseña |
| POST | `/api/auth/forgot-password` | Solicitar reset de contraseña (crea ticket) |
| POST | `/api/auth/contact` | Solicitud de cotización (nuevo cliente) |

### Clientes

| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | `/api/clients` | Listar clientes |
| POST | `/api/clients` | Crear cliente |
| GET | `/api/clients/<id>` | Detalle de cliente |
| PUT | `/api/clients/<id>` | Actualizar cliente |
| DELETE | `/api/clients/<id>` | Eliminar cliente (409 si tiene evaluaciones) |
| GET | `/api/clients/<id>/assessments` | Historial de evaluaciones de un cliente |

### Evaluaciones

| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | `/api/health` | Estado de la API |
| GET | `/api/packs` | Catálogo de assessment packs |
| POST | `/api/assessments` | Crear evaluación (requiere `client_id`) |
| GET | `/api/assessments` | Listar evaluaciones (JOIN con clients) |
| GET | `/api/assessments/<id>` | Detalle de evaluación |
| DELETE | `/api/assessments/<id>` | Eliminar evaluación |

---

## Schema de base de datos v3.0.0

| Tabla | Descripción |
|-------|-------------|
| `clients` | Empresas registradas — autenticación + datos empresariales |
| `risk_assessments` | Evaluaciones con FK obligatoria a `clients` |
| `support_tickets` | Tickets de soporte (reset de contraseña, etc.) |
| `contact_requests` | Solicitudes de cotización de prospectos |
| `schema_version` | Versión actual del schema (`3.0.0`) |

La base de datos incluye migración automática desde schemas v1.x y v2.x al iniciar.

---

## Flujo principal

```
Usuario inicia sesión
    → Flutter Web → POST /api/auth/login
    → Flask valida credenciales (bcrypt-style SHA-256 + salt)
    → Retorna datos del cliente (sin password_hash)

Usuario completa evaluación
    → Flutter envía POST /api/assessments (con client_id)
    → Flask valida input y verifica client_id
    → Risk Engine calcula score ponderado
    → Risk Engine genera recomendaciones priorizadas
    → Se genera SHA-256 hash de integridad
    → SQLite persiste el registro completo (FK a clients)
    → Flutter muestra resultado + recomendaciones
    → Historial disponible en GET /api/clients/<id>/assessments
```

---

## Seguridad implementada

| Control | Implementación |
|---------|---------------|
| SQL Injection | Queries parametrizadas en todos los endpoints |
| Contraseñas | SHA-256 con salt aleatorio por usuario + `secrets.compare_digest` |
| Secrets | Variables de entorno via `.env` (nunca hardcoded) |
| CORS | Lista blanca de orígenes; auto-detecta URLs de Codespaces |
| Errores | JSON limpio — sin stack traces expuestos |
| Input | Strip + eliminación de chars de control + longitud máxima |
| Integridad | SHA-256 hash por evaluación |
| Debug | `False` por defecto en producción |
| FK enforcement | `PRAGMA foreign_keys = ON` |
| Config fail-fast | `validate()` lanza error si falta `SECRET_KEY` |
| Enumeración | Login devuelve mensaje genérico si email no existe |
| Estado cliente | `client_status` (enabled / blocked / disabled) con bloqueo activo |

---

## Equipo

**Empresa:** TDS Innovate LLC — *Built secure. Built to scale.*  
**Desarrollador:** Daniel Munoz · hello@danielmunoz.us  
**Asignatura:** Taller de Desarrollo Web y Móvil · Sumativa 4  
**Stack:** Flask + SQLite + Flutter Web  
