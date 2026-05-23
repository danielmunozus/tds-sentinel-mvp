// lib/screens/assessment_form_screen.dart — TDS Sentinel
import 'package:flutter/material.dart';
import '../models/assessment_pack.dart';
import '../models/app_state.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/control_answer_selector.dart';
import 'assessment_result_screen.dart';

class AssessmentFormScreen extends StatefulWidget {
  final AssessmentPack pack;

  const AssessmentFormScreen({super.key, required this.pack});

  @override
  State<AssessmentFormScreen> createState() => _AssessmentFormScreenState();
}

class _AssessmentFormScreenState extends State<AssessmentFormScreen> {
  final Map<String, String> _answers = {};
  bool _submitting = false;

  int get _answeredCount => _answers.length;
  int get _totalControls => widget.pack.controls.length;
  double get _progress => _totalControls > 0 ? _answeredCount / _totalControls : 0;

  bool get _canSubmit => !_submitting && _answeredCount == _totalControls;

  Future<void> _submit() async {
    if (!_canSubmit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Responde todos los controles antes de enviar.')));
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await ApiService.instance.createAssessment(
        clientId: AppState.instance.client!.id,
        packId:   widget.pack.id,
        answers:  Map.from(_answers),
      );
      if (mounted) {
        Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => AssessmentResultScreen(assessment: result)));
      }
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
        title: Text(widget.pack.name),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: _progress,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.coreGreen),
            minHeight: 4,
          ),
        ),
      ),
      body: _buildForm(),
    );
  }

  Widget _buildForm() {
    final client = AppState.instance.client;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Cliente (solo lectura)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.navyDark.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              const Icon(Icons.business_rounded,
                  color: AppColors.navyDark, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(client?.companyName ?? '',
                      style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: AppColors.textMain)),
                    if (client != null && client.contactName.isNotEmpty)
                      Text(client.contactName,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Progreso controles
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.checklist_rounded, size: 16, color: AppColors.navyDark),
                SizedBox(width: 6),
                Text('Controles de seguridad',
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: AppColors.textMain, letterSpacing: 0.3)),
              ],
            ),
            Text('$_answeredCount / $_totalControls',
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: _answeredCount == _totalControls
                    ? AppColors.coreGreen : AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 12),

        ...widget.pack.controls.map((control) => ControlAnswerSelector(
          question: control.question,
          selectedAnswer: _answers[control.id],
          onChanged: (answer) => setState(() => _answers[control.id] = answer),
        )),

        const SizedBox(height: 16),

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
    );
  }
}
