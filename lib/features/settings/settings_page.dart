import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/api_client.dart';
import '../../core/app_log.dart';
import '../../core/theme.dart';
import '../../core/widgets/client_type_badge.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _api = ApiClient();
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
          final data = await _api.get('/sub-users/$sid');
          final su = data['sub_user'] as Map<String, dynamic>? ?? {};
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
      final data = await _api.get('/clients/$cid');
      final client = data['client'] as Map<String, dynamic>? ?? {};
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
        await _api.multipartPost('/sub-users/$sid/profile', {}, file: file, fileField: 'avatar');
        final data = await _api.get('/sub-users/$sid');
        final su = data['sub_user'] as Map<String, dynamic>?;
        if (su != null) {
          _avatarUrl = su['avatar_url'] as String?;
          await _api.setUserData(avatar: _avatarUrl);
        }
      } else {
        final cid = _api.userId;
        if (cid == null) return;
        await _api.multipartPost('/clients/$cid/profile', {}, file: file, fileField: 'avatar');
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
        final body = <String, dynamic>{
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
        };
        if (_dateOfBirth != null) body['date_of_birth'] = _dateOfBirth!.toIso8601String().substring(0, 10);
        await _api.put('/sub-users/$sid/profile', body);
        await _api.setUserData(name: _nameController.text.trim());
      } else {
        final cid = _api.userId;
        if (cid == null) return;
        final body = <String, dynamic>{
          'contact_person': _nameController.text.trim(),
        };
        if (_dateOfBirth != null) body['date_of_birth'] = _dateOfBirth!.toIso8601String().substring(0, 10);
        await _api.put('/clients/$cid/profile', body);
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
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings_title),),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 52,
              backgroundColor: ShadColors.cardBorder,
              backgroundImage: _avatarUrl != null
                  ? NetworkImage(_api.resolveFileUrl(_avatarUrl!))
                  : null,
              child: _avatarUrl == null
                  ? const Icon(Icons.person, size: 52, color: ShadColors.textDisabled)
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: _pickAvatar,
              icon: const Icon(Icons.camera_alt, size: 16),
              label: Text(l10n.settings_changePicture),
            ),
          ),
          const SizedBox(height: 8),
          if (!_isSubUser) Center(child: ClientTypeBadge(clientType: _clientType)),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: l10n.settings_displayName,
              hintText: l10n.settings_displayNameHint,
            ),
          ),
          const SizedBox(height: 16),
          if (_isSubUser) ...[
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: l10n.settings_email,
                hintText: 'email@example.com',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: l10n.settings_phone,
                hintText: '+966...',
              ),
            ),
          ],
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.settings_dateOfBirth, style: const TextStyle(fontSize: 14)),
            subtitle: Text(
              _dateOfBirth != null
                  ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                  : l10n.settings_notSet,
              style: TextStyle(fontSize: 13, color: _dateOfBirth != null ? ShadColors.textPrimary : ShadColors.textDisabled),
            ),
            trailing: const Icon(Icons.calendar_today, size: 20),
            onTap: _pickDateOfBirth,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Text(l10n.settings_save),
            ),
          ),
        ],
      ),
    );
  }
}
