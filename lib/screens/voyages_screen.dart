import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../models/camion.dart';
import '../models/chauffeur_convoyeur.dart';
import '../models/monnaie.dart';
import '../models/utilisateur.dart';
import '../models/voyage.dart';

const List<String> _kStatuts = [
  'En attente',
  'En cours',
  'Terminé',
  'Annulé',
];

class VoyagesScreen extends StatefulWidget {
  final Utilisateur user;
  const VoyagesScreen({super.key, required this.user});

  @override
  State<VoyagesScreen> createState() => _VoyagesScreenState();
}

class _VoyagesScreenState extends State<VoyagesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _numeroVoyageCtrl = TextEditingController();
  final _dateVoyageCtrl = TextEditingController();
  final _lieuDepartCtrl = TextEditingController();
  final _lieuDestinationCtrl = TextEditingController();
  final _montantCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  String? _selectedCamionUuid;
  String? _selectedChauffeurUuid;
  String? _selectedConvoyeurUuid;
  String? _selectedMonnaieUuid;
  String? _selectedStatut;

  Voyage? _editingVoyage;
  bool _isSaving = false;
  bool _isLoading = true;

  List<Voyage> _voyages = [];
  List<Camion> _camions = [];
  List<ChauffeurConvoyeur> _chauffeurs = [];
  List<ChauffeurConvoyeur> _convoyeurs = [];
  List<Monnaie> _monnaies = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _numeroVoyageCtrl.dispose();
    _dateVoyageCtrl.dispose();
    _lieuDepartCtrl.dispose();
    _lieuDestinationCtrl.dispose();
    _montantCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  bool get _isOpLogistique => widget.user.role == 'opérateur logistique';

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      AppDatabase.instance.getAllVoyages(),
      AppDatabase.instance.getAllCamions(),
      AppDatabase.instance.getAllChauffeursConvoyeurs(),
      AppDatabase.instance.getAllMonnaies(),
    ]);
    if (!mounted) return;
    final tous = results[2] as List<ChauffeurConvoyeur>;
    setState(() {
      _voyages = results[0] as List<Voyage>;
      _camions = results[1] as List<Camion>;
      _chauffeurs = tous.where((c) => c.fonction == 'Chauffeur').toList();
      _convoyeurs = tous.where((c) => c.fonction == 'Convoyeur').toList();
      _monnaies = results[3] as List<Monnaie>;
      _isLoading = false;
    });
  }

  List<Voyage> get _filteredVoyages {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _voyages;
    return _voyages.where((v) {
      return (v.numeroVoyage ?? '').toLowerCase().contains(q) ||
          (v.lieuDepart ?? '').toLowerCase().contains(q) ||
          (v.lieuDestination ?? '').toLowerCase().contains(q) ||
          (v.statut ?? '').toLowerCase().contains(q) ||
          _camionLabel(v.camionUuid).toLowerCase().contains(q) ||
          _personLabel(v.chauffeurUuid).toLowerCase().contains(q);
    }).toList();
  }

  String _camionLabel(String? uuid) {
    if (uuid == null) return '-';
    final c = _camions.where((c) => c.uuid == uuid).firstOrNull;
    if (c == null) return '-';
    return [c.marque, c.plaque].where((v) => v != null && v.isNotEmpty).join(' - ');
  }

  String _personLabel(String? uuid) {
    if (uuid == null) return '-';
    final list = [..._chauffeurs, ..._convoyeurs];
    return list.where((p) => p.uuid == uuid).firstOrNull?.nom ?? '-';
  }

  String _monnaieLabel(String? uuid) {
    if (uuid == null) return '-';
    return _monnaies.where((m) => m.uuid == uuid).firstOrNull?.label ?? '-';
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    final parts = iso.split('-');
    if (parts.length != 3) return iso;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_dateVoyageCtrl.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _dateVoyageCtrl.text =
            '${picked.year.toString().padLeft(4, '0')}-'
            '${picked.month.toString().padLeft(2, '0')}-'
            '${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  void _startEdit(Voyage v) {
    setState(() {
      _editingVoyage = v;
      _numeroVoyageCtrl.text = v.numeroVoyage ?? '';
      _dateVoyageCtrl.text = v.dateVoyage ?? '';
      _lieuDepartCtrl.text = v.lieuDepart ?? '';
      _lieuDestinationCtrl.text = v.lieuDestination ?? '';
      _montantCtrl.text = v.montantConvenu != null ? v.montantConvenu.toString() : '';
      _selectedCamionUuid = _camions.any((c) => c.uuid == v.camionUuid) ? v.camionUuid : null;
      _selectedChauffeurUuid = _chauffeurs.any((c) => c.uuid == v.chauffeurUuid) ? v.chauffeurUuid : null;
      _selectedConvoyeurUuid = _convoyeurs.any((c) => c.uuid == v.convoyeurUuid) ? v.convoyeurUuid : null;
      _selectedMonnaieUuid = _monnaies.any((m) => m.uuid == v.monnaieUuid) ? v.monnaieUuid : null;
      _selectedStatut = _kStatuts.contains(v.statut) ? v.statut : null;
    });
  }

  void _cancelEdit() {
    _formKey.currentState?.reset();
    setState(() {
      _editingVoyage = null;
      _numeroVoyageCtrl.clear();
      _dateVoyageCtrl.clear();
      _lieuDepartCtrl.clear();
      _lieuDestinationCtrl.clear();
      _montantCtrl.clear();
      _selectedCamionUuid = null;
      _selectedChauffeurUuid = null;
      _selectedConvoyeurUuid = null;
      _selectedMonnaieUuid = null;
      _selectedStatut = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final isEditing = _editingVoyage != null;
    final montant = double.tryParse(_montantCtrl.text.trim().replaceAll(',', '.'));
    try {
      if (isEditing) {
        await AppDatabase.instance.updateVoyage(
          uuid: _editingVoyage!.uuid,
          numeroVoyage: _emptyToNull(_numeroVoyageCtrl.text),
          dateVoyage: _emptyToNull(_dateVoyageCtrl.text),
          lieuDepart: _emptyToNull(_lieuDepartCtrl.text),
          lieuDestination: _emptyToNull(_lieuDestinationCtrl.text),
          montantConvenu: montant,
          monnaieUuid: _selectedMonnaieUuid,
          statut: _selectedStatut,
          camionUuid: _selectedCamionUuid,
          chauffeurUuid: _selectedChauffeurUuid,
          convoyeurUuid: _selectedConvoyeurUuid,
        );
      } else {
        await AppDatabase.instance.createVoyage(
          numeroVoyage: _emptyToNull(_numeroVoyageCtrl.text),
          dateVoyage: _emptyToNull(_dateVoyageCtrl.text),
          lieuDepart: _emptyToNull(_lieuDepartCtrl.text),
          lieuDestination: _emptyToNull(_lieuDestinationCtrl.text),
          montantConvenu: montant,
          monnaieUuid: _selectedMonnaieUuid,
          statut: _selectedStatut,
          camionUuid: _selectedCamionUuid,
          chauffeurUuid: _selectedChauffeurUuid,
          convoyeurUuid: _selectedConvoyeurUuid,
        );
      }
      _cancelEdit();
      await _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEditing ? 'Voyage modifié avec succès.' : 'Voyage ajouté avec succès.'),
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

  Future<void> _confirmDelete(Voyage v) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le voyage'),
        content: Text('Voulez-vous vraiment supprimer le voyage "${v.numeroVoyage ?? v.uuid}" ?'),
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
      if (_editingVoyage?.uuid == v.uuid) _cancelEdit();
      await AppDatabase.instance.deleteVoyage(v.uuid);
      await _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Voyage supprimé.')));
      }
    }
  }

  String? _emptyToNull(String s) => s.trim().isEmpty ? null : s.trim();

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
                    _editingVoyage != null ? Icons.edit_outlined : Icons.add_circle_outline,
                    color: const Color(0xFF1A237E),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _editingVoyage != null ? 'Modifier un voyage' : 'Ajouter un voyage',
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
                        controller: _numeroVoyageCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Numéro de voyage *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.tag),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _dateVoyageCtrl,
                        readOnly: true,
                        onTap: _pickDate,
                        decoration: InputDecoration(
                          labelText: 'Date du voyage',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.calendar_today_outlined),
                          suffixIcon: _dateVoyageCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => setState(() => _dateVoyageCtrl.clear()),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _lieuDepartCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Lieu de départ',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _lieuDestinationCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Lieu de destination',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.flag_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Camion
                      DropdownButtonFormField<String>(
                        value: _selectedCamionUuid,
                        decoration: const InputDecoration(
                          labelText: 'Camion',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.airport_shuttle_outlined),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('— Aucun —')),
                          ..._camions.map((c) {
                            final label = [c.marque, c.plaque]
                                .where((v) => v != null && v.isNotEmpty)
                                .join(' - ');
                            return DropdownMenuItem(value: c.uuid, child: Text(label));
                          }),
                        ],
                        onChanged: (v) => setState(() => _selectedCamionUuid = v),
                      ),
                      const SizedBox(height: 12),
                      // Chauffeur
                      DropdownButtonFormField<String>(
                        value: _selectedChauffeurUuid,
                        decoration: const InputDecoration(
                          labelText: 'Chauffeur',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outlined),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('— Aucun —')),
                          ..._chauffeurs.map((c) =>
                              DropdownMenuItem(value: c.uuid, child: Text(c.nom))),
                        ],
                        onChanged: (v) => setState(() => _selectedChauffeurUuid = v),
                      ),
                      const SizedBox(height: 12),
                      // Convoyeur
                      DropdownButtonFormField<String>(
                        value: _selectedConvoyeurUuid,
                        decoration: const InputDecoration(
                          labelText: 'Convoyeur',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outlined),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('— Aucun —')),
                          ..._convoyeurs.map((c) =>
                              DropdownMenuItem(value: c.uuid, child: Text(c.nom))),
                        ],
                        onChanged: (v) => setState(() => _selectedConvoyeurUuid = v),
                      ),
                      const SizedBox(height: 12),
                      if (!_isOpLogistique) ...
                      [
                        TextFormField(
                          controller: _montantCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Montant convenu',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.attach_money),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            if (double.tryParse(v.trim().replaceAll(',', '.')) == null) {
                              return 'Nombre invalide';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedMonnaieUuid,
                          decoration: const InputDecoration(
                            labelText: 'Monnaie',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('—')),
                            ..._monnaies.map((m) =>
                                DropdownMenuItem(value: m.uuid, child: Text(m.label))),
                          ],
                          onChanged: (v) => setState(() => _selectedMonnaieUuid = v),
                        ),
                        const SizedBox(height: 12),
                      ],
                      DropdownButtonFormField<String>(
                        value: _selectedStatut,
                        decoration: const InputDecoration(
                          labelText: 'Statut',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.flag_outlined),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('— Aucun —')),
                          ..._kStatuts.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                        ],
                        onChanged: (v) => setState(() => _selectedStatut = v),
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
                                  : Icon(_editingVoyage != null ? Icons.save_outlined : Icons.add),
                              label: Text(_editingVoyage != null ? 'Modifier' : 'Ajouter'),
                            ),
                          ),
                          if (_editingVoyage != null) ...[
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
  Color _statutColor(String? statut) {
    return switch (statut) {
      'En attente' => Colors.orange,
      'En cours' => Colors.indigo,
      'Terminé' => Colors.green,
      'Annulé' => Colors.red,
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
                Icon(Icons.local_shipping_outlined, color: Color(0xFF1A237E)),
                SizedBox(width: 8),
                Text('Liste des voyages',
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
            else if (_filteredVoyages.isEmpty)
              const Expanded(child: Center(child: Text('Aucun voyage trouvé.')))
            else
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(const Color(0xFF1A237E).withValues(alpha: 0.08)),
                      columnSpacing: 20,
                      columns: [
                        const DataColumn(label: Text('N° Voyage')),
                        const DataColumn(label: Text('Date')),
                        const DataColumn(label: Text('Départ')),
                        const DataColumn(label: Text('Destination')),
                        const DataColumn(label: Text('Camion')),
                        const DataColumn(label: Text('Chauffeur')),
                        const DataColumn(label: Text('Convoyeur')),
                        if (!_isOpLogistique)
                          const DataColumn(label: Text('Montant')),
                        const DataColumn(label: Text('Statut')),
                        const DataColumn(label: Text('Actions')),
                      ],
                      rows: _filteredVoyages.map((v) {
                        final isEditing = _editingVoyage?.uuid == v.uuid;
                        return DataRow(
                          color: WidgetStateProperty.resolveWith(
                            (states) => isEditing ? const Color(0xFF1A237E).withValues(alpha: 0.06) : null,
                          ),
                          cells: [
                            DataCell(Text(v.numeroVoyage ?? '-')),
                            DataCell(Text(_formatDate(v.dateVoyage))),
                            DataCell(Text(v.lieuDepart ?? '-')),
                            DataCell(Text(v.lieuDestination ?? '-')),
                            DataCell(Text(_camionLabel(v.camionUuid))),
                            DataCell(Text(_personLabel(v.chauffeurUuid))),
                            DataCell(Text(_personLabel(v.convoyeurUuid))),
                            if (!_isOpLogistique)
                              DataCell(Text(
                                v.montantConvenu != null
                                    ? '${v.montantConvenu!.toStringAsFixed(2)} ${_monnaieLabel(v.monnaieUuid)}'
                                    : '-',
                              )),
                            DataCell(
                              v.statut != null
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _statutColor(v.statut).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: _statutColor(v.statut).withValues(alpha: 0.4)),
                                      ),
                                      child: Text(
                                        v.statut!,
                                        style: TextStyle(fontSize: 12, color: _statutColor(v.statut), fontWeight: FontWeight.w500),
                                      ),
                                    )
                                  : const Text('-'),
                            ),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: Color(0xFF1A237E)),
                                  tooltip: 'Modifier',
                                  onPressed: () => _startEdit(v),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  tooltip: 'Supprimer',
                                  onPressed: () => _confirmDelete(v),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 35, child: _buildForm()),
          const SizedBox(width: 16),
          Expanded(flex: 65, child: _buildList()),
        ],
      ),
    );
  }
}
