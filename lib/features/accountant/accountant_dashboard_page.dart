import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/api_client.dart';
import '../../core/app_log.dart';
import '../../core/locale_provider.dart';
import '../../core/luxe/tokens.dart';
import '../../core/widgets/luxe/luxe_widgets.dart';
import '../../providers/auth_provider.dart';
import '../am/finance/finance_page.dart';

/// The accountant's home (ACCOUNTANT_ROLE_PLAN.md): company-wide payments with
/// approve / reject, and from a payment the client's payments and contracts.
/// Nothing else — the backend (restrict.roles) denies every other route.
class AccountantDashboardPage extends StatefulWidget {
  final ApiClient? api;
  // Lets widget tests suppress the 60 s notification poll.
  final bool enablePolling;
  const AccountantDashboardPage({super.key, this.api, this.enablePolling = true});

  @override
  State<AccountantDashboardPage> createState() => _AccountantDashboardPageState();
}

class _AccountantDashboardPageState extends State<AccountantDashboardPage> {
  late final ApiClient _api = widget.api ?? ApiClient();
  int _unread = 0;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadUnread();
    if (widget.enablePolling) {
      _pollTimer = Timer.periodic(const Duration(seconds: 60), (_) => _loadUnread());
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUnread() async {
    try {
      final res = await _api.get('/notifications');
      if (mounted) setState(() => _unread = int.tryParse(res['unread_count']?.toString() ?? '') ?? 0);
    } catch (e, s) {
      AppLog.error('accountant_dashboard._loadUnread', e, s);
    }
  }

  String _avatarInitial() {
    final n = (_api.userName ?? '').trim();
    return n.isEmpty ? '?' : n.substring(0, 1).toUpperCase();
  }

  Future<void> _logout() async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.logout),
        content: Text(l10n.logoutConfirmation),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.logout)),
        ],
      ),
    );
    if (confirm != true) return;
    await AuthProvider().logout();
    if (!mounted) return;
    context.go('/login');
  }

  void _showMenu() {
    final loc = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    showLuxeSheet<void>(context, builder: (ctx) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            LuxeAvatar(initial: _avatarInitial()),
            const SizedBox(width: 12),
            Expanded(child: Text(_api.userName ?? '', style: Lx.display(context, size: 18))),
          ]),
        ),
        LuxeMoreRow(
          key: const ValueKey('accountant-profile'),
          lxIcon: 'gear',
          label: loc.amNavSettings,
          onTap: () {
            Navigator.pop(ctx);
            context.push('/profile');
          },
        ),
        LuxeMoreRow(
          key: const ValueKey('accountant-language'),
          lxIcon: 'lang',
          label: isAr ? 'English' : 'العربية',
          onTap: () {
            Navigator.pop(ctx);
            context.read<LocaleProvider>().toggle();
          },
        ),
        LuxeMoreRow(
          key: const ValueKey('accountant-logout'),
          lxIcon: 'out',
          label: loc.logout,
          danger: true,
          last: true,
          onTap: () {
            Navigator.pop(ctx);
            _logout();
          },
        ),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
      backgroundColor: Lx.page,
      body: SafeArea(
        bottom: false,
        child: LuxeGlow(
          child: Column(children: [
            LuxeTopBar(
              company: isAr ? 'محاسب' : 'Accountant',
              avatarInitial: _avatarInitial(),
              unread: _unread > 0,
              onBell: () => context.push('/notifications').then((_) => _loadUnread()),
              onAvatar: _showMenu,
            ),
            Expanded(child: FinancePage(api: _api, embedded: true)),
          ]),
        ),
      ),
    );
  }
}
