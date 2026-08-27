import 'package:flutter/material.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/api_client.dart';
import '../../core/app_log.dart';
import '../../core/theme.dart';
import '../../core/widgets/loading_state.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/password_field.dart';

const List<String> _permissionKeys = [
  'can_chat',
  'can_view_contracts',
  'can_approve_contracts',
  'can_view_payments',
  'can_upload_payment_proof',
  'can_view_approvals',
  'can_respond_approvals',
  'can_view_files',
  'can_upload_files',
  'can_view_meetings',
  'can_join_meetings',
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
    } catch (e, s) {
      AppLog.error('subusers_page._load', e, s);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context)!;
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.subusers_createFailed)));
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _delete(int id) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await _api.delete('/sub-users/$id');
      setState(() {
        _subUsers.removeWhere((u) => u['id'] == id);
        if (_expandedId == id) _expandedId = null;
      });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.subusers_deleteFailed)));
    }
  }

  Future<void> _togglePermission(int userId, String key, bool current) async {
    final l10n = AppLocalizations.of(context)!;
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.subusers_updateFailed)));
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

  String _permissionLabel(String key) {
    final l10n = AppLocalizations.of(context)!;
    switch (key) {
      case 'can_chat': return l10n.subusers_permission_chat;
      case 'can_view_contracts': return l10n.subusers_permission_viewContracts;
      case 'can_approve_contracts': return l10n.subusers_permission_approveContracts;
      case 'can_view_payments': return l10n.subusers_permission_viewPayments;
      case 'can_upload_payment_proof': return l10n.subusers_permission_uploadProof;
      case 'can_view_approvals': return l10n.subusers_permission_viewApprovals;
      case 'can_respond_approvals': return l10n.subusers_permission_replyApprovals;
      case 'can_view_files': return l10n.subusers_permission_viewFiles;
      case 'can_upload_files': return l10n.subusers_permission_uploadFiles;
      case 'can_view_meetings': return l10n.subusers_permission_viewMeetings;
      case 'can_join_meetings': return l10n.subusers_permission_joinMeetings;
      default: return key;
    }
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
    final l10n = AppLocalizations.of(context)!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${l10n.subusers_title} (${_subUsers.length})', style: ShadTypography.sectionHeader),
          if (!_isSubUser)
            TextButton.icon(
              onPressed: () => setState(() => _showForm = !_showForm),
              icon: Icon(_showForm ? Icons.close : Icons.person_add, size: 18),
              label: Text(_showForm ? l10n.cancel : '+ ${l10n.subusers_add}'),
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
                  decoration: InputDecoration(labelText: l10n.subusers_name, hintText: l10n.subusers_username),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(labelText: l10n.subusers_email, hintText: l10n.subusers_emailHint),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                PasswordField(controller: _passwordController, showRequirements: false),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.subusers_dateOfBirth, style: const TextStyle(fontSize: 13)),
                  subtitle: Text(
                    _newDob != null ? '${_newDob!.day}/${_newDob!.month}/${_newDob!.year}' : l10n.subusers_notSet,
                    style: TextStyle(fontSize: 12, color: _newDob != null ? ShadColors.textPrimary : ShadColors.textDisabled),
                  ),
                  trailing: const Icon(Icons.calendar_today, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _newDob ?? DateTime(1990),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                      locale: Localizations.localeOf(context),
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
                        : Text(l10n.subusers_addUser),
                  ),
                ),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (_subUsers.isEmpty)
          EmptyState(icon: Icons.people_outline, title: l10n.subusers_noUsers)
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
                      '${u['email'] ?? ''} · ${l10n.subusers_permissionsCount(activeCount)}/11',
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
                        children: _permissionKeys.map((key) {
                          final val = permissions[key] == true;
                          return SwitchListTile(
                            title: Text(_permissionLabel(key), style: const TextStyle(fontSize: 13)),
                            value: val,
                            onChanged: (v) => _togglePermission(u['id'], key, val),
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
