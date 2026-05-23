// lib/widgets/control_answer_selector.dart — TDS Sentinel
// Selector de respuesta Yes/Partial/No para cada control del checklist.

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ControlAnswerSelector extends StatelessWidget {
  final String question;
  final String? selectedAnswer;
  final void Function(String) onChanged;

  const ControlAnswerSelector({
    super.key,
    required this.question,
    required this.selectedAnswer,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selectedAnswer != null
              ? AppColors.navyDark.withValues(alpha: 0.3)
              : AppColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w500,
              color: AppColors.textMain, height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _AnswerChip(label: 'Sí',      value: 'yes',     selected: selectedAnswer, onTap: onChanged, color: AppColors.riskLow),
              const SizedBox(width: 8),
              _AnswerChip(label: 'Parcial', value: 'partial', selected: selectedAnswer, onTap: onChanged, color: AppColors.riskMedium),
              const SizedBox(width: 8),
              _AnswerChip(label: 'No',      value: 'no',      selected: selectedAnswer, onTap: onChanged, color: AppColors.riskHigh),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnswerChip extends StatelessWidget {
  final String label;
  final String value;
  final String? selected;
  final void Function(String) onTap;
  final Color color;

  const _AnswerChip({
    required this.label, required this.value, required this.selected,
    required this.onTap, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : AppColors.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? color : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
