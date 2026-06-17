import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  List<Map<String, Object?>> _financialRows = [];
  Map<String, int> _voyageStats = {};
  List<Map<String, Object?>> _camionStats = [];
  List<Map<String, Object?>> _retourCharge = [];

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
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = AppDatabase.instance;
    final results = await Future.wait([
      db.getMarinaDashboardFinancialRows(),
      db.getMarinaDashboardVoyageStats(),
      db.getMarinaCamionStats(),
      db.getMarinaRetourChargeStats(),
    ]);
    if (!mounted) return;
    setState(() {
      _financialRows = results[0] as List<Map<String, Object?>>;
      _voyageStats = results[1] as Map<String, int>;
      _camionStats = results[2] as List<Map<String, Object?>>;
      _retourCharge = results[3] as List<Map<String, Object?>>;
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

                        // ── Voyage stats ─────────────────────────────────
                        _SectionHeader(
                          icon: Icons.local_shipping_rounded,
                          label: 'Statistiques des voyages',
                          iconColor: const Color(0xFF3B82F6),
                          badgeColor: const Color(0xFFEFF6FF),
                        ),
                        const SizedBox(height: 12),
                        _VoyageStatsRow(stats: _voyageStats),

                        const SizedBox(height: 28),

                        // ── Par camion ───────────────────────────────────
                        _SectionHeader(
                          icon: Icons.airport_shuttle_rounded,
                          label: 'Situation par camion',
                          iconColor: const Color(0xFF8B5CF6),
                          badgeColor: const Color(0xFFF5F3FF),
                          badge: _camionStats.isEmpty
                              ? null
                              : '${_camionStats.length}',
                        ),
                        const SizedBox(height: 12),
                        if (_camionStats.isEmpty)
                          _EmptyState(
                            icon: Icons.airport_shuttle_outlined,
                            message: 'Aucun camion enregistré.',
                          )
                        else
                          _CamionStatsList(camions: _camionStats),

                        const SizedBox(height: 28),

                        // ── Retour charge ────────────────────────────────
                        _SectionHeader(
                          icon: Icons.loop_rounded,
                          label: 'Retour camion avec charge',
                          iconColor: const Color(0xFFF59E0B),
                          badgeColor: const Color(0xFFFFFBEB),
                          badge: _retourCharge.isEmpty
                              ? null
                              : '${_retourCharge.length}',
                        ),
                        const SizedBox(height: 12),
                        if (_retourCharge.isEmpty)
                          _EmptyState(
                            icon: Icons.check_circle_rounded,
                            iconColor: const Color(0xFF10B981),
                            message: 'Aucun voyage retour avec charge.',
                          )
                        else
                          _RetourChargeList(voyages: _retourCharge),
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
