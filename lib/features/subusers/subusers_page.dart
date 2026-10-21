import 'package:flutter/material.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/api_client.dart';
import '../../core/app_log.dart';
import '../../core/luxe/lx_icons.dart';
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
  final _phoneController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  int? _expandedId;
  DateTime? _newDob;
  bool get _isSubUser => _api.role == 'sub_user';

  // subuser-review-plan.md م٤ — the owning client edits a sub-user's own
  // name/email/phone/DOB, and sets a new password for them (sub-users can no
  // longer do either themselves). Mirrors ClientSubUsers.tsx on the web.
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

  /// Returns true when the member was created (the sheet then closes).
  /// A new sub-user always starts with no permissions on the server, so the
  /// ones ticked in the sheet are sent right after, in a second call.
  Future<bool> _create(Map<String, bool> perms, bool sendEmail) async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (name.isEmpty || email.isEmpty || password.isEmpty) return false;
    final cid = _api.userId;
    if (cid == null) return false;
    setState(() => _saving = true);
    var ok = false;
    try {
      final body = <String, dynamic>{
        'name': name, 'email': email, 'password': password, 'send_email': sendEmail,
      };
      final phone = _phoneController.text.trim();
      if (phone.isNotEmpty) body['phone'] = phone;
      if (_newDob != null) body['date_of_birth'] = _newDob!.toIso8601String().substring(0, 10);
      final data = await _subUserProvider.create(cid, body);
      final created = Map<String, dynamic>.from(data['sub_user'] as Map);
      if (perms.values.any((v) => v) && created['id'] is int) {
        try {
          final upd = await _subUserProvider.updatePermissions(created['id'] as int, perms);
          created['permissions'] = upd['sub_user']?['permissions'] ?? perms;
        } catch (_) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.subusers_updateFailed)));
        }
      }
      _subUsers.add(created);
      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
      _phoneController.clear();
      _newDob = null;
      ok = true;
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.subusers_createFailed)));
    }
    if (mounted) setState(() => _saving = false);
    return ok;
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
      _editNameController.text = user['name'] as String? ?? '';
      _editEmailController.text = user['email'] as String? ?? '';
      _editPhoneController.text = user['phone'] as String? ?? '';
      final dob = user['date_of_birth'];
      _editDob = dob != null ? DateTime.tryParse(dob.toString()) : null;
    });
  }

  Future<bool> _saveEdit(int id) async {
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
        });
      }
      return true;
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.subusers_updateFailed)));
      return false;
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
    _phoneController.dispose();
    _editNameController.dispose();
    _editEmailController.dispose();
    _editPhoneController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  // Mockup permission groups (`t.groups`), headed by the tab they open.
  List<MapEntry<String, List<String>>> _groups() {
    final l10n = AppLocalizations.of(context)!;
    const byGroup = {
      'chat': ['can_chat'],
      'contracts': ['can_view_contracts', 'can_approve_contracts'],
      'payments': ['can_view_payments', 'can_upload_payment_proof'],
      'approvals': ['can_view_approvals', 'can_respond_approvals'],
      'files': ['can_view_files', 'can_upload_files'],
      'meetings': ['can_view_meetings', 'can_join_meetings'],
    };
    final titles = {
      'chat': l10n.dashboard_tab_chat,
      'contracts': l10n.dashboard_tab_contracts,
      'payments': l10n.dashboard_tab_payments,
      'approvals': l10n.dashboard_tab_approvals,
      'files': l10n.dashboard_tab_files,
      'meetings': l10n.dashboard_meetings,
    };
    final known = byGroup.values.expand((k) => k).toSet();
    final out = <MapEntry<String, List<String>>>[
      for (final g in byGroup.entries)
        if (g.value.any(_permissionKeys.contains)) MapEntry(titles[g.key]!, g.value.where(_permissionKeys.contains).toList()),
    ];
    // Any key the backend adds later still shows, in its own group.
    final extra = _permissionKeys.where((k) => !known.contains(k)).toList();
    if (extra.isNotEmpty) out.add(MapEntry('', extra));
    return out;
  }

  /// Mockup `.f2`: small muted label over an underline input.
  Widget _f2(String label, Widget input) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Lx.text(context, size: 11, color: Lx.muted)),
          input,
        ]),
      );

  Widget _fieldDob({required DateTime? value, required ValueChanged<DateTime> onPick}) {
    final l10n = AppLocalizations.of(context)!;
    return _f2(
      l10n.subusers_dateOfBirth,
      InkWell(
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
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Lx.line2))),
          child: Row(children: [
            Expanded(
              child: Text(
                value != null ? '${value.day} / ${value.month} / ${value.year}' : 'DD / MM / YYYY',
                style: Lx.text(context, size: 15, color: value != null ? Lx.ink : Lx.faint),
              ),
            ),
            const LxIcon('cal', size: 16, color: Lx.faint),
          ]),
        ),
      ),
    );
  }

  /// The mockup's `addSheet`, used for both adding and editing a teammate.
  /// Adding: name, email, phone, birthday, password, the permissions to give
  /// and "email the login details". Editing: the same fields minus the
  /// password; each permission switch saves straight away, like before.
  void _openMemberSheet({dynamic user}) {
    final l10n = AppLocalizations.of(context)!;
    final editing = user != null;
    final id = editing ? user['id'] as int : null;
    if (editing) _startEdit(user);
    final draftPerms = <String, bool>{for (final k in _permissionKeys) k: false};
    var sendEmail = true;
    var busy = false;

    showLuxeSheet<void>(context, builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setSheet) {
        final live = editing ? _getPermissions(_subUsers.firstWhere((u) => u['id'] == id, orElse: () => user)) : null;
        bool isOn(String k) => editing ? live![k] == true : draftPerms[k] == true;
        final groups = _groups();
        return LuxeFormTheme(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(editing ? (user['name'] ?? '').toString() : l10n.teamAddTitle, style: Lx.display(ctx, size: 22)),
            const SizedBox(height: 18),
            _f2(l10n.subusers_name, TextField(controller: editing ? _editNameController : _nameController, style: Lx.text(ctx, size: 15))),
            _f2(
              l10n.subusers_email,
              TextField(
                controller: editing ? _editEmailController : _emailController,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                style: Lx.text(ctx, size: 15),
                decoration: const InputDecoration(hintText: 'name@company.com'),
              ),
            ),
            _f2(
              l10n.subusers_phone,
              TextField(
                controller: editing ? _editPhoneController : _phoneController,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                style: Lx.text(ctx, size: 15),
                decoration: const InputDecoration(hintText: '+20'),
              ),
            ),
            _fieldDob(
              value: editing ? _editDob : _newDob,
              onPick: (d) {
                setState(() {
                  if (editing) {
                    _editDob = d;
                  } else {
                    _newDob = d;
                  }
                });
                setSheet(() {});
              },
            ),
            if (!editing) ...[
              PasswordField(controller: _passwordController, showRequirements: false),
              const SizedBox(height: 8),
            ],
            for (final g in groups) ...[
              if (g.key.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 2),
                  child: Text(g.key.toUpperCase(), style: Lx.text(ctx, size: 10.5, color: Lx.faint).copyWith(letterSpacing: 2.2)),
                ),
              for (var i = 0; i < g.value.length; i++)
                LuxeOptRow(
                  label: _permissionLabel(g.value[i]),
                  last: i == g.value.length - 1,
                  trailing: LuxeToggle(
                    key: ValueKey('subuser-perm-${g.value[i]}'),
                    value: isOn(g.value[i]),
                    onChanged: (v) async {
                      final k = g.value[i];
                      if (editing) {
                        await _togglePermission(id!, k, live![k] == true);
                      } else {
                        draftPerms[k] = v;
                      }
                      setSheet(() {});
                    },
                  ),
                ),
            ],
            if (!editing)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: LuxeOptRow(
                  label: l10n.teamSendLogin,
                  last: true,
                  trailing: LuxeToggle(
                    key: const ValueKey('subuser-send-email'),
                    value: sendEmail,
                    onChanged: (v) => setSheet(() => sendEmail = v),
                  ),
                ),
              ),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                child: ElevatedButton(
                  key: const ValueKey('subuser-sheet-save'),
                  onPressed: busy
                      ? null
                      : () async {
                          setSheet(() => busy = true);
                          final ok = editing ? await _saveEdit(id!) : await _create(draftPerms, sendEmail);
                          if (!ctx.mounted) return;
                          setSheet(() => busy = false);
                          if (ok) Navigator.pop(ctx);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Lx.crimson,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  child: busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(editing ? l10n.subusers_save : l10n.subusers_addUser),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: LuxeButton(
                  label: l10n.subusers_cancel,
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ]),
          ]),
        );
      });
    });
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
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(l10n.teamLead, style: Lx.text(context, size: 13.5, color: Lx.muted, height: 1.5)),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Text('${l10n.subusers_title} (${_subUsers.length})', style: Lx.text(context, size: 11.5, color: Lx.faint)),
          ),
          if (!_isSubUser)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: SizedBox(
                width: double.infinity,
                child: LuxeButton(
                  key: const ValueKey('subusers-add'),
                  label: l10n.teamAdd,
                  lxIcon: 'plus',
                  kind: LuxeButtonKind.primary,
                  size: LuxeButtonSize.lg,
                  onPressed: _saving ? null : () => _openMemberSheet(),
                ),
              ),
            ),
          if (_subUsers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text(l10n.subusers_noUsers, style: Lx.text(context, size: 14, color: Lx.muted))),
            )
          else
            ..._subUsers.map((u) {
              final id = u['id'] as int;
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
                  // Mockup `.perm`: one small pill per permission given.
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
                  if (!_isSubUser)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Wrap(spacing: 8, runSpacing: 8, children: [
                        LuxeButton(
                          key: ValueKey('subuser-edit-$id'),
                          label: l10n.subusers_edit,
                          size: LuxeButtonSize.sm,
                          onPressed: () => _openMemberSheet(user: u),
                        ),
                        LuxeButton(
                          key: ValueKey('subuser-password-$id'),
                          label: l10n.subusers_setPassword,
                          kind: LuxeButtonKind.quiet,
                          size: LuxeButtonSize.sm,
                          onPressed: () => setState(() {
                            _passwordTargetId = id;
                            _newPasswordController.clear();
                          }),
                        ),
                        LuxeButton(
                          key: ValueKey('subuser-delete-$id'),
                          label: AppLocalizations.of(context)!.delete,
                          kind: LuxeButtonKind.danger,
                          size: LuxeButtonSize.sm,
                          onPressed: () => _delete(id),
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
                        child: ElevatedButton(
                          onPressed: () => _savePassword(id),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Lx.crimson,
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                            elevation: 0,
                          ),
                          child: Text(l10n.subusers_save),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: LuxeButton(
                          label: l10n.subusers_cancel,
                          onPressed: () => setState(() {
                            _passwordTargetId = null;
                            _newPasswordController.clear();
                          }),
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
