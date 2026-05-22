// lib/widgets/recommendation_card.dart — TDS Sentinel
import 'package:flutter/material.dart';
import '../models/risk_assessment.dart';
import '../theme/app_theme.dart';

class RecommendationCard extends StatelessWidget {
  final Recommendation recommendation;

  const RecommendationCard({super.key, required this.recommendation});

  @override
  Widget build(BuildContext context) {
    final isHigh = recommendation.priority == 'HIGH';
    final borderColor = isHigh ? AppColors.riskHigh : AppColors.riskMedium;
    final iconColor   = isHigh ? AppColors.riskHigh : AppColors.riskMedium;
    final icon        = isHigh ? Icons.warning_rounded : Icons.info_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: borderColor, width: 3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _controlLabel(recommendation.controlId),
                    style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: AppColors.textMain),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    recommendation.recommendation,
                    style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isHigh ? AppColors.riskHighBg : AppColors.riskMediumBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isHigh ? 'Alta prioridad' : 'Prioridad media',
                      style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w600, color: borderColor),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _controlLabel(String controlId) {
    const labels = {
      'mfa':       'Autenticación Multifactor (MFA)',
      'backups':   'Copias de Seguridad',
      'antivirus': 'Antivirus / Antimalware',
      'firewall':  'Firewall',
      'training':  'Capacitación al Personal',
    };
    return labels[controlId] ?? controlId;
  }
}
