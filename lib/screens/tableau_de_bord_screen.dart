import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/app_database.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
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
          _DashboardHeader(onRefresh: _load),
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
                          _PendingDepenseBanner(count: _pendingDepenses),
                          const SizedBox(height: 10),
                        ],
                        if (_financialRows.isEmpty)
                          _EmptyState(
                            icon: Icons.account_balance_outlined,
                            message: 'Aucune donnée financière disponible.',
                          )
                        else
                          _FinancialTable(rows: _financialRows),

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
  const _DashboardHeader({required this.onRefresh});

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
        ],
      ),
    );
  }
}

// ─── Financial table ─────────────────────────────────────────────────────────

class _FinancialTable extends StatelessWidget {
  final List<Map<String, Object?>> rows;
  const _FinancialTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'fr_FR');
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text('MONNAIE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: cs.onSurfaceVariant,
                      )),
                ),
                Expanded(
                  flex: 3,
                  child: Text('DÉPÔTS',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: cs.onSurfaceVariant,
                      )),
                ),
                Expanded(
                  flex: 3,
                  child: Text('DÉPENSES',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: cs.onSurfaceVariant,
                      )),
                ),
                Expanded(
                  flex: 3,
                  child: Text('SOLDE',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: cs.onSurfaceVariant,
                      )),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (int i = 0; i < rows.length; i++) ...[
            _FinancialDataRow(row: rows[i], fmt: fmt, isEven: i.isEven),
            if (i < rows.length - 1) const Divider(height: 1, indent: 20),
          ],
        ],
      ),
    );
  }
}

class _FinancialDataRow extends StatelessWidget {
  final Map<String, Object?> row;
  final NumberFormat fmt;
  final bool isEven;

  const _FinancialDataRow({
    required this.row,
    required this.fmt,
    required this.isEven,
  });

  @override
  Widget build(BuildContext context) {
    final sigle = (row['sigle'] as String?) ?? (row['nom'] as String?) ?? '?';
    final depot = (row['total_depot'] as num?)?.toDouble() ?? 0.0;
    final depense = (row['total_depense'] as num?)?.toDouble() ?? 0.0;
    final solde = depot - depense;
    final soldeColor =
        solde >= 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

    return Container(
      color: isEven
          ? Colors.transparent
          : Theme.of(context).colorScheme.surfaceContainerLowest,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      sigle.substring(0, sigle.length.clamp(0, 2)),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(sigle,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(fmt.format(depot),
                textAlign: TextAlign.right,
                style: const TextStyle(color: Color(0xFF1D4ED8))),
          ),
          Expanded(
            flex: 3,
            child: Text(fmt.format(depense),
                textAlign: TextAlign.right,
                style: const TextStyle(color: Color(0xFF6B7280))),
          ),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  solde >= 0
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  size: 16,
                  color: soldeColor,
                ),
                const SizedBox(width: 4),
                Text(
                  fmt.format(solde),
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: soldeColor),
                ),
              ],
            ),
          ),
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

  const _VoyageStatsRow({
    required this.total,
    required this.enCours,
    required this.enAttente,
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
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _VoyageStatCard(
            label: 'En cours',
            value: enCours,
            icon: Icons.play_circle_rounded,
            gradient: const [Color(0xFF10B981), Color(0xFF059669)],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _VoyageStatCard(
            label: 'En attente',
            value: enAttente,
            icon: Icons.pause_circle_rounded,
            gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
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

  const _VoyageStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
