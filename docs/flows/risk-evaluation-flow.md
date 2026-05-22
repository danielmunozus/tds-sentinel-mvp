# TDS Sentinel — Risk Evaluation Flow

## Flujo completo de evaluación

```mermaid
sequenceDiagram
    actor U as Usuario
    participant F as Flutter App
    participant A as Flask API
    participant E as Risk Engine
    participant D as SQLite

    U->>F: Completa formulario (empresa, responsable, respuestas)
    F->>F: Valida campos requeridos y respuestas
    F->>A: POST /api/assessments (JSON)

    A->>A: Valida Content-Type y JSON
    A->>A: Sanitiza campos de texto
    A->>A: Verifica pack_id existe
    A->>A: Valida respuestas (yes/partial/no)

    A->>E: calculate_risk_score(pack_id, answers)
    E->>E: Calcula score ponderado
    E->>E: Determina risk_level
    E-->>A: {score, risk_level, ...}

    A->>E: generate_recommendations(pack_id, answers)
    E->>E: Filtra controles con partial/no
    E->>E: Ordena por prioridad y peso
    E-->>A: [{control_id, priority, recommendation}, ...]

    A->>A: Genera SHA-256 assessment_hash
    A->>D: INSERT INTO risk_assessments (...)
    D-->>A: id del nuevo registro
    A->>D: SELECT * WHERE id = new_id
    D-->>A: Registro completo

    A-->>F: HTTP 201 + JSON completo
    F->>F: Navega a ResultScreen
    F->>U: Muestra score, nivel y recomendaciones
```

## Lógica de scoring

### Valores de riesgo por respuesta

| Respuesta | Factor de riesgo |
|-----------|-----------------|
| `yes`     | 0.0 × weight |
| `partial` | 0.5 × weight |
| `no`      | 1.0 × weight |

### Pack: Infrastructure Basic Security

| Control    | Peso | Justificación |
|------------|------|---------------|
| `mfa`      | 25   | Acceso no autorizado es el vector más frecuente |
| `backups`  | 25   | Sin respaldo, un ransomware puede ser catastrófico |
| `antivirus`| 20   | Protección básica de endpoints |
| `firewall` | 20   | Segmentación y control de red |
| `training` | 10   | Humanos son el eslabón más débil |
| **Total**  | **100** | |

### Umbrales de nivel de riesgo

| Rango | Nivel | Descripción |
|-------|-------|-------------|
| 0% – 25% | LOW | Controles bien implementados |
| 26% – 50% | MEDIUM | Brechas que atender a corto plazo |
| 51% – 75% | HIGH | Vulnerabilidades significativas |
| 76% – 100% | CRITICAL | Acción inmediata requerida |

### Ejemplo de cálculo

```
Respuestas:
  mfa      = yes     → 0.0 × 25 = 0
  backups  = no      → 1.0 × 25 = 25
  antivirus= yes     → 0.0 × 20 = 0
  firewall = partial → 0.5 × 20 = 10
  training = no      → 1.0 × 10 = 10

score_raw     = 45 / 100 = 45%  → MEDIUM
score_display = (1 - 0.45) × 100 = 55  (invertido para UX: mayor = mejor)
```
