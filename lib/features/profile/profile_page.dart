import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/api_client.dart';
import '../../core/app_log.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

class ProfilePage extends StatefulWidget {
  // Optional so this screen can be pumped in a widget test with a mocked
  // AuthProvider instead of hitting the network.
  final AuthProvider? authProvider;
  final ApiClient? api;
  const ProfilePage({super.key, this.authProvider, this.api});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final AuthProvider _authProvider = widget.authProvider ?? AuthProvider();
  final _nameController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _avatarUrl;
  // Company staff also keep a birth date here (STAFF_TEAMS_PLAN.md); everyone
  // else's profile screen is unchanged.
  String? _dob;
  bool get _isStaff => _api.role == 'staff_member';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _authProvider.fetchCurrentUser();
      final user = data['user'] as Map<String, dynamic>? ?? {};
      _nameController.text = (user['name'] as String? ?? '');
      _avatarUrl = user['avatar_url'] as String?;
      final dob = user['date_of_birth'] as String?;
      _dob = (dob == null || dob.isEmpty) ? null : dob.substring(0, dob.length < 10 ? dob.length : 10);
    } catch (e, s) {
      AppLog.error('profile_page._load', e, s);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.single.path == null) return;
    final file = File(result.files.single.path!);
    try {
      await _authProvider.uploadAvatar(file);
      _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle, color: Colors.green, size: 18), const SizedBox(width: 8), Text(AppLocalizations.of(context)!.profile_imageChanged)])));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.profile_imageChangeFailed)));
    }
  }

  Future<void> _pickDob() async {
    final initial = DateTime.tryParse(_dob ?? '') ?? DateTime(1990, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    final mm = picked.month.toString().padLeft(2, '0');
    final dd = picked.day.toString().padLeft(2, '0');
    setState(() => _dob = '${picked.year}-$mm-$dd');
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      if (_isStaff) {
        await _authProvider.updateProfileRaw({'name': _nameController.text.trim(), 'date_of_birth': _dob});
      } else {
        await _authProvider.updateProfile(name: _nameController.text.trim());
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle, color: Colors.green, size: 18), const SizedBox(width: 8), Text(AppLocalizations.of(context)!.profile_saved)])));
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.profile_saveFailed)));
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profile_title),),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: _pickAvatar,
            child: Center(
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
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: _pickAvatar,
              icon: const Icon(Icons.camera_alt, size: 16),
              label: Text(l10n.profile_changePicture),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: l10n.profile_displayName,
              hintText: l10n.profile_displayNameHint,
            ),
          ),
          if (_isStaff) ...[
            const SizedBox(height: 16),
            ListTile(
              key: const ValueKey('profile-dob'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cake_outlined),
              title: Text(l10n.staffFieldDob),
              subtitle: Text(_dob ?? '—'),
              onTap: _pickDob,
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Text(l10n.profile_save),
            ),
          ),
        ],
      ),
    );
  }
}
