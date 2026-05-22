"""
risk_engine.py — TDS Sentinel
Motor de evaluación de riesgo de ciberseguridad.

Lógica principal:
  Assessment Packs → weighted controls → scoring → risk level → recommendations

Diseño deliberado: los packs viven en código para el MVP.
La arquitectura permite moverlos a DB en versiones futuras sin cambiar
la interfaz pública de este módulo.
"""

from __future__ import annotations
import logging
from typing import Any

logger = logging.getLogger(__name__)

# ──────────────────────────────────────────────────────────────────────────────
# Constantes
# ──────────────────────────────────────────────────────────────────────────────

# Valores de riesgo por respuesta
ANSWER_RISK: dict[str, float] = {
    "yes":     0.0,   # Control implementado → sin riesgo
    "partial": 0.5,   # Control parcial → riesgo proporcional
    "no":      1.0,   # Control ausente → riesgo total
}

VALID_ANSWERS = set(ANSWER_RISK.keys())

# Umbrales de nivel de riesgo (porcentaje del score máximo posible)
RISK_THRESHOLDS = [
    (0.25, "LOW"),
    (0.50, "MEDIUM"),
    (0.75, "HIGH"),
    (1.00, "CRITICAL"),
]

# ──────────────────────────────────────────────────────────────────────────────
# Catálogo de Assessment Packs (MVP — en código)
# Cada control tiene: id, question, weight, recommendation
#
# weight: importancia relativa del control dentro del pack.
# Controles más críticos tienen mayor peso.
# ──────────────────────────────────────────────────────────────────────────────

_ASSESSMENT_PACKS: dict[str, dict[str, Any]] = {

    "infrastructure_basic": {
        "id":          "infrastructure_basic",
        "name":        "Infrastructure Basic Security",
        "description": "Evaluación de controles fundamentales de infraestructura "
                       "para pequeñas y medianas empresas.",
        "version":     "1.0",
        "controls": [
            {
                "id":             "mfa",
                "question":       "¿La organización utiliza autenticación multifactor (MFA) "
                                  "en sus sistemas críticos?",
                "weight":         25,
                "recommendation": "Implemente MFA en todos los accesos críticos: correo "
                                  "corporativo, VPN, sistemas financieros y plataformas "
                                  "en la nube. Use una app autenticadora (Google Authenticator, "
                                  "Microsoft Authenticator) en lugar de SMS cuando sea posible.",
            },
            {
                "id":             "backups",
                "question":       "¿Se realizan copias de seguridad periódicas y se verifican "
                                  "su restauración?",
                "weight":         25,
                "recommendation": "Establezca una política de respaldo 3-2-1: 3 copias, "
                                  "2 medios distintos, 1 offsite o en la nube. "
                                  "Automatice los backups y pruebe la restauración al menos "
                                  "una vez al mes.",
            },
            {
                "id":             "antivirus",
                "question":       "¿Todos los equipos de la organización cuentan con "
                                  "antivirus/antimalware activo y actualizado?",
                "weight":         20,
                "recommendation": "Instale una solución de endpoint protection en todos los "
                                  "dispositivos corporativos. Active las actualizaciones "
                                  "automáticas de firmas y programe escaneos periódicos. "
                                  "Considere soluciones EDR para mayor protección.",
            },
            {
                "id":             "firewall",
                "question":       "¿La organización cuenta con firewall configurado y activo "
                                  "en su perímetro de red?",
                "weight":         20,
                "recommendation": "Configure un firewall perimetral con política de denegación "
                                  "por defecto. Revise y documente las reglas activas. "
                                  "Implemente segmentación de red separando la WiFi de "
                                  "invitados de la red operacional.",
            },
            {
                "id":             "training",
                "question":       "¿El personal recibe capacitación periódica en "
                                  "ciberseguridad y concientización sobre phishing?",
                "weight":         10,
                "recommendation": "Implemente un programa de concientización en seguridad "
                                  "al menos dos veces al año. Incluya simulaciones de phishing, "
                                  "buenas prácticas de contraseñas y procedimientos ante "
                                  "incidentes. El factor humano es el vector de ataque "
                                  "más frecuente.",
            },
        ],
    },

    "network_security": {
        "id":          "network_security",
        "name":        "Network Security Assessment",
        "description": "Evaluación de controles de seguridad de red para "
                       "organizaciones con infraestructura crítica de conectividad.",
        "version":     "1.0",
        "controls": [
            {
                "id":             "perimeter_firewall",
                "question":       "¿La organización cuenta con un firewall perimetral "
                                  "correctamente configurado con reglas de denegación por defecto?",
                "weight":         25,
                "recommendation": "Implemente un NGFW (Next-Generation Firewall) con inspección "
                                  "profunda de paquetes. Establezca una política de denegación "
                                  "por defecto y documente cada regla activa con su justificación "
                                  "de negocio. Revise y audite las reglas trimestralmente.",
            },
            {
                "id":             "network_segmentation",
                "question":       "¿La red está segmentada en zonas (DMZ, producción, usuarios, "
                                  "invitados) con controles de acceso entre segmentos?",
                "weight":         25,
                "recommendation": "Implemente segmentación de red mediante VLANs y micro-segmentación. "
                                  "Separe al menos: red de servidores, red de usuarios, DMZ y red de "
                                  "invitados. Controle el tráfico inter-VLAN con listas de acceso o "
                                  "firewalls internos. Aplique el principio de mínimo privilegio.",
            },
            {
                "id":             "vpn",
                "question":       "¿El acceso remoto a la red corporativa se realiza exclusivamente "
                                  "mediante VPN con autenticación robusta?",
                "weight":         20,
                "recommendation": "Implemente una solución VPN empresarial (IPSec/SSL) con MFA "
                                  "obligatorio. Elimine cualquier acceso RDP o SSH directo desde "
                                  "internet. Registre todas las sesiones VPN y configure alertas "
                                  "por accesos inusuales. Considere arquitectura Zero Trust.",
            },
            {
                "id":             "traffic_monitoring",
                "question":       "¿La organización monitorea activamente el tráfico de red "
                                  "para detectar anomalías y actividad sospechosa en tiempo real?",
                "weight":         15,
                "recommendation": "Implemente un sistema IDS/IPS y herramientas de análisis de "
                                  "flujo de red (NetFlow, sFlow). Configure alertas para tráfico "
                                  "anómalo: conexiones a IPs maliciosas, exfiltración de datos, "
                                  "escaneos de puertos. Integre con un SIEM para correlación.",
            },
            {
                "id":             "security_logs",
                "question":       "¿Los dispositivos de red generan logs de seguridad centralizados, "
                                  "retenidos por al menos 90 días y revisados periódicamente?",
                "weight":         15,
                "recommendation": "Configure logging centralizado en todos los dispositivos de red. "
                                  "Use un servidor Syslog o SIEM. Retenga logs por mínimo 90 días "
                                  "(preferiblemente 1 año para compliance). Establezca revisión "
                                  "semanal y alertas automáticas por patrones anómalos.",
            },
        ],
    },

}


# ──────────────────────────────────────────────────────────────────────────────
# API pública del módulo
# ──────────────────────────────────────────────────────────────────────────────

def get_assessment_packs() -> list[dict[str, Any]]:
    """
    Retorna el catálogo completo de assessment packs disponibles.
    Devuelve una copia limpia sin mutar el catálogo interno.
    """
    return [
        {
            "id":          pack["id"],
            "name":        pack["name"],
            "description": pack["description"],
            "version":     pack["version"],
            "controls":    [
                {
                    "id":       control["id"],
                    "question": control["question"],
                    "weight":   control["weight"],
                }
                for control in pack["controls"]
            ],
        }
        for pack in _ASSESSMENT_PACKS.values()
    ]


def get_pack_by_id(pack_id: str) -> dict[str, Any] | None:
    """
    Retorna un pack específico por su ID.
    Retorna None si no existe — el caller decide cómo manejar el error.
    """
    return _ASSESSMENT_PACKS.get(pack_id)


def calculate_risk_score(pack_id: str, answers: dict[str, str]) -> dict[str, Any]:
    """
    Calcula el score de riesgo para un conjunto de respuestas.

    Parámetros:
        pack_id: ID del assessment pack a evaluar.
        answers: dict {control_id: answer} donde answer ∈ {yes, partial, no}

    Retorna dict con:
        score_raw      float  — suma ponderada de riesgo (0 a max_score)
        score_percent  float  — porcentaje de riesgo (0.0 a 1.0)
        score_display  int    — score visual invertido (0=peor, 100=mejor)
        risk_level     str    — LOW | MEDIUM | HIGH | CRITICAL
        max_score      int    — score máximo posible del pack
        answered       int    — número de controles respondidos

    Lanza:
        ValueError si pack_id no existe o si alguna respuesta es inválida.
    """
    # Validar pack
    pack = _ASSESSMENT_PACKS.get(pack_id)
    if not pack:
        raise ValueError(f"Pack '{pack_id}' no existe en el catálogo.")

    controls = pack["controls"]

    # Validar que todas las respuestas corresponden a controles del pack
    valid_control_ids = {c["id"] for c in controls}
    for control_id, answer in answers.items():
        if control_id not in valid_control_ids:
            raise ValueError(
                f"Control '{control_id}' no pertenece al pack '{pack_id}'."
            )
        # Normalizar a minúsculas y validar valor
        answer_normalized = str(answer).strip().lower()
        if answer_normalized not in VALID_ANSWERS:
            raise ValueError(
                f"Respuesta inválida '{answer}' para control '{control_id}'. "
                f"Valores aceptados: {sorted(VALID_ANSWERS)}"
            )

    # Calcular score
    score_raw: float = 0.0
    max_score: int = 0
    answered: int = 0

    for control in controls:
        cid = control["id"]
        weight = control["weight"]
        max_score += weight

        if cid in answers:
            answer_norm = answers[cid].strip().lower()
            risk_value = ANSWER_RISK[answer_norm]
            score_raw += risk_value * weight
            answered += 1

    # Si no se respondió ningún control, el riesgo es máximo
    if answered == 0 or max_score == 0:
        score_percent = 1.0
    else:
        score_percent = score_raw / max_score

    # Score visual: 100 = seguro, 0 = crítico (invertido para UX)
    score_display = round((1 - score_percent) * 100)

    # Determinar nivel de riesgo
    risk_level = _calculate_risk_level(score_percent)

    logger.debug(
        "Score calculado — pack=%s raw=%.1f max=%d percent=%.2f level=%s",
        pack_id, score_raw, max_score, score_percent, risk_level
    )

    return {
        "score_raw":     round(score_raw, 2),
        "score_percent": round(score_percent, 4),
        "score_display": score_display,
        "risk_level":    risk_level,
        "max_score":     max_score,
        "answered":      answered,
        "total_controls": len(controls),
    }


def generate_recommendations(pack_id: str, answers: dict[str, str]) -> list[dict[str, Any]]:
    """
    Genera recomendaciones priorizadas basadas en las respuestas.

    Solo retorna recomendaciones para controles con respuesta 'partial' o 'no'.
    Ordena por prioridad: 'no' primero, luego 'partial', dentro de cada grupo
    por peso descendente.

    Parámetros:
        pack_id: ID del assessment pack.
        answers: dict {control_id: answer}

    Retorna lista de dicts con:
        control_id     str
        question       str
        answer         str
        priority       str  — HIGH | MEDIUM
        weight         int
        recommendation str

    Lanza:
        ValueError si pack_id no existe.
    """
    pack = _ASSESSMENT_PACKS.get(pack_id)
    if not pack:
        raise ValueError(f"Pack '{pack_id}' no existe en el catálogo.")

    recommendations: list[dict[str, Any]] = []

    for control in pack["controls"]:
        cid = control["id"]
        answer = answers.get(cid, "").strip().lower()

        # Solo generar recomendación si el control no está completamente implementado
        if answer in ("no", "partial"):
            priority = "HIGH" if answer == "no" else "MEDIUM"
            recommendations.append({
                "control_id":     cid,
                "question":       control["question"],
                "answer":         answer,
                "priority":       priority,
                "weight":         control["weight"],
                "recommendation": control["recommendation"],
            })

    # Ordenar: HIGH primero, luego por peso descendente
    recommendations.sort(
        key=lambda r: (0 if r["priority"] == "HIGH" else 1, -r["weight"])
    )

    return recommendations


# ──────────────────────────────────────────────────────────────────────────────
# Helpers internos
# ──────────────────────────────────────────────────────────────────────────────

def _calculate_risk_level(score_percent: float) -> str:
    """
    Determina el nivel de riesgo a partir del porcentaje de score.

    Umbrales:
        0.00 – 0.25  → LOW
        0.26 – 0.50  → MEDIUM
        0.51 – 0.75  → HIGH
        0.76 – 1.00  → CRITICAL
    """
    for threshold, level in RISK_THRESHOLDS:
        if score_percent <= threshold:
            return level
    return "CRITICAL"
