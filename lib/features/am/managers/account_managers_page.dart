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
  const AccountManagersPage({super.key, this.managerProvider});

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final newBtn = SizedBox(
      width: double.infinity,
      child: LuxeButton(
        key: const ValueKey('managers-new'),
        label: l10n.accountManagersAddButton,
        lxIcon: 'plus',
        kind: LuxeButtonKind.primary,
        size: LuxeButtonSize.lg,
        onPressed: _openCreate,
      ),
    );
    return Scaffold(
      backgroundColor: Lx.page,
      appBar: AppBar(
        backgroundColor: Lx.page,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Lx.muted),
        title: const SizedBox.shrink(),
      ),
      body: _loading
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
                    padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 28),
                    children: [
                      LuxePageTitle(l10n.amManageManagers),
                      newBtn,
                      const SizedBox(height: 12),
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
                ),
    );
  }

  Widget _managerCard(Manager m) {
    final l10n = AppLocalizations.of(context)!;
    final phone = m.phone;
    return LuxeCard(
      key: ValueKey('manager-card-${m.id}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          LuxeAvatar(initial: m.name.isNotEmpty ? m.name[0].toUpperCase() : '?', size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.name, style: Lx.display(context, size: 16)),
              if ((m.email ?? '').isNotEmpty)
                Text(m.email!, style: Lx.text(context, size: 12, color: Lx.muted)),
              if (phone != null && phone.isNotEmpty)
                Directionality(textDirection: TextDirection.ltr, child: Text(phone, style: Lx.text(context, size: 12, color: Lx.faint))),
            ]),
          ),
          Text(l10n.accountManagersClientCount(m.managedClientsCount), style: Lx.text(context, size: 12, color: Lx.muted)),
        ]),
        if (m.dateOfBirth != null && m.dateOfBirth!.length >= 10)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(m.dateOfBirth!.substring(0, 10), style: Lx.text(context, size: 12, color: Lx.faint)),
          ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: LuxeButton(
            key: ValueKey('manager-edit-${m.id}'),
            label: l10n.edit,
            size: LuxeButtonSize.sm,
            kind: LuxeButtonKind.outline,
            onPressed: () async {
              final result = await context.push<bool>('/am/managers/${m.id}/edit');
              if (result == true) _load();
            },
          ),
        ),
      ]),
    );
  }
}
