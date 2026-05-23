# TDS Sentinel — Flujos de usuario (v3.0.0)

---

## 1. Flujo de autenticación

```mermaid
sequenceDiagram
    actor U as Usuario
    participant F as Flutter Web
    participant A as Flask API
    participant D as SQLite

    U->>F: Ingresa email + contraseña
    F->>F: Valida campos requeridos
    F->>A: POST /api/auth/login {email, password}

    A->>A: Sanitiza email y password
    A->>A: Valida formato de email
    A->>D: SELECT * FROM clients WHERE LOWER(email) = ?
    D-->>A: row (o null)

    alt Email no existe
        A-->>F: 401 "Email o contraseña incorrectos."
    else client_status = blocked
        A-->>F: 403 "La cuenta está bloqueada."
    else client_status = disabled
        A-->>F: 403 "La cuenta está deshabilitada."
    else Password incorrecto
        A-->>F: 401 "Email o contraseña incorrectos."
    else Login exitoso
        A-->>F: 200 + datos del cliente (sin password_hash)
        F->>F: Guarda sesión en estado de la app
        F->>U: Navega a HomeScreen
    end
```

---

## 2. Flujo de evaluación de riesgo

```mermaid
sequenceDiagram
    actor U as Usuario autenticado
    participant F as Flutter Web
    participant A as Flask API
    participant E as Risk Engine
    participant D as SQLite

    U->>F: Selecciona Assessment Pack
    F->>A: GET /api/packs
    A-->>F: Lista de packs disponibles
    F->>U: Muestra PackSelectionScreen

    U->>F: Completa formulario de controles
    F->>F: Valida campos y respuestas (yes/partial/no)
    F->>A: POST /api/assessments {client_id, pack_id, answers}

    A->>A: Valida Content-Type y JSON
    A->>A: Sanitiza campos de texto
    A->>D: SELECT id FROM clients WHERE id = client_id
    D-->>A: Verifica que el cliente existe

    A->>A: Verifica pack_id existe en Risk Engine
    A->>A: Valida que todas las respuestas son yes/partial/no

    A->>E: calculate_risk_score(pack_id, answers)
    E->>E: Calcula score ponderado
    E->>E: Determina risk_level (LOW/MEDIUM/HIGH/CRITICAL)
    E-->>A: {score, risk_level}

    A->>E: generate_recommendations(pack_id, answers)
    E->>E: Filtra controles con partial/no
    E->>E: Ordena por prioridad y peso
    E-->>A: [{control_id, priority, recommendation}, ...]

    A->>A: Genera SHA-256 assessment_hash
    A->>D: INSERT INTO risk_assessments (client_id, ...)
    D-->>A: id del nuevo registro
    A->>D: SELECT ra.*, c.company_name FROM risk_assessments ra JOIN clients c ...
    D-->>A: Registro completo con datos del cliente

    A-->>F: HTTP 201 + JSON completo
    F->>F: Navega a AssessmentResultScreen
    F->>U: Muestra score, nivel y recomendaciones
```

---

## 3. Flujo de solicitud de reset de contraseña

```mermaid
sequenceDiagram
    actor U as Usuario
    participant F as Flutter Web
    participant A as Flask API
    participant D as SQLite

    U->>F: Ingresa email en ForgotPasswordScreen
    F->>A: POST /api/auth/forgot-password {email}

    A->>A: Valida formato de email
    A->>D: SELECT id FROM clients WHERE LOWER(email) = ?
    Note over A,D: Busca client_id (puede ser null si no existe)

    A->>D: INSERT INTO support_tickets (email, client_id, type='password_reset', status='open')
    D-->>A: ticket_id

    A-->>F: 200 {message, ticket_id}
    Note over A,F: Responde con éxito SIEMPRE — no revela si el email existe
    F->>U: "Un agente de TDS Innovate se pondrá en contacto."
```

---

## 4. Flujo de solicitud de contacto (prospecto)

```mermaid
sequenceDiagram
    actor P as Prospecto
    participant F as Flutter Web
    participant A as Flask API
    participant D as SQLite

    P->>F: Completa ContactFormScreen
    F->>A: POST /api/auth/contact {company_name, contact_name, email, phone, pack_interest?, message?}

    A->>A: Sanitiza todos los campos
    A->>A: Valida formato de email
    A->>D: INSERT INTO contact_requests (...)
    D-->>A: request_id

    A-->>F: 201 {message, request_id}
    F->>P: "El equipo comercial se pondrá en contacto pronto."
```

---

## Lógica de scoring

### Valores de riesgo por respuesta

| Respuesta | Factor de riesgo |
|-----------|-----------------|
| `yes`     | 0.0 × weight |
| `partial` | 0.5 × weight |
| `no`      | 1.0 × weight |

### Pack: Infrastructure Basic Security

| Control     | Peso | Justificación |
|-------------|------|---------------|
| `mfa`       | 25   | Acceso no autorizado es el vector más frecuente |
| `backups`   | 25   | Sin respaldo, un ransomware puede ser catastrófico |
| `antivirus` | 20   | Protección básica de endpoints |
| `firewall`  | 20   | Segmentación y control de red |
| `training`  | 10   | Humanos son el eslabón más débil |
| **Total**   | **100** | |

### Umbrales de nivel de riesgo

| Rango     | Nivel    | Descripción |
|-----------|----------|-------------|
| 0% – 25%  | LOW      | Controles bien implementados |
| 26% – 50% | MEDIUM   | Brechas que atender a corto plazo |
| 51% – 75% | HIGH     | Vulnerabilidades significativas |
| 76% – 100%| CRITICAL | Acción inmediata requerida |

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
