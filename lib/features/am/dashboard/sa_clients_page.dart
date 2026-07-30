import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/client_type_badge.dart';

class SaClientsPage extends StatefulWidget {
  const SaClientsPage({super.key});

  @override
  State<SaClientsPage> createState() => _SaClientsPageState();
}

class _SaClientsPageState extends State<SaClientsPage> {
  final _api = ApiClient();
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _allClients = [];
  List<Map<String, dynamic>> _managers = [];
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
      final params = <String, String>{};
      if (_selectedManagerId != null) params['manager_id'] = _selectedManagerId.toString();
      final query = params.isNotEmpty ? '?${params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}' : '';
      final data = await _api.get('/clients$query');
      final clients = safeList(data['clients']);
      if (mounted) setState(() { _allClients = clients.cast<Map<String, dynamic>>(); });
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadManagers() async {
    try {
      final data = await _api.get('/account-managers');
      final list = data['managers'] as List<dynamic>? ?? [];
      _managers = list.cast<Map<String, dynamic>>();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() => _searchQuery = value.trim());
    });
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      style: const TextStyle(fontSize: 13, color: ShadColors.textPrimary, fontFamily: 'Archivo'),
      textDirection: TextDirection.rtl,
      decoration: InputDecoration(
        hintText: 'بحث بالاسم أو رقم الهاتف أو البريد...',
        hintStyle: TextStyle(color: ShadColors.textDisabled, fontSize: 12, fontFamily: 'Archivo'),
        prefixIcon: const Icon(Icons.search, size: 18, color: ShadColors.textSecondary),
        suffixIcon: _searchQuery.isNotEmpty
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
      case 2: return filtered.where((c) => c['signed_at'] == null).toList();
      case 3: return filtered.where((c) => c['signed_at'] != null && (c['workspace'] as Map<String, dynamic>?)?['status'] != 'active').toList();
      default: return filtered;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: _loading && _allClients.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(children: [
                  const Text('العملاء', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: ShadColors.crimson.withAlpha(30), borderRadius: BorderRadius.circular(10)),
                    child: Text('${_allClients.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ShadColors.gold, fontFamily: 'PlayfairDisplay')),
                  ),
                ]),
                const SizedBox(height: 12),
                _buildSearchBar(),
                const SizedBox(height: 10),
                _buildManagerFilter(),
                const SizedBox(height: 10),
                _buildPillsFilter(),
                const SizedBox(height: 12),
                if (_filteredClients.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text('لا يوجد عملاء', style: TextStyle(fontSize: 13, color: ShadColors.textDisabled, fontFamily: 'Archivo'))),
                  )
                else
                  ..._filteredClients.map((c) => _clientCard(c)),
              ],
            ),
    );
  }

  Widget _buildManagerFilter() {
    if (_managers.isEmpty) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          builder: (ctx) => SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('اختر المدير', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, fontFamily: 'Archivo', color: ShadColors.textPrimary)),
              ),
              ListTile(
                title: const Text('كل المديرين', style: TextStyle(fontFamily: 'Archivo')),
                trailing: _selectedManagerId == null ? const Icon(Icons.check, color: ShadColors.gold) : null,
                onTap: () { setState(() => _selectedManagerId = null); Navigator.pop(ctx); _load(); },
              ),
              ..._managers.map((m) => ListTile(
                title: Text(m['name'] ?? '', style: const TextStyle(fontFamily: 'Archivo')),
                subtitle: Text(m['email'] ?? '', style: const TextStyle(fontSize: 11, fontFamily: 'Archivo')),
                trailing: _selectedManagerId == m['id'] ? const Icon(Icons.check, color: ShadColors.gold) : null,
                onTap: () { setState(() => _selectedManagerId = m['id']); Navigator.pop(ctx); _load(); },
              )),
            ]),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: ShadColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _selectedManagerId != null ? ShadColors.gold : ShadColors.cardBorder),
        ),
        child: Row(children: [
          Icon(Icons.person, size: 14, color: _selectedManagerId != null ? ShadColors.gold : ShadColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _selectedManagerId != null
                  ? (_managers.firstWhere((m) => m['id'] == _selectedManagerId, orElse: () => {})['name'] ?? 'مدير')
                  : 'كل المديرين',
              style: TextStyle(fontSize: 11, color: _selectedManagerId != null ? ShadColors.gold : ShadColors.textSecondary, fontFamily: 'Archivo'),
            ),
          ),
          Icon(Icons.arrow_drop_down, size: 18, color: ShadColors.textSecondary),
        ]),
      ),
    );
  }

  Widget _buildPillsFilter() {
    final active = _allClients.where((c) => (c['workspace'] as Map<String, dynamic>?)?['status'] == 'active').length;
    final pending = _allClients.where((c) => c['signed_at'] == null).length;
    final review = _allClients.where((c) => c['signed_at'] != null && (c['workspace'] as Map<String, dynamic>?)?['status'] != 'active').length;
    final filters = [
      ('الكل', _allClients.length),
      ('نشط', active),
      ('بانتظار', pending),
      ('مراجعة', review),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.asMap().entries.map((entry) {
          final i = entry.key;
          final (label, count) = entry.value;
          final activeFilter = _filterIndex == i;
          return Padding(
            padding: const EdgeInsets.only(left: 6),
            child: GestureDetector(
              onTap: () => setState(() => _filterIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: activeFilter ? ShadColors.gold.withAlpha(25) : ShadColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: activeFilter ? ShadColors.gold : ShadColors.cardBorder),
                ),
                child: Text('$label ($count)', style: TextStyle(fontSize: 11, fontWeight: activeFilter ? FontWeight.w700 : FontWeight.w500, color: activeFilter ? ShadColors.gold : ShadColors.textSecondary, fontFamily: 'Archivo')),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _clientCard(Map<String, dynamic> client) {
    final ws = client['workspace'] as Map<String, dynamic>?;
    final wsActive = ws?['status'] == 'active';
    final name = client['company_name'] as String? ?? '';
    final person = client['contact_person'] as String? ?? '';
    final phone = client['phone'] as String?;
    final signedAt = client['signed_at'] as String?;
    final initials = name.isNotEmpty ? name.substring(0, name.length.clamp(0, 2)).toUpperCase() : '?';

    return GestureDetector(
      onTap: () {
        final wsId = client['workspace']?['id'] as int?;
        if (wsId != null) context.push('/am/workspace/$wsId');
      },
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
              backgroundImage: (client['avatar_url'] as String?)?.isNotEmpty == true
                  ? NetworkImage(_api.resolveFileUrl(client['avatar_url']))
                  : null,
              child: (client['avatar_url'] as String?)?.isNotEmpty != true
                  ? Text(initials, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ShadColors.gold, fontFamily: 'Archivo'))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'Archivo'))),
                  const SizedBox(width: 6),
                  ClientTypeBadge(clientType: client['client_type'] as String?, compact: true),
                ]),
                const SizedBox(height: 2),
                Text(person, style: const TextStyle(fontSize: 10, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
                if (phone != null && phone.isNotEmpty)
                  Text(phone, style: const TextStyle(fontSize: 10, color: ShadColors.textDisabled, fontFamily: 'Archivo'), textDirection: TextDirection.ltr),
              ]),
            ),
            Column(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (wsActive ? ShadColors.success : signedAt == null ? ShadColors.gold : ShadColors.sent).withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  wsActive ? 'نشط' : signedAt == null ? 'بانتظار' : 'مراجعة',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: wsActive ? ShadColors.success : signedAt == null ? ShadColors.gold : ShadColors.sent, fontFamily: 'Archivo'),
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => _showClientActions(client),
                child: const Icon(Icons.more_vert, size: 16, color: ShadColors.textDisabled),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  void _showClientActions(Map<String, dynamic> client) {
    final clientId = int.tryParse(client['id']?.toString() ?? '') ?? 0;
    final name = client['company_name'] as String? ?? '';
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'PlayfairDisplay', color: ShadColors.textPrimary)),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.edit, color: ShadColors.gold),
            title: const Text('تعديل العميل'),
            onTap: () { Navigator.pop(ctx); context.push<bool>('/am/clients/${client['id']}').then((v) { if (v == true) _load(); }); },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: ShadColors.error),
            title: const Text('حذف العميل', style: TextStyle(color: ShadColors.error)),
            onTap: () { Navigator.pop(ctx); _deleteClient(clientId, name); },
          ),
        ]),
      ),
    );
  }

  Future<void> _deleteClient(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف العميل'),
        content: Text('حذف "$name" نهائياً؟ لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: ShadColors.error),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.delete('/clients/$id');
      _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل حذف العميل')));
    }
  }
}
