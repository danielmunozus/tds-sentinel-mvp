// lib/screens/client_selection_screen.dart — TDS Sentinel
// Primer paso del flujo de evaluación: seleccionar o crear cliente.
import 'package:flutter/material.dart';
import '../models/client.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'assessment_form_screen.dart';

class ClientSelectionScreen extends StatefulWidget {
  const ClientSelectionScreen({super.key});

  @override
  State<ClientSelectionScreen> createState() => _ClientSelectionScreenState();
}

class _ClientSelectionScreenState extends State<ClientSelectionScreen> {
  List<Client> _clients = [];
  List<Client> _filtered = [];
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.instance.fetchClients();
      setState(() {
        _clients  = data;
        _filtered = data;
        _loading  = false;
      });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    }
  }

  void _onSearch() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _clients
          : _clients.where((c) =>
              c.name.toLowerCase().contains(q) ||
              (c.contactName?.toLowerCase().contains(q) ?? false) ||
              (c.industry?.toLowerCase().contains(q) ?? false)).toList();
    });
  }

  void _selectClient(Client client) {
    Navigator.push(context,
      MaterialPageRoute(builder: (_) => AssessmentFormScreen(client: client)));
  }

  Future<void> _showCreateDialog() async {
    final nameCtrl    = TextEditingController();
    final contactCtrl = TextEditingController();
    final emailCtrl   = TextEditingController();
    final industryCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final created = await showDialog<Client>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo cliente'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre de empresa *'),
                  textCapitalization: TextCapitalization.words,
                  maxLength: 200,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: contactCtrl,
                  decoration: const InputDecoration(labelText: 'Persona de contacto'),
                  textCapitalization: TextCapitalization.words,
                  maxLength: 200,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  maxLength: 200,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: industryCtrl,
                  decoration: const InputDecoration(labelText: 'Industria'),
                  textCapitalization: TextCapitalization.words,
                  maxLength: 200,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                final client = await ApiService.instance.createClient(
                  name:        nameCtrl.text,
                  contactName: contactCtrl.text.trim().isEmpty ? null : contactCtrl.text,
                  email:       emailCtrl.text.trim().isEmpty ? null : emailCtrl.text,
                  industry:    industryCtrl.text.trim().isEmpty ? null : industryCtrl.text,
                );
                if (ctx.mounted) Navigator.pop(ctx, client);
              } on ApiException catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(e.message),
                        backgroundColor: AppColors.riskHigh));
                }
              }
            },
            child: const Text('Crear')),
        ],
      ),
    );

    if (created != null && mounted) {
      await _load();
      _selectClient(created);
    }
  }

  Future<void> _confirmDeleteClient(Client client) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar cliente'),
        content: Text(
            '¿Eliminar "${client.name}"?\nSolo es posible si no tiene evaluaciones asociadas.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.riskHigh),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await ApiService.instance.deleteClient(client.id);
        _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Cliente eliminado'),
                backgroundColor: AppColors.navyDark));
        }
      } on ApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(e.message),
                backgroundColor: AppColors.riskHigh));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seleccionar cliente')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        backgroundColor: AppColors.coreGreen,
        foregroundColor: AppColors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo cliente'),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: 'Buscar cliente…',
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () { _searchCtrl.clear(); })
              : null,
        ),
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
    if (_clients.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.business_outlined,
                  size: 56, color: AppColors.divider),
              const SizedBox(height: 16),
              const Text('Sin clientes aún',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              const Text(
                  'Crea el primer cliente con el botón "Nuevo cliente".',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    if (_filtered.isEmpty) {
      return const Center(
        child: Text('Sin resultados para esa búsqueda.',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.navyDark,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: _filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (_, i) => _ClientTile(
          client: _filtered[i],
          onTap: () => _selectClient(_filtered[i]),
          onDelete: () => _confirmDeleteClient(_filtered[i]),
        ),
      ),
    );
  }
}

class _ClientTile extends StatelessWidget {
  final Client client;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ClientTile({
    required this.client,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: AppColors.navyDark.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.business_rounded,
                    color: AppColors.navyDark, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(client.name,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMain)),
                    if (client.contactName != null) ...[
                      const SizedBox(height: 2),
                      Text(client.contactName!,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ],
                    if (client.industry != null) ...[
                      const SizedBox(height: 2),
                      Row(children: [
                        const Icon(Icons.category_outlined,
                            size: 11, color: AppColors.textSecondary),
                        const SizedBox(width: 3),
                        Text(client.industry!,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textSecondary)),
                      ]),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary, size: 20),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onDelete,
                child: const Icon(Icons.delete_outline_rounded,
                    size: 20, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
