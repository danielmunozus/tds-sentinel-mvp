# TDS Sentinel — Cybersecurity Risk Intelligence Platform

> **Built secure. Built to scale.**  
> Plataforma de evaluación de riesgos de ciberseguridad para PYMEs.

---

## ¿Qué es TDS Sentinel?

TDS Sentinel permite a empresas evaluar su nivel de riesgo de ciberseguridad mediante cuestionarios de controles ponderados. El sistema calcula un score automatizado, determina el nivel de riesgo y genera recomendaciones priorizadas por consultores de TDS Innovate LLC.

---

## Stack

```
Flutter Mobile  →  Flask REST API  →  SQLite
   (Dart)            (Python 3)
```

---

## Correr en 3 pasos (local macOS)

### 1. Backend

```bash
cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# Editar .env y completar SECRET_KEY:
# python3 -c "import secrets; print(secrets.token_hex(32))"
python3 app.py
```

Verificar: `curl http://127.0.0.1:5000/api/health`

### 2. Flutter

```bash
cd mobile/sentinel_mobile
flutter pub get
flutter run
```

> Si usas emulador Android, cambia `baseUrl` en `lib/config/api_config.dart`:  
> `http://10.0.2.2:5000/api`

### 3. Correr en Codespaces

Abre el repositorio en GitHub → **Code → Codespaces → Create codespace**.  
El entorno instala dependencias automáticamente.  
Corre `cd backend && python3 app.py` para levantar la API.

---

## Estructura del proyecto

```
tds-sentinel-mvp/
├── .devcontainer/
│   └── devcontainer.json       ← Codespaces config
├── backend/
│   ├── app.py                  ← Flask app + blueprints
│   ├── config.py               ← Configuración via .env
│   ├── database.py             ← SQLite + schema
│   ├── risk_engine.py          ← Motor de scoring
│   ├── routes/
│   │   ├── packs.py            ← GET /api/packs
│   │   └── assessments.py      ← CRUD /api/assessments
│   ├── .env.example
│   ├── requirements.txt
│   └── .gitignore
├── mobile/sentinel_mobile/
│   ├── lib/
│   │   ├── main.dart
│   │   ├── config/api_config.dart
│   │   ├── theme/app_theme.dart
│   │   ├── models/
│   │   ├── services/api_service.dart
│   │   ├── screens/
│   │   └── widgets/
│   └── pubspec.yaml
├── docs/
│   ├── README-dev.md
│   ├── architecture/
│   ├── flows/
│   └── security/
└── README.md
```

---

## Endpoints API

| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | `/api/health` | Estado de la API |
| GET | `/api/packs` | Catálogo de assessment packs |
| POST | `/api/assessments` | Crear evaluación |
| GET | `/api/assessments` | Listar evaluaciones |
| GET | `/api/assessments/<id>` | Detalle de evaluación |
| PUT | `/api/assessments/<id>` | Actualizar evaluación |
| DELETE | `/api/assessments/<id>` | Eliminar evaluación |

---

## Flujo principal

```
Usuario completa checklist
    → Flutter valida y envía POST /api/assessments
    → Flask valida input (sanitización + tipado)
    → Risk Engine calcula score ponderado
    → Risk Engine genera recomendaciones priorizadas
    → Se genera SHA-256 hash de integridad
    → SQLite persiste el registro completo
    → Flutter muestra resultado + recomendaciones
    → Historial disponible en GET /api/assessments
```

---

## Seguridad implementada

| Control | Implementación |
|---------|---------------|
| SQL Injection | Queries parametrizadas en todos los endpoints |
| Secrets | Variables de entorno via `.env` (nunca hardcoded) |
| CORS | Lista blanca de orígenes (no `*`) |
| Errores | JSON limpio — sin stack traces expuestos |
| Input | Sanitización de caracteres de control + longitud máxima |
| Integridad | SHA-256 hash por evaluación |
| Debug | `False` por defecto en producción |
| Host | `127.0.0.1` en desarrollo (nunca `0.0.0.0`) |

---

## Equipo

**Empresa:** TDS Innovate — *Built secure. Built to scale.*
**Desarrollador:** Daniel Munoz · hello@danielmunoz.us
**Asignatura:** Taller de Desarrollo Web y Móvil · Sumativa 4  
**Stack:** Flask + SQLite + Flutter  



