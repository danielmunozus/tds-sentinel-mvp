// lib/screens/assessment_history_screen.dart — TDS Sentinel
import 'package:flutter/material.dart';
import '../models/app_state.dart';
import '../models/risk_assessment.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/assessment_card.dart';
import 'assessment_result_screen.dart';

class AssessmentHistoryScreen extends StatefulWidget {
  const AssessmentHistoryScreen({super.key});

  @override
  State<AssessmentHistoryScreen> createState() => _AssessmentHistoryScreenState();
}

class _AssessmentHistoryScreenState extends State<AssessmentHistoryScreen> {
  List<RiskAssessment> _assessments = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.instance
          .fetchClientAssessments(AppState.instance.client!.id);
      setState(() { _assessments = data; _loading = false; });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _confirmDelete(RiskAssessment a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar evaluación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Eliminar la evaluación de ${a.companyName}?'),
            const SizedBox(height: 8),
            const Text('Esta acción no se puede deshacer.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.riskHigh),
            child: const Text('Eliminar')),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ApiService.instance.deleteAssessment(a.id);
        setState(() => _assessments.removeWhere((x) => x.id == a.id));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evaluación eliminada'),
            backgroundColor: AppColors.navyDark));
        }
      } on ApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.riskHigh));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar',
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.navyDark))
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : _assessments.isEmpty
                  ? const _EmptyState()
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.navyDark,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _assessments.length,
                        itemBuilder: (ctx, i) {
                          final a = _assessments[i];
                          return AssessmentCard(
                            assessment: a,
                            onTap: () => Navigator.push(context,
                              MaterialPageRoute(
                                builder: (_) => AssessmentResultScreen(assessment: a))),
                            onDelete: () => _confirmDelete(a),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 56, color: AppColors.divider),
          SizedBox(height: 16),
          Text('Sin evaluaciones', style: TextStyle(fontSize: 16,
              fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          SizedBox(height: 6),
          Text('Las evaluaciones completadas aparecerán aquí.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
