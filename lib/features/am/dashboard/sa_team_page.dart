import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../../models/manager.dart';
import '../../../providers/manager_provider.dart';
import 'package:shadapp_client/generated/app_localizations.dart';

class SaTeamPage extends StatefulWidget {
  // Optional so this screen can be pumped in a widget test with a mocked
  // ManagerProvider instead of hitting the network.
  final ManagerProvider? managerProvider;
  final ApiClient? api;
  const SaTeamPage({super.key, this.managerProvider, this.api});

  @override
  State<SaTeamPage> createState() => _SaTeamPageState();
}

class _SaTeamPageState extends State<SaTeamPage> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final ManagerProvider _managerProvider = widget.managerProvider ?? ManagerProvider();
  final _searchController = TextEditingController();
  List<Manager> _managers = [];
  String _searchQuery = '';
  bool _loading = true;
  Timer? _debounce;

  List<Manager> get _filteredManagers {
    if (_searchQuery.isEmpty) return _managers;
    final q = _searchQuery.toLowerCase();
    return _managers.where((m) {
      return m.name.toLowerCase().contains(q) || (m.email ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await _managerProvider.fetchManagers();
    _managers = _managerProvider.managers;
    if (mounted) setState(() => _loading = false);
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() => _searchQuery = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return RefreshIndicator(
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(children: [
                  Text(l10n.amNavTeam, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: ShadColors.crimson.withAlpha(30), borderRadius: BorderRadius.circular(10)),
                    child: Text('${_managers.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ShadColors.gold, fontFamily: 'PlayfairDisplay')),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => context.push('/am/managers'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: ShadColors.gold.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        const Icon(Icons.settings, size: 12, color: ShadColors.gold),
                        const SizedBox(width: 4),
                        Text(l10n.saTeamManage, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ShadColors.gold, fontFamily: 'Archivo')),
                      ]),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                _buildSearchBar(),
                const SizedBox(height: 12),
                if (_filteredManagers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text(l10n.saTeamNoManagers, style: const TextStyle(fontSize: 13, color: ShadColors.textDisabled, fontFamily: 'Archivo'))),
                  )
                else
                  ..._filteredManagers.map((m) => _managerCard(m)),
              ],
            ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      style: const TextStyle(fontSize: 13, color: ShadColors.textPrimary, fontFamily: 'Archivo'),
      textDirection: Localizations.localeOf(context).languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      decoration: InputDecoration(
        hintText: AppLocalizations.of(context)!.saTeamSearchHintPhone,
        hintStyle: TextStyle(color: ShadColors.textDisabled, fontSize: 12, fontFamily: 'Archivo'),
        prefixIcon: const Icon(Icons.search, size: 18, color: ShadColors.textSecondary),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 16, color: ShadColors.textSecondary),
                onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); },
              )
            : null,
        filled: true,
        fillColor: ShadColors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: ShadColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: ShadColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ShadColors.gold, width: 1.5),
        ),
      ),
      onChanged: _onSearchChanged,
    );
  }

  Widget _managerCard(Manager manager) {
    final name = manager.name;
    final email = manager.email ?? '';
    final phone = manager.phone;
    final clientCount = manager.managedClientsCount;
    final avatarUrl = manager.avatarUrl;
    final initials = name.isNotEmpty ? name.substring(0, name.length.clamp(0, 2)).toUpperCase() : '?';
    final mgrId = manager.id;

    return GestureDetector(
      onTap: () => context.push('/am/managers/$mgrId/detail'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: ShadColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ShadColors.cardBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: ShadColors.crimson,
              backgroundImage: avatarUrl != null ? NetworkImage(_api.resolveFileUrl(avatarUrl)) : null,
              child: avatarUrl == null ? Text(initials, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ShadColors.gold, fontFamily: 'Archivo')) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
                const SizedBox(height: 2),
                Text(email, style: const TextStyle(fontSize: 10, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
                if (phone != null && phone.isNotEmpty)
                  Text(phone, style: const TextStyle(fontSize: 10, color: ShadColors.textDisabled, fontFamily: 'Archivo')),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: ShadColors.sent.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.people, size: 12, color: ShadColors.sent),
                const SizedBox(width: 4),
                Text('$clientCount', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ShadColors.sent, fontFamily: 'PlayfairDisplay')),
              ]),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_left, size: 20, color: ShadColors.textDisabled),
          ]),
        ),
      ),
    );
  }
}
