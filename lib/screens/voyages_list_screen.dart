import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/app_database.dart';
import '../models/voyage.dart';

class VoyagesListScreen extends StatefulWidget {
  const VoyagesListScreen({super.key});

  @override
  State<VoyagesListScreen> createState() => _VoyagesListScreenState();
}

class _VoyagesListScreenState extends State<VoyagesListScreen> {
  bool _loading = true;
  List<Voyage> _voyages = [];
  String _search = '';
  final _searchCtrl = TextEditingController();
  final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final voyages = await AppDatabase.instance.getAllVoyages();
    if (!mounted) return;
    setState(() {
      _voyages = voyages;
      _loading = false;
    });
  }

  List<Voyage> get _filtered {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _voyages;
    return _voyages.where((v) {
      return (v.numeroVoyage ?? '').toLowerCase().contains(q) ||
          (v.lieuDepart ?? '').toLowerCase().contains(q) ||
          (v.lieuDestination ?? '').toLowerCase().contains(q) ||
          (v.statut ?? '').toLowerCase().contains(q);
    }).toList();
  }

  String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    try {
      return _dateFmt.format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  Color _statutColor(String? s) {
    return switch (s?.toLowerCase()) {
      'en cours' => const Color(0xFF10B981),
      'en attente' => const Color(0xFFF59E0B),
      'terminé' => const Color(0xFF6B7280),
      'annulé' => const Color(0xFFEF4444),
      _ => const Color(0xFF9CA3AF),
    };
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        title: const Text('Voyages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualiser',
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Rechercher...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _search = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                    ? _buildEmpty()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: list.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, i) => _buildCard(list[i]),
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
          Icon(Icons.local_shipping_outlined,
              size: 56, color: Colors.grey.withAlpha(160)),
          const SizedBox(height: 12),
          const Text('Aucun voyage trouvé.',
              style: TextStyle(fontSize: 15, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildCard(Voyage v) {
    final sColor = _statutColor(v.statut);
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
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.local_shipping_rounded,
                  color: Color(0xFF10B981), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    v.numeroVoyage ?? '(sans numéro)',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 13, color: Colors.black45),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          [v.lieuDepart, v.lieuDestination]
                              .where((s) => s?.isNotEmpty == true)
                              .join(' → '),
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black54),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 12, color: Colors.black38),
                      const SizedBox(width: 3),
                      Text(
                        _fmtDate(v.dateVoyage),
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black45),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (v.statut != null)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: sColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sColor.withAlpha(80)),
                ),
                child: Text(
                  v.statut!,
                  style: TextStyle(
                    fontSize: 12,
                    color: sColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
