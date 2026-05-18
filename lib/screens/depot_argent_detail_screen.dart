import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/app_database.dart';
import '../models/depot_argent.dart';

class DepotArgentDetailScreen extends StatefulWidget {
  final String monnaieUuid;
  final String monnaieLabel;

  const DepotArgentDetailScreen({
    super.key,
    required this.monnaieUuid,
    required this.monnaieLabel,
  });

  @override
  State<DepotArgentDetailScreen> createState() =>
      _DepotArgentDetailScreenState();
}

class _DepotArgentDetailScreenState extends State<DepotArgentDetailScreen> {
  bool _loading = true;
  List<DepotArgentRecord> _records = [];
  double _total = 0;
  final _dateFmt = DateFormat('dd/MM/yyyy');
  final _numFmt = NumberFormat('#,##0.00', 'fr_FR');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final records = await AppDatabase.instance.getDepotArgentRecords(limit: null);
    if (!mounted) return;
    final filtered =
        records.where((r) => r.monnaieUuid == widget.monnaieUuid).toList();
    final total =
        filtered.fold<double>(0, (sum, r) => sum + (r.montant ?? 0));
    setState(() {
      _records = filtered;
      _total = total;
      _loading = false;
    });
  }

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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        title: Text('Dépôts · ${widget.monnaieLabel}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualiser',
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildTotalBanner(),
                Expanded(
                  child: _records.isEmpty
                      ? _buildEmpty()
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _records.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) => _buildCard(_records[i]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildTotalBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet_rounded,
              color: Colors.white70, size: 20),
          const SizedBox(width: 10),
          Text(
            'Total : ${_numFmt.format(_total)} ${widget.monnaieLabel}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          Text(
            '${_records.length} dépôt${_records.length > 1 ? "s" : ""}',
            style:
                const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_rounded,
              size: 56, color: Colors.grey.withAlpha(160)),
          const SizedBox(height: 12),
          const Text('Aucun dépôt trouvé.',
              style: TextStyle(fontSize: 15, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildCard(DepotArgentRecord r) {
    return Card(
      elevation: 1,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_downward_rounded,
                  color: Color(0xFF1D4ED8), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.libelle ?? '(sans libellé)',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  if (r.sourceLabel?.isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Text(r.sourceLabel!,
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ],
                  if (r.agent?.isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Text('Agent : ${r.agent}',
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ],
                  const SizedBox(height: 2),
                  Text(_fmtDate(r.datePaiement),
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _numFmt.format(r.montant ?? 0),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Color(0xFF1D4ED8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
