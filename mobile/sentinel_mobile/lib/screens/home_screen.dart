// lib/screens/home_screen.dart — TDS Sentinel
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../models/risk_assessment.dart';
import '../widgets/assessment_card.dart';
import '../widgets/risk_badge.dart';
import 'assessment_form_screen.dart';
import 'assessment_history_screen.dart';
import 'assessment_result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<RiskAssessment> _recent = [];
  bool _loading = true;
  String? _error;
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    setState(() { _loading = true; _error = null; });
    try {
      final all = await ApiService.instance.fetchAssessments();
      setState(() { _recent = all.take(3).toList(); _loading = false; });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    }
  }

  void _goToForm() async {
    final result = await Navigator.push<RiskAssessment>(
      context,
      MaterialPageRoute(builder: (_) => const AssessmentFormScreen()),
    );
    if (result != null && mounted) {
      Navigator.push(context,
        MaterialPageRoute(builder: (_) => AssessmentResultScreen(assessment: result)));
      _loadRecent();
    }
  }

  Future<void> _confirmDelete(RiskAssessment a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar evaluación'),
        content: Text('¿Eliminar la evaluación de ${a.companyName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: AppColors.riskHigh))),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await ApiService.instance.deleteAssessment(a.id);
        _loadRecent();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Evaluación eliminada'), backgroundColor: AppColors.navyDark));
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
      backgroundColor: AppColors.navyDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Row(
        children: [
          // Logo TDS icon placeholder (blanco sobre navy)
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.coreGreen,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.shield_rounded, color: AppColors.white, size: 20),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TDS Sentinel',
                style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              Text('Plataforma de Riesgo',
                style: TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
          const Spacer(),
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.notifications_none_rounded, color: Colors.white70, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: _loadRecent,
      color: AppColors.navyDark,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Stat summary
          _buildStatsRow(),
          const SizedBox(height: 20),
          // CTA button
          ElevatedButton.icon(
            onPressed: _goToForm,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nueva Evaluación'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.coreGreen,
              foregroundColor: AppColors.white,
            ),
          ),
          const SizedBox(height: 24),
          // Recent evaluations
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Evaluaciones recientes',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMain)),
              TextButton(
                onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AssessmentHistoryScreen())).then((_) => _loadRecent()),
                child: const Text('Ver todas', style: TextStyle(fontSize: 12, color: AppColors.navyDark)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildRecentList(),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final total = _recent.length;
    final levels = _recent.map((a) => a.riskLevel).toList();

    return Row(
      children: [
        _StatBox(value: '$total', label: 'Recientes', icon: Icons.assessment_rounded),
        const SizedBox(width: 10),
        _StatBox(
          value: levels.where((l) => l == 'HIGH' || l == 'CRITICAL').length.toString(),
          label: 'Alto riesgo',
          icon: Icons.warning_amber_rounded,
          color: AppColors.riskHigh,
        ),
        const SizedBox(width: 10),
        _StatBox(
          value: levels.where((l) => l == 'LOW').length.toString(),
          label: 'Bajo riesgo',
          icon: Icons.check_circle_rounded,
          color: AppColors.riskLow,
        ),
      ],
    );
  }

  Widget _buildRecentList() {
    if (_loading) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(color: AppColors.navyDark, strokeWidth: 2),
      ));
    }
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _loadRecent);
    }
    if (_recent.isEmpty) {
      return const _EmptyState();
    }
    return Column(
      children: _recent.map((a) => AssessmentCard(
        assessment: a,
        onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => AssessmentResultScreen(assessment: a))),
        onDelete: () => _confirmDelete(a),
      )).toList(),
    );
  }

  Widget _buildBottomNav() {
    return NavigationBar(
      selectedIndex: _navIndex,
      onDestinationSelected: (i) {
        if (i == 1) {
          Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AssessmentHistoryScreen())).then((_) => _loadRecent());
        } else if (i == 2) {
          _goToForm();
        } else {
          setState(() => _navIndex = i);
        }
      },
      backgroundColor: AppColors.cardBg,
      indicatorColor: AppColors.navyDark.withValues(alpha: 0.08),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Inicio'),
        NavigationDestination(icon: Icon(Icons.history_rounded), label: 'Historial'),
        NavigationDestination(icon: Icon(Icons.add_circle_rounded), label: 'Evaluar'),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatBox({required this.value, required this.label, required this.icon,
      this.color = AppColors.navyDark});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.shield_outlined, size: 48, color: AppColors.divider),
            SizedBox(height: 12),
            Text('Sin evaluaciones aún', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            SizedBox(height: 4),
            Text('Crea la primera evaluación con el botón de arriba.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12), textAlign: TextAlign.center),
          ],
        ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.wifi_off_rounded, size: 40, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
