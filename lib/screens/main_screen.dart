import 'dart:async';

import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../models/utilisateur.dart';
import '../services/sync_service.dart';
import 'camions_screen.dart';
import 'chauffeurs_convoyeurs_screen.dart';
import 'clients_screen.dart';
import 'depot_argent_screen.dart';
import 'depenses_screen.dart';
import 'dossiers_screen.dart';
import 'login_screen.dart';
import 'tableau_de_bord_screen.dart';
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
  Timer? _syncTimer;
  StreamSubscription<SyncNotification>? _syncSubscription;
  bool _syncInProgress = AppSyncService.instance.isRunning;
  DateTime? _lastSyncCompletedAt = AppSyncService.instance.lastCompletedAt;
  String? _lastSyncError = AppSyncService.instance.lastError;
  int _dataVersion = 0;
  int _pendingManualSyncEvents = 0;
  late final Map<_NavOption, int> _screenVersions;

  @override
  void initState() {
    super.initState();
    _selected = widget.user.role == 'caissier'
        ? _NavOption.depotArgent
        : _NavOption.tableauDeBord;
    _screenVersions = {
      for (final option in _NavOption.values) option: 0,
    };
    _syncSubscription = AppSyncService.instance.notifications.listen(
      _handleSyncNotification,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      if (widget.showDefaultPasswordWarning) {
        _showDefaultPasswordAlert();
      }

      _startBackgroundSync();
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _syncSubscription?.cancel();
    super.dispose();
  }

  void _startBackgroundSync() {
    _syncTimer?.cancel();
    unawaited(_runSynchronization(showFeedback: false));
    _syncTimer = Timer.periodic(const Duration(minutes: 20), (_) {
      unawaited(_runSynchronization(showFeedback: false));
    });
  }

  Future<void> _runSynchronization({required bool showFeedback}) async {
    if (showFeedback) {
      _pendingManualSyncEvents++;
    }

    if (mounted) {
      setState(() {
        _syncInProgress = true;
      });
    }

    final result = await AppSyncService.instance.synchronize();

    if (!mounted) {
      return;
    }

    setState(() {
      _syncInProgress = AppSyncService.instance.isRunning;
      _lastSyncCompletedAt = AppSyncService.instance.lastCompletedAt;
      _lastSyncError = AppSyncService.instance.lastError;
    });

    if (!showFeedback) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? '${result.message} Pull: ${result.pulledCount}, push: ${result.pushedCount}, suppressions: ${result.deletedCount}.'
              : '${result.message} ${result.error ?? ''}'.trim(),
        ),
      ),
    );
  }

  void _handleSyncNotification(SyncNotification notification) {
    if (!mounted) {
      return;
    }

    final isManualEvent = _pendingManualSyncEvents > 0;
    if (isManualEvent) {
      _pendingManualSyncEvents--;
    }

    if (!notification.hasDataChanges) {
      return;
    }

    setState(() {
      _dataVersion++;
      _screenVersions[_selected] = _dataVersion;
    });

    if (isManualEvent) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'De nouvelles données ont été synchronisées. L\'écran courant a été actualisé.',
        ),
      ),
    );
  }

  void _selectOption(_NavOption option) {
    setState(() {
      _selected = option;
      _screenVersions[option] = _dataVersion;
    });
  }

  Key _screenKey(_NavOption option) {
    final version = _screenVersions[option] ?? 0;
    return ValueKey('${option.name}-$version');
  }

  Widget _buildScreen(_NavOption option) {
    final child = switch (option) {
      _NavOption.tableauDeBord => const TableauDeBordScreen(),
      _NavOption.depotArgent => DepotArgentScreen(user: widget.user),
      _NavOption.depenses => DepensesScreen(user: widget.user),
      _NavOption.utilisateurs => const UtilisateursScreen(),
      _NavOption.clients => const ClientsScreen(),
      _NavOption.camions => const CamionsScreen(),
      _NavOption.chauffeursConvoyeurs => const ChauffeursConvoyeursScreen(),
      _NavOption.voyages => const VoyagesScreen(),
      _NavOption.dossiers => const DossiersScreen(),
    };

    return KeyedSubtree(
      key: _screenKey(option),
      child: child,
    );
  }

  String _syncStatusLabel() {
    if (_syncInProgress) {
      return 'Synchronisation en cours...';
    }
    if (_lastSyncCompletedAt != null) {
      final completedAt = _lastSyncCompletedAt!.toLocal();
      final day = completedAt.day.toString().padLeft(2, '0');
      final month = completedAt.month.toString().padLeft(2, '0');
      final hour = completedAt.hour.toString().padLeft(2, '0');
      final minute = completedAt.minute.toString().padLeft(2, '0');
      return 'Dernière synchro: $day/$month à $hour:$minute';
    }
    if (_lastSyncError != null && _lastSyncError!.isNotEmpty) {
      return 'Dernière synchronisation en échec';
    }
    return 'Exécution automatique toutes les 20 minutes';
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
    _syncTimer?.cancel();
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
                            onTap: () => _selectOption(item.option),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // Logout / Sync
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(
                          top: BorderSide(color: Colors.white24)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.logout,
                              color: Colors.white70),
                          title: const Text(
                            'Déconnexion',
                            style: TextStyle(color: Colors.white70),
                          ),
                          onTap: _logout,
                        ),
                        const Divider(height: 1, color: Colors.white24),
                        ListTile(
                          leading: Icon(
                            _syncInProgress ? Icons.sync : Icons.sync_outlined,
                            color: Colors.white70,
                          ),
                          title: Text(
                            _syncInProgress
                                ? 'Synchronisation en cours...'
                                : 'Synchroniser maintenant',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          subtitle: Text(
                            _syncStatusLabel(),
                            style: const TextStyle(color: Colors.white54),
                          ),
                          enabled: !_syncInProgress,
                          onTap: _syncInProgress
                              ? null
                              : () => unawaited(
                                    _runSynchronization(showFeedback: true),
                                  ),
                        ),
                      ],
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
              children: _NavOption.values.map(_buildScreen).toList(),
            ),
          ),
        ],
      ),
    );
  }

}
