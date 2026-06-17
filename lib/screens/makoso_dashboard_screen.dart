import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/app_database.dart';
import '../services/sync_service.dart';
import 'company_selection_screen.dart';

class MakosoDashboardScreen extends StatefulWidget {
  const MakosoDashboardScreen({super.key});

  @override
  State<MakosoDashboardScreen> createState() => _MakosoDashboardScreenState();
}

class _MakosoDashboardScreenState extends State<MakosoDashboardScreen> {
  bool _loading = true;

  List<Map<String, Object?>> _financialRows = [];
  int _pendingDepenses = 0;
  List<Map<String, Object?>> _pendingDepensesList = [];
  List<Map<String, Object?>> _dossiersEnSouffrance = [];

  final _conteneurSearchCtrl = TextEditingController();
  bool _conteneurSearching = false;
  List<Map<String, Object?>> _conteneurResults = [];
  bool _conteneurSearched = false;

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
    _conteneurSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = AppDatabase.instance;
    final results = await Future.wait([
      db.getMakosoDashboardFinancialRows(),
      db.getMakosoPendingDepenseCount(),
      db.getMakosoPendingDepenses(),
      db.getDossiersEnSouffrance(),
    ]);
    if (!mounted) return;
    setState(() {
      _financialRows = results[0] as List<Map<String, Object?>>;
      _pendingDepenses = results[1] as int;
      _pendingDepensesList = results[2] as List<Map<String, Object?>>;
      _dossiersEnSouffrance = results[3] as List<Map<String, Object?>>;
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

  Future<void> _searchConteneur() async {
    final q = _conteneurSearchCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _conteneurSearching = true;
      _conteneurResults = [];
      _conteneurSearched = false;
    });
    final results = await AppDatabase.instance.searchConteneurs(q);
    if (!mounted) return;
    setState(() {
      _conteneurResults = results;
      _conteneurSearching = false;
      _conteneurSearched = true;
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
          _MakosoDashHeader(
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

                        // ── Dépenses en attente ──────────────────────────
                        _SectionHeader(
                          icon: Icons.hourglass_top_rounded,
                          label: 'Dépenses en attente de validation',
                          iconColor: const Color(0xFFD97706),
                          badgeColor: const Color(0xFFFFFBEB),
                          badge: _pendingDepenses > 0
                              ? '$_pendingDepenses'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        if (_pendingDepensesList.isEmpty)
                          _EmptyState(
                            icon: Icons.check_circle_rounded,
                            iconColor: const Color(0xFF10B981),
                            message: 'Aucune dépense en attente.',
                          )
                        else
                          _PendingDepensesList(
                            depenses: _pendingDepensesList,
                            onValider: _validerDepense,
                            onRejeter: _rejeterDepense,
                          ),

                        const SizedBox(height: 28),

                        // ── Recherche conteneur ──────────────────────────
                        _SectionHeader(
                          icon: Icons.search_rounded,
                          label: 'Recherche conteneur',
                          iconColor: const Color(0xFF8B5CF6),
                          badgeColor: const Color(0xFFF5F3FF),
                        ),
                        const SizedBox(height: 12),
                        _ConteneurSearchSection(
                          controller: _conteneurSearchCtrl,
                          onSearch: _searchConteneur,
                          searching: _conteneurSearching,
                          results: _conteneurResults,
                          searched: _conteneurSearched,
                        ),

                        const SizedBox(height: 28),

                        // ── Dossiers en souffrance ───────────────────────
                        _SectionHeader(
                          icon: Icons.warning_amber_rounded,
                          label: 'Dossiers en souffrance',
                          iconColor: const Color(0xFFEF4444),
                          badgeColor: const Color(0xFFFEF2F2),
                          badge: _dossiersEnSouffrance.isEmpty
                              ? null
                              : '${_dossiersEnSouffrance.length}',
                        ),
                        const SizedBox(height: 12),
                        if (_dossiersEnSouffrance.isEmpty)
                          _EmptyState(
                            icon: Icons.check_circle_rounded,
                            iconColor: const Color(0xFF10B981),
                            message: 'Aucun dossier en souffrance.',
                          )
                        else
                          _DossiersSouffranceList(
                              dossiers: _dossiersEnSouffrance),
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
          Row(
            children: [
              Text(
                'Date : $date',
                style: TextStyle(
                    fontSize: 12, color: cs.onSurfaceVariant),
              ),
              if (dossierUuid != null && dossierUuid.isNotEmpty) ...[
                const SizedBox(width: 12),
                const Icon(Icons.folder_outlined,
                    size: 13, color: Colors.grey),
                const SizedBox(width: 3),
                Text('Dossier lié',
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant)),
              ],
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
                      border: Border.all(color: statutColor.withOpacity(0.4)),
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
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
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
