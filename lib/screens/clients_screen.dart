import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../models/client.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomCtrl = TextEditingController();
  final _adresseCtrl = TextEditingController();
  final _telephoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  Client? _editingClient;
  bool _isSaving = false;
  bool _isLoading = true;
  List<Client> _clients = [];

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _adresseCtrl.dispose();
    _telephoneCtrl.dispose();
    _emailCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    setState(() => _isLoading = true);
    final list = await AppDatabase.instance.getAllClients();
    if (mounted) setState(() { _clients = list; _isLoading = false; });
  }

  List<Client> get _filteredClients {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _clients;
    return _clients.where((c) {
      return c.nom.toLowerCase().contains(q) ||
          (c.telephone ?? '').toLowerCase().contains(q) ||
          (c.email ?? '').toLowerCase().contains(q) ||
          (c.adresse ?? '').toLowerCase().contains(q);
    }).toList();
  }

  void _startEdit(Client c) {
    setState(() {
      _editingClient = c;
      _nomCtrl.text = c.nom;
      _adresseCtrl.text = c.adresse ?? '';
      _telephoneCtrl.text = c.telephone ?? '';
      _emailCtrl.text = c.email ?? '';
    });
  }

  void _cancelEdit() {
    _formKey.currentState?.reset();
    setState(() {
      _editingClient = null;
      _nomCtrl.clear();
      _adresseCtrl.clear();
      _telephoneCtrl.clear();
      _emailCtrl.clear();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final isEditing = _editingClient != null;
    try {
      if (isEditing) {
        await AppDatabase.instance.updateClient(
          uuid: _editingClient!.uuid,
          nom: _nomCtrl.text.trim(),
          adresse: _adresseCtrl.text.trim().isEmpty ? null : _adresseCtrl.text.trim(),
          telephone: _telephoneCtrl.text.trim().isEmpty ? null : _telephoneCtrl.text.trim(),
          email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        );
      } else {
        await AppDatabase.instance.createClient(
          nom: _nomCtrl.text.trim(),
          adresse: _adresseCtrl.text.trim().isEmpty ? null : _adresseCtrl.text.trim(),
          telephone: _telephoneCtrl.text.trim().isEmpty ? null : _telephoneCtrl.text.trim(),
          email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        );
      }
      _cancelEdit();
      await _loadClients();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEditing ? 'Client modifié avec succès.' : 'Client ajouté avec succès.'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmDelete(Client c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le client'),
        content: Text('Voulez-vous vraiment supprimer "${c.nom}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (_editingClient?.uuid == c.uuid) _cancelEdit();
      await AppDatabase.instance.deleteClient(c.uuid);
      await _loadClients();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Client supprimé.')),
        );
      }
    }
  }

  Widget _buildForm() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _editingClient != null ? Icons.edit_outlined : Icons.person_add_outlined,
                    color: const Color(0xFF1A237E),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _editingClient != null ? 'Modifier un client' : 'Ajouter un client',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A237E)),
                  ),
                ],
              ),
              const Divider(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nomCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nom *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.business_outlined),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _adresseCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Adresse',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.home_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _telephoneCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Téléphone',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isSaving ? null : _save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1A237E),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              icon: _isSaving
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : Icon(_editingClient != null ? Icons.save_outlined : Icons.add),
                              label: Text(_editingClient != null ? 'Modifier' : 'Ajouter'),
                            ),
                          ),
                          if (_editingClient != null) ...[
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: _cancelEdit,
                              icon: const Icon(Icons.cancel_outlined),
                              label: const Text('Annuler'),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.people_outline, color: Color(0xFF1A237E)),
                SizedBox(width: 8),
                Text('Liste des clients', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A237E))),
              ],
            ),
            const Divider(height: 24),
            TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Rechercher...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchCtrl.clear()),
                      )
                    : null,
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_filteredClients.isEmpty)
              const Expanded(child: Center(child: Text('Aucun client trouvé.')))
            else
              Expanded(
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(const Color(0xFF1A237E).withValues(alpha: 0.08)),
                    columnSpacing: 24,
                    columns: const [
                      DataColumn(label: Text('Nom')),
                      DataColumn(label: Text('Téléphone')),
                      DataColumn(label: Text('Email')),
                      DataColumn(label: Text('Adresse')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: _filteredClients.map((c) {
                      final isEditing = _editingClient?.uuid == c.uuid;
                      return DataRow(
                        color: WidgetStateProperty.resolveWith(
                          (states) => isEditing ? const Color(0xFF1A237E).withValues(alpha: 0.06) : null,
                        ),
                        cells: [
                          DataCell(Text(c.nom)),
                          DataCell(Text(c.telephone ?? '-')),
                          DataCell(Text(c.email ?? '-')),
                          DataCell(Text(c.adresse ?? '-')),
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: Color(0xFF1A237E)),
                                tooltip: 'Modifier',
                                onPressed: () => _startEdit(c),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                tooltip: 'Supprimer',
                                onPressed: () => _confirmDelete(c),
                              ),
                            ],
                          )),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 40, child: _buildForm()),
          const SizedBox(width: 16),
          Expanded(flex: 60, child: _buildList()),
        ],
      ),
    );
  }
}
