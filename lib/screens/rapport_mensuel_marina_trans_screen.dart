import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../database/app_database.dart';
import '../services/rapport_pdf.dart';

// ─── Period model ─────────────────────────────────────────────────────────────

class _Periode {
  /// Exclusive lower bound for DB query (last clôture date, SQL uses > prevCloture).
  final String? prevCloture;

  /// Inclusive upper bound for DB query (this clôture date, SQL uses <= thisCloture).
  /// null = current period (open-ended).
  final String? thisCloture;

  final String label;

  const _Periode({this.prevCloture, this.thisCloture, required this.label});
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class RapportMensuelMarinaTransScreen extends StatefulWidget {
  const RapportMensuelMarinaTransScreen({super.key});

  @override
  State<RapportMensuelMarinaTransScreen> createState() =>
      _RapportMensuelMarinaTransScreenState();
}

class _RapportMensuelMarinaTransScreenState
    extends State<RapportMensuelMarinaTransScreen> {
  static final _dateFmt = DateFormat('dd/MM/yyyy');

  bool _loading = true;
  List<_Periode> _periodes = [];
  int _selectedIndex = 0;

  List<Map<String, Object?>> _financialRows = [];
  Map<String?, double> _soldeReporteMap = {};
  List<Map<String, Object?>> _camionRows = [];
  List<Map<String, Object?>> _retourRows = [];

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

    final lastCloture = clotureDates.isNotEmpty ? clotureDates.last : null;
    final currentStart = lastCloture != null ? _addOneDay(lastCloture) : null;
    periodes.add(_Periode(
      prevCloture: lastCloture,
      thisCloture: null,
      label: currentStart != null
          ? 'Période en cours (depuis ${_fmtDate(currentStart)})'
          : 'Période en cours (toutes les données)',
    ));

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
    final dates = await db.getClotureDatesForCompany('MARINA Trans');
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
            build: (_) => RapportPdf.buildMarinasTrans(
              periodeLabel: p.label,
              financialRows: _financialRows,
              soldeReporte: _soldeReporteMap,
              camionRows: _camionRows,
              retourRows: _retourRows,
            ),
            pdfFileName: 'rapport_marina_trans.pdf',
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
        depotTable: 'depot_argent_marina_trans',
        depenseTable: 'depenses_marina_trans',
        fromDate: p.prevCloture,
        toDate: p.thisCloture,
      ),
      db.getSoldeReporteParMonnaie('MARINA Trans',
          avantStricte: p.thisCloture),
      db.getCamionsDashboardRows(fromDate: p.prevCloture, toDate: p.thisCloture),
      db.getRetourCamionDashboard(fromDate: p.prevCloture, toDate: p.thisCloture),
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
      _camionRows = results[2] as List<Map<String, Object?>>;
      _retourRows = results[3] as List<Map<String, Object?>>;
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

                        // ── Détail par camion ─────────────────────────────
                        _RapportSectionHeader(
                          icon: Icons.airport_shuttle_rounded,
                          label: 'Détail par camion',
                          iconColor: const Color(0xFF8B5CF6),
                          badgeColor: const Color(0xFFF5F3FF),
                        ),
                        const SizedBox(height: 12),
                        if (_camionRows.isEmpty)
                          _EmptyCard(
                              message:
                                  'Aucun mouvement par camion pour cette période.')
                        else
                          _CamionSection(rows: _camionRows),
                        const SizedBox(height: 28),

                        // ── Retour camion avec charge ─────────────────────
                        _RapportSectionHeader(
                          icon: Icons.swap_horiz_rounded,
                          label: 'Retour Camion avec Charge',
                          iconColor: const Color(0xFF0891B2),
                          badgeColor: const Color(0xFFECFEFF),
                        ),
                        const SizedBox(height: 12),
                        if (_retourRows.isEmpty)
                          _EmptyCard(
                              message:
                                  'Aucun retour camion pour cette période.')
                        else
                          _RetourCamionSection(rows: _retourRows),
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
          colors: [Color(0xFF1A1A5E), Color(0xFF2D4DB0)],
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
                  'Rapport mensuel – MARINA Trans',
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedIndex,
                  dropdownColor: const Color(0xFF1A1A5E),
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

  const _RapportSectionHeader({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.badgeColor,
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
      ],
    );
  }
}

// ─── Empty card ───────────────────────────────────────────────────────────────

class _EmptyCard extends StatelessWidget {
  final String message;

  const _EmptyCard({required this.message});

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
          const Icon(Icons.info_outline_rounded,
              color: Colors.black26, size: 20),
          const SizedBox(width: 10),
          Text(
            message,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
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
            if (i < rows.length - 1) const Divider(height: 1, indent: 20),
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
    final sigle =
        (row['sigle'] as String?) ?? (row['nom'] as String?) ?? '?';
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

// ─── Camion section ───────────────────────────────────────────────────────────

class _CamionSection extends StatelessWidget {
  final List<Map<String, Object?>> rows;
  const _CamionSection({required this.rows});

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Map<String, Object?>>> grouped = {};
    for (final row in rows) {
      final uuid = row['camion_uuid'] as String? ?? '';
      grouped.putIfAbsent(uuid, () => []).add(row);
    }
    return Column(
      children: [
        for (int i = 0; i < grouped.length; i++) ...[
          _CamionCard(monnaieRows: grouped.values.elementAt(i)),
          if (i < grouped.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _CamionCard extends StatelessWidget {
  final List<Map<String, Object?>> monnaieRows;
  const _CamionCard({required this.monnaieRows});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat('#,##0.00', 'fr_FR');
    final first = monnaieRows.first;
    final marque = (first['marque'] as String?) ?? '';
    final plaque = (first['plaque'] as String?) ?? '';
    final modele = (first['modele'] as String?) ?? '';
    final nbVoyages = (first['nb_voyages'] as num?)?.toInt() ?? 0;
    final label =
        [marque, plaque].where((v) => v.isNotEmpty).join(' – ');

    final activeRows = monnaieRows.where((r) {
      final d = (r['total_depot'] as num?)?.toDouble() ?? 0;
      final dv = (r['total_depense_voyage'] as num?)?.toDouble() ?? 0;
      final dr = (r['total_depense_retour'] as num?)?.toDouble() ?? 0;
      final dp = (r['total_depense_panne'] as num?)?.toDouble() ?? 0;
      return d != 0 || dv != 0 || dr != 0 || dp != 0;
    }).toList();

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withAlpha(18),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.airport_shuttle_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label.isEmpty ? 'Camion sans nom' : label,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      if (modele.isNotEmpty)
                        Text(modele,
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFF8B5CF6).withAlpha(80)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.route_rounded,
                          size: 14, color: Color(0xFF6D28D9)),
                      const SizedBox(width: 4),
                      Text(
                        '$nbVoyages voyage${nbVoyages > 1 ? "s" : ""}',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6D28D9)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Rows
          if (activeRows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Aucun mouvement financier enregistré.',
                  style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 13,
                      fontStyle: FontStyle.italic)),
            )
          else ...[
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                _ch(cs, 'MONNAIE', flex: 2),
                _ch(cs, 'DÉPÔTS', flex: 3, right: true),
                _ch(cs, 'DÉP. VOYAGE', flex: 3, right: true),
                _ch(cs, 'DÉP. RETOUR', flex: 3, right: true),
                _ch(cs, 'DÉP. PANNE', flex: 3, right: true),
                _ch(cs, 'TOTAL DÉP.', flex: 3, right: true),
                _ch(cs, 'SOLDE', flex: 3, right: true),
              ]),
            ),
            const Divider(height: 1),
            for (int i = 0; i < activeRows.length; i++) ...[
              _CamionMonnaieRow(
                  row: activeRows[i], fmt: fmt, isEven: i.isEven),
              if (i < activeRows.length - 1)
                const Divider(height: 1, indent: 16),
            ],
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }

  Widget _ch(ColorScheme cs, String t,
      {required int flex, bool right = false}) {
    return Expanded(
      flex: flex,
      child: Text(t,
          textAlign: right ? TextAlign.right : TextAlign.left,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: cs.onSurfaceVariant)),
    );
  }
}

class _CamionMonnaieRow extends StatelessWidget {
  final Map<String, Object?> row;
  final NumberFormat fmt;
  final bool isEven;

  const _CamionMonnaieRow(
      {required this.row, required this.fmt, required this.isEven});

  @override
  Widget build(BuildContext context) {
    final sigle =
        (row['sigle'] as String?) ?? (row['monnaie_nom'] as String?) ?? '?';
    final depot = (row['total_depot'] as num?)?.toDouble() ?? 0;
    final depV = (row['total_depense_voyage'] as num?)?.toDouble() ?? 0;
    final depR = (row['total_depense_retour'] as num?)?.toDouble() ?? 0;
    final depP = (row['total_depense_panne'] as num?)?.toDouble() ?? 0;
    final totalDep = depV + depR + depP;
    final solde = depot - totalDep;
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
          child: Row(children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)]),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(sigle.substring(0, sigle.length.clamp(0, 2)),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 6),
            Text(sigle,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
        ),
        Expanded(
            flex: 3,
            child: Text(fmt.format(depot),
                textAlign: TextAlign.right,
                style: const TextStyle(
                    color: Color(0xFF1D4ED8), fontSize: 13))),
        Expanded(
            flex: 3,
            child: Text(fmt.format(depV),
                textAlign: TextAlign.right,
                style: const TextStyle(
                    color: Color(0xFF6B7280), fontSize: 13))),
        Expanded(
            flex: 3,
            child: Text(fmt.format(depR),
                textAlign: TextAlign.right,
                style: const TextStyle(
                    color: Color(0xFF0891B2), fontSize: 13))),
        Expanded(
            flex: 3,
            child: Text(fmt.format(depP),
                textAlign: TextAlign.right,
                style: const TextStyle(
                    color: Color(0xFFD97706), fontSize: 13))),
        Expanded(
            flex: 3,
            child: Text(fmt.format(totalDep),
                textAlign: TextAlign.right,
                style: const TextStyle(
                    color: Color(0xFF374151), fontSize: 13))),
        Expanded(
          flex: 3,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(
                  solde >= 0
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  size: 14,
                  color: soldeColor),
              const SizedBox(width: 3),
              Text(fmt.format(solde),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: soldeColor,
                      fontSize: 13)),
            ],
          ),
        ),
      ]),
    );
  }
}

// ─── Retour camion section ────────────────────────────────────────────────────

class _RetourCamionSection extends StatelessWidget {
  final List<Map<String, Object?>> rows;
  const _RetourCamionSection({required this.rows});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat('#,##0.00', 'fr_FR');
    final activeRows = rows.where((r) {
      final d = (r['total_depot'] as num?)?.toDouble() ?? 0;
      final e = (r['total_depense'] as num?)?.toDouble() ?? 0;
      return d != 0 || e != 0;
    }).toList();

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
      child: activeRows.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Aucun mouvement Retour Camion avec Charge enregistré.',
                style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: cs.onSurfaceVariant),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Row(children: [
                    _ch(cs, 'MONNAIE', flex: 2),
                    _ch(cs, 'DÉPÔTS', flex: 3, right: true),
                    _ch(cs, 'DÉPENSES', flex: 3, right: true),
                    _ch(cs, 'SOLDE', flex: 3, right: true),
                  ]),
                ),
                const Divider(height: 1),
                for (int i = 0; i < activeRows.length; i++) ...[
                  _RetourRow(
                      row: activeRows[i], fmt: fmt, isEven: i.isEven),
                  if (i < activeRows.length - 1)
                    const Divider(height: 1, indent: 16),
                ],
                const SizedBox(height: 4),
              ],
            ),
    );
  }

  Widget _ch(ColorScheme cs, String t,
      {required int flex, bool right = false}) {
    return Expanded(
      flex: flex,
      child: Text(t,
          textAlign: right ? TextAlign.right : TextAlign.left,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: cs.onSurfaceVariant)),
    );
  }
}

class _RetourRow extends StatelessWidget {
  final Map<String, Object?> row;
  final NumberFormat fmt;
  final bool isEven;

  const _RetourRow(
      {required this.row, required this.fmt, required this.isEven});

  @override
  Widget build(BuildContext context) {
    final sigle =
        (row['sigle'] as String?) ?? (row['monnaie_nom'] as String?) ?? '?';
    final depot = (row['total_depot'] as num?)?.toDouble() ?? 0;
    final dep = (row['total_depense'] as num?)?.toDouble() ?? 0;
    final solde = depot - dep;
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
                    fontWeight: FontWeight.w700, fontSize: 13))),
        Expanded(
            flex: 3,
            child: Text(fmt.format(depot),
                textAlign: TextAlign.right,
                style: const TextStyle(
                    color: Color(0xFF1D4ED8), fontSize: 13))),
        Expanded(
            flex: 3,
            child: Text(fmt.format(dep),
                textAlign: TextAlign.right,
                style: const TextStyle(
                    color: Color(0xFF374151), fontSize: 13))),
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
