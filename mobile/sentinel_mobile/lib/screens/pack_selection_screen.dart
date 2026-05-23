// lib/screens/pack_selection_screen.dart — TDS Sentinel
import 'package:flutter/material.dart';
import '../models/assessment_pack.dart';
import '../models/app_state.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'assessment_form_screen.dart';

class PackSelectionScreen extends StatefulWidget {
  const PackSelectionScreen({super.key});

  @override
  State<PackSelectionScreen> createState() => _PackSelectionScreenState();
}

class _PackSelectionScreenState extends State<PackSelectionScreen> {
  List<AssessmentPack> _packs = [];
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
      final packs = await ApiService.instance.fetchPacks();
      setState(() { _packs = packs; _loading = false; });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    }
  }

  void _selectPack(AssessmentPack pack) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AssessmentFormScreen(pack: pack)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final client = AppState.instance.client;

    return Scaffold(
      backgroundColor: AppColors.navyDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(client?.companyName ?? ''),
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
    );
  }

  Widget _buildHeader(String companyName) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const Spacer(),
              Image.asset(
                'assets/icons/__TDS ICON (Color).png',
                height: 32,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.shield_rounded,
                  color: AppColors.coreGreen,
                  size: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Selecciona un pack',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            companyName.isNotEmpty
                ? 'Evaluación para $companyName'
                : 'Elige el tipo de evaluación de riesgo',
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.navyDark));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 48, color: AppColors.textSecondary),
              const SizedBox(height: 16),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }
    if (_packs.isEmpty) {
      return const Center(
        child: Text('No hay packs disponibles.',
            style: TextStyle(color: AppColors.textSecondary)));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _packs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _PackCard(
        pack: _packs[i],
        onTap: () => _selectPack(_packs[i]),
      ),
    );
  }
}

class _PackCard extends StatelessWidget {
  final AssessmentPack pack;
  final VoidCallback onTap;

  const _PackCard({required this.pack, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: AppColors.navyDark.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/icons/__TDS ICON (Color).png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.inventory_2_rounded,
                      color: AppColors.navyDark,
                      size: 28,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pack.name,
                      style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700,
                        color: AppColors.textMain)),
                    const SizedBox(height: 4),
                    Text(pack.description,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _Chip(
                          label: '${pack.controls.length} controles',
                          icon: Icons.checklist_rounded,
                        ),
                        const SizedBox(width: 8),
                        _Chip(
                          label: 'v${pack.version}',
                          icon: Icons.tag_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _Chip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.navyDark.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.navyDark),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(
            fontSize: 11, color: AppColors.navyDark, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
