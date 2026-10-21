import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/api_client.dart';
import '../../core/app_log.dart';
import '../../core/luxe/lx_icons.dart';
import '../../core/luxe/tokens.dart';
import '../../core/widgets/loading_state.dart';
import '../../core/widgets/luxe/luxe_widgets.dart';
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const LxIcon('check', size: 18, color: Lx.ok), const SizedBox(width: 8), Flexible(child: Text(AppLocalizations.of(context)!.profile_imageChanged))])));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const LxIcon('check', size: 18, color: Lx.ok), const SizedBox(width: 8), Flexible(child: Text(AppLocalizations.of(context)!.profile_saved))])));
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.profile_saveFailed)));
    }
    if (mounted) setState(() => _saving = false);
  }

  /// Mockup `.f2`: small muted label over an underline input.
  Widget _f2(String label, Widget input) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Lx.text(context, size: 11, color: Lx.muted)),
          input,
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_loading) {
      return const Scaffold(backgroundColor: Lx.page, body: SafeArea(child: LoadingState(style: LoadingStyle.spinner)));
    }
    final name = _nameController.text.trim();

    // Same look as the staff Settings page (mockup pSettings): back row,
    // "Account" eyebrow + serif title, 64px avatar with a small "Change
    // picture" button, underline fields, full-width crimson Save.
    return Scaffold(
      backgroundColor: Lx.page,
      body: SafeArea(
        child: LuxeFormTheme(
          child: ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 32),
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: InkWell(
                  key: const ValueKey('profile-back'),
                  onTap: () => Navigator.maybePop(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const LxIcon('back', size: 16, color: Lx.muted),
                      const SizedBox(width: 6),
                      Text(l10n.onboarding_back, style: Lx.text(context, size: 13, color: Lx.muted)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(l10n.settingsEyebrow.toUpperCase(), style: Lx.text(context, size: 10.5, color: Lx.faint).copyWith(letterSpacing: 2.73)),
              LuxePageTitle(l10n.profile_title),
              Row(children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: const Color(0xFF262626),
                  backgroundImage: _avatarUrl != null ? NetworkImage(_api.resolveFileUrl(_avatarUrl!)) : null,
                  child: _avatarUrl == null
                      ? Text(name.isEmpty ? '' : String.fromCharCode(name.runes.first), style: Lx.display(context, size: 26))
                      : null,
                ),
                const SizedBox(width: 16),
                LuxeButton(
                  key: const ValueKey('profile-change-picture'),
                  label: l10n.profile_changePicture,
                  size: LuxeButtonSize.sm,
                  onPressed: _pickAvatar,
                ),
              ]),
              const SizedBox(height: 24),
              _f2(
                l10n.profile_displayName,
                TextField(
                  controller: _nameController,
                  style: Lx.text(context, size: 15),
                  decoration: InputDecoration(hintText: l10n.profile_displayNameHint),
                ),
              ),
              if (_isStaff)
                _f2(
                  l10n.staffFieldDob,
                  InkWell(
                    key: const ValueKey('profile-dob'),
                    onTap: _pickDob,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Lx.line2))),
                      child: Row(children: [
                        Expanded(child: Text(_dob ?? '—', style: Lx.text(context, size: 15, color: _dob != null ? Lx.ink : Lx.faint))),
                        const LxIcon('cal', size: 16, color: Lx.faint),
                      ]),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Lx.crimson,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Text(l10n.profile_save),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
