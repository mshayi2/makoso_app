import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../models/client.dart';
import '../models/conteneur.dart';
import '../models/detail_conteneur.dart';
import '../models/dossier.dart';

const List<String> _kStatuts = [
  'En attente',
  'En cours',
  'Clôturé',
  'Annulé',
];

const List<String> _kDimensionsConteneur = [
  '20 Pieds',
  '40 Piueds',
];

class DossiersScreen extends StatefulWidget {
  const DossiersScreen({super.key});

  @override
  State<DossiersScreen> createState() => _DossiersScreenState();
}

class _DossiersScreenState extends State<DossiersScreen> {
  final _formKey = GlobalKey<FormState>();
  final _numeroBlCtrl = TextEditingController();
  final _portChargementCtrl = TextEditingController();
  final _portDestinationCtrl = TextEditingController();
  final _natureMarchandiseCtrl = TextEditingController();
  final _dateArriveePnCtrl = TextEditingController();
  final _dateArriveeMatadictrl = TextEditingController();
  final _datePaiement30DraftCtrl = TextEditingController();
  final _datePaiement30PnCtrl = TextEditingController();
  final _datePaiement40MatadictrlCtrl = TextEditingController();
  final _montantCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _hScrollCtrl = ScrollController();

  String? _selectedClientUuid;
  String? _selectedStatut;

  Dossier? _editingDossier;
  bool _isSaving = false;
  bool _isLoading = true;

  List<Dossier> _dossiers = [];
  List<Client> _clients = [];
  Map<String, int> _conteneurCounts = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _numeroBlCtrl.dispose();
    _portChargementCtrl.dispose();
    _portDestinationCtrl.dispose();
    _natureMarchandiseCtrl.dispose();
    _dateArriveePnCtrl.dispose();
    _dateArriveeMatadictrl.dispose();
    _datePaiement30DraftCtrl.dispose();
    _datePaiement30PnCtrl.dispose();
    _datePaiement40MatadictrlCtrl.dispose();
    _montantCtrl.dispose();
    _searchCtrl.dispose();
    _hScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      AppDatabase.instance.getAllDossiers(),
      AppDatabase.instance.getAllClients(),
      AppDatabase.instance.getConteneurCountsByDossier(),
    ]);
    if (!mounted) return;
    setState(() {
      _dossiers = results[0] as List<Dossier>;
      _clients = results[1] as List<Client>;
      _conteneurCounts = results[2] as Map<String, int>;
      _isLoading = false;
    });
  }

  List<Dossier> get _filteredDossiers {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _dossiers;
    return _dossiers.where((d) {
      return (d.numeroBl ?? '').toLowerCase().contains(q) ||
          (d.portChargement ?? '').toLowerCase().contains(q) ||
          (d.portDestination ?? '').toLowerCase().contains(q) ||
          (d.natureMarchandise ?? '').toLowerCase().contains(q) ||
          (d.statut ?? '').toLowerCase().contains(q) ||
          _clientLabel(d.clientUuid).toLowerCase().contains(q);
    }).toList();
  }

  String _clientLabel(String? uuid) {
    if (uuid == null) return '-';
    return _clients.where((c) => c.uuid == uuid).firstOrNull?.nom ?? '-';
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    final parts = iso.split('-');
    if (parts.length != 3) return iso;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  Future<String?> _pickDate(TextEditingController ctrl) async {
    final initial = DateTime.tryParse(ctrl.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      final iso =
          '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
      setState(() => ctrl.text = iso);
    }
    return null;
  }

  void _startEdit(Dossier d) {
    setState(() {
      _editingDossier = d;
      _numeroBlCtrl.text = d.numeroBl ?? '';
      _portChargementCtrl.text = d.portChargement ?? '';
      _portDestinationCtrl.text = d.portDestination ?? '';
      _natureMarchandiseCtrl.text = d.natureMarchandise ?? '';
      _dateArriveePnCtrl.text = d.dateArriveePn ?? '';
      _dateArriveeMatadictrl.text = d.dateArriveeMatadi ?? '';
      _datePaiement30DraftCtrl.text = d.datePaiement30Draft ?? '';
      _datePaiement30PnCtrl.text = d.datePaiement30Pn ?? '';
      _datePaiement40MatadictrlCtrl.text = d.datePaiement40Matadi ?? '';
      _montantCtrl.text = d.montantConvenu != null ? d.montantConvenu.toString() : '';
      _selectedClientUuid = _clients.any((c) => c.uuid == d.clientUuid) ? d.clientUuid : null;
      _selectedStatut = _kStatuts.contains(d.statut) ? d.statut : null;
    });
  }

  void _cancelEdit() {
    _formKey.currentState?.reset();
    setState(() {
      _editingDossier = null;
      _numeroBlCtrl.clear();
      _portChargementCtrl.clear();
      _portDestinationCtrl.clear();
      _natureMarchandiseCtrl.clear();
      _dateArriveePnCtrl.clear();
      _dateArriveeMatadictrl.clear();
      _datePaiement30DraftCtrl.clear();
      _datePaiement30PnCtrl.clear();
      _datePaiement40MatadictrlCtrl.clear();
      _montantCtrl.clear();
      _selectedClientUuid = null;
      _selectedStatut = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final isEditing = _editingDossier != null;
    final montant = double.tryParse(_montantCtrl.text.trim().replaceAll(',', '.'));
    try {
      if (isEditing) {
        await AppDatabase.instance.updateDossier(
          uuid: _editingDossier!.uuid,
          clientUuid: _selectedClientUuid,
          numeroBl: _n(_numeroBlCtrl.text),
          portChargement: _n(_portChargementCtrl.text),
          portDestination: _n(_portDestinationCtrl.text),
          natureMarchandise: _n(_natureMarchandiseCtrl.text),
          dateArriveePn: _n(_dateArriveePnCtrl.text),
          dateArriveeMatadi: _n(_dateArriveeMatadictrl.text),
          datePaiement30Draft: _n(_datePaiement30DraftCtrl.text),
          datePaiement30Pn: _n(_datePaiement30PnCtrl.text),
          datePaiement40Matadi: _n(_datePaiement40MatadictrlCtrl.text),
          montantConvenu: montant,
          statut: _selectedStatut,
        );
      } else {
        await AppDatabase.instance.createDossier(
          clientUuid: _selectedClientUuid,
          numeroBl: _n(_numeroBlCtrl.text),
          portChargement: _n(_portChargementCtrl.text),
          portDestination: _n(_portDestinationCtrl.text),
          natureMarchandise: _n(_natureMarchandiseCtrl.text),
          dateArriveePn: _n(_dateArriveePnCtrl.text),
          dateArriveeMatadi: _n(_dateArriveeMatadictrl.text),
          datePaiement30Draft: _n(_datePaiement30DraftCtrl.text),
          datePaiement30Pn: _n(_datePaiement30PnCtrl.text),
          datePaiement40Matadi: _n(_datePaiement40MatadictrlCtrl.text),
          montantConvenu: montant,
          statut: _selectedStatut,
        );
      }
      _cancelEdit();
      await _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEditing ? 'Dossier modifié avec succès.' : 'Dossier ajouté avec succès.'),
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

  Future<void> _confirmDelete(Dossier d) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le dossier'),
        content: Text('Voulez-vous vraiment supprimer le dossier "${d.numeroBl ?? d.uuid}" ?'),
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
      if (_editingDossier?.uuid == d.uuid) _cancelEdit();
      await AppDatabase.instance.deleteDossier(d.uuid);
      await _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dossier supprimé.')));
      }
    }
  }

  String? _n(String s) => s.trim().isEmpty ? null : s.trim();

  int _conteneurCount(String dossierUuid) => _conteneurCounts[dossierUuid] ?? 0;

  Future<void> _showConteneursDialog(Dossier dossier) async {
    final numeroCtrl = TextEditingController();
    final nomArticleCtrl = TextEditingController();
    final quantiteCtrl = TextEditingController();
    final uniteMesureCtrl = TextEditingController();
    String? selectedDimension;
    var conteneurs = await AppDatabase.instance.getConteneursByDossier(dossier.uuid);
    Conteneur? selectedConteneur = conteneurs.firstOrNull;
    var details = selectedConteneur == null
        ? <DetailConteneur>[]
        : await AppDatabase.instance.getDetailsByConteneur(selectedConteneur.uuid);
    var isSaving = false;
    var isSavingDetail = false;

    Future<void> refreshConteneurs(StateSetter setDialogState) async {
      final items = await AppDatabase.instance.getConteneursByDossier(dossier.uuid);
      final selectedUuid = selectedConteneur?.uuid;
      final nextSelected = items.where((item) => item.uuid == selectedUuid).firstOrNull ?? items.firstOrNull;
      final nextDetails = nextSelected == null
          ? <DetailConteneur>[]
          : await AppDatabase.instance.getDetailsByConteneur(nextSelected.uuid);
      if (!mounted) return;
      setDialogState(() {
        conteneurs = items;
        selectedConteneur = nextSelected;
        details = nextDetails;
      });
    }

    Future<void> refreshDetails(StateSetter setDialogState) async {
      final current = selectedConteneur;
      if (current == null) {
        setDialogState(() {
          details = [];
        });
        return;
      }

      final items = await AppDatabase.instance.getDetailsByConteneur(current.uuid);
      if (!mounted) return;
      setDialogState(() {
        details = items;
      });
    }

    try {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              Future<void> addConteneur() async {
                final numero = numeroCtrl.text.trim();
                if (numero.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Le numéro de conteneur est requis.')),
                  );
                  return;
                }

                if (selectedDimension == null || selectedDimension!.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('La dimension du conteneur est requise.')),
                  );
                  return;
                }

                setDialogState(() => isSaving = true);
                try {
                  await AppDatabase.instance.createConteneur(
                    dossierUuid: dossier.uuid,
                    numeroConteneur: numero,
                    dimension: selectedDimension,
                  );
                  numeroCtrl.clear();
                  setDialogState(() => selectedDimension = null);
                  await _loadAll();
                  await refreshConteneurs(setDialogState);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
                    );
                  }
                } finally {
                  if (mounted) {
                    setDialogState(() => isSaving = false);
                  }
                }
              }

              Future<void> deleteConteneur(Conteneur conteneur) async {
                final confirmed = await showDialog<bool>(
                  context: dialogContext,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Supprimer le conteneur'),
                    content: Text(
                      'Voulez-vous vraiment supprimer le conteneur "${conteneur.numeroConteneur ?? conteneur.uuid}" ?',
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

                if (confirmed != true) return;

                await AppDatabase.instance.deleteConteneur(conteneur.uuid);
                await _loadAll();
                await refreshConteneurs(setDialogState);
              }

              Future<void> addDetail() async {
                final current = selectedConteneur;
                if (current == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sélectionnez d\'abord un conteneur.')),
                  );
                  return;
                }

                final nomArticle = nomArticleCtrl.text.trim();
                if (nomArticle.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Le nom de l\'article est requis.')),
                  );
                  return;
                }

                final quantiteText = quantiteCtrl.text.trim().replaceAll(',', '.');
                final quantite = quantiteText.isEmpty ? null : double.tryParse(quantiteText);
                if (quantiteText.isNotEmpty && quantite == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('La quantité est invalide.')),
                  );
                  return;
                }

                setDialogState(() => isSavingDetail = true);
                try {
                  await AppDatabase.instance.createDetailConteneur(
                    conteneurUuid: current.uuid,
                    nomArticle: nomArticle,
                    quantite: quantite,
                    uniteMesure: _n(uniteMesureCtrl.text),
                  );
                  nomArticleCtrl.clear();
                  quantiteCtrl.clear();
                  uniteMesureCtrl.clear();
                  await refreshDetails(setDialogState);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
                    );
                  }
                } finally {
                  if (mounted) {
                    setDialogState(() => isSavingDetail = false);
                  }
                }
              }

              Future<void> deleteDetail(DetailConteneur detail) async {
                final confirmed = await showDialog<bool>(
                  context: dialogContext,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Supprimer le détail'),
                    content: Text(
                      'Voulez-vous vraiment supprimer le détail "${detail.nomArticle ?? detail.uuid}" ?',
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

                if (confirmed != true) return;

                await AppDatabase.instance.deleteDetailConteneur(detail.uuid);
                await refreshDetails(setDialogState);
              }

              return AlertDialog(
                title: Text('Conteneurs du dossier ${dossier.numeroBl ?? dossier.uuid}'),
                content: SizedBox(
                  width: 1100,
                  height: 620,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    'Ajouter un conteneur',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1A237E),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: numeroCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Numéro de conteneur',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.inventory_2_outlined),
                                    ),
                                    onFieldSubmitted: (_) => addConteneur(),
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    value: selectedDimension,
                                    decoration: const InputDecoration(
                                      labelText: 'Dimension',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.straighten_outlined),
                                    ),
                                    items: _kDimensionsConteneur
                                        .map((dimension) => DropdownMenuItem(
                                              value: dimension,
                                              child: Text(dimension),
                                            ))
                                        .toList(),
                                    onChanged: (value) => setDialogState(() => selectedDimension = value),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    onPressed: isSaving ? null : addConteneur,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1A237E),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                    ),
                                    icon: isSaving
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.add_box_outlined),
                                    label: const Text('Ajouter'),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Conteneurs (${conteneurs.length})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1A237E),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: conteneurs.isEmpty
                                        ? const Center(child: Text('Aucun conteneur pour ce dossier.'))
                                        : SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: SingleChildScrollView(
                                              child: DataTable(
                                                headingRowColor: WidgetStateProperty.all(
                                                  const Color(0xFF1A237E).withValues(alpha: 0.08),
                                                ),
                                                columns: const [
                                                  DataColumn(label: Text('Numéro conteneur')),
                                                  DataColumn(label: Text('Dimension')),
                                                  DataColumn(label: Text('Actions')),
                                                ],
                                                rows: conteneurs.map((conteneur) {
                                                  final isSelected = selectedConteneur?.uuid == conteneur.uuid;
                                                  return DataRow(
                                                    selected: isSelected,
                                                    color: WidgetStateProperty.resolveWith(
                                                      (states) => isSelected
                                                          ? const Color(0xFF1A237E).withValues(alpha: 0.08)
                                                          : null,
                                                    ),
                                                    onSelectChanged: (_) async {
                                                      selectedConteneur = conteneur;
                                                      await refreshDetails(setDialogState);
                                                    },
                                                    cells: [
                                                      DataCell(
                                                        Text(
                                                          conteneur.numeroConteneur ?? '-',
                                                          style: TextStyle(
                                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                                          ),
                                                        ),
                                                      ),
                                                      DataCell(Text(conteneur.dimension ?? '-')),
                                                      DataCell(
                                                        IconButton(
                                                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                                                          tooltip: 'Supprimer le conteneur et ses détails',
                                                          onPressed: () => deleteConteneur(conteneur),
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
                            const SizedBox(width: 16),
                            Expanded(
                              child: selectedConteneur == null
                                  ? const Center(
                                      child: Text('Sélectionnez un conteneur pour saisir ses détails.'),
                                    )
                                  : Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          'Détails de ${selectedConteneur!.numeroConteneur ?? selectedConteneur!.uuid}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1A237E),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        TextFormField(
                                          controller: nomArticleCtrl,
                                          decoration: const InputDecoration(
                                            labelText: 'Nom article',
                                            border: OutlineInputBorder(),
                                            prefixIcon: Icon(Icons.article_outlined),
                                          ),
                                          onFieldSubmitted: (_) => addDetail(),
                                        ),
                                        const SizedBox(height: 12),
                                        TextFormField(
                                          controller: quantiteCtrl,
                                          decoration: const InputDecoration(
                                            labelText: 'Quantité',
                                            border: OutlineInputBorder(),
                                            prefixIcon: Icon(Icons.numbers_outlined),
                                          ),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        ),
                                        const SizedBox(height: 12),
                                        TextFormField(
                                          controller: uniteMesureCtrl,
                                          decoration: const InputDecoration(
                                            labelText: 'Unité mesure',
                                            border: OutlineInputBorder(),
                                            prefixIcon: Icon(Icons.straighten_outlined),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        ElevatedButton.icon(
                                          onPressed: isSavingDetail ? null : addDetail,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF1565C0),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                          ),
                                          icon: isSavingDetail
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CircularProgressIndicator(
                                                    color: Colors.white,
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              : const Icon(Icons.playlist_add_outlined),
                                          label: const Text('Ajouter détail'),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Détails (${details.length})',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1A237E),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Expanded(
                                          child: details.isEmpty
                                              ? const Center(child: Text('Aucun détail pour ce conteneur.'))
                                              : SingleChildScrollView(
                                                  scrollDirection: Axis.horizontal,
                                                  child: SingleChildScrollView(
                                                    child: DataTable(
                                                      headingRowColor: WidgetStateProperty.all(
                                                        const Color(0xFF1565C0).withValues(alpha: 0.08),
                                                      ),
                                                      columns: const [
                                                        DataColumn(label: Text('Article')),
                                                        DataColumn(label: Text('Quantité')),
                                                        DataColumn(label: Text('Unité')),
                                                        DataColumn(label: Text('Actions')),
                                                      ],
                                                      rows: details.map((detail) {
                                                        return DataRow(
                                                          cells: [
                                                            DataCell(Text(detail.nomArticle ?? '-')),
                                                            DataCell(Text(
                                                              detail.quantite != null
                                                                  ? detail.quantite!.toStringAsFixed(2)
                                                                  : '-',
                                                            )),
                                                            DataCell(Text(detail.uniteMesure ?? '-')),
                                                            DataCell(
                                                              IconButton(
                                                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                                                tooltip: 'Supprimer',
                                                                onPressed: () => deleteDetail(detail),
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
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Fermer'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      numeroCtrl.dispose();
      nomArticleCtrl.dispose();
      quantiteCtrl.dispose();
      uniteMesureCtrl.dispose();
    }
  }

  // ── Date field helper ──────────────────────────────────────────────────────
  Widget _dateField(String label, TextEditingController ctrl) {
    return TextFormField(
      controller: ctrl,
      readOnly: true,
      onTap: () => _pickDate(ctrl),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.calendar_today_outlined),
        suffixIcon: ctrl.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => setState(() => ctrl.clear()),
              )
            : null,
      ),
    );
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    _editingDossier != null ? Icons.edit_outlined : Icons.add_circle_outline,
                    color: const Color(0xFF1A237E),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _editingDossier != null ? 'Modifier un dossier' : 'Ajouter un dossier',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A237E)),
                  ),
                ],
              ),
              const Divider(height: 20),
              // Ligne 1 : N° BL | Client | Statut
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _numeroBlCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Numéro BL *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.tag),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedClientUuid,
                      decoration: const InputDecoration(
                        labelText: 'Client',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('— Aucun —')),
                        ..._clients.map((c) => DropdownMenuItem(value: c.uuid, child: Text(c.nom))),
                      ],
                      onChanged: (v) => setState(() => _selectedClientUuid = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedStatut,
                      decoration: const InputDecoration(
                        labelText: 'Statut',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.info_outline),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('— Aucun —')),
                        ..._kStatuts.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                      ],
                      onChanged: (v) => setState(() => _selectedStatut = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Ligne 2 : Port chargement | Port destination | Nature marchandise
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _portChargementCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Port chargement',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.anchor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _portDestinationCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Port destination',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.flag_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _natureMarchandiseCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nature marchandise',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.inventory_2_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Ligne 3 : Arrivée PN | Arrivée Matadi | Montant convenu
              Row(
                children: [
                  Expanded(child: _dateField('Arrivée PN', _dateArriveePnCtrl)),
                  const SizedBox(width: 12),
                  Expanded(child: _dateField('Arrivée Matadi', _dateArriveeMatadictrl)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _montantCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Montant convenu',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        if (double.tryParse(v.trim().replaceAll(',', '.')) == null) return 'Nombre invalide';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Ligne 4 : Paiement 30% Draft | Paiement 30% PN | Paiement 40% Matadi
              Row(
                children: [
                  Expanded(child: _dateField('Paiement 30% Draft', _datePaiement30DraftCtrl)),
                  const SizedBox(width: 12),
                  Expanded(child: _dateField('Paiement 30% PN', _datePaiement30PnCtrl)),
                  const SizedBox(width: 12),
                  Expanded(child: _dateField('Paiement 40% Matadi', _datePaiement40MatadictrlCtrl)),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Icon(_editingDossier != null ? Icons.save_outlined : Icons.add),
                    label: Text(_editingDossier != null ? 'Modifier' : 'Ajouter'),
                  ),
                  if (_editingDossier != null) ...[
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
    );
  }

  // ── List ──────────────────────────────────────────────────────────────────
  Color _statutColor(String? statut) {
    return switch (statut) {
      'En attente' => Colors.orange,
      'En cours' => Colors.indigo,
      'Clôturé' => Colors.green,
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
                Icon(Icons.folder_outlined, color: Color(0xFF1A237E)),
                SizedBox(width: 8),
                Text(
                  'Liste des dossiers',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A237E)),
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
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_filteredDossiers.isEmpty)
              const Expanded(child: Center(child: Text('Aucun dossier trouvé.')))
            else
              Expanded(
                child: Scrollbar(
                  controller: _hScrollCtrl,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _hScrollCtrl,
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          const Color(0xFF1A237E).withValues(alpha: 0.08),
                        ),
                        columnSpacing: 20,
                        columns: const [
                          DataColumn(label: Text('N° BL')),
                          DataColumn(label: Text('Client')),
                          DataColumn(label: Text('Port charg.')),
                          DataColumn(label: Text('Port dest.')),
                          DataColumn(label: Text('Nbre conteneur')),
                          DataColumn(label: Text('Statut')),
                          DataColumn(label: Text('Marchandise')),
                          DataColumn(label: Text('Arr. PN')),
                          DataColumn(label: Text('Arr. Matadi')),
                          DataColumn(label: Text('Paiem. 30% Draft')),
                          DataColumn(label: Text('Paiem. 30% PN')),
                          DataColumn(label: Text('Paiem. 40% Matadi')),
                          DataColumn(label: Text('Montant')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: _filteredDossiers.map((d) {
                          final isEditing = _editingDossier?.uuid == d.uuid;
                          return DataRow(
                            color: WidgetStateProperty.resolveWith(
                              (s) => isEditing ? const Color(0xFF1A237E).withValues(alpha: 0.06) : null,
                            ),
                            cells: [
                              DataCell(Text(d.numeroBl ?? '-')),
                              DataCell(Text(_clientLabel(d.clientUuid))),
                              DataCell(Text(d.portChargement ?? '-')),
                              DataCell(Text(d.portDestination ?? '-')),
                              DataCell(Text(_conteneurCount(d.uuid).toString())),
                              DataCell(
                                d.statut != null
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _statutColor(d.statut).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: _statutColor(d.statut).withValues(alpha: 0.4)),
                                        ),
                                        child: Text(
                                          d.statut!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: _statutColor(d.statut),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      )
                                    : const Text('-'),
                              ),
                              DataCell(Text(d.natureMarchandise ?? '-')),
                              DataCell(Text(_formatDate(d.dateArriveePn))),
                              DataCell(Text(_formatDate(d.dateArriveeMatadi))),
                              DataCell(Text(_formatDate(d.datePaiement30Draft))),
                              DataCell(Text(_formatDate(d.datePaiement30Pn))),
                              DataCell(Text(_formatDate(d.datePaiement40Matadi))),
                              DataCell(Text(
                                d.montantConvenu != null
                                    ? d.montantConvenu!.toStringAsFixed(2)
                                    : '-',
                              )),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.inventory_2_outlined,
                                        color: Color(0xFF1565C0),
                                      ),
                                      tooltip: 'Gérer les conteneurs',
                                      onPressed: () => _showConteneursDialog(d),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, color: Color(0xFF1A237E)),
                                      tooltip: 'Modifier',
                                      onPressed: () => _startEdit(d),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      tooltip: 'Supprimer',
                                      onPressed: () => _confirmDelete(d),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildForm(),
          const SizedBox(height: 16),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }
}
