import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../database/app_database.dart';
import '../services/rapport_pdf.dart';

// ─── Period model ─────────────────────────────────────────────────────────────

class _Periode {
  /// The clôture date ending the PREVIOUS period (= exclusive lower bound for DB query).
  /// null = no lower bound (first period or no clôtures exist).
  final String? prevCloture;

  /// The clôture date ending THIS period (= inclusive upper bound for DB query).
  /// null = current period (open-ended).
  final String? thisCloture;

  final String label;

  const _Periode({this.prevCloture, this.thisCloture, required this.label});
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class RapportMensuelMakosoScreen extends StatefulWidget {
  const RapportMensuelMakosoScreen({super.key});

  @override
  State<RapportMensuelMakosoScreen> createState() =>
      _RapportMensuelMakosoScreenState();
}

class _RapportMensuelMakosoScreenState
    extends State<RapportMensuelMakosoScreen> {
  static final _dateFmt = DateFormat('dd/MM/yyyy');

  bool _loading = true;
  List<_Periode> _periodes = [];
  int _selectedIndex = 0;

  List<Map<String, Object?>> _financialRows = [];
  Map<String?, double> _soldeReporteMap = {};
  List<Map<String, Object?>> _dossierRows = [];
  List<Map<String, Object?>> _souffranceRows = [];

  // ── Helpers ──────────────────────────────────────────────────────────────

  static String _fmtDate(String d) {
    try {
      return _dateFmt.format(DateTime.parse(d));
    } catch (_) {
      return d;
    }
  }

  static String _addOneDay(String d) {
    try {
      return DateTime.parse(d)
          .add(const Duration(days: 1))
          .toIso8601String()
          .substring(0, 10);
    } catch (_) {
      return d;
    }
  }

  List<_Periode> _buildPeriodes(List<String> clotureDates) {
    final periodes = <_Periode>[];

    // Current period (always first in list)
    final lastCloture = clotureDates.isNotEmpty ? clotureDates.last : null;
    final currentStart = lastCloture != null ? _addOneDay(lastCloture) : null;
    periodes.add(_Periode(
      prevCloture: lastCloture,
      thisCloture: null,
      label: currentStart != null
          ? 'Période en cours (depuis ${_fmtDate(currentStart)})'
          : 'Période en cours (toutes les données)',
    ));

    // Past periods, most recent first
    for (int i = clotureDates.length - 1; i >= 0; i--) {
      final prev = i > 0 ? clotureDates[i - 1] : null;
      final end = clotureDates[i];
      final startLabel = prev != null ? _fmtDate(_addOneDay(prev)) : 'début';
      periodes.add(_Periode(
        prevCloture: prev,
        thisCloture: end,
        label: 'Clôture du ${_fmtDate(end)} ($startLabel – ${_fmtDate(end)})',
      ));
    }
    return periodes;
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadClotures();
  }

  Future<void> _loadClotures() async {
    final db = AppDatabase.instance;
    final dates = await db.getClotureDatesForCompany('MAKOSO Services');
    if (!mounted) return;
    setState(() {
      _periodes = _buildPeriodes(dates);
      _selectedIndex = 0;
    });
    await _loadData();
  }

  void _printReport(BuildContext context) {
    if (_periodes.isEmpty) return;
    final p = _periodes[_selectedIndex];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('Aperçu avant impression'),
          ),
          body: PdfPreview(
            build: (_) => RapportPdf.buildMakoso(
              periodeLabel: p.label,
              financialRows: _financialRows,
              soldeReporte: _soldeReporteMap,
              dossierRows: _dossierRows,
              souffranceRows: _souffranceRows,
            ),
            pdfFileName: 'rapport_makoso.pdf',
            canChangePageFormat: false,
            canChangeOrientation: false,
          ),
        ),
      ),
    );
  }

  Future<void> _loadData() async {
    if (_periodes.isEmpty) return;
    setState(() => _loading = true);

    final db = AppDatabase.instance;
    final p = _periodes[_selectedIndex];

    final results = await Future.wait([
      db.getDashboardFinancialRows(
        depotTable: 'depot_argent_makoso',
        depenseTable: 'depenses_makoso',
        fromDate: p.prevCloture,
        toDate: p.thisCloture,
      ),
      db.getSoldeReporteParMonnaie('MAKOSO Services', avantStricte: p.thisCloture),
      db.getRapportMakosoParDossier(fromDate: p.prevCloture, toDate: p.thisCloture),
      db.getDossiersSouffrancePaiement(),
    ]);

    if (!mounted) return;

    final soldeReporteRows = results[1] as List<Map<String, Object?>>;

    setState(() {
      _financialRows = results[0] as List<Map<String, Object?>>;
      _soldeReporteMap = {
        for (final r in soldeReporteRows)
          (r['monnaie_uuid'] as String?):
              (r['montant'] as num?)?.toDouble() ?? 0.0,
      };
      _dossierRows = results[2] as List<Map<String, Object?>>;
      _souffranceRows = results[3] as List<Map<String, Object?>>;
      _loading = false;
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Situation financière globale ──────────────────
                        _RapportSectionHeader(
                          icon: Icons.account_balance_rounded,
                          label: 'Situation financière globale',
                          iconColor: const Color(0xFF3B82F6),
                          badgeColor: const Color(0xFFEFF6FF),
                        ),
                        const SizedBox(height: 12),
                        if (_financialRows.isEmpty)
                          _EmptyCard(
                              message:
                                  'Aucune donnée financière pour cette période.')
                        else
                          _FinancialTableWithReport(
                            rows: _financialRows,
                            soldeReporte: _soldeReporteMap,
                          ),
                        const SizedBox(height: 28),

                        // ── Situation par dossier ─────────────────────────
                        _RapportSectionHeader(
                          icon: Icons.folder_copy_rounded,
                          label: 'Situation par dossier',
                          iconColor: const Color(0xFF10B981),
                          badgeColor: const Color(0xFFECFDF5),
                        ),
                        const SizedBox(height: 12),
                        if (_dossierRows.isEmpty)
                          _EmptyCard(
                              message:
                                  'Aucune activité par dossier pour cette période.')
                        else
                          _DossierRapportList(rows: _dossierRows),
                        const SizedBox(height: 28),

                        // ── Dossiers en souffrance ────────────────────────
                        _RapportSectionHeader(
                          icon: Icons.warning_amber_rounded,
                          label: 'Dossiers en souffrance de paiement',
                          iconColor: const Color(0xFFEF4444),
                          badgeColor: const Color(0xFFFEF2F2),
                          badge: _souffranceRows.isEmpty
                              ? null
                              : '${_souffranceRows.length}',
                        ),
                        const SizedBox(height: 12),
                        if (_souffranceRows.isEmpty)
                          _EmptyCard(
                            message: 'Aucun dossier en souffrance.',
                            iconColor: const Color(0xFF10B981),
                          )
                        else
                          _SouffranceList(dossiers: _souffranceRows),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF2D6A9F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded,
                  color: Colors.white70, size: 22),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Rapport mensuel – MAKOSO Services',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.print_rounded, color: Colors.white70),
                onPressed: _periodes.isNotEmpty && !_loading
                    ? () => _printReport(context)
                    : null,
                tooltip: 'Imprimer',
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                onPressed: _loadData,
                tooltip: 'Actualiser',
              ),
            ],
          ),
          if (_periodes.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedIndex,
                  dropdownColor: const Color(0xFF1E3A5F),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  iconEnabledColor: Colors.white70,
                  isExpanded: true,
                  onChanged: (v) {
                    if (v != null && v != _selectedIndex) {
                      setState(() => _selectedIndex = v);
                      _loadData();
                    }
                  },
                  items: [
                    for (int i = 0; i < _periodes.length; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text(
                          _periodes[i].label,
                          style: const TextStyle(color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _RapportSectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color badgeColor;
  final String? badge;

  const _RapportSectionHeader({
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
    );
  }
}

// ─── Empty card ───────────────────────────────────────────────────────────────

class _EmptyCard extends StatelessWidget {
  final String message;
  final Color iconColor;

  const _EmptyCard({
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
        border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline_rounded, color: iconColor, size: 20),
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

// ─── Financial table with report column ──────────────────────────────────────

class _FinancialTableWithReport extends StatelessWidget {
  final List<Map<String, Object?>> rows;
  final Map<String?, double> soldeReporte;

  const _FinancialTableWithReport({
    required this.rows,
    required this.soldeReporte,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'fr_FR');
    final cs = Theme.of(context).colorScheme;
    final hasReport = soldeReporte.values.any((v) => v != 0);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(children: [
              _hdr(cs, 'MONNAIE', flex: 2),
              if (hasReport) _hdr(cs, 'REPORT', flex: 3, right: true),
              _hdr(cs, 'DÉPÔTS', flex: 3, right: true),
              _hdr(cs, 'DÉPENSES', flex: 3, right: true),
              _hdr(cs, 'SOLDE', flex: 3, right: true),
            ]),
          ),
          const Divider(height: 1),
          for (int i = 0; i < rows.length; i++) ...[
            _FinancialRow(
              row: rows[i],
              fmt: fmt,
              isEven: i.isEven,
              report:
                  soldeReporte[(rows[i]['monnaie_uuid'] as String?)] ?? 0.0,
              showReport: hasReport,
            ),
            if (i < rows.length - 1)
              const Divider(height: 1, indent: 20),
          ],
        ],
      ),
    );
  }

  Widget _hdr(ColorScheme cs, String t,
      {required int flex, bool right = false}) {
    return Expanded(
      flex: flex,
      child: Text(t,
          textAlign: right ? TextAlign.right : TextAlign.left,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: cs.onSurfaceVariant)),
    );
  }
}

class _FinancialRow extends StatelessWidget {
  final Map<String, Object?> row;
  final NumberFormat fmt;
  final bool isEven;
  final double report;
  final bool showReport;

  const _FinancialRow({
    required this.row,
    required this.fmt,
    required this.isEven,
    this.report = 0.0,
    this.showReport = false,
  });

  @override
  Widget build(BuildContext context) {
    final sigle = (row['sigle'] as String?) ?? (row['nom'] as String?) ?? '?';
    final depot = (row['total_depot'] as num?)?.toDouble() ?? 0.0;
    final depense = (row['total_depense'] as num?)?.toDouble() ?? 0.0;
    final solde = report + depot - depense;
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
            child: Row(children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    sigle.substring(0, sigle.length.clamp(0, 2)),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(sigle,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
          ),
          if (showReport)
            Expanded(
              flex: 3,
              child: Text(fmt.format(report),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      color: Color(0xFF7C3AED), fontSize: 13)),
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
                Text(fmt.format(solde),
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: soldeColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Dossier rapport list ─────────────────────────────────────────────────────

class _DossierRapportList extends StatelessWidget {
  final List<Map<String, Object?>> rows;
  const _DossierRapportList({required this.rows});

  @override
  Widget build(BuildContext context) {
    // Group by dossier_uuid
    final grouped = <String, List<Map<String, Object?>>>{};
    for (final r in rows) {
      final uuid = (r['dossier_uuid'] as String?) ?? '';
      grouped.putIfAbsent(uuid, () => []).add(r);
    }
    final keys = grouped.keys.toList();

    return Column(
      children: [
        for (int i = 0; i < keys.length; i++) ...[
          _DossierRapportCard(monnaieRows: grouped[keys[i]]!),
          if (i < keys.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _DossierRapportCard extends StatelessWidget {
  final List<Map<String, Object?>> monnaieRows;
  const _DossierRapportCard({required this.monnaieRows});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat('#,##0.00', 'fr_FR');
    final first = monnaieRows.first;
    final numeroBl = (first['numero_bl'] as String?) ?? '-';
    final clientNom = (first['client_nom'] as String?) ?? '-';
    final statut = (first['statut'] as String?) ?? '-';

    final activeRows = monnaieRows.where((r) {
      final d = (r['total_depot'] as num?)?.toDouble() ?? 0.0;
      final e = (r['total_depense'] as num?)?.toDouble() ?? 0.0;
      return d != 0 || e != 0;
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(numeroBl,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      if (clientNom != '-')
                        Text(clientNom,
                            style: TextStyle(
                                fontSize: 13,
                                color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                _StatusPill(statut: statut),
              ],
            ),
          ),
          // Monnaie rows
          if (activeRows.isNotEmpty) ...[
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                Expanded(
                    flex: 2,
                    child: _colHdr(cs, 'MONNAIE')),
                Expanded(
                    flex: 3,
                    child: _colHdr(cs, 'DÉPÔTS', right: true)),
                Expanded(
                    flex: 3,
                    child: _colHdr(cs, 'DÉPENSES', right: true)),
                Expanded(
                    flex: 3,
                    child: _colHdr(cs, 'SOLDE', right: true)),
              ]),
            ),
            const Divider(height: 1),
            for (int i = 0; i < activeRows.length; i++) ...[
              _DossierMonnaieRow(
                  row: activeRows[i], fmt: fmt, isEven: i.isEven),
              if (i < activeRows.length - 1)
                const Divider(height: 1, indent: 16),
            ],
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _colHdr(ColorScheme cs, String t, {bool right = false}) {
    return Text(t,
        textAlign: right ? TextAlign.right : TextAlign.left,
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: cs.onSurfaceVariant));
  }
}

class _DossierMonnaieRow extends StatelessWidget {
  final Map<String, Object?> row;
  final NumberFormat fmt;
  final bool isEven;

  const _DossierMonnaieRow(
      {required this.row, required this.fmt, required this.isEven});

  @override
  Widget build(BuildContext context) {
    final sigle =
        (row['monnaie_sigle'] as String?) ?? (row['monnaie_nom'] as String?) ?? '?';
    final depot = (row['total_depot'] as num?)?.toDouble() ?? 0.0;
    final depense = (row['total_depense'] as num?)?.toDouble() ?? 0.0;
    final solde = depot - depense;
    final soldeColor =
        solde >= 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

    return Container(
      color: isEven
          ? Colors.transparent
          : Theme.of(context).colorScheme.surfaceContainerLowest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Expanded(
            flex: 2,
            child: Text(sigle,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13))),
        Expanded(
            flex: 3,
            child: Text(fmt.format(depot),
                textAlign: TextAlign.right,
                style: const TextStyle(
                    color: Color(0xFF1D4ED8), fontSize: 13))),
        Expanded(
            flex: 3,
            child: Text(fmt.format(depense),
                textAlign: TextAlign.right,
                style: const TextStyle(
                    color: Color(0xFF6B7280), fontSize: 13))),
        Expanded(
          flex: 3,
          child: Text(fmt.format(solde),
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: soldeColor,
                  fontSize: 13)),
        ),
      ]),
    );
  }
}

// ─── Dossiers en souffrance list ──────────────────────────────────────────────

class _SouffranceList extends StatelessWidget {
  final List<Map<String, Object?>> dossiers;
  const _SouffranceList({required this.dossiers});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < dossiers.length; i++) ...[
          _SouffranceCard(row: dossiers[i]),
          if (i < dossiers.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _SouffranceCard extends StatelessWidget {
  final Map<String, Object?> row;
  const _SouffranceCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final numeroBl = (row['numero_bl'] as String?) ?? '-';
    final clientNom = (row['client_nom'] as String?) ?? '-';
    final statut = (row['statut'] as String?) ?? '-';
    final souffranceDraft = (row['souffrance_draft'] as int? ?? 0) == 1;
    final souffrancePn = (row['souffrance_pn'] as int? ?? 0) == 1;
    final souffranceMatadi = (row['souffrance_matadi'] as int? ?? 0) == 1;
    const accentColor = Color(0xFFEF4444);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withAlpha(60)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 5,
              decoration: const BoxDecoration(
                color: accentColor,
                borderRadius:
                    BorderRadius.horizontal(left: Radius.circular(14)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(numeroBl,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                      _StatusPill(statut: statut),
                    ]),
                    if (clientNom != '-') ...[
                      const SizedBox(height: 3),
                      Row(children: [
                        Icon(Icons.person_outline_rounded,
                            size: 13, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(clientNom,
                            style: TextStyle(
                                fontSize: 13, color: cs.onSurfaceVariant)),
                      ]),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (souffranceDraft)
                          _SouffranceChip(label: '30% Draft non payé'),
                        if (souffrancePn)
                          _SouffranceChip(
                              label: '30% Pointe Noire non payé'),
                        if (souffranceMatadi)
                          _SouffranceChip(label: '40% Matadi non payé'),
                      ],
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

class _SouffranceChip extends StatelessWidget {
  final String label;
  const _SouffranceChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEF4444).withAlpha(100)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 13, color: Color(0xFFEF4444)),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFB91C1C),
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ─── Status pill ──────────────────────────────────────────────────────────────

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
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(statut,
          style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2)),
    );
  }
}
