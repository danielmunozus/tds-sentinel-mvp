// lib/screens/assessment_form_screen.dart — TDS Sentinel
import 'package:flutter/material.dart';
import '../models/assessment_pack.dart';
import '../models/client.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/control_answer_selector.dart';

class AssessmentFormScreen extends StatefulWidget {
  final Client client;

  const AssessmentFormScreen({super.key, required this.client});

  @override
  State<AssessmentFormScreen> createState() => _AssessmentFormScreenState();
}

class _AssessmentFormScreenState extends State<AssessmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _responsibleCtrl = TextEditingController();

  List<AssessmentPack> _packs = [];
  AssessmentPack? _selectedPack;
  final Map<String, String> _answers = {};

  bool _loadingPacks = true;
  bool _submitting = false;
  String? _packsError;

  @override
  void initState() {
    super.initState();
    _loadPacks();
  }

  @override
  void dispose() {
    _responsibleCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPacks() async {
    setState(() { _loadingPacks = true; _packsError = null; });
    try {
      final packs = await ApiService.instance.fetchPacks();
      setState(() {
        _packs = packs;
        _selectedPack = packs.isNotEmpty ? packs.first : null;
        _loadingPacks = false;
      });
    } on ApiException catch (e) {
      setState(() { _packsError = e.message; _loadingPacks = false; });
    }
  }

  int get _answeredCount => _answers.length;
  int get _totalControls => _selectedPack?.controls.length ?? 0;
  double get _progress => _totalControls > 0 ? _answeredCount / _totalControls : 0;

  bool get _canSubmit =>
      !_submitting &&
      _responsibleCtrl.text.trim().isNotEmpty &&
      _selectedPack != null &&
      _answeredCount == _totalControls;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_canSubmit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Responde todos los controles antes de enviar.')));
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await ApiService.instance.createAssessment(
        clientId:        widget.client.id,
        responsibleName: _responsibleCtrl.text.trim(),
        packId:          _selectedPack!.id,
        answers:         Map.from(_answers),
      );
      if (mounted) Navigator.pop(context, result);
    } on ApiException catch (e) {
      setState(() => _submitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.riskHigh));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva Evaluación'),
        bottom: _selectedPack != null
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.coreGreen),
                  minHeight: 4,
                ),
              )
            : null,
      ),
      body: _loadingPacks
          ? const Center(child: CircularProgressIndicator(color: AppColors.navyDark))
          : _packsError != null
              ? _ErrorBody(message: _packsError!, onRetry: _loadPacks)
              : _buildForm(),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Cliente seleccionado (solo lectura)
          const _SectionHeader(title: 'Cliente', icon: Icons.business_rounded),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.navyDark.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.coreGreen, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.client.name,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMain)),
                      if (widget.client.contactName != null)
                        Text(widget.client.contactName!,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _responsibleCtrl,
            decoration: const InputDecoration(labelText: 'Nombre del responsable'),
            textCapitalization: TextCapitalization.words,
            maxLength: 200,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),

          // Section: Pack selection
          const _SectionHeader(title: 'Pack de evaluación', icon: Icons.inventory_2_rounded),
          const SizedBox(height: 12),
          if (_packs.length > 1)
            DropdownButtonFormField<AssessmentPack>(
              initialValue: _selectedPack,
              decoration: const InputDecoration(labelText: 'Seleccionar pack'),
              items: _packs.map((p) => DropdownMenuItem(
                value: p,
                child: Text(p.name, style: const TextStyle(fontSize: 14)),
              )).toList(),
              onChanged: (p) => setState(() {
                _selectedPack = p;
                _answers.clear();
              }),
            )
          else if (_selectedPack != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.navyDark.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.coreGreen, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_selectedPack!.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                          color: AppColors.textMain)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),

          // Section: Checklist
          if (_selectedPack != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _SectionHeader(title: 'Controles de seguridad', icon: Icons.checklist_rounded),
                Text('$_answeredCount / $_totalControls',
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: _answeredCount == _totalControls
                        ? AppColors.coreGreen : AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 12),
            ..._selectedPack!.controls.map((control) => ControlAnswerSelector(
              question: control.question,
              selectedAnswer: _answers[control.id],
              onChanged: (answer) => setState(() => _answers[control.id] = answer),
            )),
            const SizedBox(height: 16),
          ],

          // Submit button
          ElevatedButton(
            onPressed: _canSubmit ? _submit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _canSubmit ? AppColors.coreGreen : AppColors.divider,
              foregroundColor: AppColors.white,
              disabledBackgroundColor: AppColors.divider,
            ),
            child: _submitting
                ? const SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Enviar evaluación →'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.navyDark),
        const SizedBox(width: 6),
        Text(title, style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: AppColors.textMain, letterSpacing: 0.3)),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBody({required this.message, required this.onRetry});

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
              style: const TextStyle(color: AppColors.textSecondary)),
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
