import 'package:flutter/material.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/api_client.dart';
import '../../core/app_log.dart';
import '../../core/luxe/tokens.dart';
import '../../core/widgets/loading_state.dart';
import '../../core/widgets/luxe/luxe_widgets.dart';
import '../../core/widgets/password_field.dart';
import '../../providers/sub_user_provider.dart';

class SubUsersPage extends StatefulWidget {
  // Optional so this screen can be pumped in a widget test with a mocked
  // SubUserProvider instead of hitting the network.
  final SubUserProvider? subUserProvider;
  final ApiClient? api;
  const SubUsersPage({super.key, this.subUserProvider, this.api});

  @override
  State<SubUsersPage> createState() => _SubUsersPageState();
}

class _SubUsersPageState extends State<SubUsersPage> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final SubUserProvider _subUserProvider = widget.subUserProvider ?? SubUserProvider();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  List<dynamic> _subUsers = [];
  // SUBUSER_PLAN.md §6.1 — fetched from the backend's single source
  // (SubUser::PERMISSION_KEYS via GET /sub-user-permissions) instead of a
  // hardcoded copy in this file.
  List<String> _permissionKeys = [];
  bool _loading = true;
  bool _showForm = false;
  bool _saving = false;
  int? _expandedId;
  DateTime? _newDob;
  bool get _isSubUser => _api.role == 'sub_user';

  // subuser-review-plan.md م٤ — the owning client edits a sub-user's own
  // name/email/phone/DOB, and sets a new password for them (sub-users can no
  // longer do either themselves). Mirrors ClientSubUsers.tsx on the web.
  int? _editingId;
  final _editNameController = TextEditingController();
  final _editEmailController = TextEditingController();
  final _editPhoneController = TextEditingController();
  DateTime? _editDob;
  int? _passwordTargetId;
  final _newPasswordController = TextEditingController();
  int? _passwordSuccessId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // This page is mounted eagerly inside ClientDashboardScreen's
    // IndexedStack for every dashboard load regardless of role (only the
    // *navigation* to it is gated — behind `!_isSubUser` in the "more" menu,
    // and _enforceTabPermission() denies index 7 outright for a sub-user).
    // Without this guard, every sub-user dashboard load fired
    // GET /clients/{id}/sub-users anyway — which SubUserPolicy/
    // ClientController::subUsers() correctly 403s (a sub-user is never
    // allowed to list their colleagues, by design), so this was pure noise:
    // a doomed request and an error log on every single load.
    if (_isSubUser) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final cid = _api.userId;
    if (cid == null) return;
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _subUserProvider.fetchForClient(cid),
        _subUserProvider.fetchPermissionKeys(),
      ]);
      _subUsers = results[0];
      _permissionKeys = results[1] as List<String>;
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
      final data = await _subUserProvider.create(cid, body);
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
      await _subUserProvider.delete(id);
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
      final data = await _subUserProvider.updatePermissions(userId, permissions);
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

  void _startEdit(dynamic user) {
    setState(() {
      _editingId = user['id'] as int;
      _editNameController.text = user['name'] as String? ?? '';
      _editEmailController.text = user['email'] as String? ?? '';
      _editPhoneController.text = user['phone'] as String? ?? '';
      final dob = user['date_of_birth'];
      _editDob = dob != null ? DateTime.tryParse(dob.toString()) : null;
    });
  }

  Future<void> _saveEdit(int id) async {
    final l10n = AppLocalizations.of(context)!;
    final body = <String, dynamic>{
      'name': _editNameController.text.trim(),
      'email': _editEmailController.text.trim(),
      'phone': _editPhoneController.text.trim(),
    };
    if (_editDob != null) body['date_of_birth'] = _editDob!.toIso8601String().substring(0, 10);
    try {
      final data = await _subUserProvider.updateProfile(id, body);
      final idx = _subUsers.indexWhere((u) => u['id'] == id);
      if (idx != -1) {
        setState(() {
          _subUsers[idx] = {..._subUsers[idx] as Map, ...(data['sub_user'] as Map? ?? {})};
          _editingId = null;
        });
      } else {
        setState(() => _editingId = null);
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.subusers_updateFailed)));
    }
  }

  Future<void> _savePassword(int id) async {
    final l10n = AppLocalizations.of(context)!;
    final password = _newPasswordController.text.trim();
    if (password.isEmpty) return;
    try {
      await _subUserProvider.setPassword(id, password);
      setState(() {
        _passwordTargetId = null;
        _newPasswordController.clear();
        _passwordSuccessId = id;
      });
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted && _passwordSuccessId == id) setState(() => _passwordSuccessId = null);
      });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.subusers_passwordChangeFailed)));
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
    _editNameController.dispose();
    _editEmailController.dispose();
    _editPhoneController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Widget _fieldDob({required DateTime? value, required ValueChanged<DateTime> onPick}) {
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime(1990),
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
          locale: Localizations.localeOf(context),
        );
        if (picked != null) onPick(picked);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.subusers_dateOfBirth, style: Lx.text(context, size: 12, color: Lx.muted)),
            const SizedBox(height: 4),
            Text(
              value != null ? '${value.day}/${value.month}/${value.year}' : l10n.subusers_notSet,
              style: Lx.text(context, size: 15, color: value != null ? Lx.ink : Lx.faint),
            ),
          ]),
          const Icon(Icons.calendar_today, size: 17, color: Lx.faint),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState();
    final l10n = AppLocalizations.of(context)!;

    return LuxeFormTheme(
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
        children: [
          LuxePageTitle(l10n.dashboard_team),
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Text('${l10n.subusers_title} (${_subUsers.length})', style: Lx.text(context, size: 13.5, color: Lx.muted)),
          ),
          if (!_isSubUser)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: SizedBox(
                width: double.infinity,
                child: LuxeButton(
                  key: const ValueKey('subusers-add'),
                  label: _showForm ? l10n.cancel : '+ ${l10n.subusers_add}',
                  lxIcon: _showForm ? null : 'plus',
                  kind: LuxeButtonKind.primary,
                  size: LuxeButtonSize.lg,
                  onPressed: () => setState(() => _showForm = !_showForm),
                ),
              ),
            ),
          if (_showForm)
            LuxeCard(
              child: Column(children: [
                TextField(
                  controller: _nameController,
                  style: Lx.text(context, size: 15),
                  decoration: InputDecoration(labelText: l10n.subusers_name, hintText: l10n.subusers_username),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _emailController,
                  style: Lx.text(context, size: 15),
                  decoration: InputDecoration(labelText: l10n.subusers_email, hintText: l10n.subusers_emailHint),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                PasswordField(controller: _passwordController, showRequirements: false),
                const SizedBox(height: 10),
                _fieldDob(value: _newDob, onPick: (d) => setState(() => _newDob = d)),
                const SizedBox(height: 18),
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
          if (_subUsers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text(l10n.subusers_noUsers, style: Lx.text(context, size: 14, color: Lx.muted))),
            )
          else
            ..._subUsers.map((u) {
              final id = u['id'] as int;
              final isEditing = _editingId == id;
              final permissions = _getPermissions(u);
              final activeKeys = _permissionKeys.where((k) => permissions[k] == true).toList();
              return LuxeCard(
                key: ValueKey('subuser-card-$id'),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    LuxeAvatar(initial: _initials(u['name'] as String? ?? '?').substring(0, 1)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(u['name'] ?? '', style: Lx.display(context, size: 16)),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text('${u['email'] ?? ''}', style: Lx.text(context, size: 12.5, color: Lx.muted)),
                        ),
                      ]),
                    ),
                  ]),
                  if (activeKeys.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Wrap(spacing: 5, runSpacing: 5, children: [
                        for (final k in activeKeys)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(Lx.rPill), border: Border.all(color: Lx.line)),
                            child: Text(_permissionLabel(k), style: Lx.text(context, size: 10.5, color: Lx.ink2)),
                          ),
                      ]),
                    ),
                  if (isEditing) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: _editNameController,
                      style: Lx.text(context, size: 15),
                      decoration: InputDecoration(labelText: l10n.subusers_name),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _editEmailController,
                      style: Lx.text(context, size: 15),
                      decoration: InputDecoration(labelText: l10n.subusers_email),
                      keyboardType: TextInputType.emailAddress,
                      textDirection: TextDirection.ltr,
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _editPhoneController,
                      style: Lx.text(context, size: 15),
                      decoration: InputDecoration(labelText: l10n.subusers_phone),
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                    ),
                    if (!_isSubUser)
                      for (final key in _permissionKeys)
                        LuxeSwitchRow(
                          label: _permissionLabel(key),
                          value: permissions[key] == true,
                          onChanged: (v) => _togglePermission(u['id'], key, permissions[key] == true),
                        ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: ElevatedButton(onPressed: () => _saveEdit(id), child: Text(l10n.subusers_save)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(onPressed: () => setState(() => _editingId = null), child: Text(l10n.subusers_cancel)),
                      ),
                    ]),
                  ] else if (!_isSubUser)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Row(children: [
                        Expanded(
                          child: LuxeButton(
                            key: ValueKey('subuser-edit-$id'),
                            label: l10n.subusers_edit,
                            size: LuxeButtonSize.sm,
                            onPressed: () => _startEdit(u),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: LuxeButton(
                            key: ValueKey('subuser-password-$id'),
                            label: l10n.subusers_setPassword,
                            kind: LuxeButtonKind.quiet,
                            size: LuxeButtonSize.sm,
                            onPressed: () => setState(() {
                              _passwordTargetId = id;
                              _newPasswordController.clear();
                            }),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: LuxeButton(
                            key: ValueKey('subuser-delete-$id'),
                            label: AppLocalizations.of(context)!.delete,
                            kind: LuxeButtonKind.danger,
                            size: LuxeButtonSize.sm,
                            onPressed: () => _delete(id),
                          ),
                        ),
                      ]),
                    ),
                  if (_passwordSuccessId == id)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(children: [
                        const LuxeStatusDot(status: LxStatus.ok),
                        const SizedBox(width: 7),
                        Expanded(child: Text(l10n.subusers_passwordChanged, style: Lx.text(context, size: 12, color: Lx.ok))),
                      ]),
                    ),
                  if (_passwordTargetId == id) ...[
                    const SizedBox(height: 14),
                    PasswordField(controller: _newPasswordController, hintText: l10n.subusers_newPasswordHint, showRequirements: false),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: ElevatedButton(onPressed: () => _savePassword(id), child: Text(l10n.subusers_save)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() {
                            _passwordTargetId = null;
                            _newPasswordController.clear();
                          }),
                          child: Text(l10n.subusers_cancel),
                        ),
                      ),
                    ]),
                  ],
                ]),
              );
            }),
        ],
      ),
    );
  }
}
