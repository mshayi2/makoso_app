import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/app_database.dart';
import '../models/depense.dart';

class DepensesDetailScreen extends StatefulWidget {
  final String monnaieUuid;
  final String monnaieLabel;

  const DepensesDetailScreen({
    super.key,
    required this.monnaieUuid,
    required this.monnaieLabel,
  });

  @override
  State<DepensesDetailScreen> createState() => _DepensesDetailScreenState();
}

class _DepensesDetailScreenState extends State<DepensesDetailScreen> {
  bool _loading = true;
  List<DepenseRecord> _records = [];
  double _totalValidees = 0;
  double _totalEnAttente = 0;
  final _dateFmt = DateFormat('dd/MM/yyyy');
  final _numFmt = NumberFormat('#,##0.00', 'fr_FR');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final records =
        await AppDatabase.instance.getDepenses(limit: null);
    if (!mounted) return;
    final filtered =
        records.where((r) => r.monnaieUuid == widget.monnaieUuid).toList();
    final totalV = filtered
        .where((r) => (r.valide ?? 0) > 0)
        .fold<double>(0, (s, r) => s + (r.montant ?? 0));
    final totalP = filtered
        .where((r) => (r.valide ?? 0) == 0)
        .fold<double>(0, (s, r) => s + (r.montant ?? 0));
    setState(() {
      _records = filtered;
      _totalValidees = totalV;
      _totalEnAttente = totalP;
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
        title: Text('Dépenses · ${widget.monnaieLabel}'),
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
                _buildSummaryBanner(),
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

  Widget _buildSummaryBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: const Color(0xFF1E3A5F),
      child: Row(
        children: [
          Expanded(
            child: _BannerStat(
              label: 'Validées',
              value: '${_numFmt.format(_totalValidees)} ${widget.monnaieLabel}',
              color: const Color(0xFF4ADE80),
            ),
          ),
          Container(width: 1, height: 36, color: Colors.white24),
          Expanded(
            child: _BannerStat(
              label: 'En attente',
              value:
                  '${_numFmt.format(_totalEnAttente)} ${widget.monnaieLabel}',
              color: const Color(0xFFFBBF24),
            ),
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
          const Text('Aucune dépense trouvée.',
              style: TextStyle(fontSize: 15, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildCard(DepenseRecord d) {
    final isValidee = (d.valide ?? 0) > 0;
    final statusColor =
        isValidee ? const Color(0xFF16A34A) : const Color(0xFFD97706);
    final statusLabel = isValidee ? 'Validée' : 'En attente';

    return Card(
      elevation: 1,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: statusColor.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isValidee
                    ? Icons.check_circle_outline_rounded
                    : Icons.hourglass_top_rounded,
                color: statusColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.libelle ?? '(sans libellé)',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(_fmtDate(d.date),
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black54)),
                  if (d.observation?.isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Text(d.observation!,
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                  if (isValidee && d.validateurNom?.isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Text('Validé par ${d.validateurNom}',
                        style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _numFmt.format(d.montant ?? 0),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                        fontSize: 11,
                        color: statusColor,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _BannerStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 13)),
      ],
    );
  }
}
