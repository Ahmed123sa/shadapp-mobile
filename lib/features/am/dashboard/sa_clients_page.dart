import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api_client.dart';
import '../../../core/app_log.dart';
import '../../../core/helpers/client_status.dart';
import '../../../core/luxe/tokens.dart';
import '../../../core/widgets/luxe/luxe_widgets.dart';
import '../../../core/widgets/client_type_badge.dart';
import '../../../models/manager.dart';
import '../../../providers/client_provider.dart';
import '../../../providers/manager_provider.dart';
import 'package:shadapp_client/generated/app_localizations.dart';

class SaClientsPage extends StatefulWidget {
  // Optional so this screen can be pumped in a widget test with mocked
  // providers instead of hitting the network.
  final ClientProvider? clientProvider;
  final ManagerProvider? managerProvider;
  final ApiClient? api;
  /// Staff mockup: a full-width primary "New client" button under the search
  /// bar. Null hides it (super admin / assistants don't create clients).
  final VoidCallback? onCreateClient;
  const SaClientsPage({super.key, this.clientProvider, this.managerProvider, this.api, this.onCreateClient});

  @override
  State<SaClientsPage> createState() => _SaClientsPageState();
}

class _SaClientsPageState extends State<SaClientsPage> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final ClientProvider _clientProvider = widget.clientProvider ?? ClientProvider();
  late final ManagerProvider _managerProvider = widget.managerProvider ?? ManagerProvider();
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _allClients = [];
  List<Manager> _managers = [];
  bool _loading = true;
  int _filterIndex = 0;
  String _searchQuery = '';
  Timer? _debounce;
  int? _selectedManagerId;

  @override
  void initState() {
    super.initState();
    _load();
    _loadManagers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // server-side-stats-plan.md, Stage 3 (M6) — was fetchClientsRaw(), a
      // single page (server-side hard cap of 30). A company with more
      // clients than that had the rest simply missing from this list (not
      // just from a count), and the filter-pill counts below were computed
      // from that same incomplete list. Every page, still scoped to the
      // selected manager when one is chosen.
      final clients = await _clientProvider.fetchAllClientsPaginatedRaw(managerId: _selectedManagerId);
      if (mounted) setState(() { _allClients = clients.cast<Map<String, dynamic>>(); });
    } catch (e, s) {
      AppLog.error('sa_clients_page._load', e, s);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadManagers() async {
    try {
      await _managerProvider.fetchManagers();
      _managers = _managerProvider.managers;
      if (mounted) setState(() {});
    } catch (e, s) {
      AppLog.error('sa_clients_page._loadManagers', e, s);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() => _searchQuery = value.trim());
    });
  }

  /// Mockup `.srch`: pill search field.
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(Lx.rPill), border: Border.all(color: Lx.line)),
      child: Row(children: [
        const Icon(Icons.search, size: 18, color: Lx.faint),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: _searchController,
            style: Lx.text(context, size: 12.5),
            cursorColor: Lx.crimsonInk,
            textDirection: Localizations.localeOf(context).languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
            decoration: InputDecoration(
              isDense: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              hintText: AppLocalizations.of(context)!.saClientsSearchHintPhone,
              hintStyle: Lx.text(context, size: 12.5, color: Lx.faint),
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        if (_searchQuery.isNotEmpty)
          GestureDetector(
            onTap: () { _searchController.clear(); setState(() => _searchQuery = ''); },
            child: const Icon(Icons.clear, size: 16, color: Lx.faint),
          ),
      ]),
    );
  }

  List<Map<String, dynamic>> get _filteredClients {
    var filtered = _allClients;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((c) {
        final name = (c['company_name'] as String? ?? '').toLowerCase();
        final person = (c['contact_person'] as String? ?? '').toLowerCase();
        final phone = (c['phone'] as String? ?? '').toLowerCase();
        final email = (c['email'] as String? ?? '').toLowerCase();
        return name.contains(q) || person.contains(q) || phone.contains(q) || email.contains(q);
      }).toList();
    }
    switch (_filterIndex) {
      case 1: return filtered.where((c) => (c['workspace'] as Map<String, dynamic>?)?['status'] == 'active').toList();
      case 2: return filtered.where((c) => !clientHasSignedContract(c)).toList();
      case 3: return filtered.where((c) => clientHasSignedContract(c) && (c['workspace'] as Map<String, dynamic>?)?['status'] != 'active').toList();
      default: return filtered;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAm = _api.role != 'super_admin';
    return RefreshIndicator(
      onRefresh: _load,
      color: Lx.crimsonInk,
      child: _loading && _allClients.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Lx.crimsonInk))
          : ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 6, 0, 14),
                  child: Row(children: [
                    Expanded(child: LuxePageTitle(isAm ? l10n.amNavClients : l10n.saClientsTitle)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(Lx.rPill), border: Border.all(color: Lx.line2)),
                      child: Text('${_allClients.length}', style: Lx.display(context, size: 14)),
                    ),
                  ]),
                ),
                _buildSearchBar(),
                if (widget.onCreateClient != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: LuxeButton(
                      key: const ValueKey('clients-new'),
                      label: l10n.createClient,
                      lxIcon: 'plus',
                      kind: LuxeButtonKind.primary,
                      size: LuxeButtonSize.lg,
                      onPressed: widget.onCreateClient!,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                _buildManagerFilter(),
                const SizedBox(height: 10),
                _buildPillsFilter(),
                const SizedBox(height: 14),
                if (_filteredClients.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text(l10n.saClientsNoClients, style: Lx.text(context, size: 13.5, color: Lx.faint))),
                  )
                else
                  ..._filteredClients.map((c) => _clientCard(c)),
              ],
            ),
    );
  }

  Widget _buildManagerFilter() {
    final l10n = AppLocalizations.of(context)!;
    if (_managers.isEmpty) return const SizedBox.shrink();
    final picked = _selectedManagerId != null;
    return GestureDetector(
      onTap: () {
        showLuxeSheet<void>(context, builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(l10n.saClientsSelectManager, style: Lx.display(ctx, size: 18)),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.saClientsAllManagers, style: Lx.text(ctx, size: 14)),
            trailing: _selectedManagerId == null ? const Icon(Icons.check, color: Lx.crimsonInk) : null,
            onTap: () { setState(() => _selectedManagerId = null); Navigator.pop(ctx); _load(); },
          ),
          ..._managers.map((m) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(m.name, style: Lx.text(ctx, size: 14)),
            subtitle: Text(m.email ?? '', style: Lx.text(ctx, size: 11.5, color: Lx.muted)),
            trailing: _selectedManagerId == m.id ? const Icon(Icons.check, color: Lx.crimsonInk) : null,
            onTap: () { setState(() => _selectedManagerId = m.id); Navigator.pop(ctx); _load(); },
          )),
        ]));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Lx.rPill),
          border: Border.all(color: picked ? const Color(0x80941414) : Lx.line2),
        ),
        child: Row(children: [
          Icon(Icons.person_outline, size: 15, color: picked ? Lx.crimsonInk : Lx.faint),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              picked ? _selectedManagerName(l10n) : l10n.saClientsAllManagers,
              style: Lx.text(context, size: 12, color: picked ? Lx.ink : Lx.muted),
            ),
          ),
          const Icon(Icons.arrow_drop_down, size: 18, color: Lx.faint),
        ]),
      ),
    );
  }

  String _selectedManagerName(AppLocalizations l10n) {
    for (final m in _managers) {
      if (m.id == _selectedManagerId) return m.name;
    }
    return l10n.saClientsManagerLabel;
  }

  Widget _buildPillsFilter() {
    final l10n = AppLocalizations.of(context)!;
    final active = _allClients.where((c) => (c['workspace'] as Map<String, dynamic>?)?['status'] == 'active').length;
    final pending = _allClients.where((c) => !clientHasSignedContract(c)).length;
    final review = _allClients.where((c) => clientHasSignedContract(c) && (c['workspace'] as Map<String, dynamic>?)?['status'] != 'active').length;
    final filters = [
      (l10n.all, _allClients.length),
      (l10n.active, active),
      (l10n.pending, pending),
      (l10n.underReview, review),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.asMap().entries.map((entry) {
          final i = entry.key;
          final (label, count) = entry.value;
          final on = _filterIndex == i;
          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: GestureDetector(
              key: ValueKey('clients-chip-$i'),
              onTap: () => setState(() => _filterIndex = i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: on ? const Color(0xFFF0F0F0) : null,
                  borderRadius: BorderRadius.circular(Lx.rPill),
                  border: Border.all(color: on ? const Color(0xFFF0F0F0) : Lx.line2),
                ),
                child: Text('$label ($count)', style: Lx.text(context, size: 12, color: on ? const Color(0xFF111111) : Lx.muted)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Mockup `pClients` card.
  Widget _clientCard(Map<String, dynamic> client) {
    final l10n = AppLocalizations.of(context)!;
    final ws = client['workspace'] as Map<String, dynamic>?;
    final wsActive = ws?['status'] == 'active';
    final name = client['company_name'] as String? ?? '';
    final person = client['contact_person'] as String? ?? '';
    final phone = client['phone'] as String?;
    final contracted = clientHasSignedContract(client);

    return LuxeCard(
      key: ValueKey('client-card-${client['id']}'),
      onTap: () {
        final wsId = client['workspace']?['id'] as int?;
        if (wsId != null) context.push('/am/workspace/$wsId');
      },
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(name, style: Lx.text(context, size: 16))),
          const SizedBox(width: 8),
          ClientTypeBadge(clientType: client['client_type'] as String?, compact: true),
          GestureDetector(
            key: ValueKey('client-actions-${client['id']}'),
            onTap: () => _showClientActions(client),
            child: const Padding(padding: EdgeInsetsDirectional.only(start: 6, top: 2), child: Icon(Icons.more_vert, size: 17, color: Lx.faint)),
          ),
        ]),
        const SizedBox(height: 6),
        Text(person, style: Lx.text(context, size: 12.5, color: Lx.muted)),
        if (phone != null && phone.isNotEmpty)
          Text(phone, style: Lx.text(context, size: 12.5, color: Lx.muted), textDirection: TextDirection.ltr),
        const SizedBox(height: 10),
        Row(children: [
          LuxeStatusDot(status: contracted ? LxStatus.ok : LxStatus.wait),
          const SizedBox(width: 7),
          Text(contracted ? l10n.amStatusContracted : l10n.amStatusNotContracted, style: Lx.text(context, size: 12, color: Lx.ink2)),
          const SizedBox(width: 16),
          LuxeStatusDot(status: wsActive ? LxStatus.ok : LxStatus.wait),
          const SizedBox(width: 7),
          Text(wsActive ? l10n.active : !contracted ? l10n.pending : l10n.underReview, style: Lx.text(context, size: 12, color: Lx.ink2)),
        ]),
      ]),
    );
  }

  void _showClientActions(Map<String, dynamic> client) {
    final l10n = AppLocalizations.of(context)!;
    final name = client['company_name'] as String? ?? '';
    showLuxeSheet<void>(context, builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(name, style: Lx.display(ctx, size: 18)),
      ),
      LuxeMoreRow(
        lxIcon: 'gear',
        label: l10n.clientDetailEditTitle,
        last: true,
        onTap: () { Navigator.pop(ctx); context.push<bool>('/am/clients/${client['id']}').then((v) { if (v == true) _load(); }); },
      ),
    ]));
  }
}
