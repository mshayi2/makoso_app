import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../database/app_database.dart';
import '../models/depense.dart';
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

class RapportDepensesMensuelScreen extends StatefulWidget {
  final AppCompany company;

  const RapportDepensesMensuelScreen({super.key, required this.company});

  @override
  State<RapportDepensesMensuelScreen> createState() =>
      _RapportDepensesMensuelScreenState();
}

class _RapportDepensesMensuelScreenState
    extends State<RapportDepensesMensuelScreen> {
  static final _dateFormat = DateFormat('dd/MM/yyyy');
  static final _numFormat = NumberFormat('#,##0.00', 'fr_FR');

  late final List<DateTime> _months;
  late DateTime _selectedMonth;
  bool _loading = true;
  List<DepenseRecord> _expenses = [];

  String get _companyName =>
      widget.company == AppCompany.makoso ? 'MAKOSO Services' : 'MARINA Trans';

  String get _expenseTable => widget.company == AppCompany.makoso
      ? 'depenses_makoso'
      : 'depenses_marina_trans';

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
    // The DB filter is exclusive on fromDate and inclusive on toDate.
    final fromDate = _iso(DateTime(_selectedMonth.year, _selectedMonth.month, 0));
    final toDate = _iso(DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0));
    final expenses = await AppDatabase.instance.getDepenses(
      table: _expenseTable,
      fromDate: fromDate,
      toDate: toDate,
      limit: null,
    );
    if (!mounted) return;
    setState(() {
      _expenses = expenses;
      _loading = false;
    });
  }

  List<MapEntry<String, double>> get _totalsByCurrency {
    final totals = <String, double>{};
    for (final e in _expenses) {
      final currency = e.monnaieSigle?.trim().isNotEmpty == true
          ? e.monnaieSigle!.trim()
          : (e.monnaieNom ?? '-');
      totals[currency] = (totals[currency] ?? 0) + (e.montant ?? 0);
    }
    return totals.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  }

  void _printReport() {
    if (_loading) return;
    final totals = _totalsByCurrency;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Aperçu avant impression')),
          body: PdfPreview(
            build: (_) => RapportPdf.buildDepensesMensuel(
              companyName: _companyName,
              periodeLabel: 'Dépenses – ${_monthLabel(_selectedMonth)}',
              depenses: _expenses,
              totalsByCurrency: totals,
            ),
            pdfFileName: widget.company == AppCompany.makoso
                ? 'depenses_mensuelles_makoso.pdf'
                : 'depenses_mensuelles_marina.pdf',
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
                const Icon(Icons.money_off_outlined,
                    color: Colors.white, size: 30),
                Text(
                  'Dépenses mensuelles – $_companyName',
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
                      _buildTotals(context),
                      const SizedBox(height: 20),
                      _buildExpensesCard(context),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotals(BuildContext context) {
    final totals = _totalsByCurrency;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 1,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total des dépenses – ${_monthLabel(_selectedMonth)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (totals.isEmpty)
              const Text('Aucune dépense pour ce mois.')
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final entry in totals)
                    Chip(
                      avatar: const Icon(Icons.payments_outlined, size: 18),
                      label: Text(
                        '${_numFormat.format(entry.value)} ${entry.key}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpensesCard(BuildContext context) {
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
                Icon(Icons.money_off_outlined,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Dépenses',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                Chip(label: Text('${_expenses.length}')),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_expenses.isEmpty)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: Text('Aucune dépense pour ce mois.')),
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
                  DataColumn(label: Text('Statut')),
                  DataColumn(label: Text('Validateur')),
                  DataColumn(label: Text('Observation')),
                ],
                rows: _expenses
                    .map((row) => DataRow(cells: [
                          DataCell(Text(_formatDate(row.date))),
                          DataCell(Text(row.libelle ?? '-')),
                          DataCell(Text(RapportPdf.depenseReference(row))),
                          DataCell(Text(_numFormat.format(row.montant ?? 0))),
                          DataCell(
                              Text(row.monnaieSigle ?? row.monnaieNom ?? '-')),
                          DataCell(Text(row.validationStatus)),
                          DataCell(Text(row.validateurNom ?? '-')),
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
