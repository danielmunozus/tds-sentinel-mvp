import 'package:flutter/material.dart';
import '../models/risk_assessment.dart';
import '../services/api_service.dart';

/// Formulario reutilizable para crear o editar una evaluación de riesgo.
/// Si [assessment] es null se crea uno nuevo; si se pasa uno se edita.
class AssessmentFormScreen extends StatefulWidget {
  final RiskAssessment? assessment;

  const AssessmentFormScreen({super.key, this.assessment});

  @override
  State<AssessmentFormScreen> createState() => _AssessmentFormScreenState();
}

class _AssessmentFormScreenState extends State<AssessmentFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _companyCtrl;
  late final TextEditingController _assetCtrl;
  late final TextEditingController _recommendationCtrl;
  late String _riskLevel;

  bool _isSaving = false;

  bool get _isEditing => widget.assessment != null;

  @override
  void initState() {
    super.initState();
    final a = widget.assessment;
    _companyCtrl = TextEditingController(text: a?.companyName ?? '');
    _assetCtrl = TextEditingController(text: a?.assetName ?? '');
    _recommendationCtrl =
        TextEditingController(text: a?.recommendation ?? '');
    _riskLevel = a?.riskLevel ?? RiskAssessment.validRiskLevels.first;
  }

  @override
  void dispose() {
    _companyCtrl.dispose();
    _assetCtrl.dispose();
    _recommendationCtrl.dispose();
    super.dispose();
  }

  /// Valida el formulario y llama a la API correspondiente.
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final payload = RiskAssessment(
      id: widget.assessment?.id,
      companyName: _companyCtrl.text.trim(),
      assetName: _assetCtrl.text.trim(),
      riskLevel: _riskLevel,
      recommendation: _recommendationCtrl.text.trim(),
    );

    try {
      if (_isEditing) {
        await ApiService.updateAssessment(payload);
      } else {
        await ApiService.createAssessment(payload);
      }
      if (!mounted) return;
      // Retorna true para que la lista sepa que debe recargar.
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar evaluación' : 'Nueva evaluación'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildField(
                controller: _companyCtrl,
                label: 'Company Name',
                icon: Icons.business,
                hint: 'Ej. TDS Innovate S.A.',
              ),
              const SizedBox(height: 16),
              _buildField(
                controller: _assetCtrl,
                label: 'Asset Name',
                icon: Icons.devices,
                hint: 'Ej. Servidor Web principal',
              ),
              const SizedBox(height: 16),
              // Dropdown de nivel de riesgo con valores controlados por el modelo.
              DropdownButtonFormField<String>(
                value: _riskLevel,
                decoration: InputDecoration(
                  labelText: 'Risk Level',
                  prefixIcon: const Icon(Icons.warning_amber_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                items: RiskAssessment.validRiskLevels
                    .map((level) =>
                        DropdownMenuItem(value: level, child: Text(level)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _riskLevel = value);
                },
              ),
              const SizedBox(height: 16),
              _buildField(
                controller: _recommendationCtrl,
                label: 'Recommendation',
                icon: Icons.lightbulb_outline,
                hint: 'Ej. Aplicar parche de seguridad urgente',
                maxLines: 3,
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_isSaving
                      ? 'Guardando…'
                      : (_isEditing ? 'Actualizar' : 'Guardar')),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Campo de texto genérico con validación de campo vacío.
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        alignLabelWithHint: maxLines > 1,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '$label no puede estar vacío';
        }
        return null;
      },
    );
  }
}
