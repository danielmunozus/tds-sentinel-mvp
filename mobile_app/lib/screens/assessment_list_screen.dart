import 'package:flutter/material.dart';
import '../models/risk_assessment.dart';
import '../services/api_service.dart';
import '../widgets/assessment_card.dart';
import 'assessment_form_screen.dart';

/// Pantalla principal: lista todas las evaluaciones de riesgo.
class AssessmentListScreen extends StatefulWidget {
  const AssessmentListScreen({super.key});

  @override
  State<AssessmentListScreen> createState() => _AssessmentListScreenState();
}

class _AssessmentListScreenState extends State<AssessmentListScreen> {
  List<RiskAssessment> _assessments = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAssessments();
  }

  /// Carga la lista desde la API y actualiza el estado.
  Future<void> _loadAssessments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await ApiService.fetchAssessments();
      setState(() => _assessments = data);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Navega al formulario y recarga al regresar si hubo cambios.
  Future<void> _openForm({RiskAssessment? assessment}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AssessmentFormScreen(assessment: assessment),
      ),
    );
    if (changed == true) _loadAssessments();
  }

  /// Confirma y ejecuta la eliminación del registro.
  Future<void> _deleteAssessment(RiskAssessment assessment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar evaluación'),
        content: Text(
            '¿Eliminar la evaluación de "${assessment.companyName}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ApiService.deleteAssessment(assessment.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Evaluación eliminada')),
      );
      _loadAssessments();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TDS Sentinel'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAssessments,
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva evaluación'),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadAssessments,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_assessments.isEmpty) {
      return const Center(
        child: Text(
          'No hay evaluaciones.\nToca + para crear una.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: Colors.grey),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAssessments,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80, top: 8),
        itemCount: _assessments.length,
        itemBuilder: (_, index) {
          final assessment = _assessments[index];
          return AssessmentCard(
            assessment: assessment,
            onEdit: () => _openForm(assessment: assessment),
            onDelete: () => _deleteAssessment(assessment),
          );
        },
      ),
    );
  }
}
