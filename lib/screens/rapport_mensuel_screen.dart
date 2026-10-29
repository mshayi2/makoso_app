import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../database/app_database.dart';
import '../models/depot_argent.dart';
import '../services/rapport_pdf.dart';
import '../widgets/horizontal_table_scroller.dart';
import 'main_screen.dart';

const List<String> _kMonthNames = [
  'Janvier',
  'Février',
  'Mars',
  'Avril',
  'Mai',
  'Juin',
  'Juillet',
  'Août',
  'Septembre',
  'Octobre',
  'Novembre',
  'Décembre',
];

const int _kMonthsBack = 60;

class RapportMensuelScreen extends StatefulWidget {
  final AppCompany company;

  const RapportMensuelScreen({super.key, required this.company});

  @override
  State<RapportMensuelScreen> createState() => _RapportMensuelScreenState();
}

class _RapportMensuelScreenState extends State<RapportMensuelScreen> {
  static final _dateFormat = DateFormat('dd/MM/yyyy');
  static final _numFormat = NumberFormat('#,##0.00', 'fr_FR');

  late final List<DateTime> _months;
  late DateTime _selectedMonth;
  bool _loading = true;
  List<DepotArgentRecord> _deposits = [];
  List<MonthlyCurrencySummary> _summaries = [];

  bool get _isMakoso => widget.company == AppCompany.makoso;

  String get _companyName => _isMakoso ? 'MAKOSO Services' : 'MARINA Trans';

  String get _depositTable =>
      _isMakoso ? 'depot_argent_makoso' : 'depot_argent_marina_trans';

  String get _expenseTable =>
      _isMakoso ? 'depenses_makoso' : 'depenses_marina_trans';

  DateTime get _previousMonth =>
      DateTime(_selectedMonth.year, _selectedMonth.month - 1);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _months = [
      for (var i = 0; i < _kMonthsBack; i++) DateTime(now.year, now.month - i),
    ];
    _selectedMonth = _months.first;
    _loadData();
  }

  String _monthLabel(DateTime month) =>
      '${_kMonthNames[month.month - 1]} ${month.year}';

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) return '-';
    try {
      return _dateFormat.format(DateTime.parse(value));
    } catch (_) {
      return value;
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final db = AppDatabase.instance;
    // The DB filter is exclusive on fromDate and inclusive on toDate.
    final previousEnd =
        _iso(DateTime(_selectedMonth.year, _selectedMonth.month, 0));
    final monthEnd =
        _iso(DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0));

    final results = await Future.wait([
      db.getDashboardFinancialRows(
        depotTable: _depositTable,
        depenseTable: _expenseTable,
        toDate: previousEnd,
      ),
      db.getDashboardFinancialRows(
        depotTable: _depositTable,
        depenseTable: _expenseTable,
        fromDate: previousEnd,
        toDate: monthEnd,
      ),
      db.getDepotArgentRecords(
        table: _depositTable,
        fromDate: previousEnd,
        toDate: monthEnd,
        limit: null,
      ),
    ]);
    if (!mounted) return;

    setState(() {
      _summaries = _buildSummaries(
        results[0] as List<Map<String, Object?>>,
        results[1] as List<Map<String, Object?>>,
      );
      _deposits = results[2] as List<DepotArgentRecord>;
      _loading = false;
    });
  }

  List<MonthlyCurrencySummary> _buildSummaries(
    List<Map<String, Object?>> previousRows,
    List<Map<String, Object?>> monthRows,
  ) {
    double num0(Object? v) => (v as num?)?.toDouble() ?? 0.0;
    final previous = {for (final r in previousRows) r['monnaie_uuid']: r};
    final month = {for (final r in monthRows) r['monnaie_uuid']: r};
    final summaries = <MonthlyCurrencySummary>[];
    for (final uuid in {...previous.keys, ...month.keys}) {
      final row = previous[uuid] ?? month[uuid]!;
      final sigle = row['sigle']?.toString().trim() ?? '';
      summaries.add(MonthlyCurrencySummary(
        currency: sigle.isNotEmpty ? sigle : (row['nom']?.toString() ?? '-'),
        previousDepot: num0(previous[uuid]?['total_depot']),
        previousDepense: num0(previous[uuid]?['total_depense']),
        monthDepot: num0(month[uuid]?['total_depot']),
        monthDepense: num0(month[uuid]?['total_depense']),
      ));
    }
    summaries.sort((a, b) => a.currency.compareTo(b.currency));
    return summaries;
  }

  void _printReport() {
    if (_loading) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Aperçu avant impression')),
          body: PdfPreview(
            build: (_) => RapportPdf.buildRapportMensuel(
              companyName: _companyName,
              periodeLabel: _monthLabel(_selectedMonth),
              previousMonthLabel: _monthLabel(_previousMonth),
              monthLabel: _monthLabel(_selectedMonth),
              summaries: _summaries,
              depots: _deposits,
            ),
            pdfFileName: _isMakoso
                ? 'rapport_mensuel_makoso.pdf'
                : 'rapport_mensuel_marina.pdf',
            canChangePageFormat: false,
            canChangeOrientation: false,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: const Color(0xFF1A1A5E),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            child: Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(Icons.bar_chart_outlined,
                    color: Colors.white, size: 30),
                Text(
                  'Rapport mensuel – $_companyName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: DropdownButtonFormField<DateTime>(
                    value: _selectedMonth,
                    dropdownColor: Colors.white,
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_month_outlined),
                    ),
                    items: [
                      for (final month in _months)
                        DropdownMenuItem(
                          value: month,
                          child: Text(_monthLabel(month)),
                        ),
                    ],
                    onChanged: _loading
                        ? null
                        : (month) async {
                            if (month == null) return;
                            setState(() => _selectedMonth = month);
                            await _loadData();
                          },
                  ),
                ),
                FilledButton.icon(
                  onPressed: _loading ? null : _printReport,
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Imprimer'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildSummaryCard(context),
                      const SizedBox(height: 20),
                      _buildDepositsCard(context),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    final previousLabel = _monthLabel(_previousMonth);
    final monthLabel = _monthLabel(_selectedMonth);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 1,
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.account_balance_outlined,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Situation financière – $monthLabel',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_summaries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: Text('Aucune donnée financière.')),
            )
          else
            HorizontalTableScroller(
              child: DataTable(
                columns: [
                  const DataColumn(label: Text('Monnaie')),
                  DataColumn(
                      label: Text('Dépôts fin $previousLabel'), numeric: true),
                  DataColumn(
                      label: Text('Dépenses fin $previousLabel'),
                      numeric: true),
                  DataColumn(
                      label: Text('Solde $previousLabel'), numeric: true),
                  DataColumn(label: Text('Dépôts $monthLabel'), numeric: true),
                  DataColumn(
                      label: Text('Dépenses $monthLabel'), numeric: true),
                  DataColumn(label: Text('Solde $monthLabel'), numeric: true),
                  const DataColumn(
                      label: Text('Solde avec report'), numeric: true),
                ],
                rows: _summaries
                    .map((s) => DataRow(cells: [
                          DataCell(Text(s.currency,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700))),
                          DataCell(Text(_numFormat.format(s.previousDepot))),
                          DataCell(Text(_numFormat.format(s.previousDepense))),
                          DataCell(Text(_numFormat.format(s.previousSolde))),
                          DataCell(Text(_numFormat.format(s.monthDepot))),
                          DataCell(Text(_numFormat.format(s.monthDepense))),
                          DataCell(Text(_numFormat.format(s.monthSolde))),
                          DataCell(Text(
                            _numFormat.format(s.soldeWithPrevious),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: s.soldeWithPrevious >= 0
                                  ? const Color(0xFF15803D)
                                  : const Color(0xFFDC2626),
                            ),
                          )),
                        ]))
                    .toList(),
              ),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              'Les dépenses comptabilisées sont les dépenses validées.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepositsCard(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 1,
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.account_balance_wallet_outlined,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text("Dépôts d'argent du mois",
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                Chip(label: Text('${_deposits.length}')),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_deposits.isEmpty)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: Text('Aucun dépôt pour ce mois.')),
            )
          else
            HorizontalTableScroller(
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Libellé')),
                  DataColumn(label: Text('Référence')),
                  DataColumn(label: Text('Montant'), numeric: true),
                  DataColumn(label: Text('Monnaie')),
                  DataColumn(label: Text('Agent')),
                  DataColumn(label: Text('Observation')),
                ],
                rows: _deposits
                    .map((row) => DataRow(cells: [
                          DataCell(Text(_formatDate(row.datePaiement))),
                          DataCell(Text(row.libelle ?? '-')),
                          DataCell(Text(row.sourceLabel ?? '-')),
                          DataCell(Text(_numFormat.format(row.montant ?? 0))),
                          DataCell(
                              Text(row.monnaieSigle ?? row.monnaieNom ?? '-')),
                          DataCell(Text(row.agent ?? '-')),
                          DataCell(Text(row.observation ?? '-')),
                        ]))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}
