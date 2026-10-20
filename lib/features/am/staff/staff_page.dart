import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../../core/api_client.dart';
import '../../../core/app_log.dart';
import '../../../core/luxe/tokens.dart';
import '../../../core/widgets/luxe/luxe_widgets.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../data/staff_repository.dart';

/// Company staff, managed by the super admin (STAFF_TEAMS_PLAN.md ف٦): list,
/// add, edit, change password, archive / unarchive, and see which clients
/// each member is on. Staff are never deleted — archiving keeps the name on
/// past chats and audit rows. The backend refuses everyone but the super admin.
class StaffPage extends StatefulWidget {
  final StaffRepository? repository;
  final ApiClient? api;
  const StaffPage({super.key, this.repository, this.api});

  @override
  State<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends State<StaffPage> {
  late final StaffRepository _repo = widget.repository ?? StaffRepository(api: widget.api);
  List<Map<String, dynamic>> _staff = [];
  bool _loading = true;
  bool _failed = false;
  bool _includeArchived = false;
  int? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final rows = await _repo.fetchAll(includeArchived: _includeArchived);
      if (!mounted) return;
      setState(() {
        _staff = rows;
        _loading = false;
      });
    } catch (e, s) {
      AppLog.error('staff_page._load', e, s);
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _errorText(Object e, AppLocalizations l10n) {
    if (e is ValidationException) return e.message;
    return l10n.staffSaveFailed;
  }

  Future<void> _openForm([Map<String, dynamic>? member]) async {
    final saved = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Lx.sheet,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _StaffForm(repository: _repo, member: member),
    );
    if (saved != null) {
      _snack(saved);
      _load();
    }
  }

  Future<void> _openPassword(Map<String, dynamic> member) async {
    final saved = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Lx.sheet,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PasswordForm(repository: _repo, member: member),
    );
    if (saved != null) _snack(saved);
  }

  Future<void> _toggleArchive(Map<String, dynamic> member) async {
    final l10n = AppLocalizations.of(context)!;
    final archived = member['archived_at'] != null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(archived ? l10n.staffUnarchiveConfirm : l10n.staffArchiveConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          ElevatedButton(
            key: const ValueKey('staff-confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(archived ? l10n.staffUnarchiveAction : l10n.staffArchiveAction),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final id = member['id'] as int;
    setState(() => _busyId = id);
    try {
      if (archived) {
        await _repo.unarchive(id);
      } else {
        await _repo.archive(id);
      }
      _snack(archived ? l10n.staffUnarchivedMsg : l10n.staffArchivedMsg);
      await _load();
    } catch (e, s) {
      AppLog.error('staff_page._toggleArchive', e, s);
      _snack(_errorText(e, l10n));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _openClients(Map<String, dynamic> member) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Lx.sheet,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ClientsSheet(repository: _repo, member: member),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Lx.page,
      appBar: AppBar(
        backgroundColor: Lx.page,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Lx.muted),
        title: const SizedBox.shrink(),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('staff-add'),
        backgroundColor: Lx.crimson,
        foregroundColor: Colors.white,
        elevation: 0,
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: Text(l10n.staffAdd),
      ),
      body: LuxeFormTheme(child: Column(children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 0),
            child: LuxePageTitle(l10n.staffNavTitle),
          ),
        ),
        SwitchListTile(
          key: const ValueKey('staff-show-archived'),
          dense: true,
          title: Text(l10n.staffShowArchived, style: Lx.text(context, size: 13)),
          value: _includeArchived,
          onChanged: (v) {
            setState(() => _includeArchived = v);
            _load();
          },
        ),
        Expanded(child: _body(l10n)),
      ])),
    );
  }

  Widget _body(AppLocalizations l10n) {
    if (_loading) return const LoadingState();
    if (_failed) return ErrorState(message: l10n.staffLoadFailed, onRetry: _load);
    if (_staff.isEmpty) return EmptyState(icon: Icons.badge_outlined, title: l10n.staffEmpty);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
        children: [for (final m in _staff) _card(m, l10n)],
      ),
    );
  }

  Widget _card(Map<String, dynamic> m, AppLocalizations l10n) {
    final archived = m['archived_at'] != null;
    final name = (m['name'] as String?) ?? '';
    final count = m['assigned_clients_count'] ?? 0;
    final busy = _busyId == m['id'];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              backgroundColor: Lx.crimson.withAlpha(40),
              backgroundImage: (m['avatar_url'] as String?)?.isNotEmpty == true ? NetworkImage(ApiClient().resolveFileUrl(m['avatar_url'] as String)) : null,
              child: (m['avatar_url'] as String?)?.isNotEmpty == true
                  ? null
                  : Text(name.isEmpty ? '?' : name.substring(0, 1), style: const TextStyle(color: Lx.crimson, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
                  if (archived) ...[
                    const SizedBox(width: 6),
                    Text(l10n.staffArchivedBadge, style: const TextStyle(fontSize: 10, color: Lx.faint)),
                  ],
                ]),
                Text('${m['email'] ?? ''}', style: const TextStyle(fontSize: 11, color: Lx.muted)),
                Text('${l10n.staffClientsLabel}: $count', style: const TextStyle(fontSize: 11, color: Lx.muted)),
                if (safeList(m['teams']).isNotEmpty)
                  Text(
                    l10n.mtInTeams(safeList(m['teams']).map((t) => t is Map ? '${t['name']}' : '').where((n) => n.isNotEmpty).join('، ')),
                    key: ValueKey('staff-teams-${m['id']}'),
                    style: const TextStyle(fontSize: 11, color: Lx.muted),
                  ),
              ]),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [
            _action(l10n.staffClientsLabel, () => _openClients(m), key: 'staff-clients-${m['id']}'),
            _action(l10n.staffEditAction, () => _openForm(m), key: 'staff-edit-${m['id']}'),
            _action(l10n.staffChangePassword, () => _openPassword(m), key: 'staff-password-${m['id']}'),
            _action(
              archived ? l10n.staffUnarchiveAction : l10n.staffArchiveAction,
              busy ? null : () => _toggleArchive(m),
              key: 'staff-archive-${m['id']}',
              color: archived ? Lx.ok : Lx.crimson,
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _action(String label, VoidCallback? onTap, {required String key, Color? color}) {
    return OutlinedButton(
      key: ValueKey(key),
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        foregroundColor: color,
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }
}

class _StaffForm extends StatefulWidget {
  final StaffRepository repository;
  final Map<String, dynamic>? member;
  const _StaffForm({required this.repository, this.member});

  @override
  State<_StaffForm> createState() => _StaffFormState();
}

class _StaffFormState extends State<_StaffForm> {
  late final _name = TextEditingController(text: widget.member?['name'] as String? ?? '');
  late final _email = TextEditingController(text: widget.member?['email'] as String? ?? '');
  late final _phone = TextEditingController(text: widget.member?['phone'] as String? ?? '');
  final _password = TextEditingController();
  String? _dob;
  bool _sendEmail = true;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.member != null;

  @override
  void initState() {
    super.initState();
    final dob = widget.member?['date_of_birth'] as String?;
    if (dob != null && dob.isNotEmpty) _dob = dob.substring(0, dob.length < 10 ? dob.length : 10);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_dob ?? '') ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    final mm = picked.month.toString().padLeft(2, '0');
    final dd = picked.day.toString().padLeft(2, '0');
    setState(() => _dob = '${picked.year}-$mm-$dd');
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final phone = _phone.text.trim().isEmpty ? null : _phone.text.trim();
      if (_editing) {
        await widget.repository.update(widget.member!['id'] as int, name: _name.text.trim(), email: _email.text.trim(), phone: phone, dateOfBirth: _dob);
        if (mounted) Navigator.pop(context, l10n.staffUpdatedMsg);
      } else {
        await widget.repository.create(
          name: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          phone: phone,
          dateOfBirth: _dob,
          sendEmail: _sendEmail,
        );
        if (mounted) Navigator.pop(context, l10n.staffCreatedMsg);
      }
    } catch (e, s) {
      AppLog.error('staff_form._save', e, s);
      if (mounted) {
        setState(() {
          _error = e is ValidationException ? e.message : l10n.staffSaveFailed;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(_editing ? l10n.staffEditAction : l10n.staffAdd, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, style: const TextStyle(color: Lx.crimson, fontSize: 13))),
          TextField(key: const ValueKey('staff-form-name'), controller: _name, decoration: InputDecoration(labelText: l10n.staffFieldName)),
          const SizedBox(height: 8),
          TextField(key: const ValueKey('staff-form-email'), controller: _email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: l10n.staffFieldEmail)),
          const SizedBox(height: 8),
          TextField(key: const ValueKey('staff-form-phone'), controller: _phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: l10n.staffFieldPhone)),
          ListTile(
            key: const ValueKey('staff-form-dob'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.staffFieldDob),
            subtitle: Text(_dob ?? '—'),
            trailing: const Icon(Icons.calendar_today_outlined, size: 18),
            onTap: _pickDob,
          ),
          if (!_editing) ...[
            TextField(key: const ValueKey('staff-form-password'), controller: _password, obscureText: true, decoration: InputDecoration(labelText: l10n.staffFieldPassword)),
            CheckboxListTile(
              key: const ValueKey('staff-form-send-email'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(l10n.staffSendEmail, style: const TextStyle(fontSize: 13)),
              value: _sendEmail,
              onChanged: (v) => setState(() => _sendEmail = v ?? true),
            ),
          ],
          const SizedBox(height: 8),
          ElevatedButton(
            key: const ValueKey('staff-form-save'),
            onPressed: _saving ? null : _save,
            child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(l10n.staffSaveAction),
          ),
        ]),
      ),
    );
  }
}

class _PasswordForm extends StatefulWidget {
  final StaffRepository repository;
  final Map<String, dynamic> member;
  const _PasswordForm({required this.repository, required this.member});

  @override
  State<_PasswordForm> createState() => _PasswordFormState();
}

class _PasswordFormState extends State<_PasswordForm> {
  final _password = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.changePassword(widget.member['id'] as int, _password.text);
      if (mounted) Navigator.pop(context, l10n.staffPasswordChangedMsg);
    } catch (e, s) {
      AppLog.error('staff_password._save', e, s);
      if (mounted) {
        setState(() {
          _error = e is ValidationException ? e.message : l10n.staffSaveFailed;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${l10n.staffChangePassword} — ${widget.member['name'] ?? ''}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, style: const TextStyle(color: Lx.crimson, fontSize: 13))),
        TextField(key: const ValueKey('staff-password-field'), controller: _password, obscureText: true, decoration: InputDecoration(labelText: l10n.staffFieldPassword)),
        const SizedBox(height: 12),
        ElevatedButton(
          key: const ValueKey('staff-password-save'),
          onPressed: _saving ? null : _save,
          child: Text(l10n.staffSaveAction),
        ),
      ]),
    );
  }
}

class _ClientsSheet extends StatefulWidget {
  final StaffRepository repository;
  final Map<String, dynamic> member;
  const _ClientsSheet({required this.repository, required this.member});

  @override
  State<_ClientsSheet> createState() => _ClientsSheetState();
}

class _ClientsSheetState extends State<_ClientsSheet> {
  List<Map<String, dynamic>> _clients = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await widget.repository.clientsOf(widget.member['id'] as int);
      if (mounted) setState(() => _clients = rows);
    } catch (e, s) {
      AppLog.error('staff_clients_sheet._load', e, s);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${l10n.staffClientsLabel} — ${widget.member['name'] ?? ''}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
        else if (_clients.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Center(child: Text(l10n.staffNoClients, style: const TextStyle(color: Lx.faint))))
        else
          Flexible(
            child: ListView(shrinkWrap: true, children: [
              for (final c in _clients)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${c['name'] ?? '#${c['client_id']}'}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: (c['manager'] is Map) ? Text('${(c['manager'] as Map)['name'] ?? ''}', style: const TextStyle(fontSize: 11)) : null,
                ),
            ]),
          ),
      ]),
    );
  }
}
