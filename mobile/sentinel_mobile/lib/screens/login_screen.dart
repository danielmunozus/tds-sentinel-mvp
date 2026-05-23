// lib/screens/login_screen.dart — TDS Sentinel
import 'package:flutter/material.dart';
import '../models/app_state.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'contact_form_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _emailCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  bool _obscure      = true;
  bool _loading      = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final client = await ApiService.instance.login(
        _emailCtrl.text.trim(),
        _passCtrl.text,
      );
      AppState.instance.login(client);
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (_) => false,
        );
      }
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    }
  }

  void _forgotPassword() {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Ingresa tu email primero para recuperar la contraseña.');
      return;
    }
    if (!email.contains('@')) {
      setState(() => _error = 'Ingresa un email válido para recuperar la contraseña.');
      return;
    }
    setState(() => _error = null);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ForgotPasswordScreen(email: email),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 36),
              _buildLogo(),
              const SizedBox(height: 24),
              _buildCard(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Image.asset(
          'assets/images/__TDS_LOGO_White.png',
          height: 157,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.shield_rounded,
            size: 157,
            color: AppColors.white,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Sentinel',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 3),
        const Text(
          'Plataforma de Evaluación de Riesgo',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Iniciar sesión',
              style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700,
                color: AppColors.textMain)),
            const SizedBox(height: 6),
            const Text('Accede con tu cuenta TDS Sentinel',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 24),

            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.riskHighBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.riskHigh.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.riskHigh, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                        style: const TextStyle(
                            color: AppColors.riskHigh, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            TextFormField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined, size: 20),
              ),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'El email es requerido.';
                if (!v.contains('@')) return 'Ingresa un email válido.';
                return null;
              },
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _passCtrl,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _login(),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'La contraseña es requerida.' : null,
            ),
            const SizedBox(height: 8),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _loading ? null : _forgotPassword,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('¿Olvidaste tu contraseña?',
                  style: TextStyle(fontSize: 12, color: AppColors.navyDark)),
              ),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _loading ? null : _login,
              child: _loading
                  ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Iniciar sesión'),
            ),
            const SizedBox(height: 20),

            const Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('¿No tienes cuenta?',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ),
                Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 16),

            OutlinedButton.icon(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ContactFormScreen())),
              icon: const Icon(Icons.mail_outline_rounded, size: 18),
              label: const Text('Solicitar acceso'),
            ),
          ],
        ),
      ),
    );
  }
}
