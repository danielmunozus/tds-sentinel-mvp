# TDS Sentinel — Developer Guide

**TDS Sentinel** es una plataforma de evaluación de riesgos de ciberseguridad para PYMEs.  
**Versión:** 3.0.0 · **Schema DB:** v3.0.0 · **QA:** ✅ Aprobado (Mayo 2026)

Stack: Flutter Web → Flask (static + API) → SQLite

---

## Estructura del proyecto

```
tds-sentinel-mvp/
├── backend/
│   ├── app.py            Punto de entrada — Flask + blueprints + SPA serving
│   ├── config.py         Configuración via variables de entorno
│   ├── database.py       Schema v3 + migraciones automáticas
│   ├── risk_engine.py    Motor de scoring y recomendaciones
│   ├── server.py         Entrada alternativa (gunicorn-ready)
│   ├── routes/
│   │   ├── auth.py       POST /auth/login · /auth/forgot-password · /auth/contact
│   │   ├── clients.py    CRUD /clients (schema v3)
│   │   ├── packs.py      GET /packs
│   │   └── assessments.py CRUD /assessments (schema v3)
│   ├── tests/
│   │   ├── conftest.py   Fixtures pytest
│   │   └── test_auth_login.py
│   ├── .env.example
│   ├── requirements.txt
│   └── .gitignore
├── mobile/sentinel_mobile/
│   ├── lib/
│   │   ├── config/api_config.dart    URLs centralizadas (same-origin en web)
│   │   ├── models/                   DTOs: client, risk_assessment, assessment_pack, app_state
│   │   ├── services/api_service.dart Capa HTTP centralizada
│   │   ├── screens/                  8 pantallas (login → historial)
│   │   └── widgets/                  Componentes reutilizables
│   └── pubspec.yaml
├── docs/                 Documentación técnica (esta carpeta)
├── rebuild_web.sh        Script para recompilar Flutter Web
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
# DB_PATH=./sentinel.db        (opcional — default: junto al backend)
# FLUTTER_BUILD_DIR=../mobile/sentinel_mobile/build/web  (opcional)
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
  "version": "1.0.0"
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

## Endpoints disponibles — v3

### Autenticación (`routes/auth.py`)

| Método | Ruta | Body requerido | Descripción |
|--------|------|----------------|-------------|
| POST | `/api/auth/login` | `email`, `password` | Autenticación de cliente |
| POST | `/api/auth/forgot-password` | `email` | Ticket de reset de contraseña |
| POST | `/api/auth/contact` | `company_name`, `contact_name`, `email`, `phone` | Solicitud de cotización |

### Clientes (`routes/clients.py`)

| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | `/api/clients` | Listar todos los clientes |
| POST | `/api/clients` | Crear cliente (email único, password hasheado) |
| GET | `/api/clients/<id>` | Detalle de cliente |
| PUT | `/api/clients/<id>` | Actualizar cliente (password opcional) |
| DELETE | `/api/clients/<id>` | Eliminar (409 si tiene evaluaciones) |
| GET | `/api/clients/<id>/assessments` | Historial de un cliente |

### Evaluaciones (`routes/assessments.py`)

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

### Tablas

```sql
clients (
    id, company_name, contact_name, email UNIQUE,
    phone, password_hash, bs_area,
    client_status CHECK (enabled|blocked|disabled),
    created_at, updated_at
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

`database.py` detecta schemas v1.x y v2.x al arrancar y los migra a v3.0.0:
- Recrea `clients` con los nuevos campos (`password_hash`, `bs_area`, `client_status`).
- Recrea `risk_assessments` eliminando `company_name`/`responsible_name`, forzando FK.
- Crea `support_tickets` y `contact_requests` si no existen.
- Clientes migrados reciben contraseña temporal `ChangeMe123!` (logeado por nivel INFO).

---

## Seguridad implementada

### Backend

| Control | Detalle | Archivo |
|---------|---------|---------|
| SQL Injection | Queries parametrizadas con `?` | `routes/*.py` |
| Contraseñas | SHA-256 + salt aleatorio (`secrets.token_hex(16)`) + `secrets.compare_digest` | `database.py` |
| Secrets | `.env` + `python-dotenv`; fail-fast si falta `SECRET_KEY` | `config.py` |
| CORS | Lista blanca; auto-detecta Codespaces | `app.py` + `config.py` |
| Stack traces | Logueados internamente, JSON limpio al cliente | `app.py` |
| Input sanitization | Strip + chars de control + longitud máxima 200/500 chars | `routes/*.py` |
| Integridad | SHA-256 hash por evaluación | `routes/assessments.py` |
| Debug | `False` por defecto; solo via `FLASK_DEBUG=true` | `config.py` |
| FK enforcement | `PRAGMA foreign_keys = ON` + `PRAGMA journal_mode = WAL` | `database.py` |
| Enumeración | Login: mismo mensaje para email no existente o password incorrecto | `routes/auth.py` |
| Estado cliente | `blocked`/`disabled` bloquean login con 403 antes de verificar password | `routes/auth.py` |

### Flutter

| Control | Detalle | Archivo |
|---------|---------|---------|
| Same-origin API | En web, `baseUrl` se deriva del `Uri.base` — sin URLs hardcodeadas | `api_config.dart` |
| Validación formulario | Campos requeridos + trim antes de enviar | `assessment_form_screen.dart` |
| Sin datos sensibles locales | No se persiste nada en el dispositivo | `api_service.dart` |
| Errores amigables | `ApiException` abstrae errores HTTP | `api_service.dart` |
| Timeout | `Duration(seconds: 15)` en todos los requests | `api_config.dart` |
| Confirmación de borrado | `AlertDialog` antes de DELETE | `assessment_history_screen.dart` |

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
cd backend
pytest tests/ -v
```

Test suite actual: `tests/test_auth_login.py` — cubre login exitoso, credenciales inválidas, cliente bloqueado.

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
