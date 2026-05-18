import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/app_database.dart';
import '../services/sync_service.dart';
import 'depenses_detail_screen.dart';
import 'depenses_en_attente_screen.dart';
import 'depot_argent_detail_screen.dart';
import 'voyages_list_screen.dart';

class TableauDeBordScreen extends StatefulWidget {
  const TableauDeBordScreen({super.key});

  @override
  State<TableauDeBordScreen> createState() => _TableauDeBordScreenState();
}

class _TableauDeBordScreenState extends State<TableauDeBordScreen> {
  bool _loading = true;

  // Financial section
  List<Map<String, Object?>> _financialRows = [];
  int _pendingDepenses = 0;

  // Voyage section
  int _voyageTotal = 0;
  int _voyageEnCours = 0;
  int _voyageEnAttente = 0;

  // Dossiers en retard
  List<Map<String, Object?>> _dossiersEnRetard = [];

  // Sync
  bool _syncInProgress = false;
  StreamSubscription<SyncNotification>? _syncSub;

  @override
  void initState() {
    super.initState();
    _syncInProgress = AppSyncService.instance.isRunning;
    _syncSub = AppSyncService.instance.notifications.listen((n) {
      if (!mounted) return;
      setState(() {
        _syncInProgress = AppSyncService.instance.isRunning;
      });
      if (n.hasDataChanges) _load();
    });
    _load();
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  Future<void> _runSync() async {
    if (_syncInProgress) return;
    setState(() => _syncInProgress = true);
    final result = await AppSyncService.instance.synchronize();
    if (!mounted) return;
    setState(() => _syncInProgress = AppSyncService.instance.isRunning);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? '${result.message} Pull : ${result.pulledCount}, push : ${result.pushedCount}.'
              : '${result.message} ${result.error ?? ''}'.trim(),
        ),
      ),
    );
    if (result.success) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = AppDatabase.instance;

    final results = await Future.wait([
      db.getDashboardFinancialRows(),
      db.getPendingDepenseCount(),
      db.getDashboardVoyageStats(),
      db.getDossiersEnRetard(),
    ]);

    if (!mounted) return;

    setState(() {
      _financialRows = results[0] as List<Map<String, Object?>>;
      _pendingDepenses = results[1] as int;
      final stats = results[2] as Map<String, int>;
      _voyageTotal = stats['total'] ?? 0;
      _voyageEnCours = stats['en_cours'] ?? 0;
      _voyageEnAttente = stats['en_attente'] ?? 0;
      _dossiersEnRetard = results[3] as List<Map<String, Object?>>;
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
          _DashboardHeader(
            onRefresh: _load,
            onSync: _runSync,
            syncInProgress: _syncInProgress,
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
                        if (_pendingDepenses > 0) ...[
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const DepensesEnAttenteScreen(),
                              ),
                            ).then((_) => _load()),
                            child: _PendingDepenseBanner(
                                count: _pendingDepenses),
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (_financialRows.isEmpty)
                          _EmptyState(
                            icon: Icons.account_balance_outlined,
                            message: 'Aucune donnée financière disponible.',
                          )
                        else
                          _FinancialTable(
                            rows: _financialRows,
                            onDepotTap: (row) {
                              final uuid =
                                  row['monnaie_uuid'] as String? ?? '';
                              final sigle =
                                  (row['sigle'] as String?)?.trim() ?? '';
                              final nom =
                                  (row['nom'] as String?)?.trim() ?? '';
                              final label =
                                  sigle.isNotEmpty ? sigle : nom;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DepotArgentDetailScreen(
                                    monnaieUuid: uuid,
                                    monnaieLabel: label,
                                  ),
                                ),
                              );
                            },
                            onDepenseTap: (row) {
                              final uuid =
                                  row['monnaie_uuid'] as String? ?? '';
                              final sigle =
                                  (row['sigle'] as String?)?.trim() ?? '';
                              final nom =
                                  (row['nom'] as String?)?.trim() ?? '';
                              final label =
                                  sigle.isNotEmpty ? sigle : nom;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DepensesDetailScreen(
                                    monnaieUuid: uuid,
                                    monnaieLabel: label,
                                  ),
                                ),
                              );
                            },
                          ),

                        const SizedBox(height: 28),

                        // ── Voyages ──────────────────────────────────────
                        _SectionHeader(
                          icon: Icons.local_shipping_rounded,
                          label: 'Voyages',
                          iconColor: const Color(0xFF10B981),
                          badgeColor: const Color(0xFFECFDF5),
                        ),
                        const SizedBox(height: 12),
                        _VoyageStatsRow(
                          total: _voyageTotal,
                          enCours: _voyageEnCours,
                          enAttente: _voyageEnAttente,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const VoyagesListScreen(),
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // ── Dossiers en retard ───────────────────────────
                        _SectionHeader(
                          icon: Icons.warning_rounded,
                          label: 'Dossiers avec retard de paiement',
                          iconColor: const Color(0xFFEF4444),
                          badgeColor: const Color(0xFFFEF2F2),
                          badge: _dossiersEnRetard.isEmpty
                              ? null
                              : '${_dossiersEnRetard.length}',
                        ),
                        const SizedBox(height: 12),
                        if (_dossiersEnRetard.isEmpty)
                          _EmptyState(
                            icon: Icons.check_circle_rounded,
                            iconColor: const Color(0xFF10B981),
                            message: 'Aucun dossier avec retard de paiement.',
                          )
                        else
                          _DossiersRetardList(dossiers: _dossiersEnRetard),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Dashboard header ────────────────────────────────────────────────────────

class _DashboardHeader extends StatelessWidget {
  final VoidCallback onRefresh;
  final VoidCallback onSync;
  final bool syncInProgress;

  const _DashboardHeader({
    required this.onRefresh,
    required this.onSync,
    required this.syncInProgress,
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
          const Icon(Icons.dashboard_rounded, color: Colors.white70, size: 22),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Tableau de bord',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          // Sync button
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
                    icon: const Icon(Icons.sync_rounded,
                        color: Colors.white70),
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

// ─── Section header ──────────────────────────────────────────────────────────

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
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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

// ─── Pending depense banner ──────────────────────────────────────────────────

class _PendingDepenseBanner extends StatelessWidget {
  final int count;
  const _PendingDepenseBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFBBF24).withAlpha(120)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.hourglass_top_rounded,
              size: 18,
              color: Color(0xFFD97706),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(color: Color(0xFF92400E), fontSize: 13),
                children: [
                  TextSpan(
                    text: '$count dépense${count > 1 ? "s" : ""} ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: 'en attente de validation'),
                ],
              ),
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: Color(0xFFD97706), size: 20),
        ],
      ),
    );
  }
}

// ─── Financial cards ─────────────────────────────────────────────────────────

class _FinancialTable extends StatelessWidget {
  final List<Map<String, Object?>> rows;
  final void Function(Map<String, Object?> row)? onDepotTap;
  final void Function(Map<String, Object?> row)? onDepenseTap;

  const _FinancialTable({
    required this.rows,
    this.onDepotTap,
    this.onDepenseTap,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'fr_FR');
    return Column(
      children: [
        for (int i = 0; i < rows.length; i++) ...[
          _FinancialCurrencyCard(
            row: rows[i],
            fmt: fmt,
            onDepotTap:
                onDepotTap == null ? null : () => onDepotTap!(rows[i]),
            onDepenseTap:
                onDepenseTap == null ? null : () => onDepenseTap!(rows[i]),
          ),
          if (i < rows.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _FinancialCurrencyCard extends StatelessWidget {
  final Map<String, Object?> row;
  final NumberFormat fmt;
  final VoidCallback? onDepotTap;
  final VoidCallback? onDepenseTap;

  const _FinancialCurrencyCard({
    required this.row,
    required this.fmt,
    this.onDepotTap,
    this.onDepenseTap,
  });

  @override
  Widget build(BuildContext context) {
    final sigle =
        (row['sigle'] as String?) ?? (row['nom'] as String?) ?? '?';
    final nom = (row['nom'] as String?) ?? sigle;
    final depot = (row['total_depot'] as num?)?.toDouble() ?? 0.0;
    final depense = (row['total_depense'] as num?)?.toDouble() ?? 0.0;
    final solde = depot - depense;
    final soldePositif = solde >= 0;
    final soldeColor =
        soldePositif ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

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
          // Currency header
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
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  nom,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: Colors.white.withAlpha(40)),
          const SizedBox(height: 12),
          // Dépôts row
          _FinancialLine(
            label: 'Dépôts',
            amount: fmt.format(depot),
            icon: Icons.arrow_downward_rounded,
            color: const Color(0xFF93C5FD),
            onTap: onDepotTap,
          ),
          const SizedBox(height: 8),
          // Dépenses row
          _FinancialLine(
            label: 'Dépenses',
            amount: fmt.format(depense),
            icon: Icons.arrow_upward_rounded,
            color: const Color(0xFFFCA5A5),
            onTap: onDepenseTap,
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: Colors.white.withAlpha(40)),
          const SizedBox(height: 10),
          // Solde
          Row(
            children: [
              Icon(
                soldePositif
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                color: soldePositif
                    ? const Color(0xFF4ADE80)
                    : const Color(0xFFF87171),
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'Solde',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                fmt.format(solde),
                style: TextStyle(
                  color: soldePositif
                      ? const Color(0xFF4ADE80)
                      : const Color(0xFFF87171),
                  fontWeight: FontWeight.w800,
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
  final VoidCallback? onTap;

  const _FinancialLine({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withAlpha(200),
              fontSize: 13,
            ),
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
          if (onTap != null) ...[
            const SizedBox(width: 2),
            Icon(Icons.chevron_right_rounded, color: color, size: 15),
          ],
        ],
      ),
    );
  }
}

// ─── Voyage stats ────────────────────────────────────────────────────────────

class _VoyageStatsRow extends StatelessWidget {
  final int total;
  final int enCours;
  final int enAttente;
  final VoidCallback? onTap;

  const _VoyageStatsRow({
    required this.total,
    required this.enCours,
    required this.enAttente,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _VoyageStatCard(
            label: 'Total',
            value: total,
            icon: Icons.summarize_rounded,
            gradient: const [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
            onTap: onTap,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _VoyageStatCard(
            label: 'En cours',
            value: enCours,
            icon: Icons.play_circle_rounded,
            gradient: const [Color(0xFF10B981), Color(0xFF059669)],
            onTap: onTap,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _VoyageStatCard(
            label: 'En attente',
            value: enAttente,
            icon: Icons.pause_circle_rounded,
            gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
            onTap: onTap,
          ),
        ),
      ],
    );
  }
}

class _VoyageStatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback? onTap;

  const _VoyageStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.last.withAlpha(80),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(50),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 16),
          Text(
            value.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withAlpha(200),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      ),
    );
  }
}

// ─── Dossiers en retard list ─────────────────────────────────────────────────

class _DossiersRetardList extends StatelessWidget {
  final List<Map<String, Object?>> dossiers;
  const _DossiersRetardList({required this.dossiers});

  static final _dateFmt = DateFormat('dd/MM/yyyy');

  String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    try {
      return _dateFmt.format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  int _daysOverdue(String raw) {
    try {
      return DateTime.now().difference(DateTime.parse(raw)).inDays;
    } catch (_) {
      return 0;
    }
  }

  List<({String label, int days})> _overdueItems(Map<String, Object?> row) {
    const mapping = {
      'date_paiement_30_draft': '30% Draft',
      'date_paiement_30_pn': '30% PN',
      'date_paiement_40_matadi': '40% Matadi',
    };
    final today = DateTime.now();
    final items = <({String label, int days})>[];
    for (final entry in mapping.entries) {
      final raw = row[entry.key] as String?;
      if (raw != null && raw.isNotEmpty) {
        try {
          if (DateTime.parse(raw).isBefore(today)) {
            items.add((
              label: '${entry.value} · échéance ${_fmtDate(raw)}',
              days: _daysOverdue(raw),
            ));
          }
        } catch (_) {}
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < dossiers.length; i++) ...[
          _DossierRetardCard(
            row: dossiers[i],
            overdueItems: _overdueItems(dossiers[i]),
          ),
          if (i < dossiers.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _DossierRetardCard extends StatelessWidget {
  final Map<String, Object?> row;
  final List<({String label, int days})> overdueItems;

  const _DossierRetardCard({
    required this.row,
    required this.overdueItems,
  });

  @override
  Widget build(BuildContext context) {
    final numeroBl = (row['numero_bl'] as String?) ?? '-';
    final clientNom = (row['client_nom'] as String?) ?? '-';
    final statut = (row['statut'] as String?) ?? '-';
    final maxDays = overdueItems.isEmpty
        ? 0
        : overdueItems.map((e) => e.days).reduce((a, b) => a > b ? a : b);

    final urgencyColor = maxDays > 30
        ? const Color(0xFFDC2626)
        : maxDays > 14
            ? const Color(0xFFEA580C)
            : const Color(0xFFD97706);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: urgencyColor.withAlpha(60)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left urgency accent
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: urgencyColor,
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(14)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            numeroBl,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        _StatusPill(statut: statut),
                      ],
                    ),
                    if (clientNom != '-') ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.person_outline_rounded,
                              size: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            clientNom,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: overdueItems
                          .map((item) => _OverdueChip(
                                label: item.label,
                                days: item.days,
                                color: urgencyColor,
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverdueChip extends StatelessWidget {
  final String label;
  final int days;
  final Color color;

  const _OverdueChip({
    required this.label,
    required this.days,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$days j',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String statut;
  const _StatusPill({required this.statut});

  (Color bg, Color fg) _colors() {
    switch (statut.toLowerCase()) {
      case 'en cours':
        return (const Color(0xFFDCFCE7), const Color(0xFF15803D));
      case 'en attente':
        return (const Color(0xFFFEF9C3), const Color(0xFF854D0E));
      default:
        return (const Color(0xFFF3F4F6), const Color(0xFF374151));
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        statut,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
