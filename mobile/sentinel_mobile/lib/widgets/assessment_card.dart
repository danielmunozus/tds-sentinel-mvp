// lib/widgets/assessment_card.dart — TDS Sentinel
import 'package:flutter/material.dart';
import '../models/risk_assessment.dart';
import '../theme/app_theme.dart';
import 'risk_badge.dart';

class AssessmentCard extends StatelessWidget {
  final RiskAssessment assessment;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const AssessmentCard({
    super.key,
    required this.assessment,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      assessment.companyName,
                      style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600,
                        color: AppColors.textMain),
                    ),
                  ),
                  RiskBadge(level: assessment.riskLevel),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onDelete,
                    child: const Icon(Icons.delete_outline,
                        size: 20, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _ScoreBar(score: assessment.scoreInt, level: assessment.riskLevel),
                  const SizedBox(width: 12),
                  Text(
                    _formatDate(assessment.createdAt),
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return iso.substring(0, 10);
    }
  }
}

class _ScoreBar extends StatelessWidget {
  final int score;
  final String level;

  const _ScoreBar({required this.score, required this.level});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.riskColor(level);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Score', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              Text('$score/100', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: AppColors.divider,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }
}
