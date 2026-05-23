// lib/screens/forgot_password_screen.dart — TDS Sentinel
// Vista de confirmación de ticket de soporte para recuperación de contraseña.
// El número de ticket es generado localmente (aleatorio) mientras se
// integra el endpoint real del backend.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String email;
  const ForgotPasswordScreen({super.key, required this.email});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {

  late final String _ticketNumber;
  late final String _createdAt;
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideIn;

  @override
  void initState() {
    super.initState();

    // Generar ticket aleatorio formato TDS-XXXXX
    final rand = Random();
    final num = 10000 + rand.nextInt(89999);          // 10000–99999
    _ticketNumber = 'TDS-$num';

    // Fecha/hora actual formateada
    final now = DateTime.now();
    final months = ['Ene','Feb','Mar','Abr','May','Jun',
                    'Jul','Ago','Sep','Oct','Nov','Dic'];
    _createdAt =
        '${now.day} ${months[now.month - 1]} ${now.year} '
        '— ${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';

    // Animación de entrada
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideIn = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));

    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Copiar número de ticket al portapapeles ─────────────────────────────────
  void _copyTicket() {
    Clipboard.setData(ClipboardData(text: _ticketNumber));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text('Ticket $_ticketNumber copiado'),
        ]),
        backgroundColor: AppColors.navyDark,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyDark,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: SlideTransition(
            position: _slideIn,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 32),
                  _buildTicketCard(),
                  const SizedBox(height: 24),
                  _buildNextSteps(),
                  const SizedBox(height: 32),
                  _buildActions(context),
                  const SizedBox(height: 16),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Column(
      children: [
        // Ícono de confirmación con círculo verde
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.coreGreen.withValues(alpha: 0.15),
            border: Border.all(color: AppColors.coreGreen, width: 2),
          ),
          child: const Icon(
            Icons.mark_email_read_rounded,
            size: 40,
            color: AppColors.coreGreen,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Solicitud registrada',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Hemos generado un ticket de soporte\npara restablecer tus credenciales.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // ── Tarjeta de ticket ──────────────────────────────────────────────────────
  Widget _buildTicketCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Cabecera del ticket
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: AppColors.navyDark,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.support_agent_rounded,
                    color: AppColors.coreGreen, size: 20),
                const SizedBox(width: 10),
                const Text(
                  'TICKET DE SOPORTE',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const Spacer(),
                // Badge de estado
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.coreGreen.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.coreGreen.withValues(alpha: 0.5)),
                  ),
                  child: const Text(
                    'ABIERTO',
                    style: TextStyle(
                      color: AppColors.coreGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Perforado decorativo
          _buildPerforated(),

          // Número de ticket
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NÚMERO DE TICKET',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '#$_ticketNumber',
                        style: const TextStyle(
                          color: AppColors.navyDark,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                // Botón copiar
                IconButton(
                  onPressed: _copyTicket,
                  tooltip: 'Copiar número de ticket',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.inputBg,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.copy_rounded,
                      size: 18, color: AppColors.navyDark),
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Divider(color: AppColors.divider),
          ),

          // Detalles del ticket
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              children: [
                _ticketRow(
                  icon: Icons.email_outlined,
                  label: 'Cuenta',
                  value: widget.email,
                ),
                const SizedBox(height: 12),
                _ticketRow(
                  icon: Icons.category_outlined,
                  label: 'Tipo',
                  value: 'Recuperación de contraseña',
                ),
                const SizedBox(height: 12),
                _ticketRow(
                  icon: Icons.schedule_rounded,
                  label: 'Creado',
                  value: _createdAt,
                ),
                const SizedBox(height: 12),
                _ticketRow(
                  icon: Icons.business_rounded,
                  label: 'Atendido por',
                  value: 'Equipo TDS Innovate',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Fila de detalle del ticket ─────────────────────────────────────────────
  Widget _ticketRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMain,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Perforado estilo ticket físico ─────────────────────────────────────────
  Widget _buildPerforated() {
    return SizedBox(
      height: 20,
      child: Row(
        children: [
          const _HalfCircle(left: true),
          Expanded(
            child: LayoutBuilder(builder: (_, constraints) {
              final count = (constraints.maxWidth / 10).floor();
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  count,
                  (_) => Container(
                    width: 5,
                    height: 1.5,
                    color: AppColors.divider,
                  ),
                ),
              );
            }),
          ),
          const _HalfCircle(left: false),
        ],
      ),
    );
  }

  // ── Sección de próximos pasos ──────────────────────────────────────────────
  Widget _buildNextSteps() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: AppColors.coreGreen, size: 16),
              SizedBox(width: 8),
              Text(
                '¿Qué sucede ahora?',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _step('1', 'Tu ticket ha sido registrado en nuestro sistema de soporte.'),
          const SizedBox(height: 10),
          _step('2', 'Un agente de TDS Innovate revisará tu solicitud en las próximas 24 horas hábiles.'),
          const SizedBox(height: 10),
          _step('3', 'Recibirás instrucciones para restablecer tu contraseña en el correo registrado.'),
          const SizedBox(height: 10),
          _step('4', 'Si es urgente, contáctanos directamente con el número de ticket.'),
        ],
      ),
    );
  }

  Widget _step(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.coreGreen.withValues(alpha: 0.2),
            border: Border.all(
                color: AppColors.coreGreen.withValues(alpha: 0.5), width: 1),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: AppColors.coreGreen,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }

  // ── Botones de acción ──────────────────────────────────────────────────────
  Widget _buildActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.coreGreen,
            foregroundColor: AppColors.navyDark,
          ),
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('Volver al inicio de sesión'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _copyTicket,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.white,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
          ),
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copiar número de ticket'),
        ),
      ],
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Text(
      'soporte@tdsinnovate.com',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.35),
        fontSize: 12,
      ),
    );
  }
}

// ── Widget auxiliar: semicírculo para el perforado ─────────────────────────
class _HalfCircle extends StatelessWidget {
  final bool left;
  const _HalfCircle({required this.left});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Align(
        alignment: left ? Alignment.centerRight : Alignment.centerLeft,
        widthFactor: 0.5,
        child: Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.navyDark,
          ),
        ),
      ),
    );
  }
}
