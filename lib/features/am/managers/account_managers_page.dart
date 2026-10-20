import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/luxe/tokens.dart';
import '../../../core/widgets/luxe/luxe_widgets.dart';
import '../../../models/manager.dart';
import '../../../providers/manager_provider.dart';
import 'package:shadapp_client/generated/app_localizations.dart';

class AccountManagersPage extends StatefulWidget {
  // Optional so this screen can be pumped in a widget test with a mocked
  // ManagerProvider instead of hitting the network — same pattern as
  // LoginPage.authProvider / CreateClientPage.clientProvider.
  final ManagerProvider? managerProvider;
  /// Shown as a tab inside the super admin dashboard (no app bar there).
  final bool embedded;
  const AccountManagersPage({super.key, this.managerProvider, this.embedded = false});

  @override
  State<AccountManagersPage> createState() => _AccountManagersPageState();
}

class _AccountManagersPageState extends State<AccountManagersPage> {
  late final ManagerProvider _managerProvider = widget.managerProvider ?? ManagerProvider();
  List<Manager> _managers = [];
  bool _loading = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _errorMsg = null; });
    await _managerProvider.fetchManagers();
    if (_managerProvider.error != null) {
      if (!mounted) return;
      _errorMsg = AppLocalizations.of(context)!.accountManagersFailedToLoad;
    } else {
      _managers = _managerProvider.managers;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openCreate() async {
    final result = await context.push<bool>('/am/managers/create');
    if (result == true) _load();
  }

  Future<void> _toggleApprove(Manager m, bool value) async {
    try {
      await _managerProvider.updateManager(m.id, {'can_approve_contracts': value});
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
    }
  }

  Future<void> _deactivate(Manager m) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l10n.amDeactivateConfirm(m.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.amDeactivate, style: const TextStyle(color: Lx.danger))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _managerProvider.deactivateManager(m.id);
      await _load();
    } catch (e) {
      // e.g. "this manager still has N clients — move them first".
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final h1 = Lx.display(context, size: 28).copyWith(height: 1.2);
    final body = _loading
        ? const Center(child: CircularProgressIndicator(color: Lx.crimsonInk))
        : _errorMsg != null
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_errorMsg!, style: Lx.text(context, size: 14, color: Lx.danger)),
                  const SizedBox(height: 12),
                  LuxeFormTheme(child: ElevatedButton(onPressed: _load, child: Text(l10n.retry))),
                ]),
              )
            : RefreshIndicator(
                onRefresh: _load,
                color: Lx.crimsonInk,
                child: ListView(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 2, 16, 18),
                  children: [
                    // Mockup pManagers: head('Team', 'Account managers').
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 6, 0, 14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(l10n.teamEyebrow.toUpperCase(), style: Lx.text(context, size: 10.5, color: Lx.faint).copyWith(letterSpacing: 2.73)),
                        const SizedBox(height: 6),
                        Text.rich(
                          TextSpan(children: [
                            TextSpan(text: l10n.accountManagers_title),
                            TextSpan(text: '.', style: h1.copyWith(color: Lx.crimsonInk, fontStyle: FontStyle.normal)),
                          ]),
                          key: const ValueKey('lx-page-title'),
                          style: h1,
                        ),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: LuxeButton(
                          key: const ValueKey('managers-new'),
                          label: l10n.amNewManager,
                          lxIcon: 'plus',
                          kind: LuxeButtonKind.primary,
                          size: LuxeButtonSize.lg,
                          onPressed: _openCreate,
                        ),
                      ),
                    ),
                    if (_managers.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(children: [
                          Text(l10n.accountManagersEmpty, style: Lx.display(context, size: 20)),
                          const SizedBox(height: 8),
                          Text(l10n.accountManagersAddHint, textAlign: TextAlign.center, style: Lx.text(context, size: 13.5, color: Lx.muted)),
                        ]),
                      )
                    else
                      ..._managers.map(_managerCard),
                  ],
                ),
              );
    if (widget.embedded) return body;
    return Scaffold(
      backgroundColor: Lx.page,
      appBar: AppBar(
        backgroundColor: Lx.page,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Lx.muted),
        title: const SizedBox.shrink(),
      ),
      body: body,
    );
  }

  /// Mockup pManagers card: `.mgr` (av 32, name serif 16, email), "N assigned
  /// clients" on the side; `.opt` "Can approve contracts" + `.sw2`; then
  /// Edit / Deactivate (quiet danger).
  Widget _managerCard(Manager m) {
    final l10n = AppLocalizations.of(context)!;
    return LuxeCard(
      key: ValueKey('manager-card-${m.id}'),
      onTap: () => context.push('/am/managers/${m.id}/detail'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          LuxeAvatar(initial: m.name.isNotEmpty ? m.name[0].toUpperCase() : '?'),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.name, style: Lx.display(context, size: 16)),
              if ((m.email ?? '').isNotEmpty)
                Text(m.email!, style: Lx.text(context, size: 12.5, color: Lx.muted)),
            ]),
          ),
          const SizedBox(width: 8),
          Text(l10n.amAssignedClients(m.managedClientsCount), style: Lx.text(context, size: 12.5, color: Lx.muted)),
        ]),
        const SizedBox(height: 10),
        LuxeOptRow(
          key: ValueKey('manager-approve-${m.id}'),
          label: l10n.amCanApproveContracts,
          trailing: LuxeToggle(value: m.canApproveContracts, onChanged: (v) => _toggleApprove(m, v)),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Row(children: [
            Expanded(
              child: LuxeButton(
                key: ValueKey('manager-edit-${m.id}'),
                label: l10n.edit,
                size: LuxeButtonSize.sm,
                onPressed: () async {
                  final result = await context.push<bool>('/am/managers/${m.id}/edit');
                  if (result == true) _load();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: LuxeButton(
                key: ValueKey('manager-deactivate-${m.id}'),
                label: l10n.amDeactivate,
                size: LuxeButtonSize.sm,
                kind: LuxeButtonKind.danger,
                onPressed: () => _deactivate(m),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
