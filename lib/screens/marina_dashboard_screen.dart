import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';
import '../services/sync_service.dart';
import 'company_selection_screen.dart';

class MarinaDashboardScreen extends StatefulWidget {
  const MarinaDashboardScreen({super.key});

  @override
  State<MarinaDashboardScreen> createState() => _MarinaDashboardScreenState();
}

class _MarinaDashboardScreenState extends State<MarinaDashboardScreen> {
  bool _loading = true;
  final TextEditingController _voyageSearchCtrl = TextEditingController();

  List<Map<String, Object?>> _financialRows = [];
  List<Map<String, Object?>> _voyages = [];

  bool _syncInProgress = false;
  StreamSubscription<SyncNotification>? _syncSub;

  @override
  void initState() {
    super.initState();
    _syncInProgress = AppSyncService.instance.isRunning;
    _syncSub = AppSyncService.instance.notifications.listen((n) {
      if (!mounted) return;
      setState(() => _syncInProgress = AppSyncService.instance.isRunning);
      if (n.hasDataChanges) _load();
    });
    _load();
  }

  @override
  void dispose() {
    _voyageSearchCtrl.dispose();
    _syncSub?.cancel();
    super.dispose();
  }

  List<Map<String, Object?>> get _filteredVoyages {
    final query = _voyageSearchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return _voyages;
    return _voyages.where((row) {
      final numeroVoyage = (row['numero_voyage']?.toString() ?? '').toLowerCase();
      final camionMarque = (row['camion_marque']?.toString() ?? '').toLowerCase();
      final camionPlaque = (row['camion_plaque']?.toString() ?? '').toLowerCase();
      final numeroCamion = '$camionMarque $camionPlaque';
      return numeroVoyage.contains(query) || numeroCamion.contains(query);
    }).toList();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = AppDatabase.instance;
    final results = await Future.wait([
      db.getMarinaDashboardFinancialRows(),
      db.getMarinaVoyageSummaryRows(),
    ]);
    if (!mounted) return;
    setState(() {
      _financialRows = results[0] as List<Map<String, Object?>>;
      _voyages = results[1] as List<Map<String, Object?>>;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MarinaHeader(
            syncInProgress: _syncInProgress,
            onRefresh: _load,
            onSync: () async {
              if (_syncInProgress) return;
              setState(() => _syncInProgress = true);
              final result = await AppSyncService.instance.synchronize();
              if (!mounted) return;
              setState(
                  () => _syncInProgress = AppSyncService.instance.isRunning);
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(
                  content: Text(result.success
                      ? '${result.message} Pull: ${result.pulledCount}, push: ${result.pushedCount}.'
                      : '${result.message} ${result.error ?? ''}'.trim()),
                ));
              if (result.success) _load();
            },
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Financial ────────────────────────────────────
                        _SectionHeader(
                          icon: Icons.account_balance_rounded,
                          label: 'Situation financière globale',
                          iconColor: const Color(0xFF10B981),
                          badgeColor: const Color(0xFFECFDF5),
                        ),
                        const SizedBox(height: 12),
                        if (_financialRows.isEmpty)
                          _EmptyState(
                            icon: Icons.account_balance_outlined,
                            message: 'Aucune donnée financière disponible.',
                          )
                        else
                          _FinancialTable(rows: _financialRows),

                        const SizedBox(height: 28),

                        // ── Voyage list ──────────────────────────────────
                        _SectionHeader(
                          icon: Icons.local_shipping_rounded,
                          label: 'Liste des voyages',
                          iconColor: const Color(0xFF3B82F6),
                          badgeColor: const Color(0xFFEFF6FF),
                          badge: '${_filteredVoyages.length}',
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _voyageSearchCtrl,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Rechercher par N° voyage ou N° camion...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _voyageSearchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      setState(() => _voyageSearchCtrl.clear());
                                    },
                                  )
                                : null,
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_filteredVoyages.isEmpty)
                          _EmptyState(
                            icon: Icons.local_shipping_outlined,
                            message: 'Aucun voyage trouvé.',
                          )
                        else
                          _VoyageList(
                            voyages: _filteredVoyages,
                            onTapVoyage: (voyage) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      MarinaVoyageDetailsScreen(voyage: voyage),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _VoyageList extends StatelessWidget {
  final List<Map<String, Object?>> voyages;
  final ValueChanged<Map<String, Object?>> onTapVoyage;

  const _VoyageList({required this.voyages, required this.onTapVoyage});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'fr_FR');
    return Column(
      children: [
        for (int i = 0; i < voyages.length; i++) ...[
          _VoyageCard(
            key: ValueKey(voyages[i]['voyage_uuid']),
            voyage: voyages[i], fmt: fmt,
            onTap: () => onTapVoyage(voyages[i]),
          ),
          if (i < voyages.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _VoyageCard extends StatelessWidget {
  final Map<String, Object?> voyage;
  final NumberFormat fmt;
  final VoidCallback onTap;

  const _VoyageCard({super.key, required this.voyage, required this.fmt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.all(16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF16A34A).withAlpha(20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.local_shipping_outlined,
              color: Color(0xFF15803D)),
        ),
        title: Text(
          'Voyage ${_voyageText(voyage['numero_voyage'])}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700, letterSpacing: 0),
        ),
        subtitle: Text(
          '${_voyageDate(voyage['date_voyage'])}\n'
          'Camion : ${_voyageCamion(voyage)}',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
        ),
        children: [
              Row(
                children: [
                  Icon(Icons.route_outlined, size: 16,
                      color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_voyageText(voyage['lieu_depart'])} → '
                      '${_voyageText(voyage['lieu_destination'])}',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              const Divider(height: 28),
              _VoyageAmounts(row: voyage, fmt: fmt),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Voir le détail'),
                ),
              ),
        ],
      ),
    );
  }
}

String _voyageText(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? '-' : text;
}

String _voyageDate(Object? value) {
  final raw = value?.toString() ?? '';
  final date = DateTime.tryParse(raw);
  return date == null ? _voyageText(value) : DateFormat('dd/MM/yyyy').format(date);
}

String _voyageCamion(Map<String, Object?> row) {
  final parts = [row['camion_marque'], row['camion_plaque']]
      .map((value) => value?.toString().trim() ?? '')
      .where((value) => value.isNotEmpty);
  return parts.isEmpty ? 'Non renseigné' : parts.join(' / ');
}

String _voyageCurrency(Map<String, Object?> row) {
  final sigle = row['monnaie_sigle']?.toString().trim() ?? '';
  return sigle.isEmpty ? _voyageText(row['monnaie_nom']) : sigle;
}

class _VoyageStatus extends StatelessWidget {
  final String value;

  const _VoyageStatus({required this.value});

  @override
  Widget build(BuildContext context) {
    final normalized = value.toLowerCase();
    final color = normalized.contains('annul')
        ? const Color(0xFFDC2626)
        : normalized.contains('termin') || normalized.startsWith('valid')
        ? const Color(0xFF15803D)
        : normalized.contains('cours')
        ? const Color(0xFF0369A1)
        : const Color(0xFFB45309);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(value == '-' ? 'Non renseigné' : value,
          style: TextStyle(color: color, fontSize: 12,
              fontWeight: FontWeight.w600)),
    );
  }
}

class _VoyageAmounts extends StatelessWidget {
  final Map<String, Object?> row;
  final NumberFormat fmt;

  const _VoyageAmounts({required this.row, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final depot = (row['total_depot'] as num?)?.toDouble() ?? 0;
    final depense = (row['total_depense'] as num?)?.toDouble() ?? 0;
    final solde = depot - depense;
    final metrics = <(String, double, Color)>[
      if (row.containsKey('montant_convenu'))
        ('Montant convenu', (row['montant_convenu'] as num?)?.toDouble() ?? 0,
            cs.onSurface),
      ('Total dépôts', depot, const Color(0xFF15803D)),
      if (row.containsKey('montant_convenu'))
        ('À recouvrer',
        ((row['montant_convenu'] as num?)?.toDouble() ?? 0) - depot,
        const Color(0xFFB45309)),
      ('Dépenses validées', depense, const Color(0xFFDC2626)),
      ('Solde', solde,
          solde >= 0 ? const Color(0xFF15803D) : const Color(0xFFDC2626)),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final columns = MediaQuery.textScalerOf(context).scale(14) > 20 ||
              constraints.maxWidth < 280
          ? 1
          : constraints.maxWidth < 720 ? 2 : metrics.length;
      final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: metrics.map((metric) => SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(metric.$1, style: TextStyle(
                  fontSize: 12, color: cs.onSurfaceVariant)),
              const SizedBox(height: 5),
              Text('${fmt.format(metric.$2)} ${_voyageCurrency(row)}',
                  style: TextStyle(fontSize: 15, color: metric.$3,
                      fontWeight: FontWeight.w700, letterSpacing: 0)),
            ],
          ),
        )).toList(),
      );
    });
  }
}

class MarinaVoyageDetailsScreen extends StatefulWidget {
  final Map<String, Object?> voyage;

  const MarinaVoyageDetailsScreen({super.key, required this.voyage});

  @override
  State<MarinaVoyageDetailsScreen> createState() =>
      _MarinaVoyageDetailsScreenState();
}

class _MarinaVoyageDetailsScreenState extends State<MarinaVoyageDetailsScreen> {
  late Future<Map<String, Object?>> _details;
  String? _openingDocumentUuid;

  @override
  void initState() {
    super.initState();
    _details = _loadDetails();
  }

  Future<Map<String, Object?>> _loadDetails() {
    return AppDatabase.instance.getMarinaVoyageDetails(
      widget.voyage['voyage_uuid'] as String,
    );
  }

  void _refresh() {
    setState(() {
      _details = _loadDetails();
    });
  }

  Future<void> _openDocument(Map<String, Object?> document) async {
    if (_openingDocumentUuid != null) return;
    setState(() => _openingDocumentUuid = document['uuid']?.toString());
    try {
      var fileName = document['nom_fichier']?.toString() ?? '';
      if (fileName.isEmpty || !await File(fileName).exists()) {
        final scan = document['scan'];
        final bytes = scan is List
            ? List<int>.from(scan)
            : scan is String && scan.isNotEmpty
            ? (scan.trimLeft().startsWith('[')
                ? List<int>.from(jsonDecode(scan) as List)
                : base64Decode(scan))
            : <int>[];
        if (bytes.isEmpty) {
          throw StateError('Document indisponible sur cet appareil.');
        }
        var extension = path.extension(fileName);
        if (extension.isEmpty) {
          extension = bytes.length >= 4 &&
                  bytes[0] == 0x25 && bytes[1] == 0x50 &&
                  bytes[2] == 0x44 && bytes[3] == 0x46
              ? '.pdf'
              : bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8
              ? '.jpg'
              : bytes.length >= 4 && bytes[0] == 0x89 && bytes[1] == 0x50
              ? '.png'
              : '';
          if (extension.isEmpty) {
            throw StateError('Format du document inconnu.');
          }
        }
        final directory = await getTemporaryDirectory();
        final safeUuid = document['uuid'].toString()
            .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
        fileName = path.join(directory.path, 'voyage_$safeUuid$extension');
        await File(fileName).writeAsBytes(bytes, flush: true);
      }
      final result = await OpenFilex.open(fileName);
      if (result.type != ResultType.done) {
        throw StateError(result.message);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d’ouvrir le document : $error')),
      );
    } finally {
      if (mounted) setState(() => _openingDocumentUuid = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text('Voyage ${_voyageText(widget.voyage['numero_voyage'])}'),
        actions: [
          IconButton(onPressed: _refresh, tooltip: 'Actualiser',
              icon: const Icon(Icons.refresh)),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<Map<String, Object?>>(
          future: _details,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Center(child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('Chargement impossible : ${snapshot.error}',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Réessayer')),
                ]),
              ));
            }
            return _buildDetails(snapshot.data!);
          },
        ),
      ),
    );
  }

  Widget _buildDetails(Map<String, Object?> data) {
    final voyage = data['voyage'] as Map<String, Object?>;
    final depots = data['depots'] as List<Map<String, Object?>>;
    final depenses = data['depenses'] as List<Map<String, Object?>>;
    final documents = data['documents'] as List<Map<String, Object?>>;
    final fmt = NumberFormat('#,##0.00', 'fr_FR');
    final balances = <String, Map<String, Object?>>{
      voyage['monnaie_uuid']?.toString() ?? '': {
        'monnaie_sigle': voyage['monnaie_sigle'],
        'monnaie_nom': voyage['monnaie_nom'],
        'montant_convenu': voyage['montant_convenu'],
        'total_depot': 0.0,
        'total_depense': 0.0,
        'en_attente': 0.0,
      },
    };
    for (final operation in [...depots, ...depenses]) {
      final key = operation['monnaie_uuid']?.toString() ?? '';
      balances.putIfAbsent(key, () => {
        'monnaie_sigle': operation['monnaie_sigle'],
        'monnaie_nom': operation['monnaie_nom'],
        'total_depot': 0.0, 'total_depense': 0.0, 'en_attente': 0.0,
      });
    }
    for (final depot in depots) {
      final balance = balances[depot['monnaie_uuid']?.toString() ?? '']!;
      balance['total_depot'] = (balance['total_depot'] as double) +
          ((depot['montant'] as num?)?.toDouble() ?? 0);
    }
    for (final depense in depenses) {
      final balance = balances[depense['monnaie_uuid']?.toString() ?? '']!;
      final field = (depense['valide'] as num?) == 1
          ? 'total_depense' : 'en_attente';
      balance[field] = (balance[field] as double) +
          ((depense['montant'] as num?)?.toDouble() ?? 0);
    }
    final voyageFields = <String, String>{
      'numero_voyage': 'Numéro voyage', 'date_voyage': 'Date du voyage',
      'lieu_depart': 'Lieu de départ',
      'lieu_destination': 'Destination',
      'dimension_conteneur': 'Dimension du conteneur',
      'poids_conteneur': 'Poids du conteneur',
      'nature_marchandise': 'Marchandise',
      'date_depart_origine': 'Départ origine',
      'date_arriver_destination': 'Arrivée destination',
      'date_depart_retour': 'Départ retour',
      'date_arriver_retour': 'Arrivée retour',
      'nature_marchandise_retour': 'Marchandise retour',
      'nom_client_retour': 'Client retour',
      'montant_convenu_retour': 'Montant convenu retour',
    };
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(spacing: 12, runSpacing: 8, children: [
                _VoyageStatus(value: (voyage['valide'] as num?) == 1
                    ? 'Validé' : 'En attente de validation'),
              ]),
              const SizedBox(height: 16),
              Text('${_voyageText(voyage['lieu_depart'])} → '
                  '${_voyageText(voyage['lieu_destination'])}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700, letterSpacing: 0)),
              const SizedBox(height: 6),
              Text('${_voyageDate(voyage['date_voyage'])} · '
                  '${_voyageCamion(voyage)}',
                  style: TextStyle(color: Theme.of(context)
                      .colorScheme.onSurfaceVariant)),
              _VoyageDetailSection(
                title: 'Situation financière', icon: Icons.account_balance_outlined,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  for (final balance in balances.values) ...[
                    Text(_voyageCurrency(balance),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    _VoyageAmounts(row: balance, fmt: fmt),
                    const SizedBox(height: 12),
                    Text('Dépenses en attente : '
                        '${fmt.format(balance['en_attente'])} '
                        '${_voyageCurrency(balance)}',
                        style: const TextStyle(color: Color(0xFFB45309))),
                    const SizedBox(height: 16),
                  ],
                ]),
              ),
              _VoyageDetailSection(
                title: 'Dépôts (${depots.length})', icon: Icons.south_west,
                child: _VoyageOperations(rows: depots, isExpense: false, fmt: fmt),
              ),
              _VoyageDetailSection(
                title: 'Dépenses (${depenses.length})', icon: Icons.north_east,
                child: _VoyageOperations(rows: depenses, isExpense: true, fmt: fmt),
              ),
              _VoyageDetailSection(
                title: 'Voyage et itinéraire', icon: Icons.route_outlined,
                child: _VoyageDetailFields(values: {
                  for (final entry in voyageFields.entries)
                    if (voyage.containsKey(entry.key))
                      entry.value: entry.key.startsWith('date_')
                          ? _voyageDate(voyage[entry.key])
                          : _voyageText(voyage[entry.key]),
                }),
              ),
              _VoyageDetailSection(
                title: 'Camion', icon: Icons.local_shipping_outlined,
                child: _VoyageDetailFields(values: {
                  'Marque': _voyageText(voyage['camion_marque']),
                  'Plaque': _voyageText(voyage['camion_plaque']),
                  'Modèle': _voyageText(voyage['camion_modele']),
                  'Capacité': _voyageText(voyage['camion_capacite']),
                }),
              ),
              _VoyageDetailSection(
                title: 'Équipage', icon: Icons.people_outline,
                child: _VoyageDetailFields(values: {
                  'Chauffeur': _voyageText(voyage['chauffeur_nom']),
                  'Téléphone chauffeur': _voyageText(voyage['chauffeur_telephone']),
                  'Adresse chauffeur': _voyageText(voyage['chauffeur_adresse']),
                  'Convoyeur': _voyageText(voyage['convoyeur_nom']),
                  'Téléphone convoyeur': _voyageText(voyage['convoyeur_telephone']),
                  'Adresse convoyeur': _voyageText(voyage['convoyeur_adresse']),
                }),
              ),
              _VoyageDetailSection(
                title: 'Client', icon: Icons.business_outlined,
                child: _VoyageDetailFields(values: {
                  'Nom': _voyageText(voyage['client_nom']),
                  'Téléphone': _voyageText(voyage['client_telephone']),
                  'Email': _voyageText(voyage['client_email']),
                  'Adresse': _voyageText(voyage['client_adresse']),
                }),
              ),
              _VoyageDetailSection(
                title: 'Documents (${documents.length})',
                icon: Icons.folder_open_outlined,
                child: documents.isEmpty
                    ? const Text('Aucun document associé.')
                    : Column(children: documents.map((document) {
                        final name = document['nom_fichier']?.toString() ?? '';
                        final opening = _openingDocumentUuid == document['uuid'];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.description_outlined),
                          title: Text(name.isEmpty ? 'Document' :
                              path.basename(name.replaceAll('\\', '/'))),
                          subtitle: Text('Page ${_voyageText(document['page'])}'),
                          trailing: opening
                              ? const SizedBox(width: 24, height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : IconButton(
                                  tooltip: 'Ouvrir le document',
                                  icon: const Icon(Icons.open_in_new),
                                  onPressed: _openingDocumentUuid == null
                                      ? () => _openDocument(document) : null,
                                ),
                        );
                      }).toList()),
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Références techniques'),
                children: [
                  _VoyageDetailFields(values: {
                    for (final key in ['uuid', 'id', 'sync', 'camion_uuid',
                      'chauffeur_uuid', 'convoyeur_uuid', 'client_uuid', 'monnaie_uuid'])
                      key: _voyageText(voyage[key]),
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoyageDetailSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _VoyageDetailSection({required this.title, required this.icon,
    required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(icon, size: 20, color: const Color(0xFF15803D)),
          const SizedBox(width: 10),
          Expanded(child: Text(title,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16,
                  color: cs.onSurface))),
        ]),
        const Divider(height: 24),
        child,
      ]),
    );
  }
}

class _VoyageDetailFields extends StatelessWidget {
  final Map<String, String> values;

  const _VoyageDetailFields({required this.values});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth < 560 ? 1 : 2;
      final width = (constraints.maxWidth - (columns - 1) * 24) / columns;
      return Wrap(spacing: 24, runSpacing: 18, children: [
        for (final entry in values.entries)
          SizedBox(width: width,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.key, style: TextStyle(
                    fontSize: 12, color: cs.onSurfaceVariant)),
                const SizedBox(height: 4),
                SelectableText(entry.value,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
      ]);
    });
  }
}

class _VoyageOperations extends StatelessWidget {
  final List<Map<String, Object?>> rows;
  final bool isExpense;
  final NumberFormat fmt;

  const _VoyageOperations({required this.rows, required this.isExpense,
    required this.fmt});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Text(isExpense ? 'Aucune dépense associée.' : 'Aucun dépôt associé.');
    }
    final cs = Theme.of(context).colorScheme;
    return Column(children: rows.map((row) {
      final date = _voyageDate(row[isExpense ? 'date' : 'date_paiement']);
      final validated = (row['valide'] as num?) == 1;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: cs.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: cs.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            title: Text(_voyageText(row['libelle']),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('$date · ${fmt.format((row['montant'] as num?) ?? 0)} '
                '${_voyageCurrency(row)}'
                '${isExpense ? ' · ${validated ? 'Validée' : 'En attente'}' : ''}'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              _VoyageDetailFields(values: {
                'Observation': _voyageText(row['observation']),
                if (!isExpense) 'Agent': _voyageText(row['agent']),
                if (isExpense) ...{
                  'Type de dépense': _voyageText(row['type_depense']),
                  'Exécutée': (row['deja_executer'] as num?) == 1 ? 'Oui' : 'Non',
                  'Validateur': _voyageText(row['validateur_nom']),
                  'Date de validation': _voyageDate(row['date_validation']),
                },
              }),
            ],
          ),
        ),
      );
    }).toList());
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _MarinaHeader extends StatelessWidget {
  final bool syncInProgress;
  final VoidCallback onRefresh;
  final VoidCallback onSync;

  const _MarinaHeader({
    required this.syncInProgress,
    required this.onRefresh,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF14532D), Color(0xFF16A34A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
            tooltip: 'Changer d\'espace',
            onPressed: () => Navigator.pop(context),
          ),
          const Icon(Icons.local_shipping_rounded,
              color: Colors.white70, size: 22),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MARINA Trans',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Tableau de bord',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 40,
            height: 40,
            child: syncInProgress
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white70),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.sync_rounded, color: Colors.white70),
                    tooltip: 'Synchroniser',
                    onPressed: onSync,
                  ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: 'Actualiser',
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color badgeColor;
  final String? badge;

  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.badgeColor,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
          ),
        ),
        if (badge != null)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: iconColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              badge!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color iconColor;

  const _EmptyState({
    required this.icon,
    required this.message,
    this.iconColor = Colors.black26,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Text(
            message,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Financial table ──────────────────────────────────────────────────────────

class _FinancialTable extends StatelessWidget {
  final List<Map<String, Object?>> rows;

  const _FinancialTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'fr_FR');
    return Column(
      children: [
        for (int i = 0; i < rows.length; i++) ...[
          _FinancialCard(row: rows[i], fmt: fmt),
          if (i < rows.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _FinancialCard extends StatelessWidget {
  final Map<String, Object?> row;
  final NumberFormat fmt;

  const _FinancialCard({required this.row, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final sigle = (row['sigle'] as String?) ?? (row['nom'] as String?) ?? '?';
    final nom = (row['nom'] as String?) ?? sigle;
    final depot = (row['total_depot'] as num?)?.toDouble() ?? 0.0;
    final depense = (row['total_depense'] as num?)?.toDouble() ?? 0.0;
    final solde = depot - depense;
    final positif = solde >= 0;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF14532D), Color(0xFF16A34A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF14532D).withAlpha(80),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(40),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    sigle.substring(0, sigle.length.clamp(0, 3)),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                nom,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: Colors.white.withAlpha(40)),
          const SizedBox(height: 12),
          _FinancialLine(
            label: 'Revenus encaissés',
            amount: fmt.format(depot),
            icon: Icons.arrow_downward_rounded,
            color: const Color(0xFF86EFAC),
          ),
          const SizedBox(height: 8),
          _FinancialLine(
            label: 'Dépenses validées',
            amount: fmt.format(depense),
            icon: Icons.arrow_upward_rounded,
            color: const Color(0xFFFCA5A5),
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: Colors.white.withAlpha(40)),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                positif
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                color: positif
                    ? const Color(0xFF86EFAC)
                    : const Color(0xFFF87171),
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'Solde',
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Text(
                fmt.format(solde),
                style: TextStyle(
                  color: positif
                      ? const Color(0xFF86EFAC)
                      : const Color(0xFFF87171),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FinancialLine extends StatelessWidget {
  final String label;
  final String amount;
  final IconData icon;
  final Color color;

  const _FinancialLine({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 13),
        ),
        const Spacer(),
        Text(
          amount,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

// ─── Voyage stats ─────────────────────────────────────────────────────────────

class _VoyageStatsRow extends StatelessWidget {
  final Map<String, int> stats;

  const _VoyageStatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final total = stats['total'] ?? 0;
    final enCours = stats['en_cours'] ?? 0;
    final enAttente = stats['en_attente'] ?? 0;
    final termines = stats['termines'] ?? 0;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Total',
            value: total,
            icon: Icons.summarize_rounded,
            gradient: const [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'En cours',
            value: enCours,
            icon: Icons.play_arrow_rounded,
            gradient: const [Color(0xFF10B981), Color(0xFF059669)],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'En attente',
            value: enAttente,
            icon: Icons.hourglass_empty_rounded,
            gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Terminés',
            value: termines,
            icon: Icons.check_circle_rounded,
            gradient: const [Color(0xFF6B7280), Color(0xFF4B5563)],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final List<Color> gradient;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: gradient.last.withAlpha(80),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ─── Camion stats ─────────────────────────────────────────────────────────────

class _CamionStatsList extends StatelessWidget {
  final List<Map<String, Object?>> camions;

  const _CamionStatsList({required this.camions});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'fr_FR');
    return Column(
      children: [
        for (int i = 0; i < camions.length; i++) ...[
          _CamionCard(c: camions[i], fmt: fmt),
          if (i < camions.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _CamionCard extends StatelessWidget {
  final Map<String, Object?> c;
  final NumberFormat fmt;

  const _CamionCard({required this.c, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final marque = (c['marque'] as String?) ?? '-';
    final plaque = (c['plaque'] as String?) ?? '-';
    final modele = (c['modele'] as String?) ?? '';
    final total = (c['total_voyages'] as int?) ?? 0;
    final enCours = (c['voyages_en_cours'] as int?) ?? 0;
    final enAttente = (c['voyages_en_attente'] as int?) ?? 0;
    final termines = (c['voyages_termines'] as int?) ?? 0;
    final revenus = (c['total_revenus'] as num?)?.toDouble() ?? 0.0;
    final depenses = (c['total_depenses'] as num?)?.toDouble() ?? 0.0;
    final solde = revenus - depenses;
    final positif = solde >= 0;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.airport_shuttle_rounded,
                    size: 22, color: Color(0xFF8B5CF6)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$marque — $plaque',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (modele.isNotEmpty)
                      Text(
                        modele,
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              Text(
                '$total voyage${total > 1 ? 's' : ''}',
                style: TextStyle(
                    fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Voyage breakdown
          Row(
            children: [
              _MiniChip(label: 'En cours', value: enCours, color: const Color(0xFF10B981)),
              const SizedBox(width: 8),
              _MiniChip(label: 'En attente', value: enAttente, color: const Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              _MiniChip(label: 'Terminés', value: termines, color: const Color(0xFF6B7280)),
            ],
          ),
          const SizedBox(height: 10),
          // Financial
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Revenus', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    Text(
                      fmt.format(revenus),
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF10B981)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Dépenses', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    Text(
                      fmt.format(depenses),
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFDC2626)),
                    ),
                  ],
                ),
                const Divider(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Solde', style: TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      fmt.format(solde),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: positif
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _MiniChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─── Retour charge list ───────────────────────────────────────────────────────

class _RetourChargeList extends StatelessWidget {
  final List<Map<String, Object?>> voyages;

  const _RetourChargeList({required this.voyages});

  static final _dateFmt = DateFormat('dd/MM/yyyy');
  static final _numFmt = NumberFormat('#,##0.00', 'fr_FR');

  String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    try {
      return _dateFmt.format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < voyages.length; i++) ...[
          _RetourChargeCard(v: voyages[i], fmtDate: _fmtDate, numFmt: _numFmt),
          if (i < voyages.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _RetourChargeCard extends StatelessWidget {
  final Map<String, Object?> v;
  final String Function(String?) fmtDate;
  final NumberFormat numFmt;

  const _RetourChargeCard({
    required this.v,
    required this.fmtDate,
    required this.numFmt,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final numero = (v['numero_voyage'] as String?) ?? '-';
    final date = fmtDate(v['date_voyage'] as String?);
    final depart = (v['lieu_depart'] as String?) ?? '-';
    final destination = (v['lieu_destination'] as String?) ?? '-';
    final camionMarque = (v['camion_marque'] as String?) ?? '';
    final camionPlaque = (v['camion_plaque'] as String?) ?? '';
    final chauffeur = (v['chauffeur_nom'] as String?) ?? '-';
    final client = (v['client_nom'] as String?) ?? '-';
    final montantConvenu =
        (v['montant_convenu'] as num?)?.toDouble() ?? 0.0;
    final sigle = (v['monnaie_sigle'] as String?) ?? '';
    final depot = (v['total_depot'] as num?)?.toDouble() ?? 0.0;
    final depense = (v['total_depense'] as num?)?.toDouble() ?? 0.0;
    final solde = depot - depense;
    final positif = solde >= 0;
    final camion = [camionMarque, camionPlaque]
        .where((s) => s.isNotEmpty)
        .join(' — ');

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFFF59E0B).withAlpha(80)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.loop_rounded,
                    size: 20, color: Color(0xFFF59E0B)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Voyage $numero',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      date,
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Validé',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF16A34A)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Route
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '$depart → $destination',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (camion.isNotEmpty) ...[
                const Icon(Icons.airport_shuttle_outlined,
                    size: 13, color: Colors.grey),
                const SizedBox(width: 4),
                Text(camion,
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant)),
                const SizedBox(width: 12),
              ],
              const Icon(Icons.person_outline, size: 13, color: Colors.grey),
              const SizedBox(width: 4),
              Text(chauffeur,
                  style: TextStyle(
                      fontSize: 12, color: cs.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.business_outlined, size: 13, color: Colors.grey),
              const SizedBox(width: 4),
              Text(client,
                  style: TextStyle(
                      fontSize: 12, color: cs.onSurfaceVariant)),
              if (montantConvenu > 0) ...[
                const Spacer(),
                Text(
                  'Convenu: ${numFmt.format(montantConvenu)} $sigle'.trim(),
                  style: TextStyle(
                      fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          // Financial summary
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Encaissé',
                          style: TextStyle(
                              fontSize: 11, color: cs.onSurfaceVariant)),
                      Text(
                        numFmt.format(depot),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF10B981),
                            fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dépenses',
                          style: TextStyle(
                              fontSize: 11, color: cs.onSurfaceVariant)),
                      Text(
                        numFmt.format(depense),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFDC2626),
                            fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Solde',
                          style: TextStyle(
                              fontSize: 11, color: cs.onSurfaceVariant)),
                      Text(
                        numFmt.format(solde),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: positif
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFDC2626),
                          fontSize: 13,
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
    );
  }
}
