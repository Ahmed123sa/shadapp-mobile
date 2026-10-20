import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/api_client.dart';
import '../../core/app_log.dart';
import '../../core/luxe/lx_icons.dart';
import '../../core/luxe/tokens.dart';
import '../../core/widgets/luxe/luxe_widgets.dart';
import '../../core/widgets/client_type_badge.dart';
import '../../providers/settings_provider.dart';

class SettingsPage extends StatefulWidget {
  // Optional so this screen can be pumped in a widget test with a mocked
  // SettingsProvider instead of hitting the network.
  final SettingsProvider? settingsProvider;
  final ApiClient? api;
  const SettingsPage({super.key, this.settingsProvider, this.api});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final SettingsProvider _settingsProvider = widget.settingsProvider ?? SettingsProvider();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _avatarUrl;
  String? _clientType;
  DateTime? _dateOfBirth;
  bool get _isSubUser => _api.role == 'sub_user';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_isSubUser) {
      _nameController.text = _api.userName ?? '';
      _avatarUrl = _api.avatarUrl;
      final sid = _api.subUserId;
      if (sid != null) {
        try {
          final su = await _settingsProvider.fetchSubUser(sid);
          _emailController.text = su['email'] as String? ?? '';
          _phoneController.text = su['phone'] as String? ?? '';
          if (su['date_of_birth'] != null) {
            _dateOfBirth = DateTime.tryParse(su['date_of_birth']);
          }
        } catch (e, s) {
          AppLog.error('settings_page._load(subUser)', e, s);
        }
      }
      if (mounted) setState(() => _loading = false);
      return;
    }
    final cid = _api.userId;
    if (cid == null) return;
    try {
      final client = await _settingsProvider.fetchClient(cid);
      _nameController.text = (client['contact_person'] as String? ?? '');
      _avatarUrl = client['avatar_url'] as String?;
      _clientType = client['client_type'] as String?;
      _emailController.text = client['email'] as String? ?? '';
      if (client['date_of_birth'] != null) {
        _dateOfBirth = DateTime.tryParse(client['date_of_birth'].toString());
      }
    } catch (e, s) {
      AppLog.error('settings_page._load(client)', e, s);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: now,
      locale: Localizations.localeOf(context),
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.single.path == null) return;
    final file = File(result.files.single.path!);
    try {
      if (_isSubUser) {
        final sid = _api.subUserId;
        if (sid == null) return;
        await _settingsProvider.uploadSubUserAvatar(sid, file);
        final su = await _settingsProvider.fetchSubUser(sid);
        _avatarUrl = su['avatar_url'] as String?;
        await _api.setUserData(avatar: _avatarUrl);
      } else {
        final cid = _api.userId;
        if (cid == null) return;
        await _settingsProvider.uploadClientAvatar(cid, file);
        _load();
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle, color: Colors.green, size: 18), const SizedBox(width: 8), Text(AppLocalizations.of(context)!.settings_imageChanged)])));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.settings_imageChangeFailed)));
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      if (_isSubUser) {
        final sid = _api.subUserId;
        if (sid == null) return;
        // subuser-review-plan.md م٤ — email is the sub-user's login; only the
        // owning client can change it (SubUserController::updateProfile
        // 403s a sub-user who tries). It used to be sent here unconditionally,
        // which meant an unchanged value would round-trip harmlessly today
        // but any edit to the (still-editable) field below would 403 the
        // whole save. The field itself is now read-only, and 'email' is
        // dropped from this payload entirely.
        final body = <String, dynamic>{
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
        };
        if (_dateOfBirth != null) body['date_of_birth'] = _dateOfBirth!.toIso8601String().substring(0, 10);
        await _settingsProvider.updateSubUserProfile(sid, body);
        await _api.setUserData(name: _nameController.text.trim());
      } else {
        final cid = _api.userId;
        if (cid == null) return;
        final body = <String, dynamic>{
          'contact_person': _nameController.text.trim(),
        };
        if (_dateOfBirth != null) body['date_of_birth'] = _dateOfBirth!.toIso8601String().substring(0, 10);
        await _settingsProvider.updateClientProfile(cid, body);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle, color: Colors.green, size: 18), const SizedBox(width: 8), Text(AppLocalizations.of(context)!.settings_saved)])));
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.settings_saveFailed)));
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_loading) {
      return const Scaffold(backgroundColor: Lx.page, body: Center(child: CircularProgressIndicator(color: Lx.crimsonInk)));
    }

    return Scaffold(
      backgroundColor: Lx.page,
      appBar: AppBar(
        backgroundColor: Lx.page,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Lx.muted),
        title: Text(l10n.settings_title, style: Lx.display(context, size: 26)),
      ),
      body: LuxeFormTheme(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Row(children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: const Color(0xFF262626),
                backgroundImage: _avatarUrl != null ? NetworkImage(_api.resolveFileUrl(_avatarUrl!)) : null,
                child: _avatarUrl == null ? const Icon(Icons.person, size: 30, color: Lx.faint) : null,
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: _pickAvatar,
                icon: const Icon(Icons.camera_alt, size: 16),
                label: Text(l10n.settings_changePicture),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 14)),
              ),
            ]),
            const SizedBox(height: 14),
            if (!_isSubUser) Align(alignment: AlignmentDirectional.centerStart, child: ClientTypeBadge(clientType: _clientType)),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              style: Lx.text(context, size: 15),
              decoration: InputDecoration(
                labelText: l10n.settings_displayName,
                hintText: l10n.settings_displayNameHint,
              ),
            ),
            const SizedBox(height: 18),
            if (_isSubUser) ...[
              TextField(
                controller: _emailController,
                enabled: false,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                style: Lx.text(context, size: 15, color: Lx.muted),
                decoration: InputDecoration(
                  labelText: l10n.settings_email,
                  hintText: 'email@example.com',
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 18),
                child: Row(children: [
                  const LxIcon('lock', size: 14, color: Lx.faint),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l10n.settings_contactOwnerForEmail, style: Lx.text(context, size: 12.5, color: Lx.faint))),
                ]),
              ),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                style: Lx.text(context, size: 15),
                decoration: InputDecoration(
                  labelText: l10n.settings_phone,
                  hintText: '+966...',
                ),
              ),
              const SizedBox(height: 18),
            ],
            InkWell(
              onTap: _pickDateOfBirth,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l10n.settings_dateOfBirth, style: Lx.text(context, size: 12, color: Lx.muted)),
                    const SizedBox(height: 4),
                    Text(
                      _dateOfBirth != null
                          ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                          : l10n.settings_notSet,
                      style: Lx.text(context, size: 15, color: _dateOfBirth != null ? Lx.ink : Lx.faint),
                    ),
                  ]),
                  const Icon(Icons.calendar_today, size: 17, color: Lx.faint),
                ]),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
                child: _saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Text(l10n.settings_save),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
