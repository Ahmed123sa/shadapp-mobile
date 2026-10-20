import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api_client.dart';
import '../../../core/app_log.dart';
import '../../../core/helpers/client_status.dart';
import '../../../core/luxe/lx_icons.dart';
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

  /// Mockup `.srch`: border line, r999, padding 10 14, gap 10, faint
  /// search icon, 12.5px text; margin-bottom 12.
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(Lx.rPill), border: Border.all(color: Lx.line)),
      child: Row(children: [
        const LxIcon('search', size: 18, color: Lx.faint),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            key: const ValueKey('clients-search'),
            controller: _searchController,
            style: Lx.text(context, size: 12.5),
            cursorColor: Lx.crimsonInk,
            decoration: InputDecoration(
              isDense: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              hintText: AppLocalizations.of(context)!.saClientsSearchHintPhone,
              hintStyle: Lx.text(context, size: 12.5, color: Lx.faint),
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        if (_searchQuery.isNotEmpty)
          GestureDetector(
            onTap: () { _searchController.clear(); setState(() => _searchQuery = ''); },
            child: const Icon(Icons.close, size: 15, color: Lx.faint),
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
    final h1 = Lx.display(context, size: 28).copyWith(height: 1.2);
    return RefreshIndicator(
      onRefresh: _load,
      color: Lx.crimsonInk,
      child: _loading && _allClients.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Lx.crimsonInk))
          : ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 2, 16, 18),
              children: [
                // Mockup head(SA 'Directory' / AM 'Your book', Clients / My clients).
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 6, 0, 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text((isAm ? l10n.clientsEyebrowAm : l10n.clientsEyebrowSa).toUpperCase(),
                        style: Lx.text(context, size: 10.5, color: Lx.faint).copyWith(letterSpacing: 2.73)),
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: isAm ? l10n.staffMyClientsTitle : l10n.saClientsTitle),
                        TextSpan(text: '.', style: h1.copyWith(color: Lx.crimsonInk, fontStyle: FontStyle.normal)),
                      ]),
                      key: const ValueKey('lx-page-title'),
                      style: h1,
                    ),
                  ]),
                ),
                _buildSearchBar(),
                if (widget.onCreateClient != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: LuxeButton(
                        key: const ValueKey('clients-new'),
                        label: l10n.amNewClient,
                        lxIcon: 'plus',
                        kind: LuxeButtonKind.primary,
                        size: LuxeButtonSize.lg,
                        onPressed: widget.onCreateClient!,
                      ),
                    ),
                  ),
                // Not in the mockup: status + manager filters, kept because
                // they are real features. Styled as the mockup's `.chips`.
                _buildPillsFilter(isAm),
                if (_filteredClients.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text(l10n.saClientsNoClients, style: Lx.text(context, size: 13.5, color: Lx.faint))),
                  )
                else
                  ..._filteredClients.map((c) => _clientCard(c, showManager: !isAm)),
              ],
            ),
    );
  }

  void _pickManager() {
    final l10n = AppLocalizations.of(context)!;
    Widget row(BuildContext ctx, String label, String? sub, bool on, VoidCallback onTap, {bool last = false}) => InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
            decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: Lx.line))),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: Lx.text(ctx, size: 14.5)),
                  if (sub != null && sub.isNotEmpty) Text(sub, style: Lx.text(ctx, size: 12.5, color: Lx.muted)),
                ]),
              ),
              if (on) const LuxeStatusDot(status: LxStatus.bad),
            ]),
          ),
        );
    showLuxeSheet<void>(context, builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Text(l10n.saClientsSelectManager, style: Lx.display(ctx, size: 22)),
      ),
      row(ctx, l10n.saClientsAllManagers, null, _selectedManagerId == null, () { setState(() => _selectedManagerId = null); Navigator.pop(ctx); _load(); }, last: _managers.isEmpty),
      for (var i = 0; i < _managers.length; i++)
        row(ctx, _managers[i].name, _managers[i].email, _selectedManagerId == _managers[i].id, () {
          setState(() => _selectedManagerId = _managers[i].id);
          Navigator.pop(ctx);
          _load();
        }, last: i == _managers.length - 1),
    ]));
  }

  String _managerName(dynamic id) {
    final key = id?.toString();
    for (final m in _managers) {
      if (m.id.toString() == key) return m.name;
    }
    return '';
  }

  /// Mockup `.chip` / `.chip.on`.
  Widget _chip(String label, bool on, VoidCallback onTap, {Key? key}) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: GestureDetector(
          key: key,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: on ? const Color(0xFFF0F0F0) : null,
              borderRadius: BorderRadius.circular(Lx.rPill),
              border: Border.all(color: on ? const Color(0xFFF0F0F0) : Lx.line2),
            ),
            child: Text(label, style: Lx.text(context, size: 12, color: on ? const Color(0xFF111111) : Lx.muted)),
          ),
        ),
      );

  Widget _buildPillsFilter(bool isAm) {
    final l10n = AppLocalizations.of(context)!;
    final filters = [l10n.all, l10n.active, l10n.pending, l10n.underReview];
    final picked = _selectedManagerId != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (var i = 0; i < filters.length; i++)
            _chip(filters[i], _filterIndex == i, () => setState(() => _filterIndex = i), key: ValueKey('clients-chip-$i')),
          if (!isAm && _managers.isNotEmpty)
            _chip('${picked ? _managerName(_selectedManagerId) : l10n.saClientsAllManagers} ▾', picked, _pickManager, key: const ValueKey('clients-manager-filter')),
        ]),
      ),
    );
  }

  /// Mockup `pClients` card: name (16) / "Type · industry" + `.tagr`;
  /// "contact · phone" (margin-top 8); SA "Manager: X"; then contract and
  /// workspace status (gap 16, margin-top 10). Long-press → actions.
  Widget _clientCard(Map<String, dynamic> client, {required bool showManager}) {
    final l10n = AppLocalizations.of(context)!;
    final ws = client['workspace'] as Map<String, dynamic>?;
    final wsActive = ws?['status'] == 'active';
    final name = client['company_name'] as String? ?? '';
    final person = client['contact_person'] as String? ?? '';
    final phone = (client['phone'] as String?)?.trim() ?? '';
    final type = client['client_type'] as String?;
    final typeLabel = type == null || type.isEmpty ? '' : (type == 'business' ? l10n.clientTypeCompany : l10n.clientTypeIndividual);
    final industry = (client['industry'] as String?)?.trim() ?? '';
    final typeLine = [typeLabel, industry].where((e) => e.isNotEmpty).join(' · ');
    final manager = showManager ? _managerName(client['manager_id']) : '';
    final contracted = clientHasSignedContract(client);

    Widget st(LxStatus s, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
          LuxeStatusDot(status: s),
          const SizedBox(width: 7),
          Text(label, style: Lx.text(context, size: 12, color: Lx.ink2)),
        ]);

    return GestureDetector(
      onLongPress: () => _showClientActions(client),
      child: LuxeCard(
        key: ValueKey('client-card-${client['id']}'),
        onTap: () {
          final wsId = client['workspace']?['id'] as int?;
          if (wsId != null) context.push('/am/workspace/$wsId');
        },
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: Lx.text(context, size: 16)),
                if (typeLine.isNotEmpty) Text(typeLine, style: Lx.text(context, size: 12.5, color: Lx.muted)),
              ]),
            ),
            const SizedBox(width: 10),
            ClientTypeBadge(clientType: type, compact: true),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Flexible(child: Text(person, overflow: TextOverflow.ellipsis, style: Lx.text(context, size: 12.5, color: Lx.muted))),
            if (phone.isNotEmpty) ...[
              Text(' · ', style: Lx.text(context, size: 12.5, color: Lx.muted)),
              Text(phone, textDirection: TextDirection.ltr, style: Lx.text(context, size: 12.5, color: Lx.muted)),
            ],
          ]),
          if (manager.isNotEmpty) Text('${l10n.saClientsManagerLabel}: $manager', style: Lx.text(context, size: 12.5, color: Lx.muted)),
          const SizedBox(height: 10),
          Wrap(spacing: 16, runSpacing: 6, children: [
            st(contracted ? LxStatus.ok : LxStatus.wait, contracted ? l10n.approved : l10n.amStatusNotContracted),
            st(wsActive ? LxStatus.ok : LxStatus.wait, wsActive ? l10n.active : !contracted ? l10n.pending : l10n.underReview),
          ]),
        ]),
      ),
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
