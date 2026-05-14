import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../models/depot_argent.dart';
import '../models/monnaie.dart';
import '../models/utilisateur.dart';

const int _kDepotPageSize = 250;

const List<String> _kDepotLibelles = [
  'Paiement 30% draft',
  'Paiement 30% Pointe Noir',
  'Paiement 40% Matadi',
  'Voyage camion',
];

const Map<String, List<String>?> _kStatusFilters = {
  'Tous': null,
  'En attente': ['en attente'],
  'En cours': ['en cours'],
  'Terminé / Clôturé': ['terminé', 'termine', 'clôturé', 'cloturé'],
  'Annulé': ['annulé', 'annule'],
};

class DepotArgentScreen extends StatefulWidget {
  final Utilisateur user;

  const DepotArgentScreen({super.key, required this.user});

  @override
  State<DepotArgentScreen> createState() => _DepotArgentScreenState();
}

class _DepotArgentScreenState extends State<DepotArgentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _montantCtrl = TextEditingController();
  final _datePaiementCtrl = TextEditingController();
  final _observationCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  DepotArgentRecord? _editingDepot;
  bool _isSaving = false;
  bool _isLoading = true;
  bool _isGridLoading = true;
  int _currentPage = 0;
  int _totalRows = 0;

  String? _selectedLibelle;
  String? _selectedMonnaieUuid;
  String? _selectedSourceUuid;
  String _selectedStatusFilter = 'Tous';

  List<Monnaie> _monnaies = [];
  List<DepotSourceOption> _sources = [];
  List<DepotArgentRecord> _depots = [];

  String get _sourceFieldLabel {
    if (_selectedLibelle == 'Voyage camion') return 'Voyage *';
    if (_selectedLibelle != null && _selectedLibelle!.isNotEmpty) return 'Dossier *';
    return 'Source *';
  }

  String get _agentLabel {
    final nom = widget.user.nomComplet?.trim();
    if (nom != null && nom.isNotEmpty) return nom;
    return widget.user.nomUtilisateur;
  }

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _montantCtrl.dispose();
    _datePaiementCtrl.dispose();
    _observationCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _isGridLoading = true;
    });
    final monnaies = await AppDatabase.instance.getAllMonnaies();
    if (!mounted) return;
    setState(() {
      _monnaies = monnaies;
      _isLoading = false;
    });
    await _loadGrid(resetPage: true);
  }

  Future<void> _loadGrid({bool resetPage = false, int? page}) async {
    final targetPage = resetPage ? 0 : (page ?? _currentPage);
    setState(() => _isGridLoading = true);
    final search = _searchCtrl.text;
    final statuses = _kStatusFilters[_selectedStatusFilter];
    final total = await AppDatabase.instance.getDepotArgentCount(
      search: search,
      sourceStatuses: statuses,
    );
    final maxPage = total <= 0 ? 0 : (total - 1) ~/ _kDepotPageSize;
    final safePage = total <= 0
        ? 0
        : targetPage < 0
            ? 0
            : targetPage > maxPage
                ? maxPage
                : targetPage;
    final records = await AppDatabase.instance.getDepotArgentRecords(
      search: search,
      sourceStatuses: statuses,
      limit: _kDepotPageSize,
      offset: safePage * _kDepotPageSize,
    );
    if (!mounted) return;
    setState(() {
      _currentPage = safePage;
      _totalRows = total;
      _depots = records;
      _isGridLoading = false;
    });
  }

  Future<void> _loadSourcesForLibelle({String? includeSourceUuid}) async {
    final libelle = _selectedLibelle;
    if (libelle == null || libelle.isEmpty) {
      if (!mounted) return;
      setState(() {
        _sources = [];
        _selectedSourceUuid = null;
      });
      return;
    }

    final sources = await AppDatabase.instance.getDepotSourceOptions(
      libelle,
      includeSourceUuid: includeSourceUuid,
    );
    if (!mounted) return;
    setState(() {
      _sources = sources;
      if (!_sources.any((source) => source.uuid == _selectedSourceUuid)) {
        _selectedSourceUuid = null;
      }
    });
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    final parts = iso.split('-');
    if (parts.length != 3) return iso;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_datePaiementCtrl.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _datePaiementCtrl.text =
            '${picked.year.toString().padLeft(4, '0')}-'
            '${picked.month.toString().padLeft(2, '0')}-'
            '${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  String? _emptyToNull(String text) => text.trim().isEmpty ? null : text.trim();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final montant = double.tryParse(_montantCtrl.text.trim().replaceAll(',', '.'));
    if (montant == null) return;

    setState(() => _isSaving = true);
    final isEditing = _editingDepot != null;
    try {
      if (isEditing) {
        await AppDatabase.instance.updateDepotArgent(
          uuid: _editingDepot!.uuid,
          monnaieUuid: _selectedMonnaieUuid!,
          montant: montant,
          libelle: _selectedLibelle!,
          observation: _emptyToNull(_observationCtrl.text),
          datePaiement: _emptyToNull(_datePaiementCtrl.text),
          sourceUuid: _selectedSourceUuid!,
          agent: _editingDepot!.agent ?? _agentLabel,
        );
      } else {
        await AppDatabase.instance.createDepotArgent(
          monnaieUuid: _selectedMonnaieUuid!,
          montant: montant,
          libelle: _selectedLibelle!,
          observation: _emptyToNull(_observationCtrl.text),
          datePaiement: _emptyToNull(_datePaiementCtrl.text),
          sourceUuid: _selectedSourceUuid!,
          agent: _agentLabel,
        );
      }

      _cancelEdit();
      await _loadGrid(resetPage: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Dépôt modifié avec succès.' : 'Dépôt ajouté avec succès.'),
          ),
        );
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

  Future<void> _startEdit(DepotArgentRecord depot) async {
    setState(() {
      _editingDepot = depot;
      _selectedLibelle = depot.libelle;
      _selectedMonnaieUuid = depot.monnaieUuid;
      _selectedSourceUuid = depot.sourceUuid;
      _montantCtrl.text = depot.montant?.toString() ?? '';
      _datePaiementCtrl.text = depot.datePaiement ?? '';
      _observationCtrl.text = depot.observation ?? '';
    });
    await _loadSourcesForLibelle(includeSourceUuid: depot.sourceUuid);
    if (!mounted) return;
    setState(() {
      _selectedSourceUuid = depot.sourceUuid;
    });
  }

  void _cancelEdit() {
    _formKey.currentState?.reset();
    setState(() {
      _editingDepot = null;
      _selectedLibelle = null;
      _selectedMonnaieUuid = null;
      _selectedSourceUuid = null;
      _sources = [];
      _montantCtrl.clear();
      _datePaiementCtrl.clear();
      _observationCtrl.clear();
    });
  }

  Future<void> _confirmDelete(DepotArgentRecord depot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le dépôt'),
        content: Text('Voulez-vous vraiment supprimer le dépôt "${depot.libelle ?? depot.uuid}" ?'),
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

    if (confirmed != true) return;
    if (_editingDepot?.uuid == depot.uuid) _cancelEdit();
    await AppDatabase.instance.deleteDepotArgent(depot.uuid);
    await _loadGrid();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dépôt supprimé.')),
      );
    }
  }

  Widget _buildThreeColumnForm() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = 12.0;
        final fieldWidth = (constraints.maxWidth - (gap * 2)) / 3;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            SizedBox(
              width: fieldWidth,
              child: DropdownButtonFormField<String>(
                value: _selectedLibelle,
                decoration: const InputDecoration(
                  labelText: 'Libellé *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.list_alt_outlined),
                ),
                items: _kDepotLibelles
                    .map((libelle) => DropdownMenuItem(value: libelle, child: Text(libelle)))
                    .toList(),
                validator: (value) => value == null ? 'Champ requis' : null,
                onChanged: (value) async {
                  setState(() {
                    _selectedLibelle = value;
                    _selectedSourceUuid = null;
                    _sources = [];
                  });
                  await _loadSourcesForLibelle();
                },
              ),
            ),
            SizedBox(
              width: fieldWidth,
              child: DropdownButtonFormField<String>(
                value: _selectedSourceUuid,
                decoration: InputDecoration(
                  labelText: _sourceFieldLabel,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.link_outlined),
                ),
                items: _sources
                    .map(
                      (source) => DropdownMenuItem(
                        value: source.uuid,
                        child: Text(
                          source.statut?.isNotEmpty == true
                              ? '${source.label} - ${source.statut}'
                              : source.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                validator: (value) => value == null ? 'Champ requis' : null,
                onChanged: (value) => setState(() => _selectedSourceUuid = value),
              ),
            ),
            SizedBox(
              width: fieldWidth,
              child: DropdownButtonFormField<String>(
                value: _selectedMonnaieUuid,
                decoration: const InputDecoration(
                  labelText: 'Monnaie *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                items: _monnaies
                    .map(
                      (monnaie) => DropdownMenuItem(
                        value: monnaie.uuid,
                        child: Text(monnaie.label),
                      ),
                    )
                    .toList(),
                validator: (value) => value == null ? 'Champ requis' : null,
                onChanged: (value) => setState(() => _selectedMonnaieUuid = value),
              ),
            ),
            SizedBox(
              width: fieldWidth,
              child: TextFormField(
                controller: _montantCtrl,
                decoration: const InputDecoration(
                  labelText: 'Montant *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Champ requis';
                  if (double.tryParse(value.trim().replaceAll(',', '.')) == null) {
                    return 'Nombre invalide';
                  }
                  return null;
                },
              ),
            ),
            SizedBox(
              width: fieldWidth,
              child: TextFormField(
                controller: _datePaiementCtrl,
                readOnly: true,
                onTap: _pickDate,
                decoration: InputDecoration(
                  labelText: 'Date paiement',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.calendar_today_outlined),
                  suffixIcon: _datePaiementCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _datePaiementCtrl.clear()),
                        )
                      : null,
                ),
              ),
            ),
            SizedBox(
              width: fieldWidth,
              child: TextFormField(
                initialValue: _editingDepot?.agent ?? _agentLabel,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Agent',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
            ),
            SizedBox(
              width: (fieldWidth * 2) + gap,
              child: TextFormField(
                controller: _observationCtrl,
                maxLines: 1,
                decoration: const InputDecoration(
                  labelText: 'Observation',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
            ),
            SizedBox(
              width: fieldWidth,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.start,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Icon(_editingDepot != null ? Icons.save_outlined : Icons.add),
                    label: Text(_editingDepot != null ? 'Modifier' : 'Ajouter'),
                  ),
                  if (_editingDepot != null)
                    OutlinedButton.icon(
                      onPressed: _cancelEdit,
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Annuler'),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Color _statusColor(String? status) {
    return switch (status) {
      'En attente' => Colors.orange,
      'En cours' => Colors.indigo,
      'Terminé' => Colors.green,
      'Clôturé' => Colors.green,
      'Annulé' => Colors.red,
      _ => Colors.grey,
    };
  }

  Widget _buildPaginationBar() {
    final totalPages = _totalRows == 0 ? 1 : ((_totalRows - 1) ~/ _kDepotPageSize) + 1;
    final start = _totalRows == 0 ? 0 : (_currentPage * _kDepotPageSize) + 1;
    final end = _totalRows == 0 ? 0 : (_currentPage * _kDepotPageSize) + _depots.length;

    return Row(
      children: [
        Text(
          'Lignes $start-$end sur $_totalRows',
          style: const TextStyle(color: Colors.black54),
        ),
        const Spacer(),
        Text(
          'Page ${_currentPage + 1} / $totalPages',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Page précédente',
          onPressed: _currentPage > 0 && !_isGridLoading ? () => _loadGrid(page: _currentPage - 1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          tooltip: 'Page suivante',
          onPressed: end < _totalRows && !_isGridLoading ? () => _loadGrid(page: _currentPage + 1) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildFormCard() {
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
                    _editingDepot != null ? Icons.edit_outlined : Icons.account_balance_wallet_outlined,
                    color: const Color(0xFF1A237E),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _editingDepot != null ? 'Modifier un dépôt d\'argent' : 'Ajouter un dépôt d\'argent',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A237E)),
                  ),
                ],
              ),
              const Divider(height: 24),
              _buildThreeColumnForm(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.history_outlined, color: Color(0xFF1A237E)),
                SizedBox(width: 8),
                Text(
                  'Historique des dépôts',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A237E)),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => _loadGrid(resetPage: true),
                    decoration: InputDecoration(
                      hintText: 'Rechercher...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() => _searchCtrl.clear());
                                _loadGrid(resetPage: true);
                              },
                            )
                          : null,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _kStatusFilters.keys.map((label) {
                      final selected = _selectedStatusFilter == label;
                      return ChoiceChip(
                        label: Text(label),
                        selected: selected,
                        onSelected: (_) async {
                          setState(() => _selectedStatusFilter = label);
                          await _loadGrid(resetPage: true);
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildPaginationBar(),
            const SizedBox(height: 12),
            if (_isGridLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_depots.isEmpty)
              const Expanded(child: Center(child: Text('Aucun dépôt trouvé.')))
            else
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(const Color(0xFF1A237E).withValues(alpha: 0.08)),
                      columnSpacing: 20,
                      columns: const [
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Libellé')),
                        DataColumn(label: Text('Source')),
                        DataColumn(label: Text('Statut')),
                        DataColumn(label: Text('Montant')),
                        DataColumn(label: Text('Monnaie')),
                        DataColumn(label: Text('Agent')),
                        DataColumn(label: Text('Observation')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: _depots.map((depot) {
                        final isEditing = _editingDepot?.uuid == depot.uuid;
                        return DataRow(
                          color: WidgetStateProperty.resolveWith(
                            (states) => isEditing ? const Color(0xFF1A237E).withValues(alpha: 0.06) : null,
                          ),
                          cells: [
                            DataCell(Text(_formatDate(depot.datePaiement))),
                            DataCell(Text(depot.libelle ?? '-')),
                            DataCell(Text(depot.sourceLabel ?? '-')),
                            DataCell(
                              depot.sourceStatut != null
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _statusColor(depot.sourceStatut).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: _statusColor(depot.sourceStatut).withValues(alpha: 0.4)),
                                      ),
                                      child: Text(
                                        depot.sourceStatut!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _statusColor(depot.sourceStatut),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    )
                                  : const Text('-'),
                            ),
                            DataCell(Text(depot.montant != null ? depot.montant!.toStringAsFixed(2) : '-')),
                            DataCell(Text(depot.monnaieLabel)),
                            DataCell(Text(depot.agent ?? '-')),
                            DataCell(Text(depot.observation ?? '-')),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: Color(0xFF1A237E)),
                                    tooltip: 'Modifier',
                                    onPressed: () => _startEdit(depot),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    tooltip: 'Supprimer',
                                    onPressed: () => _confirmDelete(depot),
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
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFormCard(),
          const SizedBox(height: 16),
          Expanded(child: _buildGridCard()),
        ],
      ),
    );
  }
}