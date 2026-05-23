// lib/screens/assessment_result_screen.dart — TDS Sentinel
import 'package:flutter/material.dart';
import '../models/risk_assessment.dart';
import '../theme/app_theme.dart';
import '../widgets/risk_badge.dart';
import '../widgets/recommendation_card.dart';
import 'assessment_history_screen.dart';

class AssessmentResultScreen extends StatelessWidget {
  final RiskAssessment assessment;

  const AssessmentResultScreen({super.key, required this.assessment});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultado'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const AssessmentHistoryScreen()),
              (route) => route.isFirst,
            ),
            child: const Text('Ver historial',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Score circle
          _ScoreCircle(assessment: assessment),
          const SizedBox(height: 20),

          // Metadata card
          _MetaCard(assessment: assessment),
          const SizedBox(height: 20),

          // Recommendations
          if (assessment.recommendations.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.tips_and_updates_rounded,
                    size: 16, color: AppColors.navyDark),
                const SizedBox(width: 6),
                Text(
                  'Recomendaciones (${assessment.recommendations.length})',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: AppColors.textMain),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...assessment.recommendations
                .map((r) => RecommendationCard(recommendation: r)),
          ] else
            _AllGoodBanner(),

          const SizedBox(height: 16),

          // Hash reference
          _HashReference(hash: assessment.assessmentHash),
          const SizedBox(height: 8),

          // Actions
          OutlinedButton.icon(
            onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
            icon: const Icon(Icons.home_rounded),
            label: const Text('Volver al inicio'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _ScoreCircle extends StatelessWidget {
  final RiskAssessment assessment;

  const _ScoreCircle({required this.assessment});

  @override
  Widget build(BuildContext context) {
    final color   = AppTheme.riskColor(assessment.riskLevel);
    final bgColor = AppTheme.riskBgColor(assessment.riskLevel);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.white,
              border: Border.all(color: color, width: 4),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${assessment.scoreInt}',
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: color)),
                Text('/100', style: TextStyle(fontSize: 13, color: color.withValues(alpha: 0.7))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          RiskBadge(level: assessment.riskLevel, large: true),
          const SizedBox(height: 8),
          Text(
            _riskDescription(assessment.riskLevel),
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _riskDescription(String level) {
    switch (level.toUpperCase()) {
      case 'LOW':
        return 'Los controles básicos están implementados correctamente.';
      case 'MEDIUM':
        return 'Existen brechas importantes que deben atenderse a corto plazo.';
      case 'HIGH':
        return 'La organización presenta vulnerabilidades significativas. Acción urgente requerida.';
      case 'CRITICAL':
        return 'Nivel de riesgo crítico. Se requieren acciones inmediatas para proteger los activos.';
      default:
        return '';
    }
  }
}

class _MetaCard extends StatelessWidget {
  final RiskAssessment assessment;

  const _MetaCard({required this.assessment});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _Row(label: 'Empresa', value: assessment.companyName),
            _Row(label: 'Pack',    value: _packLabel(assessment.packId)),
            _Row(label: 'Fecha',       value: _formatDate(assessment.createdAt)),
            _Row(label: 'Controles',   value: '${assessment.answers.length} evaluados'),
          ],
        ),
      ),
    );
  }

  String _packLabel(String id) {
    const labels = {
      'infrastructure_basic': 'Infrastructure Basic Security',
      'network_security':     'Network Security',
    };
    return labels[id] ?? id;
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontSize: 12,
                color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13,
                color: AppColors.textMain, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _AllGoodBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.riskLowBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.riskLow.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_rounded, color: AppColors.riskLow, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '¡Excelente! Todos los controles están implementados. Mantén las buenas prácticas.',
              style: TextStyle(fontSize: 13, color: AppColors.textMain, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _HashReference extends StatelessWidget {
  final String hash;

  const _HashReference({required this.hash});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Referencia de integridad',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: AppColors.textSecondary, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(
            hash,
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary,
                fontFamily: 'monospace'),
            maxLines: 2, overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
