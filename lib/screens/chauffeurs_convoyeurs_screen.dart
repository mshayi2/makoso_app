import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../models/chauffeur_convoyeur.dart';

const List<String> _kFonctions = ['Chauffeur', 'Convoyeur'];

class ChauffeursConvoyeursScreen extends StatefulWidget {
  const ChauffeursConvoyeursScreen({super.key});

  @override
  State<ChauffeursConvoyeursScreen> createState() =>
      _ChauffeursConvoyeursScreenState();
}

class _ChauffeursConvoyeursScreenState
    extends State<ChauffeursConvoyeursScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomCtrl = TextEditingController();
  final _telephoneCtrl = TextEditingController();
  final _adresseCtrl = TextEditingController();
  final _dateEngagementCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  String? _selectedFonction;
  ChauffeurConvoyeur? _editingItem;
  bool _isSaving = false;
  bool _isLoading = true;
  List<ChauffeurConvoyeur> _items = [];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _telephoneCtrl.dispose();
    _adresseCtrl.dispose();
    _dateEngagementCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    final list = await AppDatabase.instance.getAllChauffeursConvoyeurs();
    if (mounted) setState(() { _items = list; _isLoading = false; });
  }

  List<ChauffeurConvoyeur> get _filteredItems {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((item) {
      return item.nom.toLowerCase().contains(q) ||
          (item.fonction ?? '').toLowerCase().contains(q) ||
          (item.telephone ?? '').toLowerCase().contains(q) ||
          (item.adresse ?? '').toLowerCase().contains(q);
    }).toList();
  }

  void _startEdit(ChauffeurConvoyeur item) {
    setState(() {
      _editingItem = item;
      _nomCtrl.text = item.nom;
      _telephoneCtrl.text = item.telephone ?? '';
      _adresseCtrl.text = item.adresse ?? '';
      _dateEngagementCtrl.text = item.dateEngagement ?? '';
      _selectedFonction = _kFonctions.contains(item.fonction) ? item.fonction : null;
    });
  }

  void _cancelEdit() {
    _formKey.currentState?.reset();
    setState(() {
      _editingItem = null;
      _nomCtrl.clear();
      _telephoneCtrl.clear();
      _adresseCtrl.clear();
      _dateEngagementCtrl.clear();
      _selectedFonction = null;
    });
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    final parts = iso.split('-');
    if (parts.length != 3) return iso;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_dateEngagementCtrl.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      _dateEngagementCtrl.text =
          '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final isEditing = _editingItem != null;
    try {
      if (isEditing) {
        await AppDatabase.instance.updateChauffeurConvoyeur(
          uuid: _editingItem!.uuid,
          nom: _nomCtrl.text.trim(),
          telephone: _telephoneCtrl.text.trim().isEmpty ? null : _telephoneCtrl.text.trim(),
          adresse: _adresseCtrl.text.trim().isEmpty ? null : _adresseCtrl.text.trim(),
          dateEngagement: _dateEngagementCtrl.text.trim().isEmpty ? null : _dateEngagementCtrl.text.trim(),
          fonction: _selectedFonction,
        );
      } else {
        await AppDatabase.instance.createChauffeurConvoyeur(
          nom: _nomCtrl.text.trim(),
          telephone: _telephoneCtrl.text.trim().isEmpty ? null : _telephoneCtrl.text.trim(),
          adresse: _adresseCtrl.text.trim().isEmpty ? null : _adresseCtrl.text.trim(),
          dateEngagement: _dateEngagementCtrl.text.trim().isEmpty ? null : _dateEngagementCtrl.text.trim(),
          fonction: _selectedFonction,
        );
      }
      _cancelEdit();
      await _loadItems();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEditing ? 'Enregistrement modifié avec succès.' : 'Enregistrement ajouté avec succès.'),
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

  Future<void> _confirmDelete(ChauffeurConvoyeur item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer'),
        content: Text('Voulez-vous vraiment supprimer "${item.nom}" ?'),
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
      if (_editingItem?.uuid == item.uuid) _cancelEdit();
      await AppDatabase.instance.deleteChauffeurConvoyeur(item.uuid);
      await _loadItems();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enregistrement supprimé.')));
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
                    _editingItem != null ? Icons.edit_outlined : Icons.person_add_outlined,
                    color: const Color(0xFF1A237E),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _editingItem != null
                        ? 'Modifier un chauffeur / convoyeur'
                        : 'Ajouter un chauffeur / convoyeur',
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
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedFonction,
                        decoration: const InputDecoration(
                          labelText: 'Fonction *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.work_outline),
                        ),
                        items: _kFonctions
                            .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedFonction = v),
                        validator: (v) => v == null ? 'Veuillez sélectionner une fonction' : null,
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
                        controller: _adresseCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Adresse',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.home_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _dateEngagementCtrl,
                        readOnly: true,
                        onTap: _pickDate,
                        decoration: InputDecoration(
                          labelText: 'Date d\'engagement',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.calendar_today_outlined),
                          suffixIcon: _dateEngagementCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => setState(() => _dateEngagementCtrl.clear()),
                                )
                              : null,
                        ),
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
                                  : Icon(_editingItem != null ? Icons.save_outlined : Icons.add),
                              label: Text(_editingItem != null ? 'Modifier' : 'Ajouter'),
                            ),
                          ),
                          if (_editingItem != null) ...[
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

  Color _fonctionColor(String? fonction) {
    return switch (fonction) {
      'Chauffeur' => Colors.indigo,
      'Convoyeur' => Colors.teal,
      _ => Colors.grey,
    };
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
                Icon(Icons.drive_eta_outlined, color: Color(0xFF1A237E)),
                SizedBox(width: 8),
                Text('Liste des chauffeurs / convoyeurs',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A237E))),
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
            else if (_filteredItems.isEmpty)
              const Expanded(child: Center(child: Text('Aucun enregistrement trouvé.')))
            else
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(const Color(0xFF1A237E).withValues(alpha: 0.08)),
                      columnSpacing: 24,
                      columns: const [
                        DataColumn(label: Text('Nom')),
                        DataColumn(label: Text('Fonction')),
                        DataColumn(label: Text('Téléphone')),
                        DataColumn(label: Text('Date engagement')),
                        DataColumn(label: Text('Actions')),
                      ],
                    rows: _filteredItems.map((item) {
                      final isEditing = _editingItem?.uuid == item.uuid;
                      return DataRow(
                        color: WidgetStateProperty.resolveWith(
                          (states) => isEditing ? const Color(0xFF1A237E).withValues(alpha: 0.06) : null,
                        ),
                        cells: [
                          DataCell(Text(item.nom)),
                          DataCell(
                            item.fonction != null
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _fonctionColor(item.fonction).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: _fonctionColor(item.fonction).withValues(alpha: 0.4)),
                                    ),
                                    child: Text(
                                      item.fonction!,
                                      style: TextStyle(fontSize: 12, color: _fonctionColor(item.fonction), fontWeight: FontWeight.w500),
                                    ),
                                  )
                                : const Text('-'),
                          ),
                          DataCell(Text(item.telephone ?? '-')),
                          DataCell(Text(_formatDate(item.dateEngagement))),
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: Color(0xFF1A237E)),
                                tooltip: 'Modifier',
                                onPressed: () => _startEdit(item),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                tooltip: 'Supprimer',
                                onPressed: () => _confirmDelete(item),
                              ),
                            ],
                          )),
                        ],
                      );
                    }).toList(),
                    ),
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
