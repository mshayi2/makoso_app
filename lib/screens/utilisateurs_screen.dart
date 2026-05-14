import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../models/utilisateur.dart';

const List<String> _kRoles = [
  'admin',
  'boss',
  'collaborateur',
  'opérateur logistique',
  'caissier',
];

class UtilisateursScreen extends StatefulWidget {
  const UtilisateursScreen({super.key});

  @override
  State<UtilisateursScreen> createState() => _UtilisateursScreenState();
}

class _UtilisateursScreenState extends State<UtilisateursScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomCompletCtrl = TextEditingController();
  final _nomUtilisateurCtrl = TextEditingController();
  final _motDePasseCtrl = TextEditingController();
  final _adresseCtrl = TextEditingController();
  final _telephoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  String? _selectedRole;
  bool _obscurePassword = true;
  Utilisateur? _editingUser;
  bool _isSaving = false;
  bool _isLoading = true;
  List<Utilisateur> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _nomCompletCtrl.dispose();
    _nomUtilisateurCtrl.dispose();
    _motDePasseCtrl.dispose();
    _adresseCtrl.dispose();
    _telephoneCtrl.dispose();
    _emailCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final list = await AppDatabase.instance.getAllUtilisateurs();
    if (mounted) setState(() { _users = list; _isLoading = false; });
  }

  List<Utilisateur> get _filteredUsers {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _users;
    return _users.where((u) {
      return (u.nomComplet ?? '').toLowerCase().contains(q) ||
          u.nomUtilisateur.toLowerCase().contains(q) ||
          (u.role ?? '').toLowerCase().contains(q);
    }).toList();
  }

  void _startEdit(Utilisateur u) {
    setState(() {
      _editingUser = u;
      _nomCompletCtrl.text = u.nomComplet ?? '';
      _nomUtilisateurCtrl.text = u.nomUtilisateur;
      _motDePasseCtrl.clear();
      _adresseCtrl.text = u.adresse ?? '';
      _telephoneCtrl.text = u.telephone ?? '';
      _emailCtrl.text = u.email ?? '';
      _selectedRole = _kRoles.contains(u.role) ? u.role : null;
    });
  }

  void _cancelEdit() {
    _formKey.currentState?.reset();
    setState(() {
      _editingUser = null;
      _nomCompletCtrl.clear();
      _nomUtilisateurCtrl.clear();
      _motDePasseCtrl.clear();
      _adresseCtrl.clear();
      _telephoneCtrl.clear();
      _emailCtrl.clear();
      _selectedRole = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final isEditing = _editingUser != null;

    try {
      if (isEditing) {
        await AppDatabase.instance.updateUtilisateurData(
          uuid: _editingUser!.uuid,
          nomComplet: _nomCompletCtrl.text.trim().isEmpty
              ? null
              : _nomCompletCtrl.text.trim(),
          nomUtilisateur: _nomUtilisateurCtrl.text.trim(),
          plainPassword:
              _motDePasseCtrl.text.isEmpty ? null : _motDePasseCtrl.text,
          adresse: _adresseCtrl.text.trim().isEmpty
              ? null
              : _adresseCtrl.text.trim(),
          telephone: _telephoneCtrl.text.trim().isEmpty
              ? null
              : _telephoneCtrl.text.trim(),
          email:
              _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          role: _selectedRole,
        );
      } else {
        await AppDatabase.instance.createUtilisateur(
          nomUtilisateur: _nomUtilisateurCtrl.text.trim(),
          nomComplet: _nomCompletCtrl.text.trim().isEmpty
              ? null
              : _nomCompletCtrl.text.trim(),
          plainPassword:
              _motDePasseCtrl.text.isEmpty ? '12345' : _motDePasseCtrl.text,
          adresse: _adresseCtrl.text.trim().isEmpty
              ? null
              : _adresseCtrl.text.trim(),
          telephone: _telephoneCtrl.text.trim().isEmpty
              ? null
              : _telephoneCtrl.text.trim(),
          email:
              _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          role: _selectedRole,
        );
      }
      _cancelEdit();
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing
                ? 'Utilisateur modifié avec succès.'
                : 'Utilisateur ajouté avec succès.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmDelete(Utilisateur u) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'utilisateur'),
        content: Text(
          'Voulez-vous vraiment supprimer "${u.nomComplet ?? u.nomUtilisateur}" ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (_editingUser?.uuid == u.uuid) _cancelEdit();
      await AppDatabase.instance.deleteUtilisateur(u.uuid);
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Utilisateur supprimé.')),
        );
      }
    }
  }

  // ── Form ──────────────────────────────────────────────────────────────────
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
                    _editingUser != null
                        ? Icons.edit_outlined
                        : Icons.person_add_outlined,
                    color: const Color(0xFF1A237E),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _editingUser != null
                        ? 'Modifier un utilisateur'
                        : 'Ajouter un utilisateur',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nomCompletCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nom complet',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nomUtilisateurCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nom d\'utilisateur *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _motDePasseCtrl,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: _editingUser != null
                              ? 'Nouveau mot de passe (vide = inchangé)'
                              : 'Mot de passe (vide = 12345 par défaut)',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () =>
                                setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Rôle *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.work_outline),
                        ),
                        items: _kRoles
                            .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedRole = v),
                        validator: (v) =>
                            v == null ? 'Veuillez sélectionner un rôle' : null,
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
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2),
                                    )
                                  : Icon(_editingUser != null
                                      ? Icons.save_outlined
                                      : Icons.add),
                              label: Text(
                                  _editingUser != null ? 'Modifier' : 'Ajouter'),
                            ),
                          ),
                          if (_editingUser != null) ...[
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

  // ── List ──────────────────────────────────────────────────────────────────
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
                Icon(Icons.group_outlined, color: Color(0xFF1A237E)),
                SizedBox(width: 8),
                Text(
                  'Liste des utilisateurs',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A237E),
                  ),
                ),
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
              const Expanded(
                  child: Center(child: CircularProgressIndicator()))
            else if (_filteredUsers.isEmpty)
              const Expanded(
                  child: Center(child: Text('Aucun utilisateur trouvé.')))
            else
              Expanded(
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                        const Color(0xFF1A237E).withValues(alpha: 0.08)),
                    columnSpacing: 24,
                    columns: const [
                      DataColumn(label: Text('Nom complet')),
                      DataColumn(label: Text('Nom d\'utilisateur')),
                      DataColumn(label: Text('Rôle')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: _filteredUsers.map((u) {
                      final isEditing = _editingUser?.uuid == u.uuid;
                      return DataRow(
                        color: WidgetStateProperty.resolveWith(
                          (states) => isEditing
                              ? const Color(0xFF1A237E).withValues(alpha: 0.06)
                              : null,
                        ),
                        cells: [
                          DataCell(Text(u.nomComplet ?? '-')),
                          DataCell(Text(u.nomUtilisateur)),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _roleColor(u.role)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color:
                                        _roleColor(u.role).withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                u.role ?? '-',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _roleColor(u.role),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined,
                                      color: Color(0xFF1A237E)),
                                  tooltip: 'Modifier',
                                  onPressed: () => _startEdit(u),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.red),
                                  tooltip: 'Supprimer',
                                  onPressed: () => _confirmDelete(u),
                                ),
                              ],
                            ),
                          ),
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

  Color _roleColor(String? role) {
    return switch (role) {
      'admin' => Colors.deepPurple,
      'boss' => Colors.indigo,
      'collaborateur' => Colors.teal,
      'opérateur logistique' => Colors.orange,
      'caissier' => Colors.green,
      _ => Colors.grey,
    };
  }

  // ── Build ──────────────────────────────────────────────────────────────────
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
