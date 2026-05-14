import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../models/utilisateur.dart';
import 'camions_screen.dart';
import 'chauffeurs_convoyeurs_screen.dart';
import 'clients_screen.dart';
import 'depot_argent_screen.dart';
import 'depenses_screen.dart';
import 'dossiers_screen.dart';
import 'login_screen.dart';
import 'utilisateurs_screen.dart';
import 'voyages_screen.dart';

enum _NavOption {
  tableauDeBord,
  depotArgent,
  depenses,
  dossiers,
  voyages,
  clients,
  chauffeursConvoyeurs,
  camions,
  utilisateurs,
}

class _NavItem {
  final _NavOption option;
  final IconData icon;
  final String label;
  const _NavItem(this.option, this.icon, this.label);
}

const _navItems = [
  _NavItem(_NavOption.tableauDeBord, Icons.dashboard_outlined, 'Tableau de bord'),
  _NavItem(_NavOption.depotArgent, Icons.account_balance_wallet_outlined, 'Dépôt Argent'),
  _NavItem(_NavOption.depenses, Icons.money_off_outlined, 'Dépenses'),
  _NavItem(_NavOption.dossiers, Icons.folder_outlined, 'Dossiers'),
  _NavItem(_NavOption.voyages, Icons.local_shipping_outlined, 'Voyages'),
  _NavItem(_NavOption.clients, Icons.people_outline, 'Clients'),
  _NavItem(_NavOption.chauffeursConvoyeurs, Icons.drive_eta_outlined, 'Chauffeurs / Convoyeurs'),
  _NavItem(_NavOption.camions, Icons.airport_shuttle_outlined, 'Camions'),
  _NavItem(_NavOption.utilisateurs, Icons.manage_accounts_outlined, 'Utilisateurs'),
];

class MainScreen extends StatefulWidget {
  final Utilisateur user;
  final bool showDefaultPasswordWarning;

  const MainScreen({
    super.key,
    required this.user,
    this.showDefaultPasswordWarning = false,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late _NavOption _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.user.role == 'caissier'
        ? _NavOption.depotArgent
        : _NavOption.tableauDeBord;
    if (widget.showDefaultPasswordWarning) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showDefaultPasswordAlert();
      });
    }
  }

  void _showDefaultPasswordAlert() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Mot de passe par défaut'),
          ],
        ),
        content: const Text(
          'Vous utilisez le mot de passe par défaut (12345).\n\n'
          'Pour votre sécurité, veuillez personnaliser votre mot de passe '
          'en cliquant sur l\'icône 🔑 dans le panneau de gauche.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK, compris'),
          ),
        ],
      ),
    );
  }

  // ── Change password dialog ─────────────────────────────────────────────────
  Future<void> _showChangePasswordDialog() async {
    final formKey = GlobalKey<FormState>();
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? errorMsg;
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Modifier le mot de passe'),
          content: SizedBox(
            width: 360,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: currentCtrl,
                    obscureText: obscureCurrent,
                    decoration: InputDecoration(
                      labelText: 'Mot de passe actuel',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(obscureCurrent
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setDialogState(() => obscureCurrent = !obscureCurrent),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Champ requis' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: newCtrl,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'Nouveau mot de passe',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                            obscureNew ? Icons.visibility_off : Icons.visibility),
                        onPressed: () =>
                            setDialogState(() => obscureNew = !obscureNew),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Champ requis';
                      if (v.length < 6) return 'Minimum 6 caractères';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmCtrl,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirmer le nouveau mot de passe',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirm
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setDialogState(() => obscureConfirm = !obscureConfirm),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Champ requis';
                      if (v != newCtrl.text) {
                        return 'Les mots de passe ne correspondent pas';
                      }
                      return null;
                    },
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 10),
                    Text(errorMsg!, style: const TextStyle(color: Colors.red)),
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
                final ok = await AppDatabase.instance.verifyUserPassword(
                  widget.user.nomUtilisateur,
                  currentCtrl.text,
                );
                if (!ok) {
                  setDialogState(
                      () => errorMsg = 'Mot de passe actuel incorrect.');
                  return;
                }
                await AppDatabase.instance
                    .updatePassword(widget.user.uuid, newCtrl.text);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Mot de passe modifié avec succès.')),
                  );
                }
              },
              child: const Text('Confirmer'),
            ),
          ],
        ),
      ),
    );

    currentCtrl.dispose();
    newCtrl.dispose();
    confirmCtrl.dispose();
  }

  // ── Logout ─────────────────────────────────────────────────────────────────
  void _logout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    const sidebarBg = Color(0xFF1A237E);

    return Scaffold(
      body: Row(
        children: [
          // ── Left panel ────────────────────────────────────────────────────
          Expanded(
            flex: 27,
            child: Container(
              color: sidebarBg,
              child: Column(
                children: [
                  // User header
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 18),
                    decoration: const BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: Colors.white24)),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Colors.white24,
                          child:
                              Icon(Icons.person, color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.user.nomComplet?.isNotEmpty == true
                                ? widget.user.nomComplet!
                                : widget.user.nomUtilisateur,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.lock_reset,
                              color: Colors.white70),
                          tooltip: 'Modifier le mot de passe',
                          onPressed: _showChangePasswordDialog,
                        ),
                      ],
                    ),
                  ),

                  // Navigation items
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: _navItems.where((item) {
                        final role = widget.user.role;
                        if (role == 'caissier') {
                          return item.option == _NavOption.depotArgent ||
                              item.option == _NavOption.depenses;
                        }
                        if (item.option == _NavOption.utilisateurs) {
                          return role == 'admin';
                        }
                        return true;
                      }).map((item) {
                        final isSelected = _selected == item.option;
                        return Container(
                          color: isSelected
                              ? Colors.white24
                              : Colors.transparent,
                          child: ListTile(
                            leading: Icon(
                              item.icon,
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white70,
                            ),
                            title: Text(
                              item.label,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white70,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                            onTap: () =>
                                setState(() => _selected = item.option),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // Logout
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(
                          top: BorderSide(color: Colors.white24)),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.logout,
                          color: Colors.white70),
                      title: const Text(
                        'Déconnexion',
                        style: TextStyle(color: Colors.white70),
                      ),
                      onTap: _logout,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Right panel ───────────────────────────────────────────────────
          Expanded(
            flex: 73,
            child: IndexedStack(
              index: _NavOption.values.indexOf(_selected),
              children: _NavOption.values.map((option) {
                return switch (option) {
                  _NavOption.depotArgent => DepotArgentScreen(user: widget.user),
                  _NavOption.depenses => DepensesScreen(user: widget.user),
                  _NavOption.utilisateurs => const UtilisateursScreen(),
                  _NavOption.clients => const ClientsScreen(),
                  _NavOption.camions => const CamionsScreen(),
                  _NavOption.chauffeursConvoyeurs => const ChauffeursConvoyeursScreen(),
                  _NavOption.voyages => const VoyagesScreen(),
                  _NavOption.dossiers => const DossiersScreen(),
                  _ => Center(
                      child: Text(
                        _navItems.firstWhere((e) => e.option == option).label,
                        style: const TextStyle(
                            fontSize: 24,
                            color: Colors.black38,
                            fontWeight: FontWeight.w300),
                      ),
                    ),
                };
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

}
