import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../../core/api_client.dart';
import '../../../core/app_log.dart';
import '../../../core/locale_provider.dart';
import '../../../core/luxe/lx_icons.dart';
import '../../../core/luxe/tokens.dart';
import '../../../core/widgets/luxe/luxe_widgets.dart';
import '../../../data/signature_repository.dart';
import '../../../data/system_settings_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/contract_provider.dart';
import '../../../providers/signature_provider.dart';
import '../../../providers/system_settings_provider.dart';
import 'admin_settings_clauses.dart';
import '../../../core/widgets/signature_pad_screen.dart';

class AdminSettingsPage extends StatefulWidget {
  // Optional so this screen can be pumped in a widget test (e.g. embedded
  // inside am_dashboard_page.dart/client_dashboard_screen.dart's
  // IndexedStack, which mounts every tab eagerly) with a mocked ApiClient
  // instead of hitting the network. Defaults to the real singleton — zero
  // behavior change for every existing call site.
  final ApiClient? api;
  final AuthProvider? authProvider;
  final ContractProvider? contractProvider;
  final SignatureProvider? signatureProvider;
  final SystemSettingsProvider? systemSettingsProvider;
  const AdminSettingsPage({super.key, this.api, this.authProvider, this.contractProvider, this.signatureProvider, this.systemSettingsProvider});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final AuthProvider _authProvider = widget.authProvider ?? AuthProvider(api: _api);
  late final ContractProvider _contractProvider = widget.contractProvider ?? ContractProvider(api: _api);
  late final SignatureProvider _signatureProvider = widget.signatureProvider ?? SignatureProvider(repository: SignatureRepository(api: _api));
  late final SystemSettingsProvider _systemSettingsProvider = widget.systemSettingsProvider ?? SystemSettingsProvider(repository: SystemSettingsRepository(api: _api));
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _sigTextController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String _sigMode = 'draw';
  String? _existingSigUrl;
  String? _existingSigText;
  String? _avatarUrl;
  final _taxController = TextEditingController();
  bool _taxSaving = false;
  bool _managersCanReviewFiles = false;
  bool _savingManagersCanReviewFiles = false;
  bool _showContractDates = true;
  bool _savingShowContractDates = false;
  List<Map<String, dynamic>> _clauses = [];
  bool _clausesLoading = true;
  bool _clauseSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _sigTextController.dispose();
    _taxController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _existingSigUrl = null;
      _existingSigText = null;
    });
    try {
      final data = await _authProvider.fetchCurrentUser();
      final user = data['user'] as Map<String, dynamic>? ?? {};
      _emailController.text = (user['official_email'] as String? ?? '');
      _nameController.text = (user['name'] as String? ?? '');
      _avatarUrl = user['avatar_url'] as String?;

      final sigData = user['signature_data'] as String?;
      if (sigData != null && sigData.isNotEmpty) {
        if (sigData.startsWith('http') || sigData.startsWith('/storage')) {
          // signature_url: the backend's signed link — /storage/... doesn't
          // exist in production (23 Sept 2026).
          _existingSigUrl = user['signature_url'] as String? ??
              (sigData.startsWith('http') ? sigData : '${_api.baseUrl.replaceAll('/api', '')}$sigData');
        } else {
          _existingSigText = sigData;
        }
      }
    } catch (e, s) {
      AppLog.error('admin_settings._load(profile)', e, s);
    }
    if (_api.role == 'super_admin') {
      try {
        final settingsData = await _systemSettingsProvider.fetchSettings();
        final settings = settingsData['settings'] as Map<String, dynamic>? ?? {};
        _taxController.text = (settings['corporate_tax_percentage']?['value'] ?? '15').toString();
        final mcr = settings['managers_can_review_files']?['value'];
        _managersCanReviewFiles = mcr == true || mcr == 1 || mcr == '1' || mcr == 'true';
        final scd = settings['show_contract_dates']?['value'];
        _showContractDates = scd == null || scd == true || scd == 1 || scd == '1' || scd == 'true';
      } catch (e, s) {
        AppLog.error('admin_settings._load(settings)', e, s);
      }
      await _loadClauses();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadClauses() async {
    if (mounted) setState(() => _clausesLoading = true);
    try {
      final data = await _contractProvider.fetchAllClauseTemplates();
      final list = (data['templates'] as List<dynamic>? ?? []);
      if (mounted) setState(() => _clauses = list.whereType<Map<String, dynamic>>().toList());
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.adminSettings_clausesLoadFailed)));
    }
    if (mounted) setState(() => _clausesLoading = false);
  }

  Future<void> _saveClause([Map<String, dynamic>? existing]) => showSaveClauseDialog(
    context: context,
    existing: existing,
    contractProvider: _contractProvider,
    setSaving: (v) => setState(() => _clauseSaving = v),
    reloadClauses: _loadClauses,
  );

  Future<void> _deleteClause(Map<String, dynamic> clause) => deleteClauseTemplate(
    context: context,
    clause: clause,
    contractProvider: _contractProvider,
    reloadClauses: _loadClauses,
  );

  Future<void> _toggleClause(Map<String, dynamic> clause) => toggleClauseTemplate(
    context: context,
    clause: clause,
    contractProvider: _contractProvider,
    reloadClauses: _loadClauses,
  );

  Future<void> _moveClause(int index, int delta) async {
    final target = index + delta;
    if (index < 0 || index >= _clauses.length || target < 0 || target >= _clauses.length) return;
    setState(() {
      final item = _clauses.removeAt(index);
      _clauses.insert(target, item);
    });
  }

  Future<void> _saveClauseOrder() => saveClauseTemplateOrder(
    context: context,
    clauses: _clauses,
    contractProvider: _contractProvider,
    reloadClauses: _loadClauses,
  );

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    try {
      final isAM = _api.role == 'account_manager' || _api.role == 'manager_assistant';
      final body = <String, dynamic>{'name': _nameController.text.trim()};
      if (!isAM) body['official_email'] = _emailController.text.trim();
      await _authProvider.updateProfileRaw(body);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle, color: Colors.green, size: 18), const SizedBox(width: 8), Text(AppLocalizations.of(context)!.settingsSaved)])));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppLocalizations.of(context)!.settingsSaveFailed}: $e')));
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _saveTax() async {
    final value = double.tryParse(_taxController.text.trim());
    if (value == null || value < 0 || value > 100) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.settingsTaxInvalid)));
      return;
    }
    setState(() => _taxSaving = true);
    try {
      await _systemSettingsProvider.updateSetting('corporate_tax_percentage', value);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle, color: Colors.green, size: 18), const SizedBox(width: 8), Text(AppLocalizations.of(context)!.settingsTaxSaved)])));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppLocalizations.of(context)!.settingsTaxSaveFailed}: $e')));
    }
    if (mounted) setState(() => _taxSaving = false);
  }

  Future<void> _toggleManagersCanReviewFiles(bool val) async {
    setState(() => _savingManagersCanReviewFiles = true);
    try {
      await _systemSettingsProvider.updateSetting('managers_can_review_files', val ? '1' : '0');
      setState(() => _managersCanReviewFiles = val);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 18),
                const SizedBox(width: 8),
                Text(AppLocalizations.of(context)!.settingsSaved),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.settingsSaveFailed}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingManagersCanReviewFiles = false);
    }
  }

  Future<void> _toggleShowContractDates(bool val) async {
    setState(() => _savingShowContractDates = true);
    try {
      await _systemSettingsProvider.updateSetting('show_contract_dates', val ? '1' : '0');
      setState(() => _showContractDates = val);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 18),
                const SizedBox(width: 8),
                Text(AppLocalizations.of(context)!.settingsSaved),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.settingsSaveFailed}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingShowContractDates = false);
    }
  }

  Future<void> _openFullscreenSignature() async {
    final bytes = await SignaturePadScreen.show(context);
    if (bytes == null) return;
    setState(() => _saving = true);
    try {
      final dir = Directory.systemTemp;
      final file = File('${dir.path}/sig_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      await _signatureProvider.uploadSelfSignatureImage(file);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 18),
                const SizedBox(width: 8),
                Text(AppLocalizations.of(context)!.signatureSaved),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.signatureSaveFailed}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.single.bytes == null) return;
    try {
      final f = result.files.single;
      final response = await _authProvider.uploadAvatarBytes(bytes: f.bytes, filename: f.name);
      final user = response['user'] as Map<String, dynamic>?;
      if (user != null) _avatarUrl = user['avatar_url'] as String?;
      if (mounted) setState(() {});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle, color: Colors.green, size: 18), const SizedBox(width: 8), Text(AppLocalizations.of(context)!.settingsImageChanged)])));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppLocalizations.of(context)!.settingsImageChangeFailed}: $e')));
    }
  }

  Future<void> _saveSignature() async {
    setState(() => _saving = true);
    try {
      if (_sigMode == 'text') {
        final text = _sigTextController.text.trim();
        if (text.isEmpty) return;
        await _signatureProvider.saveSelfSignatureText(text);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle, color: Colors.green, size: 18), const SizedBox(width: 8), Text(AppLocalizations.of(context)!.signatureSaved)])));
        _load();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppLocalizations.of(context)!.signatureSaveFailed}: $e')));
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _deleteSignature() async {
    try {
      await _signatureProvider.deleteSelfSignature();
      setState(() {
        _existingSigUrl = null;
        _existingSigText = null;
      });
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle, color: Colors.green, size: 18), const SizedBox(width: 8), Text(AppLocalizations.of(context)!.signatureDeleted)])));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppLocalizations.of(context)!.signatureDeleteFailed}: $e')));
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.single.path == null) return;
    final file = File(result.files.single.path!);
    try {
      await _signatureProvider.uploadSelfSignatureImage(file);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle, color: Colors.green, size: 18), const SizedBox(width: 8), Text(AppLocalizations.of(context)!.signatureSaved)])));
        _load();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppLocalizations.of(context)!.signatureSaveFailed}: $e')));
    }
  }

  /// Mockup `.segm`: pill group, the selected one lightly filled.
  Widget _segm(List<(String, String)> items, String selected, ValueChanged<String> onTap) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(Lx.rPill), border: Border.all(color: Lx.line2)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final (value, label) in items)
          GestureDetector(
            onTap: () => onTap(value),
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected == value ? const Color(0x14FFFFFF) : Colors.transparent,
                borderRadius: BorderRadius.circular(Lx.rPill),
              ),
              child: Text(label, style: Lx.text(context, size: 12, color: selected == value ? Lx.ink : Lx.muted)),
            ),
          ),
      ]),
    );
  }

  /// Mockup `.sec`: margin 22 0 10, 16px muted icon, serif 18.
  Widget _sec(String icon, String title, {String? count}) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Row(children: [
        LxIcon(icon, size: 16, color: Lx.muted),
        const SizedBox(width: 8),
        Text(title, style: Lx.display(context, size: 18)),
        if (count != null) ...[
          const SizedBox(width: 8),
          Text(count, style: Lx.text(context, size: 12, color: Lx.muted)),
        ],
      ]),
    );
  }

  /// Mockup `.f2`: 12px muted label, then the underlined input (15px).
  Widget _f2(String label, Widget input) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Lx.text(context, size: 12, color: Lx.muted)),
          const SizedBox(height: 6),
          input,
        ]),
      );

  Widget _input(TextEditingController c, {TextInputType? keyboardType, Key? key, String? suffix}) => TextField(
        key: key,
        controller: c,
        keyboardType: keyboardType,
        style: Lx.text(context, size: 15),
        cursorColor: Lx.crimsonInk,
        decoration: InputDecoration(
          isDense: true,
          filled: false,
          suffixText: suffix,
          suffixStyle: Lx.text(context, size: 15, color: Lx.muted),
          contentPadding: const EdgeInsets.only(top: 6, bottom: 9),
          border: const UnderlineInputBorder(borderSide: BorderSide(color: Lx.line2)),
          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Lx.line2)),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Lx.crimsonInk)),
        ),
      );

  /// Mockup `.sigprev`: 84px box, r12, line-2 border, centred script.
  Widget _sigprev(Widget child, {VoidCallback? onTap}) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 84,
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Lx.line2)),
          child: child,
        ),
      );

  /// Mockup settings switch row (`.opt`, align top): label (500) + sub, `.sw2`.
  Widget _swRow(String title, String desc, bool value, ValueChanged<bool>? onChanged, {Key? key, bool last = false}) => Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: Lx.line))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Lx.text(context, size: 13.5, weight: FontWeight.w500)),
              Text(desc, style: Lx.text(context, size: 12.5, color: Lx.muted)),
            ]),
          ),
          const SizedBox(width: 12),
          LuxeToggle(key: key, value: value, onChanged: onChanged),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: Lx.page, body: Center(child: CircularProgressIndicator(color: Lx.crimsonInk)));
    final isAM = _api.role == 'account_manager' || _api.role == 'manager_assistant';
    final l10n = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final h1 = Lx.display(context, size: 28).copyWith(height: 1.2);
    final name = _nameController.text.trim();
    final hasSig = _existingSigUrl != null || _existingSigText != null;
    const script = TextStyle(fontFamily: 'DancingScript', fontSize: 30, color: Lx.ink);

    return Scaffold(
      backgroundColor: Lx.page,
      appBar: AppBar(
        backgroundColor: Lx.page,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Lx.muted),
        title: const SizedBox.shrink(),
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 2, 16, 28),
        children: [
          // Mockup pSettings: head('Account', 'Settings', 'Your profile and language.').
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 6, 0, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.settingsEyebrow.toUpperCase(), style: Lx.text(context, size: 10.5, color: Lx.faint).copyWith(letterSpacing: 2.73)),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: l10n.settingsTitle),
                  TextSpan(text: '.', style: h1.copyWith(color: Lx.crimsonInk, fontStyle: FontStyle.normal)),
                ]),
                key: const ValueKey('lx-page-title'),
                style: h1,
              ),
              const SizedBox(height: 8),
              Text(l10n.settingsLead, style: Lx.text(context, size: 13, color: Lx.muted)),
            ]),
          ),
          // The account manager's own team of company staff (PLAN_2 ف٦).
          if (_api.role == 'account_manager')
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: LuxeCard(
                key: const ValueKey('am-my-team-entry'),
                onTap: () => context.push('/am/my-team'),
                child: Row(children: [
                  const LxIcon('users', size: 18, color: Lx.muted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l10n.mtTitle, style: Lx.text(context, size: 14.5)),
                      Text(l10n.mtSubtitle, style: Lx.text(context, size: 12.5, color: Lx.muted)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right, size: 18, color: Lx.faint),
                ]),
              ),
            ),

          // ── Profile ──
          _sec('users', l10n.settingsProfile),
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Row(children: [
              GestureDetector(
                onTap: _pickAvatar,
                child: _avatarUrl != null
                    ? CircleAvatar(radius: 32, backgroundImage: NetworkImage(_api.resolveFileUrl(_avatarUrl!)))
                    : Container(
                        width: 64,
                        height: 64,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: const Color(0xFF262626), shape: BoxShape.circle, border: Border.all(color: Lx.line2)),
                        child: Text(name.isEmpty ? '·' : name[0].toUpperCase(), style: const TextStyle(fontFamily: Lx.serif, fontStyle: FontStyle.italic, fontSize: 26, color: Lx.ink)),
                      ),
              ),
              const SizedBox(width: 16),
              LuxeButton(key: const ValueKey('settings-change-picture'), label: l10n.profileChangePicture, size: LuxeButtonSize.sm, onPressed: _pickAvatar),
            ]),
          ),
          _f2(l10n.settingsDisplayName, _input(_nameController, key: const ValueKey('settings-name'))),
          if (!isAM) _f2(l10n.settingsOfficialEmail, _input(_emailController, keyboardType: TextInputType.emailAddress, key: const ValueKey('settings-email'))),
          _f2(
            l10n.settingsLanguage,
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: _segm([('en', 'English'), ('ar', 'العربية')], isAr ? 'ar' : 'en', (v) {
                if ((v == 'ar') != isAr) context.read<LocaleProvider>().toggle();
              }),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: LuxeButton(
              key: const ValueKey('settings-save-profile'),
              label: l10n.settingsSaveChanges,
              kind: LuxeButtonKind.primary,
              size: LuxeButtonSize.lg,
              onPressed: _saving ? null : _saveProfile,
            ),
          ),

          // ── Signature (super admin) ──
          if (!isAM) ...[
            _sec('sign', l10n.signatureTitle),
            LuxeCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (hasSig) ...[
                  Row(children: [
                    Expanded(child: LuxeKind(l10n.signatureCurrentSignature)),
                    InkResponse(
                      key: const ValueKey('signature-delete'),
                      onTap: _deleteSignature,
                      radius: 18,
                      child: const Padding(padding: EdgeInsets.all(4), child: LxIcon('trash', size: 16, color: Lx.danger)),
                    ),
                  ]),
                  _sigprev(
                    _existingSigUrl != null
                        ? Padding(padding: const EdgeInsets.all(10), child: Image.network(_existingSigUrl!, fit: BoxFit.contain))
                        : Text(_existingSigText!, style: script),
                  ),
                  Text(l10n.settingsSigUsedFor, style: Lx.text(context, size: 11, color: Lx.faint)),
                  const SizedBox(height: 14),
                ],
                Text((hasSig ? l10n.settingsNewSignature : l10n.settingsAddYourSignature).toUpperCase(),
                    style: Lx.text(context, size: 10.5, color: Lx.faint).copyWith(letterSpacing: 2.73)),
                const SizedBox(height: 8),
                _segm([('draw', l10n.signatureDrawMode), ('text', l10n.signatureTextMode), ('upload', l10n.upload)], _sigMode, (v) => setState(() => _sigMode = v)),
                if (_sigMode == 'draw') ...[
                  _sigprev(Text(l10n.settingsSignHere, style: Lx.text(context, size: 14, color: Lx.faint)), onTap: _saving ? null : _openFullscreenSignature),
                  SizedBox(
                    width: double.infinity,
                    child: LuxeButton(
                      key: const ValueKey('settings-sign-fullscreen'),
                      label: l10n.signatureOpenFullscreen,
                      size: LuxeButtonSize.sm,
                      kind: LuxeButtonKind.primary,
                      onPressed: _saving ? null : _openFullscreenSignature,
                    ),
                  ),
                ],
                if (_sigMode == 'text') ...[
                  _sigprev(
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TextField(
                        controller: _sigTextController,
                        textAlign: TextAlign.center,
                        style: script,
                        cursorColor: Lx.crimsonInk,
                        decoration: InputDecoration(
                          isDense: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          hintText: l10n.settingsSignatureHint,
                          hintStyle: Lx.text(context, size: 14, color: Lx.faint),
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: LuxeButton(
                      key: const ValueKey('settings-save-signature'),
                      label: l10n.signatureSaveSignature,
                      size: LuxeButtonSize.sm,
                      kind: LuxeButtonKind.primary,
                      onPressed: _saving ? null : _saveSignature,
                    ),
                  ),
                ],
                if (_sigMode == 'upload') ...[
                  _sigprev(Row(mainAxisSize: MainAxisSize.min, children: [
                    const LxIcon('up', size: 18, color: Lx.faint),
                    const SizedBox(width: 8),
                    Text(l10n.settingsUploadSignatureImage, style: Lx.text(context, size: 13, color: Lx.faint)),
                  ]), onTap: _saving ? null : _pickImage),
                  SizedBox(
                    width: double.infinity,
                    child: LuxeButton(
                      label: l10n.settingsUploadSignatureImage,
                      lxIcon: 'up',
                      size: LuxeButtonSize.sm,
                      kind: LuxeButtonKind.primary,
                      onPressed: _saving ? null : _pickImage,
                    ),
                  ),
                ],
              ]),
            ),

            // ── System settings ──
            _sec('gear', l10n.settingsSystemSettings),
            LuxeCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l10n.settingsCorporateTax, style: Lx.text(context, size: 13.5, weight: FontWeight.w500)),
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Text(l10n.settingsCorporateTaxDesc, style: Lx.text(context, size: 11, color: Lx.faint)),
                ),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(child: _input(_taxController, keyboardType: const TextInputType.numberWithOptions(decimal: true), key: const ValueKey('settings-tax'), suffix: '%')),
                  const SizedBox(width: 12),
                  LuxeButton(
                    key: const ValueKey('settings-save-tax'),
                    label: l10n.settingsSaveTax,
                    size: LuxeButtonSize.sm,
                    onPressed: _taxSaving ? null : _saveTax,
                  ),
                ]),
              ]),
            ),
            LuxeCard(
              child: Column(children: [
                _swRow(l10n.settingManagersCanReviewFiles, l10n.settingManagersCanReviewFilesDesc, _managersCanReviewFiles,
                    _savingManagersCanReviewFiles ? null : _toggleManagersCanReviewFiles,
                    key: const ValueKey('settings-managers-review')),
                _swRow(l10n.settingShowContractDates, l10n.settingShowContractDatesDesc, _showContractDates,
                    _savingShowContractDates ? null : _toggleShowContractDates,
                    key: const ValueKey('settings-show-dates'), last: true),
              ]),
            ),

            // ── Contract clauses ──
            _sec('list', l10n.adminSettings_clauses, count: _clausesLoading ? null : '${_clauses.length}'),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(l10n.clausesLead, style: Lx.text(context, size: 12.5, color: Lx.muted)),
            ),
            buildClauseTemplatesSection(
              context: context,
              clausesLoading: _clausesLoading,
              clauseSaving: _clauseSaving,
              clauses: _clauses,
              onAdd: () => _saveClause(),
              onMove: _moveClause,
              onSaveOrder: _saveClauseOrder,
              onToggle: _toggleClause,
              onEdit: (clause) => _saveClause(clause),
              onDelete: _deleteClause,
            ),
          ],
        ],
      ),
    );
  }
}
