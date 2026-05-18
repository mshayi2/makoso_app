import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/app_database.dart';
import '../models/depense.dart';

class DepensesEnAttenteScreen extends StatefulWidget {
  const DepensesEnAttenteScreen({super.key});

  @override
  State<DepensesEnAttenteScreen> createState() =>
      _DepensesEnAttenteScreenState();
}

class _DepensesEnAttenteScreenState extends State<DepensesEnAttenteScreen> {
  bool _loading = true;
  List<DepenseRecord> _depenses = [];
  final _dateFmt = DateFormat('dd/MM/yyyy');
  final _numFmt = NumberFormat('#,##0.00', 'fr_FR');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final records = await AppDatabase.instance.getDepenses(
      valideOnly: false,
      limit: null,
    );
    if (!mounted) return;
    setState(() {
      _depenses = records.where((d) => (d.valide ?? 0) == 0).toList();
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

  String _fmtMontant(DepenseRecord d) {
    if (d.montant == null) return '-';
    final sigle = d.monnaieSigle?.trim().isNotEmpty == true
        ? d.monnaieSigle!
        : (d.monnaieNom ?? '');
    return '${_numFmt.format(d.montant!)} $sigle'.trim();
  }

  Future<void> _valider(DepenseRecord d) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Valider la dépense'),
        content: Text(
          'Valider "${d.libelle ?? d.uuid}" (${_fmtMontant(d)}) ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final today = DateTime.now();
    final dateValidation =
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    await AppDatabase.instance.updateDepense(
      uuid: d.uuid,
      monnaieUuid: d.monnaieUuid!,
      montant: d.montant!,
      libelle: d.libelle ?? '',
      observation: d.observation,
      date: d.date,
      valide: 1,
      dateValidation: dateValidation,
      validateurUuid: null,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dépense validée.')),
    );
    _load();
  }

  Future<void> _rejeter(DepenseRecord d) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rejeter la dépense'),
        content: Text(
          'Supprimer définitivement "${d.libelle ?? d.uuid}" (${_fmtMontant(d)}) ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await AppDatabase.instance.deleteDepense(d.uuid);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dépense rejetée.')),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        title: const Text('Dépenses en attente'),
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
          : _depenses.isEmpty
              ? _buildEmpty()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _depenses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _buildCard(_depenses[i]),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded,
              size: 64, color: const Color(0xFF16A34A).withAlpha(180)),
          const SizedBox(height: 16),
          const Text(
            'Aucune dépense en attente',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(DepenseRecord d) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.hourglass_top_rounded,
                  color: Color(0xFFD97706), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.libelle ?? '(sans libellé)',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _fmtMontant(d),
                    style: const TextStyle(
                        color: Color(0xFF1D4ED8),
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _fmtDate(d.date),
                    style: TextStyle(
                        fontSize: 12,
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  if (d.observation?.isNotEmpty == true) ...[
                    const SizedBox(height: 3),
                    Text(
                      d.observation!,
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF16A34A), size: 28),
                  tooltip: 'Valider',
                  onPressed: () => _valider(d),
                ),
                IconButton(
                  icon: const Icon(Icons.cancel_rounded,
                      color: Color(0xFFDC2626), size: 28),
                  tooltip: 'Rejeter',
                  onPressed: () => _rejeter(d),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
