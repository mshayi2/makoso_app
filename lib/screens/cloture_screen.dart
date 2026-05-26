import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/app_database.dart';
import '../models/monnaie.dart';
import '../models/solde.dart';
import 'main_screen.dart' show AppCompany;

class ClotureScreen extends StatefulWidget {
  final AppCompany company;

  const ClotureScreen({super.key, required this.company});

  @override
  State<ClotureScreen> createState() => _ClotureScreenState();
}

class _ClotureScreenState extends State<ClotureScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  List<Solde> _soldes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final soldes = await AppDatabase.instance.getAllSoldes();
    if (!mounted) return;
    setState(() {
      _soldes = soldes;
      _isLoading = false;
    });
  }

  // ── Cloture ─────────────────────────────────────────────────────────────

  Future<void> _cloturer() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la clôture'),
        content: const Text(
          'Cette opération va calculer et enregistrer le solde de clôture '
          'pour chaque monnaie et chaque compagnie.\n\nContinuer ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clôturer'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      await AppDatabase.instance.calculerEtInsererSoldes();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clôture enregistrée avec succès.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Saisie manuelle ──────────────────────────────────────────────────────

  Future<void> _showSaisieManuelleDialog() async {
    final monnaies = await AppDatabase.instance.getAllMonnaies();
    if (!mounted) return;

    final formKey = GlobalKey<FormState>();
    String? selectedMonnaieUuid;
    String? selectedCompany;
    final montantCtrl = TextEditingController();
    final dateCtrl = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    String? errorMsg;

    final companies = ['MAKOSO Services', 'MARINA Trans'];

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Saisie manuelle du solde'),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Company
                  DropdownButtonFormField<String>(
                    value: selectedCompany,
                    decoration: const InputDecoration(
                      labelText: 'Compagnie',
                      border: OutlineInputBorder(),
                    ),
                    items: companies
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => selectedCompany = v),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Champ requis' : null,
                  ),
                  const SizedBox(height: 12),
                  // Monnaie
                  DropdownButtonFormField<String>(
                    value: selectedMonnaieUuid,
                    decoration: const InputDecoration(
                      labelText: 'Monnaie',
                      border: OutlineInputBorder(),
                    ),
                    items: monnaies
                        .map((m) => DropdownMenuItem(
                              value: m.uuid,
                              child: Text(m.label),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => selectedMonnaieUuid = v),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Champ requis' : null,
                  ),
                  const SizedBox(height: 12),
                  // Montant
                  TextFormField(
                    controller: montantCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Montant',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Champ requis';
                      if (double.tryParse(v.replaceAll(',', '.')) == null) {
                        return 'Nombre invalide';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  // Date de clôture
                  TextFormField(
                    controller: dateCtrl,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Date de clôture',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.tryParse(dateCtrl.text) ??
                            DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          dateCtrl.text =
                              DateFormat('yyyy-MM-dd').format(picked);
                        });
                      }
                    },
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Champ requis' : null,
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 8),
                    Text(errorMsg!,
                        style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  await AppDatabase.instance.createSoldeManuel(
                    monnaieUuid: selectedMonnaieUuid!,
                    montant: double.parse(
                        montantCtrl.text.replaceAll(',', '.')),
                    dateCloture: dateCtrl.text,
                    nomCompany: selectedCompany!,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _load();
                } catch (e) {
                  setDialogState(() => errorMsg = 'Erreur : $e');
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );

    montantCtrl.dispose();
    dateCtrl.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Groupe les soldes par company, puis retourne la dernière entrée par
  /// (company, monnaie) pour l'affichage de la grille.
  Map<String, List<Solde>> _groupByCompany() {
    final map = <String, List<Solde>>{};
    for (final s in _soldes) {
      final key = s.nomCompany ?? '—';
      map.putIfAbsent(key, () => []).add(s);
    }
    return map;
  }

  String _formatMontant(double? v) {
    if (v == null) return '—';
    final fmt = NumberFormat('#,##0.##', 'fr_FR');
    return fmt.format(v);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.company == AppCompany.makoso
        ? const Color(0xFF1A237E)
        : const Color(0xFF00695C);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clôture & Soldes'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: primaryColor,
              ),
              icon: const Icon(Icons.edit_note),
              label: const Text('Saisie manuelle'),
              onPressed: _isSaving ? null : _showSaisieManuelleDialog,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                foregroundColor: Colors.white,
              ),
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.lock_outline),
              label: const Text('Clôturer'),
              onPressed: _isSaving ? null : _cloturer,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(primaryColor),
    );
  }

  Widget _buildBody(Color primaryColor) {
    if (_soldes.isEmpty) {
      return const Center(
        child: Text(
          'Aucun solde enregistré.\nUtilisez "Clôturer" ou "Saisie manuelle" pour ajouter des soldes.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final grouped = _groupByCompany();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: grouped.entries.map((entry) {
          final company = entry.key;
          final soldes = entry.value;

          // Garde uniquement le dernier solde par monnaie (le plus récent)
          final Map<String, Solde> latestByMonnaie = {};
          for (final s in soldes) {
            final key = s.monnaieUuid ?? '';
            if (!latestByMonnaie.containsKey(key)) {
              latestByMonnaie[key] = s; // déjà trié DESC
            }
          }
          final latest = latestByMonnaie.values.toList();

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Company header
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(8)),
                  ),
                  child: Text(
                    company,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                // Table header
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                          flex: 3,
                          child: Text('Monnaie',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12))),
                      Expanded(
                          flex: 3,
                          child: Text('Solde',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12))),
                      Expanded(
                          flex: 3,
                          child: Text('Date clôture',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12))),
                      SizedBox(width: 32),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Rows
                ...latest.map((s) => _SoldeRow(
                      solde: s,
                      formatMontant: _formatMontant,
                      onDelete: () async {
                        await AppDatabase.instance.deleteSolde(s.uuid);
                        await _load();
                      },
                    )),
                // Totaux par monnaie
                if (latest.length > 1) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Expanded(
                          flex: 3,
                          child: Text('TOTAL',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: latest.map((s) {
                              return Text(
                                '${_formatMontant(s.montant)} ${s.monnaieSigle ?? s.monnaieNom ?? ''}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12),
                              );
                            }).toList(),
                          ),
                        ),
                        const Expanded(flex: 3, child: SizedBox()),
                        const SizedBox(width: 32),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SoldeRow extends StatelessWidget {
  final Solde solde;
  final String Function(double?) formatMontant;
  final VoidCallback onDelete;

  const _SoldeRow({
    required this.solde,
    required this.formatMontant,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(solde.monnaieLabel,
                style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              formatMontant(solde.montant),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: (solde.montant ?? 0) < 0
                    ? Colors.red.shade700
                    : Colors.green.shade700,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              solde.dateCloture ?? '—',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 18, color: Colors.redAccent),
            tooltip: 'Supprimer',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Confirmer la suppression'),
                  content: const Text(
                      'Voulez-vous supprimer ce solde ?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Non'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Supprimer'),
                    ),
                  ],
                ),
              );
              if (confirm == true) onDelete();
            },
          ),
        ],
      ),
    );
  }
}
