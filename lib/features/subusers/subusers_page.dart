import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/loading_state.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/password_field.dart';

const List<Map<String, String>> _permissionDefs = [
  {'key': 'can_chat', 'label': 'المحادثة'},
  {'key': 'can_view_contracts', 'label': 'عرض العقود'},
  {'key': 'can_approve_contracts', 'label': 'الموافقة على العقود'},
  {'key': 'can_view_payments', 'label': 'عرض المدفوعات'},
  {'key': 'can_upload_payment_proof', 'label': 'رفع إثبات الدفع'},
  {'key': 'can_view_approvals', 'label': 'عرض الطلبات'},
  {'key': 'can_respond_approvals', 'label': 'الرد على الطلبات'},
  {'key': 'can_view_files', 'label': 'عرض الملفات'},
  {'key': 'can_upload_files', 'label': 'رفع ملفات'},
  {'key': 'can_view_meetings', 'label': 'عرض الاجتماعات'},
  {'key': 'can_join_meetings', 'label': 'الانضمام للاجتماعات'},
];

class SubUsersPage extends StatefulWidget {
  const SubUsersPage({super.key});

  @override
  State<SubUsersPage> createState() => _SubUsersPageState();
}

class _SubUsersPageState extends State<SubUsersPage> {
  final _api = ApiClient();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  List<dynamic> _subUsers = [];
  bool _loading = true;
  bool _showForm = false;
  bool _saving = false;
  int? _expandedId;
  DateTime? _newDob;
  bool get _isSubUser => _api.role == 'sub_user';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cid = _api.userId;
    if (cid == null) return;
    setState(() => _loading = true);
    try {
      final data = await _api.get('/clients/$cid/sub-users');
      _subUsers = data['sub_users'] as List<dynamic>? ?? [];
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (name.isEmpty || email.isEmpty || password.isEmpty) return;
    final cid = _api.userId;
    if (cid == null) return;
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'name': name, 'email': email, 'password': password,
      };
      if (_newDob != null) body['date_of_birth'] = _newDob!.toIso8601String().substring(0, 10);
      final data = await _api.post('/clients/$cid/sub-users', body);
      _subUsers.add(data['sub_user']);
      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
      setState(() { _showForm = false; _newDob = null; });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل إنشاء المستخدم')));
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _delete(int id) async {
    try {
      await _api.delete('/sub-users/$id');
      setState(() {
        _subUsers.removeWhere((u) => u['id'] == id);
        if (_expandedId == id) _expandedId = null;
      });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل حذف المستخدم')));
    }
  }

  Future<void> _togglePermission(int userId, String key, bool current) async {
    final user = _subUsers.firstWhere((u) => u['id'] == userId, orElse: () => {});
    final permissions = _getPermissions(user);
    permissions[key] = !current;
    try {
      final data = await _api.patch('/sub-users/$userId/permissions', {
        'permissions': permissions,
      });
      final idx = _subUsers.indexWhere((u) => u['id'] == userId);
      if (idx != -1) {
        setState(() {
          _subUsers[idx]['permissions'] = data['sub_user']?['permissions'] ?? permissions;
        });
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل تحديث الصلاحيات')));
    }
  }

  Map<String, dynamic> _getPermissions(dynamic user) {
    try {
      return Map<String, dynamic>.from(user['permissions'] as Map);
    } catch (_) {
      return {};
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('فريق العمل (${_subUsers.length})', style: ShadTypography.sectionHeader),
          if (!_isSubUser)
            TextButton.icon(
              onPressed: () => setState(() => _showForm = !_showForm),
              icon: Icon(_showForm ? Icons.close : Icons.person_add, size: 18),
              label: Text(_showForm ? 'إلغاء' : '+ إضافة'),
            ),
        ]),
        if (_showForm) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'الاسم', hintText: 'اسم المستخدم'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'البريد الإلكتروني', hintText: 'email@example.com'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                PasswordField(controller: _passwordController, showRequirements: false),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('تاريخ الميلاد (اختياري)', style: TextStyle(fontSize: 13)),
                  subtitle: Text(
                    _newDob != null ? '${_newDob!.day}/${_newDob!.month}/${_newDob!.year}' : 'لم يُحدد',
                    style: TextStyle(fontSize: 12, color: _newDob != null ? ShadColors.textPrimary : ShadColors.textDisabled),
                  ),
                  trailing: const Icon(Icons.calendar_today, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _newDob ?? DateTime(1990),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                      locale: const Locale('ar'),
                    );
                    if (picked != null) setState(() => _newDob = picked);
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _create,
                    child: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('إضافة المستخدم'),
                  ),
                ),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (_subUsers.isEmpty)
          const EmptyState(icon: Icons.people_outline, title: 'لا يوجد مستخدمون تابعون')
        else
          ..._subUsers.map((u) {
            final isExpanded = _expandedId == u['id'];
            final permissions = _getPermissions(u);
            final activeCount = permissions.values.where((v) => v == true).length;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Column(
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: ShadColors.black,
                      child: Text(_initials(u['name'] as String? ?? '?'),
                          style: const TextStyle(color: ShadColors.gold, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(u['name'] ?? '', style: ShadTypography.cardTitle),
                    subtitle: Text(
                      '${u['email'] ?? ''} · $activeCount/11 صلاحية',
                      style: ShadTypography.caption.copyWith(color: ShadColors.textSecondary),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            color: ShadColors.textSecondary,
                          ),
                          onPressed: () => setState(() => _expandedId = isExpanded ? null : u['id']),
                        ),
                        if (!_isSubUser)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: ShadColors.error, size: 20),
                            onPressed: () => _delete(u['id']),
                          ),
                      ],
                    ),
                  ),
                  if (isExpanded && !_isSubUser) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        children: _permissionDefs.map((def) {
                          final val = permissions[def['key']] == true;
                          return SwitchListTile(
                            title: Text(def['label']!, style: const TextStyle(fontSize: 13)),
                            value: val,
                            onChanged: (v) => _togglePermission(u['id'], def['key']!, val),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            activeThumbColor: ShadColors.crimson,
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }
}
