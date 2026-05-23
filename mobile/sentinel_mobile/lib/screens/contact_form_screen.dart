// lib/screens/contact_form_screen.dart — TDS Sentinel
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ContactFormScreen extends StatefulWidget {
  const ContactFormScreen({super.key});

  @override
  State<ContactFormScreen> createState() => _ContactFormScreenState();
}

class _ContactFormScreenState extends State<ContactFormScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _companyCtrl  = TextEditingController();
  final _contactCtrl  = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _messageCtrl  = TextEditingController();
  String? _packInterest;
  bool _loading = false;
  bool _sent    = false;

  static const _packs = [
    'Infrastructure Basic Security',
    'Network Security',
    'Ambos packs',
    'No estoy seguro aún',
  ];

  @override
  void dispose() {
    _companyCtrl.dispose();
    _contactCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ApiService.instance.sendContactRequest(
        companyName:  _companyCtrl.text,
        contactName:  _contactCtrl.text,
        email:        _emailCtrl.text,
        phone:        _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text,
        packInterest: _packInterest,
        message:      _messageCtrl.text.trim().isEmpty ? null : _messageCtrl.text,
      );
      setState(() { _sent = true; _loading = false; });
    } on ApiException catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.riskHigh));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitar acceso')),
      body: _sent ? _buildSuccess() : _buildForm(),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: const BoxDecoration(
                color: AppColors.riskLowBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  color: AppColors.riskLow, size: 44),
            ),
            const SizedBox(height: 24),
            const Text('¡Solicitud enviada!',
              style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700,
                color: AppColors.textMain)),
            const SizedBox(height: 12),
            const Text(
              'El equipo de TDS Innovate revisará tu solicitud y se pondrá en contacto contigo a la brevedad.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Volver al inicio de sesión'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.navyDark.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: AppColors.navyDark, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Completa el formulario y el equipo de TDS se contactará a la brevedad.',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textMain, height: 1.4)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _sectionHeader('Datos de la empresa', Icons.business_rounded),
            const SizedBox(height: 12),
            TextFormField(
              controller: _companyCtrl,
              decoration: const InputDecoration(labelText: 'Nombre de empresa *'),
              textCapitalization: TextCapitalization.words,
              maxLength: 200,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Campo requerido.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contactCtrl,
              decoration: const InputDecoration(labelText: 'Persona de contacto *'),
              textCapitalization: TextCapitalization.words,
              maxLength: 200,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Campo requerido.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'Email corporativo *'),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              maxLength: 200,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Campo requerido.';
                if (!v.contains('@')) return 'Ingresa un email válido.';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(labelText: 'Teléfono (opcional)'),
              keyboardType: TextInputType.phone,
              maxLength: 50,
            ),
            const SizedBox(height: 24),

            _sectionHeader('Pack de interés', Icons.inventory_2_rounded),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _packInterest,
              decoration: const InputDecoration(labelText: 'Pack de evaluación'),
              items: _packs.map((p) => DropdownMenuItem(
                value: p,
                child: Text(p, style: const TextStyle(fontSize: 14)),
              )).toList(),
              onChanged: (v) => setState(() => _packInterest = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _messageCtrl,
              decoration: const InputDecoration(
                labelText: 'Mensaje adicional (opcional)',
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              maxLength: 1000,
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Enviar solicitud'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
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
