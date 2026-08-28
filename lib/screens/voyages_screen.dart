import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../database/app_database.dart';
import '../models/camion.dart';
import '../models/chauffeur_convoyeur.dart';
import '../models/client.dart';
import '../models/monnaie.dart';
import '../models/scan_voyage.dart';
import '../models/utilisateur.dart';
import '../models/voyage.dart';
import '../widgets/horizontal_table_scroller.dart';
import 'main_screen.dart' show AppCompany;

const List<String> _kStatuts = ['En attente', 'En cours', 'Terminé', 'Annulé'];
const List<String> _kDimensionsConteneur = ['20 pieds', '40 pieds'];

class VoyagesScreen extends StatefulWidget {
  final Utilisateur user;
  final AppCompany company;
  const VoyagesScreen({super.key, required this.user, required this.company});

  @override
  State<VoyagesScreen> createState() => _VoyagesScreenState();
}

class _VoyagesScreenState extends State<VoyagesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _numeroVoyageCtrl = TextEditingController();
  final _dateVoyageCtrl = TextEditingController();
  final _lieuDepartCtrl = TextEditingController();
  final _lieuDestinationCtrl = TextEditingController();
  final _poidsConteneurCtrl = TextEditingController();
  final _natureMarchandiseCtrl = TextEditingController();
  final _dateDepartOrigineCtrl = TextEditingController();
  final _dateArriverDestinationCtrl = TextEditingController();
  final _dateDepartRetourCtrl = TextEditingController();
  final _dateArriverRetourCtrl = TextEditingController();
  final _natureMarchandiseRetourCtrl = TextEditingController();
  final _nomClientRetourCtrl = TextEditingController();
  final _montantConvenuRetourCtrl = TextEditingController();
  final _montantCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _formScrollCtrl = ScrollController();

  String? _selectedCamionUuid;
  String? _selectedChauffeurUuid;
  String? _selectedConvoyeurUuid;
  String? _selectedMonnaieUuid;
  String? _selectedStatut;
  String? _selectedClientUuid;
  String? _selectedDimensionConteneur;

  Voyage? _editingVoyage;
  bool _isSaving = false;
  bool _isLoading = true;
  bool _isFormExpanded = true;
  bool _isListExpanded = true;

  List<Voyage> _voyages = [];
  List<Camion> _camions = [];
  List<ChauffeurConvoyeur> _chauffeurs = [];
  List<ChauffeurConvoyeur> _convoyeurs = [];
  List<Monnaie> _monnaies = [];
  List<Client> _marinaClients = [];

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
    _poidsConteneurCtrl.dispose();
    _natureMarchandiseCtrl.dispose();
    _dateDepartOrigineCtrl.dispose();
    _dateArriverDestinationCtrl.dispose();
    _dateDepartRetourCtrl.dispose();
    _dateArriverRetourCtrl.dispose();
    _natureMarchandiseRetourCtrl.dispose();
    _nomClientRetourCtrl.dispose();
    _montantConvenuRetourCtrl.dispose();
    _montantCtrl.dispose();
    _searchCtrl.dispose();
    _formScrollCtrl.dispose();
    super.dispose();
  }

  bool get _isOpLogistique => widget.user.role == 'opérateur logistique';
  bool get _isValidateur =>
      widget.user.role == 'boss' || widget.user.role == 'collaborateur';

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      AppDatabase.instance.getAllVoyages(),
      AppDatabase.instance.getAllCamions(),
      AppDatabase.instance.getAllChauffeursConvoyeurs(),
      AppDatabase.instance.getAllMonnaies(),
      AppDatabase.instance.getClientsByType('marina'),
    ]);
    if (!mounted) return;
    final tous = results[2] as List<ChauffeurConvoyeur>;
    setState(() {
      _voyages = results[0] as List<Voyage>;
      _camions = results[1] as List<Camion>;
      _chauffeurs = tous.where((c) => c.fonction == 'Chauffeur').toList();
      _convoyeurs = tous.where((c) => c.fonction == 'Convoyeur').toList();
      _monnaies = results[3] as List<Monnaie>;
      _marinaClients = results[4] as List<Client>;
      _isLoading = false;
    });
    if (_editingVoyage == null) {
      await _refreshNextVoyageNumber();
    }
  }

  Future<void> _refreshNextVoyageNumber() async {
    final numero = await AppDatabase.instance.getNextVoyageNumber(
      widget.user.nomUtilisateur,
    );
    if (!mounted || _editingVoyage != null) return;
    setState(() => _numeroVoyageCtrl.text = numero);
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
    return [
      c.marque,
      c.plaque,
    ].where((v) => v != null && v.isNotEmpty).join(' - ');
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

  Future<void> _pickDate(TextEditingController controller) async {
    final initial = DateTime.tryParse(controller.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        controller.text =
            '${picked.year.toString().padLeft(4, '0')}-'
            '${picked.month.toString().padLeft(2, '0')}-'
            '${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  void _startEdit(Voyage v) {
    setState(() {
      if (widget.company == AppCompany.marian) {
        _isFormExpanded = true;
      }
      _editingVoyage = v;
      _numeroVoyageCtrl.text = v.numeroVoyage ?? '';
      _dateVoyageCtrl.text = v.dateVoyage ?? '';
      _lieuDepartCtrl.text = v.lieuDepart ?? '';
      _lieuDestinationCtrl.text = v.lieuDestination ?? '';
      _selectedDimensionConteneur =
          _kDimensionsConteneur.contains(v.dimensionConteneur)
          ? v.dimensionConteneur
          : null;
      _poidsConteneurCtrl.text = v.poidsConteneur?.toString() ?? '';
      _natureMarchandiseCtrl.text = v.natureMarchandise ?? '';
      _dateDepartOrigineCtrl.text = v.dateDepartOrigine ?? '';
      _dateArriverDestinationCtrl.text = v.dateArriverDestination ?? '';
      _dateDepartRetourCtrl.text = v.dateDepartRetour ?? '';
      _dateArriverRetourCtrl.text = v.dateArriverRetour ?? '';
      _natureMarchandiseRetourCtrl.text = v.natureMarchandiseRetour ?? '';
      _nomClientRetourCtrl.text = v.nomClientRetour ?? '';
      _montantConvenuRetourCtrl.text = v.montantConvenuRetour?.toString() ?? '';
      _montantCtrl.text = v.montantConvenu != null
          ? v.montantConvenu.toString()
          : '';
      _selectedCamionUuid = _camions.any((c) => c.uuid == v.camionUuid)
          ? v.camionUuid
          : null;
      _selectedChauffeurUuid = _chauffeurs.any((c) => c.uuid == v.chauffeurUuid)
          ? v.chauffeurUuid
          : null;
      _selectedConvoyeurUuid = _convoyeurs.any((c) => c.uuid == v.convoyeurUuid)
          ? v.convoyeurUuid
          : null;
      _selectedMonnaieUuid = _monnaies.any((m) => m.uuid == v.monnaieUuid)
          ? v.monnaieUuid
          : null;
      _selectedStatut = _kStatuts.contains(v.statut) ? v.statut : null;
      _selectedClientUuid = _marinaClients.any((c) => c.uuid == v.clientUuid)
          ? v.clientUuid
          : null;
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
      _poidsConteneurCtrl.clear();
      _natureMarchandiseCtrl.clear();
      _dateDepartOrigineCtrl.clear();
      _dateArriverDestinationCtrl.clear();
      _dateDepartRetourCtrl.clear();
      _dateArriverRetourCtrl.clear();
      _natureMarchandiseRetourCtrl.clear();
      _nomClientRetourCtrl.clear();
      _montantConvenuRetourCtrl.clear();
      _montantCtrl.clear();
      _selectedCamionUuid = null;
      _selectedChauffeurUuid = null;
      _selectedConvoyeurUuid = null;
      _selectedMonnaieUuid = null;
      _selectedStatut = null;
      _selectedClientUuid = null;
      _selectedDimensionConteneur = null;
    });
    _refreshNextVoyageNumber();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final isEditing = _editingVoyage != null;
    final montant = double.tryParse(
      _montantCtrl.text.trim().replaceAll(',', '.'),
    );
    final poidsConteneur = double.tryParse(
      _poidsConteneurCtrl.text.trim().replaceAll(',', '.'),
    );
    final montantConvenuRetour = double.tryParse(
      _montantConvenuRetourCtrl.text.trim().replaceAll(',', '.'),
    );
    try {
      final String? numeroVoyage;
      if (isEditing) {
        numeroVoyage = _emptyToNull(_numeroVoyageCtrl.text);
      } else {
        final generatedNumero = await AppDatabase.instance.getNextVoyageNumber(
          widget.user.nomUtilisateur,
        );
        _numeroVoyageCtrl.text = generatedNumero;
        numeroVoyage = generatedNumero;
      }
      if (isEditing) {
        await AppDatabase.instance.updateVoyage(
          uuid: _editingVoyage!.uuid,
          numeroVoyage: numeroVoyage,
          dateVoyage: _emptyToNull(_dateVoyageCtrl.text),
          lieuDepart: _emptyToNull(_lieuDepartCtrl.text),
          lieuDestination: _emptyToNull(_lieuDestinationCtrl.text),
          dimensionConteneur: _selectedDimensionConteneur,
          poidsConteneur: poidsConteneur,
          natureMarchandise: _emptyToNull(_natureMarchandiseCtrl.text),
          dateDepartOrigine: _emptyToNull(_dateDepartOrigineCtrl.text),
          dateArriverDestination: _emptyToNull(
            _dateArriverDestinationCtrl.text,
          ),
          dateDepartRetour: _emptyToNull(_dateDepartRetourCtrl.text),
          dateArriverRetour: _emptyToNull(_dateArriverRetourCtrl.text),
          natureMarchandiseRetour: _emptyToNull(
            _natureMarchandiseRetourCtrl.text,
          ),
          nomClientRetour: _emptyToNull(_nomClientRetourCtrl.text),
          montantConvenuRetour: montantConvenuRetour,
          montantConvenu: montant,
          monnaieUuid: _selectedMonnaieUuid,
          statut: _selectedStatut,
          camionUuid: _selectedCamionUuid,
          chauffeurUuid: _selectedChauffeurUuid,
          convoyeurUuid: _selectedConvoyeurUuid,
          clientUuid: _selectedClientUuid,
        );
      } else {
        await AppDatabase.instance.createVoyage(
          numeroVoyage: numeroVoyage,
          dateVoyage: _emptyToNull(_dateVoyageCtrl.text),
          lieuDepart: _emptyToNull(_lieuDepartCtrl.text),
          lieuDestination: _emptyToNull(_lieuDestinationCtrl.text),
          dimensionConteneur: _selectedDimensionConteneur,
          poidsConteneur: poidsConteneur,
          natureMarchandise: _emptyToNull(_natureMarchandiseCtrl.text),
          dateDepartOrigine: _emptyToNull(_dateDepartOrigineCtrl.text),
          dateArriverDestination: _emptyToNull(
            _dateArriverDestinationCtrl.text,
          ),
          dateDepartRetour: _emptyToNull(_dateDepartRetourCtrl.text),
          dateArriverRetour: _emptyToNull(_dateArriverRetourCtrl.text),
          natureMarchandiseRetour: _emptyToNull(
            _natureMarchandiseRetourCtrl.text,
          ),
          nomClientRetour: _emptyToNull(_nomClientRetourCtrl.text),
          montantConvenuRetour: montantConvenuRetour,
          montantConvenu: montant,
          monnaieUuid: _selectedMonnaieUuid,
          statut: _selectedStatut,
          camionUuid: _selectedCamionUuid,
          chauffeurUuid: _selectedChauffeurUuid,
          convoyeurUuid: _selectedConvoyeurUuid,
          clientUuid: _selectedClientUuid,
        );
      }
      _cancelEdit();
      await _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing
                  ? 'Voyage modifié avec succès.'
                  : 'Voyage ajouté avec succès.',
            ),
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

  Future<void> _confirmDelete(Voyage v) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le voyage'),
        content: Text(
          'Voulez-vous vraiment supprimer le voyage "${v.numeroVoyage ?? v.uuid}" ?',
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
      if (_editingVoyage?.uuid == v.uuid) _cancelEdit();
      await AppDatabase.instance.deleteVoyage(v.uuid);
      await _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Voyage supprimé.')));
      }
    }
  }

  String? _emptyToNull(String s) => s.trim().isEmpty ? null : s.trim();

  String? _validateOptionalDecimal(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return double.tryParse(value.trim().replaceAll(',', '.')) == null
        ? 'Nombre invalide'
        : null;
  }

  Widget _dateFormField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: () => _pickDate(controller),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.calendar_today_outlined),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => setState(controller.clear),
              )
            : null,
      ),
    );
  }

  Future<void> _validateVoyage(Voyage v) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Valider le voyage'),
        content: Text(
          'Voulez-vous valider ce voyage ? Un numéro sera généré automatiquement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final existingNumero = v.numeroVoyage == null
        ? null
        : _emptyToNull(v.numeroVoyage!);
    final numero =
        existingNumero ??
        await AppDatabase.instance.getNextVoyageNumber(
          widget.user.nomUtilisateur,
        );
    await AppDatabase.instance.validateVoyage(v.uuid, numero);
    await _loadAll();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Voyage validé : $numero')));
    }
  }

  Future<void> _showScanVoyageDialog(Voyage voyage) async {
    List<ScanVoyage> scans = await AppDatabase.instance.getScanVoyageByVoyage(
      voyage.uuid,
    );
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.document_scanner_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Documents – ${voyage.numeroVoyage ?? voyage.uuid}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 560,
            height: 420,
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: const [
                        'pdf',
                        'png',
                        'jpg',
                        'jpeg',
                        'gif',
                        'webp',
                        'bmp',
                      ],
                      allowMultiple: false,
                    );
                    if (result == null || result.files.first.path == null) {
                      return;
                    }
                    try {
                      final localPath = await AppDatabase.instance
                          .storeManagedDocument(
                            folder: 'scan_voyage',
                            ownerLabel: voyage.numeroVoyage ?? voyage.uuid,
                            sourcePath: result.files.first.path!,
                          );
                      final page = scans.length + 1;
                      await AppDatabase.instance.createScanVoyage(
                        voyageUuid: voyage.uuid,
                        nomFichier: localPath,
                        page: page,
                      );
                      scans = await AppDatabase.instance.getScanVoyageByVoyage(
                        voyage.uuid,
                      );
                      setDlgState(() {});
                    } catch (error) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Erreur : $error'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Ajouter une page'),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: scans.isEmpty
                      ? const Center(child: Text('Aucun document enregistré.'))
                      : ListView.builder(
                          itemCount: scans.length,
                          itemBuilder: (_, i) {
                            final s = scans[i];
                            return ListTile(
                              leading: const Icon(
                                Icons.insert_drive_file_outlined,
                              ),
                              title: Text(
                                s.nomFichier == null
                                    ? 'Page ${s.page ?? i + 1}'
                                    : path.basename(s.nomFichier!),
                              ),
                              subtitle: Text('Page ${s.page ?? i + 1}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.visibility_outlined,
                                      color: Color(0xFF1A237E),
                                    ),
                                    tooltip: 'Visualiser',
                                    onPressed: () =>
                                        _viewLocalDocument(s.nomFichier),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    tooltip: 'Supprimer',
                                    onPressed: () async {
                                      await AppDatabase.instance
                                          .deleteScanVoyage(s.uuid);
                                      scans = await AppDatabase.instance
                                          .getScanVoyageByVoyage(voyage.uuid);
                                      setDlgState(() {});
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fermer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _viewLocalDocument(String? filePath) async {
    if (filePath == null ||
        filePath.isEmpty ||
        !await File(filePath).exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Le fichier est introuvable sur ce poste.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (path.extension(filePath).toLowerCase() != '.pdf') {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          child: SizedBox(
            width: 900,
            height: 650,
            child: Column(
              children: [
                ListTile(
                  title: Text(path.basename(filePath)),
                  trailing: IconButton(
                    tooltip: 'Fermer',
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 5,
                    child: Center(
                      child: Image.file(File(filePath), fit: BoxFit.contain),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    try {
      if (Platform.isWindows) {
        await Process.start('explorer.exe', [filePath]);
      } else if (Platform.isMacOS) {
        await Process.start('open', [filePath]);
      } else if (Platform.isLinux) {
        await Process.start('xdg-open', [filePath]);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible d’ouvrir le PDF : $error'),
            backgroundColor: Colors.red,
          ),
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
                    _editingVoyage != null
                        ? Icons.edit_outlined
                        : Icons.add_circle_outline,
                    color: const Color(0xFF1A237E),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _editingVoyage != null
                        ? 'Modifier un voyage'
                        : 'Ajouter un voyage',
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
                        controller: _numeroVoyageCtrl,
                        readOnly:
                            _editingVoyage == null ||
                            _editingVoyage?.valide == 1,
                        decoration: InputDecoration(
                          labelText: 'Numéro de voyage',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.tag),
                          suffixText: _editingVoyage == null
                              ? 'Auto'
                              : _editingVoyage?.valide == 1
                              ? 'Validé'
                              : null,
                          suffixStyle: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        validator: (v) {
                          if (_editingVoyage == null) return null;
                          return (v == null || v.trim().isEmpty)
                              ? 'Champ requis'
                              : null;
                        },
                      ),
                      const SizedBox(height: 12),
                      // Client (Marina Trans)
                      DropdownButtonFormField<String>(
                        value: _selectedClientUuid,
                        decoration: const InputDecoration(
                          labelText: 'Client',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('— Aucun —'),
                          ),
                          ..._marinaClients.map(
                            (c) => DropdownMenuItem(
                              value: c.uuid,
                              child: Text(c.nom),
                            ),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _selectedClientUuid = v),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _dateVoyageCtrl,
                        readOnly: true,
                        onTap: () => _pickDate(_dateVoyageCtrl),
                        decoration: InputDecoration(
                          labelText: 'Date du voyage',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.calendar_today_outlined),
                          suffixIcon: _dateVoyageCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () =>
                                      setState(() => _dateVoyageCtrl.clear()),
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
                          const DropdownMenuItem(
                            value: null,
                            child: Text('— Aucun —'),
                          ),
                          ..._camions.map((c) {
                            final label = [c.marque, c.plaque]
                                .where((v) => v != null && v.isNotEmpty)
                                .join(' - ');
                            return DropdownMenuItem(
                              value: c.uuid,
                              child: Text(label),
                            );
                          }),
                        ],
                        onChanged: (v) =>
                            setState(() => _selectedCamionUuid = v),
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
                          const DropdownMenuItem(
                            value: null,
                            child: Text('— Aucun —'),
                          ),
                          ..._chauffeurs.map(
                            (c) => DropdownMenuItem(
                              value: c.uuid,
                              child: Text(c.nom),
                            ),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _selectedChauffeurUuid = v),
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
                          const DropdownMenuItem(
                            value: null,
                            child: Text('— Aucun —'),
                          ),
                          ..._convoyeurs.map(
                            (c) => DropdownMenuItem(
                              value: c.uuid,
                              child: Text(c.nom),
                            ),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _selectedConvoyeurUuid = v),
                      ),
                      const SizedBox(height: 12),
                      if (!_isOpLogistique) ...[
                        TextFormField(
                          controller: _montantCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Montant convenu',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.attach_money),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            if (double.tryParse(
                                  v.trim().replaceAll(',', '.'),
                                ) ==
                                null) {
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
                            const DropdownMenuItem(
                              value: null,
                              child: Text('—'),
                            ),
                            ..._monnaies.map(
                              (m) => DropdownMenuItem(
                                value: m.uuid,
                                child: Text(m.label),
                              ),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _selectedMonnaieUuid = v),
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
                          const DropdownMenuItem(
                            value: null,
                            child: Text('— Aucun —'),
                          ),
                          ..._kStatuts.map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          ),
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      _editingVoyage != null
                                          ? Icons.save_outlined
                                          : Icons.add,
                                    ),
                              label: Text(
                                _editingVoyage != null ? 'Modifier' : 'Ajouter',
                              ),
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

  Widget _buildMarinaHorizontalForm() {
    final header = InkWell(
      onTap: () => setState(() => _isFormExpanded = !_isFormExpanded),
      child: Row(
        children: [
          Icon(
            _editingVoyage != null
                ? Icons.edit_outlined
                : Icons.add_circle_outline,
            color: const Color(0xFF1A237E),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _editingVoyage != null
                  ? 'Modifier un voyage'
                  : 'Ajouter un voyage',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A237E),
              ),
            ),
          ),
          Icon(
            _isFormExpanded ? Icons.expand_less : Icons.expand_more,
            color: const Color(0xFF1A237E),
          ),
        ],
      ),
    );
    if (!_isFormExpanded) {
      return Card(
        elevation: 2,
        child: Padding(padding: const EdgeInsets.all(20), child: header),
      );
    }

    final fields = <Widget>[
      TextFormField(
        controller: _numeroVoyageCtrl,
        readOnly: _editingVoyage == null || _editingVoyage?.valide == 1,
        decoration: InputDecoration(
          labelText: 'Numéro de voyage',
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.tag),
          suffixText: _editingVoyage == null
              ? 'Auto'
              : _editingVoyage?.valide == 1
              ? 'Validé'
              : null,
          suffixStyle: const TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
        validator: (value) {
          if (_editingVoyage == null) return null;
          return (value == null || value.trim().isEmpty)
              ? 'Champ requis'
              : null;
        },
      ),
      DropdownButtonFormField<String>(
        value: _selectedClientUuid,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Client',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.person_outline),
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text('— Aucun —')),
          ..._marinaClients.map(
            (client) => DropdownMenuItem(
              value: client.uuid,
              child: Text(client.nom, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
        onChanged: (value) => setState(() => _selectedClientUuid = value),
      ),
      TextFormField(
        controller: _dateVoyageCtrl,
        readOnly: true,
        onTap: () => _pickDate(_dateVoyageCtrl),
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
      TextFormField(
        controller: _lieuDepartCtrl,
        decoration: const InputDecoration(
          labelText: 'Lieu de départ',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.location_on_outlined),
        ),
      ),
      TextFormField(
        controller: _lieuDestinationCtrl,
        decoration: const InputDecoration(
          labelText: 'Lieu de destination',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.flag_outlined),
        ),
      ),
      DropdownButtonFormField<String>(
        value: _selectedDimensionConteneur,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Dimension du conteneur',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.straighten_outlined),
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text('— Aucune —')),
          ..._kDimensionsConteneur.map(
            (dimension) =>
                DropdownMenuItem(value: dimension, child: Text(dimension)),
          ),
        ],
        onChanged: (value) =>
            setState(() => _selectedDimensionConteneur = value),
      ),
      TextFormField(
        controller: _poidsConteneurCtrl,
        decoration: const InputDecoration(
          labelText: 'Poids du conteneur',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.scale_outlined),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: _validateOptionalDecimal,
      ),
      TextFormField(
        controller: _natureMarchandiseCtrl,
        decoration: const InputDecoration(
          labelText: 'Nature de la marchandise',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.category_outlined),
        ),
      ),
      _dateFormField('Date départ origine', _dateDepartOrigineCtrl),
      _dateFormField('Date arrivée destination', _dateArriverDestinationCtrl),
      _dateFormField('Date départ retour', _dateDepartRetourCtrl),
      _dateFormField('Date arrivée retour', _dateArriverRetourCtrl),
      TextFormField(
        controller: _natureMarchandiseRetourCtrl,
        decoration: const InputDecoration(
          labelText: 'Nature de la marchandise retour',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.category_outlined),
        ),
      ),
      TextFormField(
        controller: _nomClientRetourCtrl,
        decoration: const InputDecoration(
          labelText: 'Nom du client retour',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.person_outline),
        ),
      ),
      if (!_isOpLogistique)
        TextFormField(
          controller: _montantConvenuRetourCtrl,
          decoration: const InputDecoration(
            labelText: 'Montant convenu retour',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.attach_money),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: _validateOptionalDecimal,
        ),
      DropdownButtonFormField<String>(
        value: _selectedCamionUuid,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Camion',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.airport_shuttle_outlined),
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text('— Aucun —')),
          ..._camions.map((camion) {
            final label = [
              camion.marque,
              camion.plaque,
            ].where((value) => value != null && value.isNotEmpty).join(' - ');
            return DropdownMenuItem(
              value: camion.uuid,
              child: Text(label, overflow: TextOverflow.ellipsis),
            );
          }),
        ],
        onChanged: (value) => setState(() => _selectedCamionUuid = value),
      ),
      DropdownButtonFormField<String>(
        value: _selectedChauffeurUuid,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Chauffeur',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.person_outlined),
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text('— Aucun —')),
          ..._chauffeurs.map(
            (chauffeur) => DropdownMenuItem(
              value: chauffeur.uuid,
              child: Text(chauffeur.nom, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
        onChanged: (value) => setState(() => _selectedChauffeurUuid = value),
      ),
      DropdownButtonFormField<String>(
        value: _selectedConvoyeurUuid,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Convoyeur',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.person_outlined),
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text('— Aucun —')),
          ..._convoyeurs.map(
            (convoyeur) => DropdownMenuItem(
              value: convoyeur.uuid,
              child: Text(convoyeur.nom, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
        onChanged: (value) => setState(() => _selectedConvoyeurUuid = value),
      ),
      if (!_isOpLogistique)
        TextFormField(
          controller: _montantCtrl,
          decoration: const InputDecoration(
            labelText: 'Montant convenu',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.attach_money),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (value) {
            if (value == null || value.trim().isEmpty) return null;
            if (double.tryParse(value.trim().replaceAll(',', '.')) == null) {
              return 'Nombre invalide';
            }
            return null;
          },
        ),
      if (!_isOpLogistique)
        DropdownButtonFormField<String>(
          value: _selectedMonnaieUuid,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Monnaie',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('—')),
            ..._monnaies.map(
              (monnaie) => DropdownMenuItem(
                value: monnaie.uuid,
                child: Text(monnaie.label, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: (value) => setState(() => _selectedMonnaieUuid = value),
        ),
      DropdownButtonFormField<String>(
        value: _selectedStatut,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Statut',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.flag_outlined),
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text('— Aucun —')),
          ..._kStatuts.map(
            (statut) => DropdownMenuItem(value: statut, child: Text(statut)),
          ),
        ],
        onChanged: (value) => setState(() => _selectedStatut = value),
      ),
    ];

    return Card(
      elevation: 2,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.52,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                const Divider(height: 24),
                Expanded(
                  child: Scrollbar(
                    controller: _formScrollCtrl,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _formScrollCtrl,
                      padding: const EdgeInsets.only(right: 12),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          const spacing = 12.0;
                          final fieldWidth =
                              (constraints.maxWidth - spacing * 2) / 3;
                          return Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: fields
                                .map(
                                  (field) =>
                                      SizedBox(width: fieldWidth, child: field),
                                )
                                .toList(),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (_editingVoyage != null) ...[
                      OutlinedButton.icon(
                        onPressed: _cancelEdit,
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Annuler'),
                      ),
                      const SizedBox(width: 8),
                    ],
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A237E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 24,
                        ),
                      ),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              _editingVoyage != null
                                  ? Icons.save_outlined
                                  : Icons.add,
                            ),
                      label: Text(
                        _editingVoyage != null ? 'Modifier' : 'Ajouter',
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
    final canCollapse = widget.company == AppCompany.marian;
    final header = InkWell(
      onTap: canCollapse
          ? () => setState(() => _isListExpanded = !_isListExpanded)
          : null,
      child: Row(
        children: [
          const Icon(Icons.local_shipping_outlined, color: Color(0xFF1A237E)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Liste des voyages',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A237E),
              ),
            ),
          ),
          if (canCollapse)
            Icon(
              _isListExpanded ? Icons.expand_less : Icons.expand_more,
              color: const Color(0xFF1A237E),
            ),
        ],
      ),
    );
    if (canCollapse && !_isListExpanded) {
      return Card(
        elevation: 2,
        child: Padding(padding: const EdgeInsets.all(16), child: header),
      );
    }
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
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
                child: HorizontalTableScroller(
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        const Color(0xFF1A237E).withValues(alpha: 0.08),
                      ),
                      columnSpacing: 20,
                      columns: [
                        const DataColumn(label: Text('Actions')),
                        const DataColumn(label: Text('N° Voyage')),
                        const DataColumn(label: Text('Validé')),
                        const DataColumn(label: Text('Date')),
                        const DataColumn(label: Text('Départ')),
                        const DataColumn(label: Text('Destination')),
                        const DataColumn(label: Text('Camion')),
                        const DataColumn(label: Text('Chauffeur')),
                        const DataColumn(label: Text('Convoyeur')),
                        if (!_isOpLogistique)
                          const DataColumn(label: Text('Montant')),
                        const DataColumn(label: Text('Statut')),
                      ],
                      rows: _filteredVoyages.map((v) {
                        final isEditing = _editingVoyage?.uuid == v.uuid;
                        return DataRow(
                          color: WidgetStateProperty.resolveWith(
                            (states) => isEditing
                                ? const Color(
                                    0xFF1A237E,
                                  ).withValues(alpha: 0.06)
                                : null,
                          ),
                          cells: [
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isValidateur && v.valide != 1)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.verified_outlined,
                                        color: Colors.green,
                                      ),
                                      tooltip: 'Valider',
                                      onPressed: () => _validateVoyage(v),
                                    ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.document_scanner_outlined,
                                      color: Colors.teal,
                                    ),
                                    tooltip: 'Documents',
                                    onPressed: () => _showScanVoyageDialog(v),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      color: Color(0xFF1A237E),
                                    ),
                                    tooltip: 'Modifier',
                                    onPressed: () => _startEdit(v),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    tooltip: 'Supprimer',
                                    onPressed: () => _confirmDelete(v),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(Text(v.numeroVoyage ?? '-')),
                            DataCell(
                              v.valide == 1
                                  ? const Icon(
                                      Icons.verified_rounded,
                                      color: Colors.green,
                                      size: 18,
                                    )
                                  : const Icon(
                                      Icons.hourglass_empty_rounded,
                                      color: Colors.orange,
                                      size: 18,
                                    ),
                            ),
                            DataCell(Text(_formatDate(v.dateVoyage))),
                            DataCell(Text(v.lieuDepart ?? '-')),
                            DataCell(Text(v.lieuDestination ?? '-')),
                            DataCell(Text(_camionLabel(v.camionUuid))),
                            DataCell(Text(_personLabel(v.chauffeurUuid))),
                            DataCell(Text(_personLabel(v.convoyeurUuid))),
                            if (!_isOpLogistique)
                              DataCell(
                                Text(
                                  v.montantConvenu != null
                                      ? '${v.montantConvenu!.toStringAsFixed(2)} ${_monnaieLabel(v.monnaieUuid)}'
                                      : '-',
                                ),
                              ),
                            DataCell(
                              v.statut != null
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _statutColor(
                                          v.statut,
                                        ).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _statutColor(
                                            v.statut,
                                          ).withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: Text(
                                        v.statut!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _statutColor(v.statut),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    )
                                  : const Text('-'),
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
    if (widget.company == AppCompany.marian) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildMarinaHorizontalForm(),
            const SizedBox(height: 16),
            if (_isListExpanded)
              Expanded(child: _buildList())
            else
              _buildList(),
          ],
        ),
      );
    }

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
