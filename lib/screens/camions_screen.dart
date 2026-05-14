import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../models/camion.dart';

class CamionsScreen extends StatefulWidget {
  const CamionsScreen({super.key});

  @override
  State<CamionsScreen> createState() => _CamionsScreenState();
}

class _CamionsScreenState extends State<CamionsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _marqueCtrl = TextEditingController();
  final _plaqueCtrl = TextEditingController();
  final _modeleCtrl = TextEditingController();
  final _capaciteCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  Camion? _editingCamion;
  bool _isSaving = false;
  bool _isLoading = true;
  List<Camion> _camions = [];

  @override
  void initState() {
    super.initState();
    _loadCamions();
  }

  @override
  void dispose() {
    _marqueCtrl.dispose();
    _plaqueCtrl.dispose();
    _modeleCtrl.dispose();
    _capaciteCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCamions() async {
    setState(() => _isLoading = true);
    final list = await AppDatabase.instance.getAllCamions();
    if (mounted) setState(() { _camions = list; _isLoading = false; });
  }

  List<Camion> get _filteredCamions {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _camions;
    return _camions.where((c) {
      return (c.marque ?? '').toLowerCase().contains(q) ||
          (c.plaque ?? '').toLowerCase().contains(q) ||
          (c.modele ?? '').toLowerCase().contains(q) ||
          (c.capacite ?? '').toLowerCase().contains(q);
    }).toList();
  }

  void _startEdit(Camion c) {
    setState(() {
      _editingCamion = c;
      _marqueCtrl.text = c.marque ?? '';
      _plaqueCtrl.text = c.plaque ?? '';
      _modeleCtrl.text = c.modele ?? '';
      _capaciteCtrl.text = c.capacite ?? '';
    });
  }

  void _cancelEdit() {
    _formKey.currentState?.reset();
    setState(() {
      _editingCamion = null;
      _marqueCtrl.clear();
      _plaqueCtrl.clear();
      _modeleCtrl.clear();
      _capaciteCtrl.clear();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final isEditing = _editingCamion != null;
    try {
      if (isEditing) {
        await AppDatabase.instance.updateCamion(
          uuid: _editingCamion!.uuid,
          marque: _marqueCtrl.text.trim().isEmpty ? null : _marqueCtrl.text.trim(),
          plaque: _plaqueCtrl.text.trim().isEmpty ? null : _plaqueCtrl.text.trim(),
          modele: _modeleCtrl.text.trim().isEmpty ? null : _modeleCtrl.text.trim(),
          capacite: _capaciteCtrl.text.trim().isEmpty ? null : _capaciteCtrl.text.trim(),
        );
      } else {
        await AppDatabase.instance.createCamion(
          marque: _marqueCtrl.text.trim().isEmpty ? null : _marqueCtrl.text.trim(),
          plaque: _plaqueCtrl.text.trim().isEmpty ? null : _plaqueCtrl.text.trim(),
          modele: _modeleCtrl.text.trim().isEmpty ? null : _modeleCtrl.text.trim(),
          capacite: _capaciteCtrl.text.trim().isEmpty ? null : _capaciteCtrl.text.trim(),
        );
      }
      _cancelEdit();
      await _loadCamions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEditing ? 'Camion modifié avec succès.' : 'Camion ajouté avec succès.'),
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

  Future<void> _confirmDelete(Camion c) async {
    final label = [c.marque, c.plaque].where((v) => v != null && v.isNotEmpty).join(' - ');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le camion'),
        content: Text('Voulez-vous vraiment supprimer "${label.isEmpty ? 'ce camion' : label}" ?'),
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
      if (_editingCamion?.uuid == c.uuid) _cancelEdit();
      await AppDatabase.instance.deleteCamion(c.uuid);
      await _loadCamions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Camion supprimé.')));
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
                    _editingCamion != null ? Icons.edit_outlined : Icons.add_circle_outline,
                    color: const Color(0xFF1A237E),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _editingCamion != null ? 'Modifier un camion' : 'Ajouter un camion',
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
                        controller: _marqueCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Marque *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.branding_watermark_outlined),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _plaqueCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Plaque *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.confirmation_number_outlined),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _modeleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Modèle',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.directions_car_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _capaciteCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Capacité',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.scale_outlined),
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
                                  : Icon(_editingCamion != null ? Icons.save_outlined : Icons.add),
                              label: Text(_editingCamion != null ? 'Modifier' : 'Ajouter'),
                            ),
                          ),
                          if (_editingCamion != null) ...[
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
                Icon(Icons.airport_shuttle_outlined, color: Color(0xFF1A237E)),
                SizedBox(width: 8),
                Text('Liste des camions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A237E))),
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
            else if (_filteredCamions.isEmpty)
              const Expanded(child: Center(child: Text('Aucun camion trouvé.')))
            else
              Expanded(
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(const Color(0xFF1A237E).withValues(alpha: 0.08)),
                    columnSpacing: 24,
                    columns: const [
                      DataColumn(label: Text('Marque')),
                      DataColumn(label: Text('Plaque')),
                      DataColumn(label: Text('Modèle')),
                      DataColumn(label: Text('Capacité')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: _filteredCamions.map((c) {
                      final isEditing = _editingCamion?.uuid == c.uuid;
                      return DataRow(
                        color: WidgetStateProperty.resolveWith(
                          (states) => isEditing ? const Color(0xFF1A237E).withValues(alpha: 0.06) : null,
                        ),
                        cells: [
                          DataCell(Text(c.marque ?? '-')),
                          DataCell(Text(c.plaque ?? '-')),
                          DataCell(Text(c.modele ?? '-')),
                          DataCell(Text(c.capacite ?? '-')),
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
