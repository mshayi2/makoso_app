import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../models/conteneur.dart';
import '../models/detail_conteneur.dart';
import '../models/dossier.dart';
import '../models/interchange.dart';
import '../models/utilisateur.dart';

const List<String> _kDimensions = ['20 Pieds', '40 Pieds'];

class ConteneursMakosoScreen extends StatefulWidget {
  final Utilisateur user;
  const ConteneursMakosoScreen({super.key, required this.user});

  @override
  State<ConteneursMakosoScreen> createState() => _ConteneursMakosoScreenState();
}

class _ConteneursMakosoScreenState extends State<ConteneursMakosoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _searchCtrl = TextEditingController();

  // Form controllers
  final _numeroCtrl = TextEditingController();
  final _dateSortiPortCtrl = TextEditingController();
  final _nomTransporteurCtrl = TextEditingController();
  final _marqueCamionCtrl = TextEditingController();
  final _numeroPlaqueCtrl = TextEditingController();
  final _nomChauffeurCtrl = TextEditingController();
  final _numeroChauffeurCtrl = TextEditingController();
  final _lieuDechargementCtrl = TextEditingController();
  final _dateArriverLieuCtrl = TextEditingController();
  final _dateDechargementCtrl = TextEditingController();
  final _dateDepartRetourCtrl = TextEditingController();
  final _dateRetourPortCtrl = TextEditingController();

  String? _selectedDossierUuid;
  String? _selectedDimension;

  Conteneur? _editingConteneur;
  bool _isSaving = false;
  bool _isLoading = true;

  List<Map<String, Object?>> _conteneurs = [];
  List<Dossier> _activeDossiers = [];

  bool get _canEdit => widget.user.role != 'opérateur logistique';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
    _loadAll();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _numeroCtrl.dispose();
    _dateSortiPortCtrl.dispose();
    _nomTransporteurCtrl.dispose();
    _marqueCamionCtrl.dispose();
    _numeroPlaqueCtrl.dispose();
    _nomChauffeurCtrl.dispose();
    _numeroChauffeurCtrl.dispose();
    _lieuDechargementCtrl.dispose();
    _dateArriverLieuCtrl.dispose();
    _dateDechargementCtrl.dispose();
    _dateDepartRetourCtrl.dispose();
    _dateRetourPortCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      AppDatabase.instance.getAllActiveConteneurs(),
      AppDatabase.instance.getActiveDossiers(),
    ]);
    if (!mounted) return;
    setState(() {
      _conteneurs = results[0] as List<Map<String, Object?>>;
      _activeDossiers = results[1] as List<Dossier>;
      _isLoading = false;
    });
  }

  List<Map<String, Object?>> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _conteneurs;
    return _conteneurs.where((row) {
      final numero = (row['numero_conteneur'] as String? ?? '').toLowerCase();
      final bl = (row['numero_bl'] as String? ?? '').toLowerCase();
      return numero.contains(q) || bl.contains(q);
    }).toList();
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    final parts = iso.split('-');
    if (parts.length != 3) return iso;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    final initial = DateTime.tryParse(ctrl.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        ctrl.text =
            '${picked.year.toString().padLeft(4, '0')}-'
            '${picked.month.toString().padLeft(2, '0')}-'
            '${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  void _startEdit(Map<String, Object?> row) {
    final c = Conteneur.fromMap(row);
    setState(() {
      _editingConteneur = c;
      _selectedDossierUuid = _activeDossiers.any((d) => d.uuid == c.dossierUuid)
          ? c.dossierUuid
          : null;
      _numeroCtrl.text = c.numeroConteneur ?? '';
      _selectedDimension = _kDimensions.contains(c.dimension) ? c.dimension : null;
      _dateSortiPortCtrl.text = c.dateSortiPort ?? '';
      _nomTransporteurCtrl.text = c.nomTransporteur ?? '';
      _marqueCamionCtrl.text = c.marqueCamion ?? '';
      _numeroPlaqueCtrl.text = c.numeroPlaque ?? '';
      _nomChauffeurCtrl.text = c.nomChauffeur ?? '';
      _numeroChauffeurCtrl.text = c.numeroChauffeur ?? '';
      _lieuDechargementCtrl.text = c.lieuDechargement ?? '';
      _dateArriverLieuCtrl.text = c.dateArriverLieuDechargement ?? '';
      _dateDechargementCtrl.text = c.dateDechargement ?? '';
      _dateDepartRetourCtrl.text = c.dateDepartRetourPort ?? '';
      _dateRetourPortCtrl.text = c.dateRetourPort ?? '';
    });
  }

  void _cancelEdit() {
    _formKey.currentState?.reset();
    setState(() {
      _editingConteneur = null;
      _selectedDossierUuid = null;
      _selectedDimension = null;
      _numeroCtrl.clear();
      _dateSortiPortCtrl.clear();
      _nomTransporteurCtrl.clear();
      _marqueCamionCtrl.clear();
      _numeroPlaqueCtrl.clear();
      _nomChauffeurCtrl.clear();
      _numeroChauffeurCtrl.clear();
      _lieuDechargementCtrl.clear();
      _dateArriverLieuCtrl.clear();
      _dateDechargementCtrl.clear();
      _dateDepartRetourCtrl.clear();
      _dateRetourPortCtrl.clear();
    });
  }

  String? _n(String s) => s.trim().isEmpty ? null : s.trim();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final isEditing = _editingConteneur != null;
    try {
      if (isEditing) {
        await AppDatabase.instance.updateConteneur(
          uuid: _editingConteneur!.uuid,
          dossierUuid: _selectedDossierUuid,
          numeroConteneur: _n(_numeroCtrl.text),
          dimension: _selectedDimension,
          dateSortiPort: _n(_dateSortiPortCtrl.text),
          nomTransporteur: _n(_nomTransporteurCtrl.text),
          marqueCamion: _n(_marqueCamionCtrl.text),
          numeroPlaque: _n(_numeroPlaqueCtrl.text),
          nomChauffeur: _n(_nomChauffeurCtrl.text),
          numeroChauffeur: _n(_numeroChauffeurCtrl.text),
          lieuDechargement: _n(_lieuDechargementCtrl.text),
          dateArriverLieuDechargement: _n(_dateArriverLieuCtrl.text),
          dateDechargement: _n(_dateDechargementCtrl.text),
          dateDepartRetourPort: _n(_dateDepartRetourCtrl.text),
          dateRetourPort: _n(_dateRetourPortCtrl.text),
        );
      } else {
        if (_selectedDossierUuid == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Veuillez sélectionner un dossier.')),
          );
          setState(() => _isSaving = false);
          return;
        }
        await AppDatabase.instance.createConteneur(
          dossierUuid: _selectedDossierUuid!,
          numeroConteneur: _numeroCtrl.text.trim(),
          dimension: _selectedDimension,
          dateSortiPort: _n(_dateSortiPortCtrl.text),
          nomTransporteur: _n(_nomTransporteurCtrl.text),
          marqueCamion: _n(_marqueCamionCtrl.text),
          numeroPlaque: _n(_numeroPlaqueCtrl.text),
          nomChauffeur: _n(_nomChauffeurCtrl.text),
          numeroChauffeur: _n(_numeroChauffeurCtrl.text),
          lieuDechargement: _n(_lieuDechargementCtrl.text),
          dateArriverLieuDechargement: _n(_dateArriverLieuCtrl.text),
          dateDechargement: _n(_dateDechargementCtrl.text),
          dateDepartRetourPort: _n(_dateDepartRetourCtrl.text),
          dateRetourPort: _n(_dateRetourPortCtrl.text),
        );
      }
      _cancelEdit();
      await _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEditing
              ? 'Conteneur modifié avec succès.'
              : 'Conteneur ajouté avec succès.'),
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

  Future<void> _confirmDelete(Map<String, Object?> row) async {
    final numero = row['numero_conteneur'] as String? ?? row['uuid'] as String;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le conteneur'),
        content: Text('Supprimer le conteneur "$numero" et tous ses détails ?'),
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
      if (_editingConteneur?.uuid == row['uuid']) _cancelEdit();
      await AppDatabase.instance.deleteConteneur(row['uuid'] as String);
      await _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conteneur supprimé.')),
        );
      }
    }
  }

  // ── Popup: Détails logistiques (double-clic) ──────────────────────────────
  Future<void> _showDetailsPopup(Map<String, Object?> row) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.inventory_2_outlined, color: Color(0xFF1A237E)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Détails – ${row['numero_conteneur'] ?? row['uuid']}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 640,
          child: SingleChildScrollView(
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(3),
              },
              children: [
                _detailRow('Numéro conteneur', row['numero_conteneur']),
                _detailRow('Dossier (N° BL)', row['numero_bl']),
                _detailRow('Client', row['client_nom']),
                _detailRow('Dimension', row['dimension']),
                _detailRow('Date sortie port', _formatDate(row['date_sorti_port'] as String?)),
                _detailRow('Transporteur', row['nom_transporteur']),
                _detailRow('Marque camion', row['marque_camion']),
                _detailRow('N° plaque', row['numero_plaque']),
                _detailRow('Nom chauffeur', row['nom_chauffeur']),
                _detailRow('N° chauffeur', row['numero_chauffeur']),
                _detailRow('Lieu déchargement', row['lieu_dechargement']),
                _detailRow('Date arrivée lieu décharg.', _formatDate(row['date_arriver_lieu_dechargement'] as String?)),
                _detailRow('Date déchargement', _formatDate(row['date_dechargement'] as String?)),
                _detailRow('Date départ retour port', _formatDate(row['date_depart_retour_port'] as String?)),
                _detailRow('Date retour port', _formatDate(row['date_retour_port'] as String?)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
        ],
      ),
    );
  }

  TableRow _detailRow(String label, Object? value) {
    final text = value?.toString();
    return TableRow(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: Color(0xFF1A237E), fontSize: 13)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Text(
            (text == null || text.isEmpty) ? '-' : text,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }

  // ── Popup: Détails articles (detail_conteneurs) ───────────────────────────
  Future<void> _showArticlesDialog(Map<String, Object?> row) async {
    final conteneur = Conteneur.fromMap(row);
    final nomArticleCtrl = TextEditingController();
    final quantiteCtrl = TextEditingController();
    final uniteMesureCtrl = TextEditingController();
    var details = await AppDatabase.instance.getDetailsByConteneur(conteneur.uuid);
    var isSavingDetail = false;

    try {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> addDetail() async {
              final nom = nomArticleCtrl.text.trim();
              if (nom.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Le nom de l'article est requis.")),
                );
                return;
              }
              final qStr = quantiteCtrl.text.trim().replaceAll(',', '.');
              final quantite = qStr.isEmpty ? null : double.tryParse(qStr);
              if (qStr.isNotEmpty && quantite == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Quantité invalide.')),
                );
                return;
              }
              setDialogState(() => isSavingDetail = true);
              try {
                await AppDatabase.instance.createDetailConteneur(
                  conteneurUuid: conteneur.uuid,
                  nomArticle: nom,
                  quantite: quantite,
                  uniteMesure: _n(uniteMesureCtrl.text),
                );
                nomArticleCtrl.clear();
                quantiteCtrl.clear();
                uniteMesureCtrl.clear();
                final items =
                    await AppDatabase.instance.getDetailsByConteneur(conteneur.uuid);
                if (!mounted) return;
                setDialogState(() => details = items);
              } finally {
                if (mounted) setDialogState(() => isSavingDetail = false);
              }
            }

            Future<void> deleteDetail(DetailConteneur detail) async {
              final ok = await showDialog<bool>(
                context: ctx,
                builder: (c) => AlertDialog(
                  title: const Text('Supprimer le détail'),
                  content: Text('Supprimer "${detail.nomArticle ?? detail.uuid}" ?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Annuler')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red, foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Supprimer'),
                    ),
                  ],
                ),
              );
              if (ok != true) return;
              await AppDatabase.instance.deleteDetailConteneur(detail.uuid);
              final items =
                  await AppDatabase.instance.getDetailsByConteneur(conteneur.uuid);
              if (!mounted) return;
              setDialogState(() => details = items);
            }

            return AlertDialog(
              title: Text(
                  'Articles – ${conteneur.numeroConteneur ?? conteneur.uuid}'),
              content: SizedBox(
                width: 700,
                height: 500,
                child: Column(
                  children: [
                    // Add form
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: nomArticleCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Nom article',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.article_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 110,
                          child: TextFormField(
                            controller: quantiteCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Quantité',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 120,
                          child: TextFormField(
                            controller: uniteMesureCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Unité',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: ElevatedButton.icon(
                            onPressed: isSavingDetail ? null : addDetail,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A237E),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 18, horizontal: 12),
                            ),
                            icon: isSavingDetail
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.add),
                            label: const Text('Ajouter'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: details.isEmpty
                          ? const Center(
                              child: Text('Aucun article pour ce conteneur.'))
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(
                                      const Color(0xFF1A237E)
                                          .withValues(alpha: 0.08)),
                                  columns: const [
                                    DataColumn(label: Text('Article')),
                                    DataColumn(label: Text('Quantité')),
                                    DataColumn(label: Text('Unité')),
                                    DataColumn(label: Text('Actions')),
                                  ],
                                  rows: details
                                      .map((d) => DataRow(cells: [
                                            DataCell(Text(d.nomArticle ?? '-')),
                                            DataCell(Text(d.quantite != null
                                                ? d.quantite!.toStringAsFixed(2)
                                                : '-')),
                                            DataCell(
                                                Text(d.uniteMesure ?? '-')),
                                            DataCell(IconButton(
                                              icon: const Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.red),
                                              tooltip: 'Supprimer',
                                              onPressed: () =>
                                                  deleteDetail(d),
                                            )),
                                          ]))
                                      .toList(),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Fermer')),
              ],
            );
          },
        ),
      );
    } finally {
      nomArticleCtrl.dispose();
      quantiteCtrl.dispose();
      uniteMesureCtrl.dispose();
    }
  }

  // ── Popup: Interchanges ───────────────────────────────────────────────────
  Future<void> _showInterchangesDialog(Map<String, Object?> row) async {
    final conteneur = Conteneur.fromMap(row);
    final pageCtrl = TextEditingController();
    final nomFichierCtrl = TextEditingController();
    Uint8List? selectedScanBytes;
    String? selectedScanName;
    var interchanges =
        await AppDatabase.instance.getInterchangesByConteneur(conteneur.uuid);
    var isSaving = false;

    try {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> pickFile() async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.any,
                withData: true,
              );
              if (result != null && result.files.isNotEmpty) {
                final file = result.files.first;
                if (file.bytes != null) {
                  setDialogState(() {
                    selectedScanBytes = file.bytes;
                    selectedScanName = file.name;
                    if (nomFichierCtrl.text.isEmpty) {
                      nomFichierCtrl.text = file.name;
                    }
                  });
                }
              }
            }

            Future<void> save() async {
              if (selectedScanBytes == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Veuillez choisir un fichier scan.')),
                );
                return;
              }
              final nom = nomFichierCtrl.text.trim();
              if (nom.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Le nom de fichier est requis.')),
                );
                return;
              }
              final pageText = pageCtrl.text.trim();
              final page = pageText.isEmpty ? null : int.tryParse(pageText);
              if (pageText.isNotEmpty && page == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('N° de page invalide.')),
                );
                return;
              }
              setDialogState(() => isSaving = true);
              try {
                await AppDatabase.instance.createInterchange(
                  conteneurUuid: conteneur.uuid,
                  scan: selectedScanBytes!,
                  nomFichier: nom,
                  page: page,
                );
                pageCtrl.clear();
                nomFichierCtrl.clear();
                final items = await AppDatabase.instance
                    .getInterchangesByConteneur(conteneur.uuid);
                if (!mounted) return;
                setDialogState(() {
                  selectedScanBytes = null;
                  selectedScanName = null;
                  interchanges = items;
                });
              } finally {
                if (mounted) setDialogState(() => isSaving = false);
              }
            }

            Future<void> deleteInterchange(Interchange interchange) async {
              final ok = await showDialog<bool>(
                context: ctx,
                builder: (c) => AlertDialog(
                  title: const Text('Supprimer l\'interchange'),
                  content: Text(
                    'Supprimer page ${interchange.page ?? '-'} '
                    '(${interchange.nomFichier ?? interchange.uuid}) ?',
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Annuler')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Supprimer'),
                    ),
                  ],
                ),
              );
              if (ok != true) return;
              await AppDatabase.instance.deleteInterchange(interchange.uuid);
              final items = await AppDatabase.instance
                  .getInterchangesByConteneur(conteneur.uuid);
              if (!mounted) return;
              setDialogState(() => interchanges = items);
            }

            return AlertDialog(
              title: Text(
                  'Interchanges – ${conteneur.numeroConteneur ?? conteneur.uuid}'),
              content: SizedBox(
                width: 700,
                height: 520,
                child: Column(
                  children: [
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Ajouter un interchange',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A237E))),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: nomFichierCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Nom fichier',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.attach_file),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 100,
                                  child: TextFormField(
                                    controller: pageCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Page',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: pickFile,
                                  icon: const Icon(Icons.upload_file_outlined),
                                  label: Text(selectedScanName != null
                                      ? selectedScanName!
                                      : 'Choisir fichier'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: isSaving ? null : save,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1A237E),
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: isSaving
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2))
                                      : const Icon(Icons.save_outlined),
                                  label: const Text('Sauvegarder'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: interchanges.isEmpty
                          ? const Center(
                              child: Text('Aucun interchange pour ce conteneur.'))
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(
                                      const Color(0xFF1A237E)
                                          .withValues(alpha: 0.08)),
                                  columns: const [
                                    DataColumn(label: Text('Page')),
                                    DataColumn(label: Text('Fichier')),
                                    DataColumn(label: Text('Actions')),
                                  ],
                                  rows: interchanges
                                      .map((ic) => DataRow(cells: [
                                            DataCell(
                                                Text(ic.page?.toString() ?? '-')),
                                            DataCell(
                                                Text(ic.nomFichier ?? '-')),
                                            DataCell(IconButton(
                                              icon: const Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.red),
                                              tooltip: 'Supprimer',
                                              onPressed: () =>
                                                  deleteInterchange(ic),
                                            )),
                                          ]))
                                      .toList(),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Fermer')),
              ],
            );
          },
        ),
      );
    } finally {
      pageCtrl.dispose();
      nomFichierCtrl.dispose();
    }
  }

  // ── Date field helper ─────────────────────────────────────────────────────
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
    final isEditing = _editingConteneur != null;
    const labelStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: Color(0xFF1A237E),
    );

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
                    isEditing ? Icons.edit_outlined : Icons.add_box_outlined,
                    color: const Color(0xFF1A237E),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEditing
                        ? 'Modifier le conteneur'
                        : 'Ajouter un conteneur',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),

              // ── Dossier + numéro + dimension
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      value: _selectedDossierUuid,
                      decoration: const InputDecoration(
                        labelText: 'Dossier (N° BL)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.folder_outlined),
                      ),
                      items: _activeDossiers
                          .map((d) => DropdownMenuItem(
                                value: d.uuid,
                                child: Text(d.numeroBl ?? d.uuid),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedDossierUuid = v),
                      validator: (v) =>
                          v == null ? 'Sélectionnez un dossier' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _numeroCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Numéro conteneur',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.inventory_2_outlined),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Champ requis'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _selectedDimension,
                      decoration: const InputDecoration(
                        labelText: 'Dimension',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.straighten_outlined),
                      ),
                      items: _kDimensions
                          .map((d) =>
                              DropdownMenuItem(value: d, child: Text(d)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedDimension = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Transport section header
              const Text('Informations de transport', style: labelStyle),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _dateField('Date sortie port', _dateSortiPortCtrl),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _nomTransporteurCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nom transporteur',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.business_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _marqueCamionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Marque camion',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.airport_shuttle_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _numeroPlaqueCtrl,
                      decoration: const InputDecoration(
                        labelText: 'N° plaque',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.pin_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _nomChauffeurCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nom chauffeur',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _numeroChauffeurCtrl,
                      decoration: const InputDecoration(
                        labelText: 'N° chauffeur',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _lieuDechargementCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Lieu de déchargement',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.place_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Dates section header
              const Text('Dates de déchargement / retour', style: labelStyle),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _dateField(
                        'Arrivée lieu déchargement', _dateArriverLieuCtrl),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dateField('Date déchargement', _dateDechargementCtrl),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dateField(
                        'Départ retour port', _dateDepartRetourCtrl),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dateField('Date retour port', _dateRetourPortCtrl),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isEditing) ...[
                    OutlinedButton.icon(
                      onPressed: _cancelEdit,
                      icon: const Icon(Icons.close),
                      label: const Text('Annuler'),
                    ),
                    const SizedBox(width: 10),
                  ],
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Icon(isEditing
                            ? Icons.save_outlined
                            : Icons.add_box_outlined),
                    label: Text(isEditing ? 'Enregistrer' : 'Ajouter'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Grid ──────────────────────────────────────────────────────────────────
  Widget _buildGrid() {
    final rows = _filtered;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined, color: Color(0xFF1A237E)),
                const SizedBox(width: 8),
                const Text(
                  'Conteneurs actifs',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A237E),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Recherche par N° conteneur ou N° BL...',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => _searchCtrl.clear(),
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            if (_isLoading)
              const Expanded(
                  child: Center(child: CircularProgressIndicator()))
            else if (rows.isEmpty)
              const Expanded(
                  child: Center(
                      child: Text('Aucun conteneur trouvé.',
                          style: TextStyle(color: Colors.grey))))
            else
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                          const Color(0xFF1A237E).withValues(alpha: 0.08)),
                      columns: const [
                        DataColumn(label: Text('N° Conteneur')),
                        DataColumn(label: Text('N° BL (Dossier)')),
                        DataColumn(label: Text('Client')),
                        DataColumn(label: Text('Dimension')),
                        DataColumn(label: Text('Date sortie port')),
                        DataColumn(label: Text('Transporteur')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: rows.map((row) {
                        final isEditing =
                            _editingConteneur?.uuid == row['uuid'] as String?;
                        return DataRow(
                          color: WidgetStateProperty.resolveWith((states) =>
                              isEditing
                                  ? const Color(0xFF1A237E)
                                      .withValues(alpha: 0.08)
                                  : null),
                          cells: [
                            // Double-click on this cell opens details popup
                            DataCell(
                              GestureDetector(
                                onDoubleTap: () => _showDetailsPopup(row),
                                child: Tooltip(
                                  message: 'Double-clic pour voir les détails',
                                  child: Text(
                                    row['numero_conteneur'] as String? ?? '-',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                                Text(row['numero_bl'] as String? ?? '-')),
                            DataCell(
                                Text(row['client_nom'] as String? ?? '-')),
                            DataCell(
                                Text(row['dimension'] as String? ?? '-')),
                            DataCell(Text(_formatDate(
                                row['date_sorti_port'] as String?))),
                            DataCell(Text(
                                row['nom_transporteur'] as String? ?? '-')),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_canEdit)
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined,
                                          color: Color(0xFF1A237E)),
                                      tooltip: 'Modifier',
                                      onPressed: () => _startEdit(row),
                                    ),
                                  if (_canEdit)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.red),
                                      tooltip: 'Supprimer',
                                      onPressed: () =>
                                          _confirmDelete(row),
                                    ),
                                  IconButton(
                                    icon: const Icon(
                                        Icons.format_list_bulleted_outlined,
                                        color: Color(0xFF0288D1)),
                                    tooltip: 'Détails (articles)',
                                    onPressed: () =>
                                        _showArticlesDialog(row),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.swap_horiz,
                                        color: Color(0xFF00695C)),
                                    tooltip: 'Interchanges',
                                    onPressed: () =>
                                        _showInterchangesDialog(row),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                        Icons.info_outline,
                                        color: Colors.blueGrey),
                                    tooltip: 'Voir tous les détails',
                                    onPressed: () =>
                                        _showDetailsPopup(row),
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
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildForm(),
          const SizedBox(height: 16),
          Expanded(child: _buildGrid()),
        ],
      ),
    );
  }
}
