import 'package:flutter/material.dart';
import '../models/risk_assessment.dart';

/// Paleta de colores semántica por nivel de riesgo.
const _riskColors = {
  'Low': Color(0xFF2E7D32),
  'Medium': Color(0xFFF57F17),
  'High': Color(0xFFE65100),
  'Critical': Color(0xFFB71C1C),
};

/// Card reutilizable que muestra el resumen de una evaluación de riesgo.
class AssessmentCard extends StatelessWidget {
  final RiskAssessment assessment;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const AssessmentCard({
    super.key,
    required this.assessment,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final riskColor =
        _riskColors[assessment.riskLevel] ?? const Color(0xFF616161);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado coloreado con empresa y nivel de riesgo.
          Container(
            decoration: BoxDecoration(
              color: riskColor.withOpacity(0.12),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    assessment.companyName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    assessment.riskLevel,
                    style: TextStyle(
                      color: riskColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: riskColor.withOpacity(0.15),
                  side: BorderSide(color: riskColor, width: 1),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          // Cuerpo con activo y recomendación.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  icon: Icons.devices,
                  label: 'Activo',
                  value: assessment.assetName,
                ),
                const SizedBox(height: 4),
                _InfoRow(
                  icon: Icons.lightbulb_outline,
                  label: 'Recomendación',
                  value: assessment.recommendation,
                ),
              ],
            ),
          ),
          // Acciones editar / eliminar.
          OverflowBar(
            alignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Editar'),
              ),
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 18,
                    color: Colors.red),
                label: const Text('Eliminar',
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Text('$label: ',
            style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500)),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
              maxLines: 2),
        ),
      ],
    );
  }
}
