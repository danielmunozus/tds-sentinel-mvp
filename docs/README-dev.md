# TDS Sentinel — Developer Guide

**TDS Sentinel** es una plataforma académica de evaluación de riesgos de ciberseguridad para PYMEs.  
Stack: Flutter Mobile → Flask REST API → SQLite.

---

## Estructura del proyecto

```
tds-sentinel-mvp/
├── backend/          ← Flask REST API
│   ├── app.py            Punto de entrada
│   ├── config.py         Configuración via variables de entorno
│   ├── database.py       Conexión y schema SQLite
│   ├── risk_engine.py    Motor de scoring (Hito 2)
│   ├── routes/           Blueprints por recurso (Hito 3+)
│   ├── .env.example      Template de variables de entorno
│   ├── .gitignore
│   └── requirements.txt
├── mobile/           ← Flutter app (Hito 4+)
└── docs/             ← Documentación técnica
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

Editar `.env` y completar:

```env
FLASK_DEBUG=true
SECRET_KEY=<genera_uno_con_el_comando_abajo>
PORT=5000
CORS_ORIGINS=http://localhost:5000,http://127.0.0.1:5000
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
[Sentinel] Iniciando TDS Sentinel API en puerto 5000 (debug=True)
```

### 6. Verificar health check

```bash
curl http://127.0.0.1:5000/api/health
```

Respuesta esperada:

```json
{
  "message": "TDS Sentinel API is running",
  "status": "ok",
  "version": "1.0.0"
}
```

---

## Endpoints disponibles por hito

| Hito | Método | Ruta | Descripción |
|------|--------|------|-------------|
| 1 | GET | `/api/health` | Estado de la API |
| 2 | GET | `/api/packs` | Catálogo de assessment packs |
| 3 | POST | `/api/assessments` | Crear evaluación |
| 3 | GET | `/api/assessments` | Listar evaluaciones |
| 3 | GET | `/api/assessments/<id>` | Detalle de evaluación |
| 3 | PUT | `/api/assessments/<id>` | Actualizar evaluación |
| 3 | DELETE | `/api/assessments/<id>` | Eliminar evaluación |

---

## Seguridad implementada

- Variables de entorno para todos los secretos (nunca hardcoded)
- CORS con lista blanca de orígenes
- Queries SQLite parametrizadas (anti SQL injection)
- Errores internos logueados pero no expuestos al cliente
- `debug=False` por defecto en producción
- Host restringido a `127.0.0.1` en desarrollo
- Schema versioning en base de datos

---

## Convenciones de código

- Nombres de variables, funciones y clases: **inglés**
- Comentarios explicativos: **español**
- Respuestas JSON: siempre, sin excepciones
- HTTP status codes: correctos y semánticos

---

## Git workflow

Cada hito se versiona con un commit descriptivo:

```bash
git add .
git commit -m "feat: initialize local Flask backend foundation"
git push origin main
```

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
