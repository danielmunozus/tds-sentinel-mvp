# TDS Sentinel — System Context

## Descripción del sistema

TDS Sentinel evalúa el nivel de riesgo de ciberseguridad de organizaciones mediante cuestionarios de controles ponderados (Assessment Packs). El resultado es un score numérico, un nivel de riesgo y recomendaciones priorizadas.

## Diagrama de contexto

```mermaid
C4Context
    title TDS Sentinel — System Context

    Person(user, "Usuario", "Consultor o responsable TI de la organización evaluada")

    System(sentinel, "TDS Sentinel", "Plataforma de evaluación de riesgo de ciberseguridad. Calcula scores, niveles de riesgo y genera recomendaciones.")

    System_Ext(sqlite, "SQLite", "Base de datos local. Persiste evaluaciones y resultados históricos.")

    Rel(user, sentinel, "Completa checklist de controles", "Flutter Mobile")
    Rel(sentinel, sqlite, "Lee y escribe evaluaciones", "SQL parametrizado")
```

## Diagrama de contenedores

```mermaid
C4Container
    title TDS Sentinel — Container Diagram

    Person(user, "Usuario")

    Container(mobile, "Flutter Mobile App", "Dart / Flutter", "Interfaz móvil. Formulario de evaluación, resultados e historial.")
    Container(api, "Flask REST API", "Python / Flask", "Lógica de negocio. Valida input, ejecuta el risk engine, persiste datos.")
    Container(engine, "Risk Engine", "Python", "Calcula score ponderado, nivel de riesgo y recomendaciones.")
    ContainerDb(db, "SQLite", "SQLite 3", "Almacena evaluaciones, respuestas, scores y recomendaciones.")

    Rel(user, mobile, "Usa", "iOS / Android")
    Rel(mobile, api, "HTTP/JSON", "REST API :5000")
    Rel(api, engine, "Llama funciones", "Módulo interno")
    Rel(api, db, "Lee / escribe", "SQL parametrizado")
```

## Decisiones de arquitectura

### ¿Por qué Assessment Packs en código?

Para el MVP académico, los packs viven en `risk_engine.py` como diccionarios Python. Esta decisión:

- Simplifica el desarrollo inicial
- Elimina la necesidad de migraciones de datos
- Permite iterar rápido sobre preguntas y pesos

La arquitectura permite mover los packs a una tabla `assessment_packs` en SQLite sin cambiar la interfaz pública del módulo.

### ¿Por qué SQLite?

- Sin dependencias externas
- Suficiente para un MVP con carga baja
- El schema está versionado (`schema_version`) para facilitar migración futura a PostgreSQL

### ¿Por qué SHA-256 en las evaluaciones?

`assessment_hash` es un hash de integridad, no de seguridad de contraseña. Permite:
- Verificar que el registro no fue alterado
- Usar como referencia única de la evaluación
- Detectar duplicados exactos

No usa salt porque su propósito es referencia, no autenticación.
