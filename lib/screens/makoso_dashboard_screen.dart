import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';
import '../services/sync_service.dart';

Uint8List? _decodeScanBytes(Object? value) {
  if (value is Uint8List) return value;
  if (value is List) {
    try {
      return Uint8List.fromList(
        value.cast<num>().map((item) => item.toInt()).toList(),
      );
    } catch (_) {
      return null;
    }
  }
  if (value is Map) return _decodeScanBytes(value['data']);
  if (value is! String || value.trim().isEmpty) return null;

  final encoded = value.trim();
  if (RegExp(r'^(?:[0-9a-fA-F]{2})+$').hasMatch(encoded)) {
    return Uint8List.fromList([
      for (var index = 0; index < encoded.length; index += 2)
        int.parse(encoded.substring(index, index + 2), radix: 16),
    ]);
  }
  try {
    final decoded = _decodeScanBytes(jsonDecode(encoded));
    if (decoded != null) return decoded;
  } catch (_) {}
  try {
    return base64Decode(encoded);
  } catch (_) {
    return null;
  }
}

({String extension, String mimeType})? _scanFileType(
  Uint8List bytes,
  String fileName,
) {
  if (bytes.length >= 4 &&
      bytes[0] == 0x25 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x44 &&
      bytes[3] == 0x46) {
    return (extension: '.pdf', mimeType: 'application/pdf');
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return (extension: '.png', mimeType: 'image/png');
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return (extension: '.jpg', mimeType: 'image/jpeg');
  }
  if (bytes.length >= 6) {
    final signature = ascii.decode(bytes.sublist(0, 6), allowInvalid: true);
    if (signature == 'GIF87a' || signature == 'GIF89a') {
      return (extension: '.gif', mimeType: 'image/gif');
    }
  }
  if (bytes.length >= 12 &&
      ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
      ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') {
    return (extension: '.webp', mimeType: 'image/webp');
  }

  return switch (path.extension(fileName).toLowerCase()) {
    '.pdf' => (extension: '.pdf', mimeType: 'application/pdf'),
    '.png' => (extension: '.png', mimeType: 'image/png'),
    '.jpg' || '.jpeg' => (extension: '.jpg', mimeType: 'image/jpeg'),
    '.gif' => (extension: '.gif', mimeType: 'image/gif'),
    '.webp' => (extension: '.webp', mimeType: 'image/webp'),
    '.bmp' => (extension: '.bmp', mimeType: 'image/bmp'),
    _ => null,
  };
}

class MakosoDashboardScreen extends StatefulWidget {
  const MakosoDashboardScreen({super.key});

  @override
  State<MakosoDashboardScreen> createState() => _MakosoDashboardScreenState();
}

class _MakosoDashboardScreenState extends State<MakosoDashboardScreen> {
  bool _loading = true;

  List<Map<String, Object?>> _financialRows = [];
  int _pendingDepenses = 0;
  List<Map<String, Object?>> _dossiers = [];

  final _dossierSearchCtrl = TextEditingController();

  List<Map<String, Object?>> get _filteredDossiers {
    final query = _dossierSearchCtrl.text.trim().toLowerCase();
    return _dossiers.where((dossier) => query.isEmpty ||
        (dossier['numero_bl']?.toString() ?? '').toLowerCase().contains(query) ||
        (dossier['numeros_conteneurs']?.toString() ?? '')
            .toLowerCase().contains(query)).toList();
  }

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
    _syncSub?.cancel();
    _dossierSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = AppDatabase.instance;
    final results = await Future.wait([
      db.getMakosoDashboardFinancialRows(),
      db.getMakosoPendingDepenseCount(),
      db.getMakosoDossierSummaryRows(),
    ]);
    if (!mounted) return;
    setState(() {
      _financialRows = results[0] as List<Map<String, Object?>>;
      _pendingDepenses = results[1] as int;
      _dossiers = results[2] as List<Map<String, Object?>>;
      _loading = false;
    });
  }

  Future<void> _validerDepense(Map<String, Object?> d) async {
    final uuid = d['uuid'] as String? ?? '';
    final libelle = d['libelle'] as String? ?? uuid;
    final montant = (d['montant'] as num?)?.toDouble();
    final sigle = (d['monnaie_sigle'] as String?)?.trim() ?? '';
    final montantStr = montant != null
        ? '${NumberFormat('#,##0.00', 'fr_FR').format(montant)} $sigle'.trim()
        : '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Valider la dépense'),
        content: Text('Valider "$libelle" ($montantStr) ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final today = DateTime.now();
    final dateVal =
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    await AppDatabase.instance.validateMakosoDepense(uuid, dateVal);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Dépense validée.')));
    _load();
  }

  Future<void> _rejeterDepense(Map<String, Object?> d) async {
    final uuid = d['uuid'] as String? ?? '';
    final libelle = d['libelle'] as String? ?? uuid;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rejeter la dépense'),
        content: Text('Supprimer définitivement "$libelle" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await AppDatabase.instance.deleteMakosoDepense(uuid);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Dépense rejetée.')));
    _load();
  }

  Future<void> _viewScanBl(Map<String, Object?> scan) async {
    Uint8List? bytes = _decodeScanBytes(scan['scan']);
    final filePath = scan['nom_fichier']?.toString().trim() ?? '';
    if ((bytes == null || bytes.isEmpty) && filePath.isNotEmpty) {
      final file = File(filePath);
      if (await file.exists()) bytes = await file.readAsBytes();
    }
    if (bytes == null || bytes.isEmpty) {
      final uuid = scan['uuid']?.toString() ?? '';
      if (uuid.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('Récupération du scan BL depuis le serveur...'),
              ),
            );
        }
        try {
          final remoteData = await AppSyncService.instance.recoverScanBlData(
            uuid,
          );
          bytes = _decodeScanBytes(remoteData);
        } catch (error) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Impossible de récupérer le scan BL : $error'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
    }
    if (!mounted) return;
    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le scan BL est introuvable sur ce poste.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final storedName = filePath.replaceAll('\\', '/');
    final fileName = storedName.isEmpty ? 'scan_bl' : path.basename(storedName);
    final fileType = _scanFileType(bytes, fileName);
    if (fileType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ce scan n’est ni un PDF ni une image reconnue.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final cacheDirectory = await getTemporaryDirectory();
      final uuid = scan['uuid']?.toString().replaceAll(
            RegExp(r'[^a-zA-Z0-9_-]'),
            '_',
          ) ??
          'scan_bl';
      final scanFile = File(
        path.join(cacheDirectory.path, '$uuid${fileType.extension}'),
      );
      await scanFile.writeAsBytes(bytes, flush: true);
      final result = await OpenFilex.open(
        scanFile.path,
        type: fileType.mimeType,
      );
      if (!mounted) return;
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.message.isEmpty
                  ? 'Aucune application ne peut ouvrir ce scan.'
                  : result.message,
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible d’ouvrir le scan BL : $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MakosoDashHeader(
            syncInProgress: _syncInProgress,
            onRefresh: _load,
            onSync: () async {
              if (_syncInProgress) return;
              setState(() => _syncInProgress = true);
              final result = await AppSyncService.instance.synchronize();
              if (!context.mounted) return;
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
                          label: 'Situation financière',
                          iconColor: const Color(0xFF3B82F6),
                          badgeColor: const Color(0xFFEFF6FF),
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

                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.hourglass_top_rounded,
                              color: Color(0xFFD97706)),
                          title: const Text('Dépenses en attente de validation'),
                          subtitle: Text('$_pendingDepenses dépense(s)'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => _MakosoPendingExpensesScreen(
                                onValider: _validerDepense,
                                onRejeter: _rejeterDepense,
                              ),
                            ));
                            if (mounted) _load();
                          },
                        ),
                        const SizedBox(height: 28),
                        _SectionHeader(
                          icon: Icons.folder_open_rounded,
                          label: 'Liste des dossiers',
                          iconColor: const Color(0xFF0F766E),
                          badgeColor: const Color(0xFFF0FDFA),
                          badge: '${_filteredDossiers.length}',
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _dossierSearchCtrl,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Rechercher par BL ou numéro de conteneur...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _dossierSearchCtrl.text.isEmpty ? null
                                : IconButton(
                                    tooltip: 'Effacer la recherche',
                                    onPressed: () => setState(_dossierSearchCtrl.clear),
                                    icon: const Icon(Icons.clear),
                                  ),
                            border: const OutlineInputBorder(),
                            isDense: true,
                          )
                        ),
                        const SizedBox(height: 12),
                        if (_filteredDossiers.isEmpty)
                          const _EmptyState(
                            icon: Icons.folder_off_outlined,
                            message: 'Aucun dossier trouvé.',
                          ),
                        for (final dossier in _filteredDossiers) ...[
                          _MakosoDossierCard(
                            key: ValueKey(dossier['uuid']),
                            dossier: dossier,
                            onDetails: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => _MakosoDossierDetailsScreen(
                                dossier: dossier, onViewScan: _viewScanBl,
                              )),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _MakosoDossierCard extends StatelessWidget {
  final Map<String, Object?> dossier;
  final VoidCallback onDetails;

  const _MakosoDossierCard({super.key, required this.dossier, required this.onDetails});

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
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const Icon(Icons.folder_outlined, color: Color(0xFF0F766E)),
        title: Text('Dossier / BL : ${dossier['numero_bl'] ?? dossier['id'] ?? '-'}'),
        subtitle: Text('${dossier['client_nom'] ?? '-'}\n'
            '${dossier['nb_conteneurs'] ?? 0} conteneur(s)'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Divider(),
          _MakosoDossierAmounts(dossier: dossier),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onDetails,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Voir le détail'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MakosoDossierAmounts extends StatelessWidget {
  final Map<String, Object?> dossier;

  const _MakosoDossierAmounts({required this.dossier});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'fr_FR');
    final balances = ((dossier['financial_rows'] as List?) ?? const [])
      .map((row) => Map<String, Object?>.from(row as Map)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DossierDetailValue(
          label: 'Montant convenu',
          value: fmt.format((dossier['montant_convenu'] as num?) ?? 0),
        ),
        const SizedBox(height: 12),
        for (final balance in balances.isEmpty
            ? [<String, Object?>{'total_depot': 0, 'total_depense': 0}]
            : balances) ...[
          LayoutBuilder(builder: (context, constraints) {
            final depot = (balance['total_depot'] as num?)?.toDouble() ?? 0;
            final depense = (balance['total_depense'] as num?)?.toDouble() ?? 0;
            final currency = balance['monnaie_sigle']?.toString() ??
                balance['monnaie_nom']?.toString() ??
                (balance['monnaie_uuid'] == null ? '' : 'Devise inconnue');
            final columns = constraints.maxWidth < 600 ||
                MediaQuery.textScalerOf(context).scale(14) > 20 ? 1 : 3;
            final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
            return Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                for (final metric in [
                  ('Total dépôts', depot, const Color(0xFF15803D)),
                  ('Dépenses validées', depense, const Color(0xFFDC2626)),
                  ('Solde', depot - depense, depot >= depense
                      ? const Color(0xFF15803D) : const Color(0xFFDC2626)),
                ])
                  SizedBox(
                    width: width,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(metric.$1, style: Theme.of(context).textTheme.labelMedium),
                        const SizedBox(height: 4),
                        Text('${fmt.format(metric.$2)} $currency'.trim(),
                            style: TextStyle(color: metric.$3, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
              ],
            );
          }),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _MakosoPendingExpensesScreen extends StatefulWidget {
  final Future<void> Function(Map<String, Object?>) onValider;
  final Future<void> Function(Map<String, Object?>) onRejeter;

  const _MakosoPendingExpensesScreen({required this.onValider, required this.onRejeter});

  @override
  State<_MakosoPendingExpensesScreen> createState() => _MakosoPendingExpensesScreenState();
}

class _MakosoPendingExpensesScreenState extends State<_MakosoPendingExpensesScreen> {
  late Future<List<Map<String, Object?>>> _expenses;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _expenses = AppDatabase.instance.getMakosoPendingDepenses();
  }

  void _refresh() {
    setState(() {
      _expenses = AppDatabase.instance.getMakosoPendingDepenses();
    });
  }

  Future<void> _act(Map<String, Object?> expense,
      Future<void> Function(Map<String, Object?>) action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action(expense);
      if (mounted) _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible de traiter la dépense : $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dépenses en attente de validation'),
        actions: [IconButton(
          tooltip: 'Actualiser', onPressed: _busy ? null : _refresh,
          icon: const Icon(Icons.refresh),
        )],
      ),
      body: Column(children: [
        if (_busy) const LinearProgressIndicator(),
        Expanded(child: FutureBuilder<List<Map<String, Object?>>>(
          future: _expenses,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: TextButton.icon(
                onPressed: _refresh, icon: const Icon(Icons.refresh),
                label: const Text('Chargement impossible. Réessayer'),
              ));
            }
            final expenses = snapshot.data ?? [];
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: AbsorbPointer(
                absorbing: _busy,
                child: expenses.isEmpty
                    ? const _EmptyState(icon: Icons.check_circle_outline,
                        message: 'Aucune dépense en attente.')
                    : _PendingDepensesList(
                        depenses: expenses,
                        onValider: (expense) => _act(expense, widget.onValider),
                        onRejeter: (expense) => _act(expense, widget.onRejeter),
                      ),
              ),
            );
          },
        )),
      ]),
    );
  }
}

class _MakosoDossierDetailsScreen extends StatefulWidget {
  final Map<String, Object?> dossier;
  final Future<void> Function(Map<String, Object?>) onViewScan;

  const _MakosoDossierDetailsScreen({required this.dossier, required this.onViewScan});

  @override
  State<_MakosoDossierDetailsScreen> createState() => _MakosoDossierDetailsScreenState();
}

class _MakosoDossierDetailsScreenState extends State<_MakosoDossierDetailsScreen> {
  late Future<Map<String, Object?>?> _details;

  @override
  void initState() {
    super.initState();
    _details = _load();
  }

  Future<Map<String, Object?>?> _load() async {
    final uuid = widget.dossier['uuid'] as String;
    final details = await AppDatabase.instance.searchMakosoDossierDetails('', dossierUuid: uuid);
    if (details == null) return null;
    final summaries = await AppDatabase.instance.getMakosoDossierSummaryRows(dossierUuid: uuid);
    return {...details, 'summary': summaries.firstWhere(
      (dossier) => dossier['uuid'] == uuid, orElse: () => widget.dossier,
    )};
  }

  void _refresh() {
    setState(() {
      _details = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dossier / BL : ${widget.dossier['numero_bl'] ?? widget.dossier['id'] ?? '-'}'),
        actions: [IconButton(tooltip: 'Actualiser', onPressed: _refresh,
            icon: const Icon(Icons.refresh))],
      ),
      body: FutureBuilder<Map<String, Object?>?>(
        future: _details,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: TextButton.icon(
              onPressed: _refresh, icon: const Icon(Icons.refresh),
              label: const Text('Chargement impossible. Réessayer'),
            ));
          }
          final details = snapshot.data;
          if (details == null) return const Center(child: Text('Dossier introuvable.'));
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Situation financière', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _MakosoDossierAmounts(dossier: details['summary'] as Map<String, Object?>),
                  const Divider(height: 28),
                  _DossierSearchResult(result: details, onViewScan: widget.onViewScan),
                ],
              ),
            )),
          );
        },
      ),
    );
  }
}

class _MakosoDashHeader extends StatelessWidget {
  final bool syncInProgress;
  final VoidCallback onRefresh;
  final VoidCallback onSync;

  const _MakosoDashHeader({
    required this.syncInProgress,
    required this.onRefresh,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF2D6A9F)],
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
          const Icon(Icons.warehouse_rounded, color: Colors.white70, size: 22),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MAKOSO Service',
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

// ─── Section header ───────────────────────────────────────────────────────────

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

// ─── Empty state ─────────────────────────────────────────────────────────────

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
          Flexible(
            child: Text(
              message,
              textAlign: TextAlign.center,
              softWrap: true,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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
          colors: [Color(0xFF1E3A5F), Color(0xFF2D6A9F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A5F).withAlpha(80),
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
            label: 'Dépôts',
            amount: fmt.format(depot),
            icon: Icons.arrow_downward_rounded,
            color: const Color(0xFF93C5FD),
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

// ─── Pending depenses list ────────────────────────────────────────────────────

class _PendingDepensesList extends StatelessWidget {
  final List<Map<String, Object?>> depenses;
  final Future<void> Function(Map<String, Object?>) onValider;
  final Future<void> Function(Map<String, Object?>) onRejeter;

  const _PendingDepensesList({
    required this.depenses,
    required this.onValider,
    required this.onRejeter,
  });

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

  String _fmtMontant(Map<String, Object?> d) {
    final montant = (d['montant'] as num?)?.toDouble();
    if (montant == null) return '-';
    final sigle = (d['monnaie_sigle'] as String?)?.trim() ?? '';
    return '${_numFmt.format(montant)} $sigle'.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < depenses.length; i++) ...[
          _PendingDepenseCard(
            d: depenses[i],
            fmtDate: _fmtDate,
            fmtMontant: _fmtMontant,
            onValider: () => onValider(depenses[i]),
            onRejeter: () => onRejeter(depenses[i]),
          ),
          if (i < depenses.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _PendingDepenseCard extends StatelessWidget {
  final Map<String, Object?> d;
  final String Function(String?) fmtDate;
  final String Function(Map<String, Object?>) fmtMontant;
  final VoidCallback onValider;
  final VoidCallback onRejeter;

  const _PendingDepenseCard({
    required this.d,
    required this.fmtDate,
    required this.fmtMontant,
    required this.onValider,
    required this.onRejeter,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final libelle = (d['libelle'] as String?) ?? '-';
    final obs = (d['observation'] as String?) ?? '';
    final date = fmtDate(d['date'] as String?);
    final montant = fmtMontant(d);
    final dossierUuid = d['dossier_uuid'] as String?;
    final numeroBl = d['dossier_numero_bl']?.toString().trim() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFBBF24).withAlpha(100)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded,
                  size: 18, color: Color(0xFFD97706)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  libelle,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                montant,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                'Date : $date',
                style: TextStyle(
                    fontSize: 12, color: cs.onSurfaceVariant),
              ),
              if (dossierUuid != null && dossierUuid.isNotEmpty)
                Text('BL : ${numeroBl.isEmpty ? 'Non renseigné' : numeroBl}',
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant)),
            ],
          ),
          if (obs.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              obs,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: onRejeter,
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Rejeter'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                  side: const BorderSide(color: Color(0xFFDC2626)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: onValider,
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Valider'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Dossiers en souffrance ───────────────────────────────────────────────────

class _DossiersSouffranceList extends StatelessWidget {
  final List<Map<String, Object?>> dossiers;

  const _DossiersSouffranceList({required this.dossiers});

  static final _numFmt = NumberFormat('#,##0.00', 'fr_FR');

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < dossiers.length; i++) ...[
          _DossierSouffranceCard(d: dossiers[i], numFmt: _numFmt),
          if (i < dossiers.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _DossierSouffranceCard extends StatelessWidget {
  final Map<String, Object?> d;
  final NumberFormat numFmt;

  const _DossierSouffranceCard({required this.d, required this.numFmt});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final numeroBl = (d['numero_bl'] as String?) ?? '-';
    final clientNom = (d['client_nom'] as String?) ?? '-';
    final montant = (d['montant_convenu'] as num?)?.toDouble() ?? 0.0;
    final statut = (d['statut'] as String?) ?? '';

    final souffranceDraft = (d['souffrance_draft'] as int?) == 1;
    final souffrancePn = (d['souffrance_pn'] as int?) == 1;
    final souffranceMatadi = (d['souffrance_matadi'] as int?) == 1;

    final manqueDraft = (d['manque_draft'] as num?)?.toDouble() ?? 0.0;
    final manquePn = (d['manque_pn'] as num?)?.toDouble() ?? 0.0;
    final manqueMatadi = (d['manque_matadi'] as num?)?.toDouble() ?? 0.0;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF4444).withAlpha(80)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.folder_open_rounded,
                  size: 18, color: Color(0xFFEF4444)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  numeroBl,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statut,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFFEF4444)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            clientNom,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
          Text(
            'Montant convenu : ${numFmt.format(montant)}',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          // Souffrance tags
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (souffranceDraft)
                _SouffranceChip(
                  label: '30% Draft',
                  manque: manqueDraft,
                  numFmt: numFmt,
                ),
              if (souffrancePn)
                _SouffranceChip(
                  label: '30% PN',
                  manque: manquePn,
                  numFmt: numFmt,
                ),
              if (souffranceMatadi)
                _SouffranceChip(
                  label: '40% Matadi',
                  manque: manqueMatadi,
                  numFmt: numFmt,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SouffranceChip extends StatelessWidget {
  final String label;
  final double manque;
  final NumberFormat numFmt;

  const _SouffranceChip({
    required this.label,
    required this.manque,
    required this.numFmt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Text(
        '$label — manque ${numFmt.format(manque)}',
        style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
      ),
    );
  }
}

// ─── Dossier Search Section ─────────────────────────────────────────────────

class _DossierSearchSection extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSearch;
  final bool searching;
  final Map<String, Object?>? result;
  final bool searched;
  final Future<void> Function(Map<String, Object?>) onViewScan;

  const _DossierSearchSection({
    required this.controller,
    required this.onSearch,
    required this.searching,
    required this.result,
    required this.searched,
    required this.onViewScan,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Numéro BL',
                  prefixIcon: const Icon(
                    Icons.folder_outlined,
                    color: Color(0xFF0F766E),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onSubmitted: (_) => onSearch(),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: searching ? null : onSearch,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: searching
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.search_rounded),
                label: const Text('Rechercher'),
              ),
            ),
          ],
        ),
        if (searching) ...[
          const SizedBox(height: 20),
          const Center(child: CircularProgressIndicator()),
        ] else if (searched && result == null) ...[
          const SizedBox(height: 16),
          const _EmptyState(
            icon: Icons.folder_off_outlined,
            message: 'Aucun dossier trouvé pour ce numéro BL.',
          ),
        ] else if (result != null) ...[
          const SizedBox(height: 16),
          _DossierSearchResult(result: result!, onViewScan: onViewScan),
        ],
      ],
    );
  }
}

class _DossierSearchResult extends StatelessWidget {
  final Map<String, Object?> result;
  final Future<void> Function(Map<String, Object?>) onViewScan;

  const _DossierSearchResult({
    required this.result,
    required this.onViewScan,
  });

  static final _numberFormat = NumberFormat('#,##0.00', 'fr_FR');
  static final _dateFormat = DateFormat('dd/MM/yyyy');

  String _text(Map<String, Object?> row, String key) {
    return row[key]?.toString().trim() ?? '';
  }

  String _date(Object? value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return '-';
    try {
      return _dateFormat.format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  String _amount(Map<String, Object?> row) {
    final amount = (row['montant'] as num?)?.toDouble();
    if (amount == null) return '-';
    final currency = _text(row, 'monnaie_sigle');
    return '${_numberFormat.format(amount)} $currency'.trim();
  }

  @override
  Widget build(BuildContext context) {
    final dossier = Map<String, Object?>.from(
      result['dossier'] as Map,
    );
    final depots = (result['depots'] as List)
        .map((row) => Map<String, Object?>.from(row as Map))
        .toList();
    final depenses = (result['depenses'] as List)
        .map((row) => Map<String, Object?>.from(row as Map))
        .toList();
    final conteneurs = (result['conteneurs'] as List)
      .map((row) => Map<String, Object?>.from(row as Map))
      .toList();
    final scans = (result['scans'] as List)
      .map((row) => Map<String, Object?>.from(row as Map))
      .toList();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: const Color(0xFF99F6E4)),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 24,
            runSpacing: 10,
            children: [
              _DossierDetailValue(
                label: 'Numéro BL',
                value: _text(dossier, 'numero_bl'),
              ),
              _DossierDetailValue(
                label: 'Client',
                value: _text(dossier, 'client_nom'),
              ),
              _DossierDetailValue(
                label: 'Statut',
                value: _text(dossier, 'statut'),
              ),
              _DossierDetailValue(
                label: 'Marchandise',
                value: _text(dossier, 'nature_marchandise'),
              ),
              _DossierDetailValue(
                label: 'Port de chargement',
                value: _text(dossier, 'port_chargement'),
              ),
              _DossierDetailValue(
                label: 'Port de destination',
                value: _text(dossier, 'port_destination'),
              ),
            ],
          ),
          const Divider(height: 28),
          Row(
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                size: 19,
                color: Color(0xFF0F766E),
              ),
              const SizedBox(width: 8),
              Text(
                'Conteneurs (${conteneurs.length})',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (conteneurs.isEmpty)
            Text(
              'Aucun conteneur lié.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: conteneurs.map((conteneur) {
                final numero = _text(conteneur, 'numero_conteneur');
                final dimension = _text(conteneur, 'dimension');
                return Chip(
                  avatar: const Icon(Icons.inventory_2_outlined, size: 16),
                  label: Text(
                    [numero.isEmpty ? '-' : numero, dimension]
                        .where((value) => value.isNotEmpty)
                        .join(' • '),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(
                Icons.document_scanner_outlined,
                size: 19,
                color: Color(0xFF7C3AED),
              ),
              const SizedBox(width: 8),
              Text(
                'Scans BL (${scans.length})',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (scans.isEmpty)
            Text(
              'Aucun scan BL lié.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...scans.map((scan) {
              final storedName = _text(scan, 'nom_fichier');
              final fileName = storedName.isEmpty
                  ? 'Scan BL'
                  : path.basename(storedName);
              final page = (scan['page'] as num?)?.toInt();
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.description_outlined,
                  color: Color(0xFF7C3AED),
                ),
                title: Text(fileName),
                subtitle: Text(page == null ? 'Page non renseignée' : 'Page $page'),
                trailing: IconButton(
                  tooltip: 'Visualiser',
                  onPressed: () => onViewScan(scan),
                  icon: const Icon(Icons.visibility_outlined),
                ),
              );
            }),
          const Divider(height: 28),
          _MovementList(
            title: "Dépôts d'argent",
            icon: Icons.account_balance_wallet_outlined,
            color: const Color(0xFF2563EB),
            rows: depots,
            dateFor: (row) => _date(row['date_paiement']),
            amountFor: _amount,
            detailFor: (row) => _text(row, 'agent'),
          ),
          const SizedBox(height: 18),
          _MovementList(
            title: 'Dépenses',
            icon: Icons.money_off_outlined,
            color: const Color(0xFFDC2626),
            rows: depenses,
            dateFor: (row) => _date(row['date']),
            amountFor: _amount,
            detailFor: (row) =>
                ((row['valide'] as num?)?.toInt() ?? 0) > 0
                    ? 'Validée'
                    : 'En attente',
          ),
        ],
      ),
    );
  }
}

class _DossierDetailValue extends StatelessWidget {
  final String label;
  final String value;

  const _DossierDetailValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 2),
          Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _MovementList extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Map<String, Object?>> rows;
  final String Function(Map<String, Object?>) dateFor;
  final String Function(Map<String, Object?>) amountFor;
  final String Function(Map<String, Object?>) detailFor;

  const _MovementList({
    required this.title,
    required this.icon,
    required this.color,
    required this.rows,
    required this.dateFor,
    required this.amountFor,
    required this.detailFor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(width: 8),
            Text(
              '$title (${rows.length})',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          Text(
            'Aucun mouvement.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          )
        else
          ...rows.map((row) {
            final observation = row['observation']?.toString().trim() ?? '';
            final detail = detailFor(row).trim();
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: color.withAlpha(12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color.withAlpha(45)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 88, child: Text(dateFor(row))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row['libelle']?.toString().trim().isNotEmpty == true
                              ? row['libelle'].toString()
                              : '-',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (detail.isNotEmpty || observation.isNotEmpty)
                          Text(
                            [detail, observation]
                                .where((value) => value.isNotEmpty)
                                .join(' • '),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    amountFor(row),
                    style: TextStyle(fontWeight: FontWeight.w700, color: color),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

// ─── Conteneur Search Section ─────────────────────────────────────────────

class _ConteneurSearchSection extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSearch;
  final bool searching;
  final List<Map<String, Object?>> results;
  final bool searched;

  const _ConteneurSearchSection({
    required this.controller,
    required this.onSearch,
    required this.searching,
    required this.results,
    required this.searched,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Numéro conteneur (ex: MSCU1234567)',
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: Color(0xFF8B5CF6)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFF8B5CF6), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onSubmitted: (_) => onSearch(),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: searching ? null : onSearch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                child: searching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Chercher',
                        style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
        if (searching) ...[
          const SizedBox(height: 20),
          const Center(child: CircularProgressIndicator()),
        ] else if (searched && results.isEmpty) ...[
          const SizedBox(height: 20),
          Center(
            child: Column(
              children: [
                Icon(Icons.search_off_rounded,
                    size: 42, color: Colors.grey.shade300),
                const SizedBox(height: 8),
                Text('Aucun conteneur trouvé.',
                    style: TextStyle(color: Colors.grey.shade500)),
              ],
            ),
          ),
        ] else if (results.isNotEmpty) ...[
          const SizedBox(height: 14),
          ...results.map((c) => _ConteneurResultCard(data: c)),
        ],
      ],
    );
  }
}

class _ConteneurResultCard extends StatelessWidget {
  final Map<String, Object?> data;
  const _ConteneurResultCard({required this.data});

  String _s(String key) => (data[key] as String?)?.trim() ?? '';
  double _d(String key) =>
      (data[key] as num?)?.toDouble() ?? 0.0;
  int _i(String key) => (data[key] as num?)?.toInt() ?? 0;

  String _fmt(String? val) {
    if (val == null || val.trim().isEmpty) return '—';
    try {
      final d = DateTime.parse(val.trim());
      return DateFormat('dd/MM/yyyy').format(d);
    } catch (_) {
      return val.trim();
    }
  }

  @override
  Widget build(BuildContext context) {
    final numFmt = NumberFormat('#,##0.00', 'fr_FR');
    final statut = _s('dossier_statut');
    final montant = _d('montant_convenu');
    final nbArticles = _i('nb_articles');
    final nbInterchange = _i('nb_interchange');

    Color statutColor;
    Color statutBg;
    switch (statut.toLowerCase()) {
      case 'termine':
        statutColor = const Color(0xFF16A34A);
        statutBg = const Color(0xFFF0FDF4);
        break;
      case 'en cours':
        statutColor = const Color(0xFF2563EB);
        statutBg = const Color(0xFFEFF6FF);
        break;
      case 'annule':
        statutColor = const Color(0xFF6B7280);
        statutBg = const Color(0xFFF9FAFB);
        break;
      default:
        statutColor = const Color(0xFFD97706);
        statutBg = const Color(0xFFFFFBEB);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Text(
                    _s('numero_conteneur').isEmpty
                        ? '—'
                        : _s('numero_conteneur'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (statut.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statutBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: statutColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      statut,
                      style: TextStyle(
                          fontSize: 12,
                          color: statutColor,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            if (_s('dimension').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(_s('dimension'),
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF6B7280))),
            ],
            const Divider(height: 20),

            // Dossier / client
            if (_s('numero_bl').isNotEmpty)
              _InfoRow(icon: Icons.folder_outlined,
                  label: 'BL', value: _s('numero_bl')),
            if (_s('client_nom').isNotEmpty)
              _InfoRow(icon: Icons.person_outlined,
                  label: 'Client', value: _s('client_nom')),
            if (montant > 0)
              _InfoRow(
                  icon: Icons.payments_outlined,
                  label: 'Montant',
                  value: numFmt.format(montant)),
            if (_s('nature_marchandise').isNotEmpty)
              _InfoRow(
                  icon: Icons.inventory_2_outlined,
                  label: 'Marchandise',
                  value: _s('nature_marchandise')),

            // Transport
            if (_s('nom_transporteur').isNotEmpty ||
                _s('marque_camion').isNotEmpty ||
                _s('nom_chauffeur').isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Transport',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151))),
              const SizedBox(height: 4),
              if (_s('nom_transporteur').isNotEmpty)
                _InfoRow(
                    icon: Icons.local_shipping_outlined,
                    label: 'Transporteur',
                    value: _s('nom_transporteur')),
              if (_s('marque_camion').isNotEmpty ||
                  _s('numero_plaque').isNotEmpty)
                _InfoRow(
                    icon: Icons.directions_car_outlined,
                    label: 'Camion',
                    value: [_s('marque_camion'), _s('numero_plaque')]
                        .where((v) => v.isNotEmpty)
                        .join(' / ')),
              if (_s('nom_chauffeur').isNotEmpty ||
                  _s('numero_chauffeur').isNotEmpty)
                _InfoRow(
                    icon: Icons.badge_outlined,
                    label: 'Chauffeur',
                    value: [_s('nom_chauffeur'), _s('numero_chauffeur')]
                        .where((v) => v.isNotEmpty)
                        .join(' — ')),
            ],

            // Dates de suivi
            if (_s('date_sorti_port').isNotEmpty ||
                _s('lieu_dechargement').isNotEmpty ||
                _s('date_arriver_lieu_dechargement').isNotEmpty ||
                _s('date_dechargement').isNotEmpty ||
                _s('date_depart_retour_port').isNotEmpty ||
                _s('date_retour_port').isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Suivi',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151))),
              const SizedBox(height: 4),
              if (_s('date_sorti_port').isNotEmpty)
                _InfoRow(
                    icon: Icons.anchor_outlined,
                    label: 'Sorti port',
                    value: _fmt(_s('date_sorti_port'))),
              if (_s('lieu_dechargement').isNotEmpty)
                _InfoRow(
                    icon: Icons.location_on_outlined,
                    label: 'Lieu décharg.',
                    value: _s('lieu_dechargement')),
              if (_s('date_arriver_lieu_dechargement').isNotEmpty)
                _InfoRow(
                    icon: Icons.event_available_outlined,
                    label: 'Arrivée lieu',
                    value: _fmt(_s('date_arriver_lieu_dechargement'))),
              if (_s('date_dechargement').isNotEmpty)
                _InfoRow(
                    icon: Icons.unarchive_outlined,
                    label: 'Déchargement',
                    value: _fmt(_s('date_dechargement'))),
              if (_s('date_depart_retour_port').isNotEmpty)
                _InfoRow(
                    icon: Icons.directions_outlined,
                    label: 'Départ retour',
                    value: _fmt(_s('date_depart_retour_port'))),
              if (_s('date_retour_port').isNotEmpty)
                _InfoRow(
                    icon: Icons.check_circle_outline,
                    label: 'Retour port',
                    value: _fmt(_s('date_retour_port'))),
            ],

            // Counts
            if (nbArticles > 0 || nbInterchange > 0) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  if (nbArticles > 0)
                    _CountBadge(
                        icon: Icons.list_alt_rounded,
                        label: '$nbArticles article${nbArticles > 1 ? 's' : ''}',
                        color: const Color(0xFF3B82F6)),
                  if (nbInterchange > 0)
                    _CountBadge(
                        icon: Icons.swap_horiz_rounded,
                        label: '$nbInterchange interchange',
                        color: const Color(0xFF8B5CF6)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF9CA3AF)),
          const SizedBox(width: 6),
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF6B7280))),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF1F2937),
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _CountBadge(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
