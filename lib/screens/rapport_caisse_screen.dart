import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../database/app_database.dart';
import '../models/depense.dart';
import '../models/depot_argent.dart';
import '../services/rapport_pdf.dart';
import '../widgets/horizontal_table_scroller.dart';
import 'main_screen.dart';

class _CashPeriod {
  final String? previousClosingDate;
  final String? closingDate;
  final String label;

  const _CashPeriod({
    required this.previousClosingDate,
    required this.closingDate,
    required this.label,
  });
}

class RapportCaisseScreen extends StatefulWidget {
  final AppCompany company;

  const RapportCaisseScreen({super.key, required this.company});

  @override
  State<RapportCaisseScreen> createState() => _RapportCaisseScreenState();
}

class _RapportCaisseScreenState extends State<RapportCaisseScreen> {
  static final _dateFormat = DateFormat('dd/MM/yyyy');

  bool _loading = true;
  List<_CashPeriod> _periods = [];
  int _selectedPeriod = 0;
  List<DepotArgentRecord> _deposits = [];
  List<DepenseRecord> _expenses = [];

  String get _companyName =>
      widget.company == AppCompany.makoso ? 'MAKOSO Services' : 'MARINA Trans';

  String get _depositTable => widget.company == AppCompany.makoso
      ? 'depot_argent_makoso'
      : 'depot_argent_marina_trans';

  String get _expenseTable => widget.company == AppCompany.makoso
      ? 'depenses_makoso'
      : 'depenses_marina_trans';

  @override
  void initState() {
    super.initState();
    _loadPeriods();
  }

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) return '-';
    try {
      return _dateFormat.format(DateTime.parse(value));
    } catch (_) {
      return value;
    }
  }

  String _nextDay(String value) {
    return DateTime.parse(value)
        .add(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);
  }

  List<_CashPeriod> _buildPeriods(List<String> closingDates) {
    final periods = <_CashPeriod>[];
    final lastClosingDate = closingDates.isEmpty ? null : closingDates.last;
    periods.add(_CashPeriod(
      previousClosingDate: lastClosingDate,
      closingDate: null,
      label: lastClosingDate == null
          ? 'Période en cours (toutes les données)'
          : 'Période en cours (depuis ${_formatDate(_nextDay(lastClosingDate))})',
    ));

    for (var index = closingDates.length - 1; index >= 0; index--) {
      final previous = index > 0 ? closingDates[index - 1] : null;
      final current = closingDates[index];
      periods.add(_CashPeriod(
        previousClosingDate: previous,
        closingDate: current,
        label: 'Clôture du ${_formatDate(current)} '
            '(${previous == null ? 'début' : _formatDate(_nextDay(previous))} – '
            '${_formatDate(current)})',
      ));
    }
    return periods;
  }

  Future<void> _loadPeriods() async {
    final closingDates =
        await AppDatabase.instance.getClotureDatesForCompany(_companyName);
    if (!mounted) return;
    setState(() {
      _periods = _buildPeriods(closingDates);
      _selectedPeriod = 0;
    });
    await _loadData();
  }

  Future<void> _loadData() async {
    if (_periods.isEmpty) return;
    setState(() => _loading = true);
    final period = _periods[_selectedPeriod];
    final results = await Future.wait([
      AppDatabase.instance.getDepotArgentRecords(
        table: _depositTable,
        fromDate: period.previousClosingDate,
        toDate: period.closingDate,
        limit: null,
      ),
      AppDatabase.instance.getDepenses(
        table: _expenseTable,
        fromDate: period.previousClosingDate,
        toDate: period.closingDate,
        limit: null,
      ),
    ]);
    if (!mounted) return;
    setState(() {
      _deposits = results[0] as List<DepotArgentRecord>;
      _expenses = results[1] as List<DepenseRecord>;
      _loading = false;
    });
  }

  void _printReport() {
    if (_periods.isEmpty || _loading) return;
    final period = _periods[_selectedPeriod];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Aperçu avant impression')),
          body: PdfPreview(
            build: (_) => RapportPdf.buildCashMovements(
              companyName: _companyName,
              periodeLabel: period.label,
              depots: _deposits,
              depenses: _expenses,
            ),
            pdfFileName: widget.company == AppCompany.makoso
                ? 'rapport_caisse_makoso.pdf'
                : 'rapport_caisse_marina.pdf',
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
                const Icon(Icons.receipt_long_rounded,
                    color: Colors.white, size: 30),
                Text(
                  'Rapport de caisse – $_companyName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(
                  width: 360,
                  child: DropdownButtonFormField<int>(
                    value: _periods.isEmpty ? null : _selectedPeriod,
                    dropdownColor: Colors.white,
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (var index = 0; index < _periods.length; index++)
                        DropdownMenuItem(
                          value: index,
                          child: Text(_periods[index].label,
                              overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: _loading
                        ? null
                        : (index) async {
                            if (index == null) return;
                            setState(() => _selectedPeriod = index);
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
                      _ReportSection(
                        title: "Dépôts d'argent",
                        icon: Icons.account_balance_wallet_outlined,
                        count: _deposits.length,
                        child: _buildDepositTable(),
                      ),
                      const SizedBox(height: 20),
                      _ReportSection(
                        title: 'Dépenses',
                        icon: Icons.money_off_outlined,
                        count: _expenses.length,
                        child: _buildExpenseTable(),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepositTable() {
    if (_deposits.isEmpty) {
      return const _EmptyReport(message: 'Aucun dépôt pour cette période.');
    }
    return HorizontalTableScroller(
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
                  DataCell(Text(row.montant?.toStringAsFixed(2) ?? '-')),
                  DataCell(Text(row.monnaieSigle ?? row.monnaieNom ?? '-')),
                  DataCell(Text(row.agent ?? '-')),
                  DataCell(Text(row.observation ?? '-')),
                ]))
            .toList(),
      ),
    );
  }

  Widget _buildExpenseTable() {
    if (_expenses.isEmpty) {
      return const _EmptyReport(message: 'Aucune dépense pour cette période.');
    }
    return HorizontalTableScroller(
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Libellé')),
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
                  DataCell(Text(row.montant?.toStringAsFixed(2) ?? '-')),
                  DataCell(Text(row.monnaieSigle ?? row.monnaieNom ?? '-')),
                  DataCell(Text(row.validationStatus)),
                  DataCell(Text(row.validateurNom ?? '-')),
                  DataCell(Text(row.observation ?? '-')),
                ]))
            .toList(),
      ),
    );
  }
}

class _ReportSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final int count;
  final Widget child;

  const _ReportSection({
    required this.title,
    required this.icon,
    required this.count,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
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
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                Chip(label: Text('$count')),
              ],
            ),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }
}

class _EmptyReport extends StatelessWidget {
  final String message;

  const _EmptyReport({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Center(child: Text(message)),
    );
  }
}