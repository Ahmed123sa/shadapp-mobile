import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/shad_logo.dart';
import 'package:shadapp_client/generated/app_localizations.dart';

class AccountManagersPage extends StatefulWidget {
  const AccountManagersPage({super.key});

  @override
  State<AccountManagersPage> createState() => _AccountManagersPageState();
}

class _AccountManagersPageState extends State<AccountManagersPage> {
  final _api = ApiClient();
  List<dynamic> _managers = [];
  bool _loading = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _errorMsg = null; });
    try {
      final data = await _api.get('/account-managers');
      _managers = data['managers'] as List<dynamic>? ?? [];
    } catch (e) {
      if (!mounted) return;
      _errorMsg = AppLocalizations.of(context)!.accountManagersFailedToLoad;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _delete(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx)!.accountManagersDeleteTitle),
        content: Text(AppLocalizations.of(ctx)!.accountManagersDeleteNameConfirmation(name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(ctx)!.cancel)),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppLocalizations.of(ctx)!.delete)),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.delete('/account-managers/$id');
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.accountManagersDeleteFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ShadLogo(size: 24, showText: false),
            const SizedBox(width: 8),
            Text(l10n.amManageManagers, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, fontFamily: 'PlayfairDisplay')),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await context.push<bool>('/am/managers/create');
              if (result == true) _load();
            },
          ),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _errorMsg != null
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_errorMsg!, style: const TextStyle(color: ShadColors.error)),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: _load, child: Text(l10n.retry)),
              ]),
            )
          : _managers.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.people_outline, size: 56, color: ShadColors.textDisabled),
                  const SizedBox(height: 16),
                  Text(l10n.accountManagersEmpty, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ShadColors.textPrimary)),
                  const SizedBox(height: 8),
                  Text(l10n.accountManagersAddHint, style: const TextStyle(fontSize: 14, color: ShadColors.textSecondary)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final result = await context.push<bool>('/am/managers/create');
                      if (result == true) _load();
                    },
                    icon: const Icon(Icons.person_add, size: 18),
                    label: Text(l10n.accountManagersAddButton),
                  ),
                ]),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _managers.length,
                  itemBuilder: (_, i) {
                    final m = _managers[i] as Map<String, dynamic>;
                    final name = m['name'] as String? ?? '';
                    final email = m['email'] as String? ?? '';
                    final mgrId = int.tryParse(m['id']?.toString() ?? '') ?? 0;
                    final clientCount = int.tryParse(m['managed_clients_count']?.toString() ?? '') ?? 0;
                    final phone = m['phone'] as String?;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: ShadColors.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: ShadColors.cardBorder),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: ShadColors.black,
                          child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(color: ShadColors.textPrimary, fontWeight: FontWeight.bold, fontFamily: 'Archivo')),
                        ),
                        title: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
                        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(email, style: TextStyle(fontSize: 11, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
                          if (phone != null && phone.isNotEmpty)
                            Text(phone, style: TextStyle(fontSize: 10, color: ShadColors.textDisabled, fontFamily: 'Archivo')),
                          Row(children: [
                            Text(l10n.accountManagersClientCount(clientCount), style: TextStyle(fontSize: 10, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
                            if (m['date_of_birth'] != null && (m['date_of_birth'] as String).isNotEmpty) ...[
                              Text(' · ', style: TextStyle(fontSize: 10, color: ShadColors.textDisabled)),
                              Text((m['date_of_birth'] as String).substring(0, 10), style: TextStyle(fontSize: 10, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
                            ],
                          ]),
                        ]),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20, color: ShadColors.gold),
                            onPressed: () async {
                              final result = await context.push<bool>('/am/managers/$mgrId/edit');
                              if (result == true) _load();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20, color: ShadColors.error),
                            onPressed: () => _delete(mgrId, name),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
              ),
    );
  }
}
