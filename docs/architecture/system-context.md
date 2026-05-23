# TDS Sentinel — System Context (v3.0.0)

## Descripción del sistema

TDS Sentinel evalúa el nivel de riesgo de ciberseguridad de organizaciones mediante cuestionarios de controles ponderados (Assessment Packs). El resultado es un score numérico, un nivel de riesgo y recomendaciones priorizadas.

A partir de **v3.0.0**, el sistema incluye autenticación de clientes, gestión de tickets de soporte y solicitudes de contacto. Flask actúa como servidor unificado que sirve tanto la SPA Flutter Web como la REST API.

---

## Diagrama de contexto

```mermaid
C4Context
    title TDS Sentinel v3 — System Context

    Person(consultant, "Consultor TDS", "Administra clientes y evalúa riesgos desde la plataforma")
    Person(client_user, "Cliente / Responsable TI", "Se autentica y consulta sus evaluaciones de riesgo")
    Person(prospect, "Prospecto", "Solicita cotización desde el formulario de contacto")

    System(sentinel, "TDS Sentinel", "Plataforma de evaluación de riesgo de ciberseguridad. Autenticación, scoring, recomendaciones y gestión de tickets.")

    System_Ext(sqlite, "SQLite", "Base de datos local (schema v3). Persiste clientes, evaluaciones, tickets y solicitudes.")

    Rel(consultant, sentinel, "Gestiona clientes y evaluaciones", "Flutter Web / HTTPS")
    Rel(client_user, sentinel, "Inicia sesión y consulta evaluaciones", "Flutter Web / HTTPS")
    Rel(prospect, sentinel, "Envía solicitud de contacto", "Flutter Web / HTTPS")
    Rel(sentinel, sqlite, "Lee y escribe datos", "SQL parametrizado")
```

---

## Diagrama de contenedores

```mermaid
C4Container
    title TDS Sentinel v3 — Container Diagram

    Person(user, "Usuario (Consultor / Cliente / Prospecto)")

    Container(web, "Flutter Web App", "Dart / Flutter → build/web", "SPA compilada. Login, evaluaciones, historial, formulario de contacto.")
    Container(flask, "Flask Server", "Python 3 / Flask", "Servidor unificado: sirve la SPA como archivos estáticos y expone la REST API bajo /api/*.")
    Container(engine, "Risk Engine", "Python — risk_engine.py", "Calcula score ponderado, determina nivel de riesgo y genera recomendaciones.")
    ContainerDb(db, "SQLite v3", "SQLite 3", "clients · risk_assessments · support_tickets · contact_requests · schema_version")

    Rel(user, web, "Accede via navegador", "HTTPS")
    Rel(web, flask, "Requests HTTP/JSON", "Same-origin /api/*")
    Rel(flask, web, "Sirve SPA (index.html + assets)", "Static files")
    Rel(flask, engine, "Llama funciones de scoring", "Módulo interno")
    Rel(flask, db, "Lee / escribe", "SQL parametrizado + PRAGMA FK ON")
```

---

## Decisiones de arquitectura

### ¿Por qué Flask sirve la SPA Flutter Web?

En v3, Flask actúa como servidor unificado eliminando la necesidad de un servidor web separado (nginx, etc.) para el MVP:

- Un solo proceso, un solo puerto (5000).
- Sin problemas de CORS en producción — las requests son same-origin.
- Codespaces expone el puerto 5000 con HTTPS automático.
- Rutas no-API devuelven `index.html` para soportar el router de Flutter Web.

Para producción a escala, la separación nginx + gunicorn sigue siendo la arquitectura recomendada.

### ¿Por qué Assessment Packs en código?

Para el MVP, los packs viven en `risk_engine.py` como diccionarios Python:

- Simplifica el desarrollo inicial y elimina migraciones de datos.
- Permite iterar rápido sobre preguntas y pesos.
- La interfaz pública del módulo (`get_pack_by_id`, `calculate_risk_score`) permite mover los packs a una tabla `assessment_packs` sin cambios en las rutas.

### ¿Por qué SQLite?

- Sin dependencias externas de servidor.
- Suficiente para un MVP con carga baja (1 escritura a la vez con WAL mode).
- Schema versionado (`schema_version`) con migraciones automáticas desde v1.x/v2.x.
- `PRAGMA journal_mode = WAL` mejora la concurrencia de lectura.
- Path de migración a PostgreSQL trazado: queries parametrizadas compatibles, sin ORM.

### ¿Por qué SHA-256 + salt para contraseñas?

`hash_password()` en `database.py` usa `secrets.token_hex(16)` como salt y `hashlib.sha256` para el digest. El salt se almacena junto al hash (`salt:digest`):

- Cada contraseña tiene un salt único → mismo password da hashes distintos.
- `secrets.compare_digest` previene timing attacks en la verificación.
- Para producción real se recomienda migrar a `bcrypt` o `argon2`.

### ¿Por qué SHA-256 en `assessment_hash`?

`assessment_hash` es un hash de integridad, no de seguridad de contraseña:
- Verifica que el registro no fue alterado post-creación.
- Sirve como referencia única de la evaluación.
- No usa salt porque su propósito es reproducibilidad, no autenticación.

### ¿Por qué `client_status` en clients?

El campo `client_status` (enabled / blocked / disabled) permite:
- Bloquear acceso sin eliminar datos históricos.
- Distinguir cuentas temporalmente bloqueadas (`blocked`) de deshabilitadas permanentemente (`disabled`).
- El check ocurre antes de verificar la contraseña (falla rápido con 403).
