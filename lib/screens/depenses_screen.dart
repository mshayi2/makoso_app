import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../models/depense.dart';
import '../models/monnaie.dart';
import '../models/utilisateur.dart';

const int _kDepensePageSize = 250;

const Map<String, bool?> _kDepenseStatusFilters = {
  'Toutes': null,
  'En attente': false,
  'Validées': true,
};

const List<String> _kDepenseFormStatuses = [
  'Automatique',
  'En attente',
  'Validée',
];

class DepensesScreen extends StatefulWidget {
  final Utilisateur user;

  const DepensesScreen({super.key, required this.user});

  @override
  State<DepensesScreen> createState() => _DepensesScreenState();
}

class _DepensesScreenState extends State<DepensesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _libelleCtrl = TextEditingController();
  final _montantCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _observationCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  DepenseRecord? _editingDepense;
  bool _isSaving = false;
  bool _isLoading = true;
  bool _isGridLoading = true;
  int _currentPage = 0;
  int _totalRows = 0;

  String? _selectedMonnaieUuid;
  String _selectedStatusFilter = 'Toutes';
  String _selectedValidationStatus = 'Automatique';

  List<Monnaie> _monnaies = [];
  List<DepenseRecord> _depenses = [];

  static const double _autoValidationUsdThreshold = 1000;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _libelleCtrl.dispose();
    _montantCtrl.dispose();
    _dateCtrl.dispose();
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
    final statusFilter = _kDepenseStatusFilters[_selectedStatusFilter];
    final total = await AppDatabase.instance.getDepenseCount(
      search: search,
      valideOnly: statusFilter,
    );
    final maxPage = total <= 0 ? 0 : (total - 1) ~/ _kDepensePageSize;
    final safePage = total <= 0
        ? 0
        : targetPage < 0
            ? 0
            : targetPage > maxPage
                ? maxPage
                : targetPage;
    final records = await AppDatabase.instance.getDepenses(
      search: search,
      valideOnly: statusFilter,
      limit: _kDepensePageSize,
      offset: safePage * _kDepensePageSize,
    );
    if (!mounted) return;
    setState(() {
      _currentPage = safePage;
      _totalRows = total;
      _depenses = records;
      _isGridLoading = false;
    });
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    final parts = iso.split('-');
    if (parts.length != 3) return iso;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_dateCtrl.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _dateCtrl.text =
            '${picked.year.toString().padLeft(4, '0')}-'
            '${picked.month.toString().padLeft(2, '0')}-'
            '${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  String? _emptyToNull(String text) => text.trim().isEmpty ? null : text.trim();

  String get _currentValidatorLabel {
    final fullName = widget.user.nomComplet?.trim();
    if (fullName != null && fullName.isNotEmpty) {
      return fullName;
    }
    return widget.user.nomUtilisateur;
  }

  Monnaie? _selectedMonnaie() {
    final monnaieUuid = _selectedMonnaieUuid;
    if (monnaieUuid == null) {
      return null;
    }
    return _monnaies.where((monnaie) => monnaie.uuid == monnaieUuid).firstOrNull;
  }

  bool _isUsdCurrency(Monnaie monnaie) {
    final sigle = (monnaie.sigle ?? '').trim().toUpperCase();
    final nom = monnaie.nom.trim().toUpperCase();
    return sigle == 'USD' || nom == 'USD' || nom.contains('US') && nom.contains('DOLLAR');
  }

  String _todayIso() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  Future<_DepenseValidationDecision?> _resolveValidationDecision({
    required double montant,
    required Monnaie monnaie,
  }) async {
    if (_isUsdCurrency(monnaie)) {
      return _buildValidationDecision(montant < _autoValidationUsdThreshold);
    }

    final rate = await _promptConversionRate(monnaie);
    if (rate == null) {
      return null;
    }

    final montantUsd = montant / rate;
    return _buildValidationDecision(montantUsd < _autoValidationUsdThreshold);
  }

  _DepenseValidationDecision _buildValidationDecision(bool autoValidated) {
    if (!autoValidated) {
      return const _DepenseValidationDecision(
        valide: 0,
        dateValidation: null,
        validateurUuid: null,
      );
    }

    return _DepenseValidationDecision(
      valide: 1,
      dateValidation: _todayIso(),
      validateurUuid: widget.user.uuid,
    );
  }

  _DepenseValidationDecision _buildManualValidationDecision() {
    if (_selectedValidationStatus == 'Validée') {
      if (_editingDepense != null && _editingDepense!.valideValue > 0) {
        return _DepenseValidationDecision(
          valide: _editingDepense!.valideValue,
          dateValidation: _editingDepense!.dateValidation,
          validateurUuid: _editingDepense!.validateurUuid,
        );
      }

      return _DepenseValidationDecision(
        valide: 1,
        dateValidation: _todayIso(),
        validateurUuid: widget.user.uuid,
      );
    }

    return const _DepenseValidationDecision(
      valide: 0,
      dateValidation: null,
      validateurUuid: null,
    );
  }

  String _currentValidateurDisplayLabel() {
    switch (_selectedValidationStatus) {
      case 'Validée':
        return _editingDepense?.validateurNom ?? _currentValidatorLabel;
      case 'En attente':
        return '-';
      default:
        return _editingDepense?.validateurNom ?? '-';
    }
  }

  Future<double?> _promptConversionRate(Monnaie monnaie) async {
    final controller = TextEditingController();
    String? errorText;
    final currencyLabel = monnaie.sigle?.trim().isNotEmpty == true
        ? monnaie.sigle!.trim()
        : monnaie.nom;

    try {
      return await showDialog<double>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Taux de conversion'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Saisissez le taux pour convertir la dépense en USD.'),
                  const SizedBox(height: 8),
                  Text('1 USD = combien de $currencyLabel ?'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Taux de conversion',
                      border: const OutlineInputBorder(),
                      errorText: errorText,
                    ),
                    onSubmitted: (_) {
                      final normalized = controller.text.trim().replaceAll(',', '.');
                      final rate = double.tryParse(normalized);
                      if (rate == null || rate <= 0) {
                        setDialogState(() {
                          errorText = 'Entrez un taux valide supérieur à 0.';
                        });
                        return;
                      }
                      Navigator.of(dialogContext).pop(rate);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () {
                  final normalized = controller.text.trim().replaceAll(',', '.');
                  final rate = double.tryParse(normalized);
                  if (rate == null || rate <= 0) {
                    setDialogState(() {
                      errorText = 'Entrez un taux valide supérieur à 0.';
                    });
                    return;
                  }
                  Navigator.of(dialogContext).pop(rate);
                },
                child: const Text('Confirmer'),
              ),
            ],
          ),
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final montant = double.tryParse(_montantCtrl.text.trim().replaceAll(',', '.'));
    if (montant == null) return;

    final monnaie = _selectedMonnaie();
    if (monnaie == null) {
      return;
    }

    _DepenseValidationDecision validationDecision;
    if (_selectedValidationStatus == 'Automatique') {
      if (_editingDepense != null &&
          _editingDepense!.montant == montant &&
          _editingDepense!.monnaieUuid == monnaie.uuid) {
        validationDecision = _DepenseValidationDecision(
          valide: _editingDepense!.valideValue,
          dateValidation: _editingDepense!.dateValidation,
          validateurUuid: _editingDepense!.validateurUuid,
        );
      } else {
        final resolvedDecision = await _resolveValidationDecision(
          montant: montant,
          monnaie: monnaie,
        );
        if (resolvedDecision == null) {
          return;
        }
        validationDecision = resolvedDecision;
      }
    } else {
      validationDecision = _buildManualValidationDecision();
    }

    setState(() => _isSaving = true);
    final isEditing = _editingDepense != null;

    // Collaborateur restriction: can only manually validate 1000 or 10000 USD
    if (widget.user.role == 'collaborateur' &&
        validationDecision.valide > 0 &&
        _selectedValidationStatus == 'Validée') {
      final monnaie = _selectedMonnaie();
      if (monnaie == null ||
          !_isUsdCurrency(monnaie) ||
          (montant != 1000 && montant != 10000)) {
        setState(() => _isSaving = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'En tant que collaborateur, vous ne pouvez valider que les dépenses de 1000 USD ou 10 000 USD.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }
    try {
      if (isEditing) {
        await AppDatabase.instance.updateDepense(
          uuid: _editingDepense!.uuid,
          monnaieUuid: _selectedMonnaieUuid!,
          montant: montant,
          libelle: _libelleCtrl.text.trim(),
          observation: _emptyToNull(_observationCtrl.text),
          date: _emptyToNull(_dateCtrl.text),
          valide: validationDecision.valide,
          dateValidation: validationDecision.dateValidation,
          validateurUuid: validationDecision.validateurUuid,
        );
      } else {
        await AppDatabase.instance.createDepense(
          monnaieUuid: _selectedMonnaieUuid!,
          montant: montant,
          libelle: _libelleCtrl.text.trim(),
          observation: _emptyToNull(_observationCtrl.text),
          date: _emptyToNull(_dateCtrl.text),
          valide: validationDecision.valide,
          dateValidation: validationDecision.dateValidation,
          validateurUuid: validationDecision.validateurUuid,
        );
      }

      _cancelEdit();
      await _loadGrid(resetPage: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Dépense modifiée avec succès.' : 'Dépense ajoutée avec succès.'),
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

  Future<void> _startEdit(DepenseRecord depense) async {
    setState(() {
      _editingDepense = depense;
      _libelleCtrl.text = depense.libelle ?? '';
      _montantCtrl.text = depense.montant?.toString() ?? '';
      _dateCtrl.text = depense.date ?? '';
      _observationCtrl.text = depense.observation ?? '';
      _selectedMonnaieUuid = depense.monnaieUuid;
      _selectedValidationStatus = depense.validationStatus;
    });
  }

  void _cancelEdit() {
    _formKey.currentState?.reset();
    setState(() {
      _editingDepense = null;
      _selectedMonnaieUuid = null;
      _selectedValidationStatus = 'Automatique';
      _libelleCtrl.clear();
      _montantCtrl.clear();
      _dateCtrl.clear();
      _observationCtrl.clear();
    });
  }

  Future<void> _confirmDelete(DepenseRecord depense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la dépense'),
        content: Text('Voulez-vous vraiment supprimer la dépense "${depense.libelle ?? depense.uuid}" ?'),
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
    if (_editingDepense?.uuid == depense.uuid) _cancelEdit();
    await AppDatabase.instance.deleteDepense(depense.uuid);
    await _loadGrid();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dépense supprimée.')),
      );
    }
  }

  Widget _buildReadOnlyField({
    required double width,
    required String label,
    required IconData icon,
    required String value,
  }) {
    return SizedBox(
      width: width,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: Icon(icon),
        ),
        child: Text(value.isEmpty ? '-' : value),
      ),
    );
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
              child: TextFormField(
                controller: _libelleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Libellé *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.receipt_long_outlined),
                ),
                validator: (value) => value == null || value.trim().isEmpty ? 'Champ requis' : null,
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
                controller: _dateCtrl,
                readOnly: true,
                onTap: _pickDate,
                decoration: InputDecoration(
                  labelText: 'Date',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.calendar_today_outlined),
                  suffixIcon: _dateCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _dateCtrl.clear()),
                        )
                      : null,
                ),
              ),
            ),
            SizedBox(
              width: fieldWidth,
              child: DropdownButtonFormField<String>(
                value: _selectedValidationStatus,
                decoration: const InputDecoration(
                  labelText: 'Statut',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.verified_outlined),
                ),
                items: _kDepenseFormStatuses
                    .map((status) => DropdownMenuItem(value: status, child: Text(status)))
                    .toList(),
                onChanged: widget.user.role == 'caissier'
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _selectedValidationStatus = value;
                        });
                      },
              ),
            ),
            _buildReadOnlyField(
              width: fieldWidth,
              label: 'Validateur',
              icon: Icons.person_outline,
              value: _currentValidateurDisplayLabel(),
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
                        : Icon(_editingDepense != null ? Icons.save_outlined : Icons.add),
                    label: Text(_editingDepense != null ? 'Modifier' : 'Ajouter'),
                  ),
                  if (_editingDepense != null)
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

  Color _statusColor(int valide) {
    return valide > 0 ? Colors.green : Colors.orange;
  }

  Widget _buildPaginationBar() {
    final totalPages = _totalRows == 0 ? 1 : ((_totalRows - 1) ~/ _kDepensePageSize) + 1;
    final start = _totalRows == 0 ? 0 : (_currentPage * _kDepensePageSize) + 1;
    final end = _totalRows == 0 ? 0 : (_currentPage * _kDepensePageSize) + _depenses.length;

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
                    _editingDepense != null ? Icons.edit_outlined : Icons.money_off_outlined,
                    color: const Color(0xFF1A237E),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _editingDepense != null ? 'Modifier une dépense' : 'Ajouter une dépense',
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
                  'Historique des dépenses',
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
                    children: _kDepenseStatusFilters.keys.map((label) {
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
            else if (_depenses.isEmpty)
              const Expanded(child: Center(child: Text('Aucune dépense trouvée.')))
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
                        DataColumn(label: Text('Montant')),
                        DataColumn(label: Text('Monnaie')),
                        DataColumn(label: Text('Statut')),
                        DataColumn(label: Text('Validateur')),
                        DataColumn(label: Text('Observation')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: _depenses.map((depense) {
                        final isEditing = _editingDepense?.uuid == depense.uuid;
                        return DataRow(
                          color: WidgetStateProperty.resolveWith(
                            (states) => isEditing ? const Color(0xFF1A237E).withValues(alpha: 0.06) : null,
                          ),
                          cells: [
                            DataCell(Text(_formatDate(depense.date))),
                            DataCell(Text(depense.libelle ?? '-')),
                            DataCell(Text(depense.montant != null ? depense.montant!.toStringAsFixed(2) : '-')),
                            DataCell(Text(depense.monnaieLabel)),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _statusColor(depense.valideValue).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: _statusColor(depense.valideValue).withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  depense.validationStatus,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _statusColor(depense.valideValue),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(Text(depense.validateurNom ?? '-')),
                            DataCell(Text(depense.observation ?? '-')),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: Color(0xFF1A237E)),
                                    tooltip: 'Modifier',
                                    onPressed: () => _startEdit(depense),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    tooltip: 'Supprimer',
                                    onPressed: () => _confirmDelete(depense),
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

class _DepenseValidationDecision {
  final int valide;
  final String? dateValidation;
  final String? validateurUuid;

  const _DepenseValidationDecision({
    required this.valide,
    required this.dateValidation,
    required this.validateurUuid,
  });
}