import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../../core/api_client.dart';
import '../../../core/app_log.dart';
import '../../../core/theme.dart';
import '../../../data/signature_repository.dart';
import '../../../data/system_settings_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/contract_provider.dart';
import '../../../providers/signature_provider.dart';
import '../../../providers/system_settings_provider.dart';
import '../../signature/render_signature.dart';
import 'admin_settings_clauses.dart';

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
  final _boundaryKey = GlobalKey();
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];
  bool _loading = true;
  bool _saving = false;
  String _sigMode = 'draw';
  String? _existingSigUrl;
  String? _existingSigText;
  String? _avatarUrl;
  final _taxController = TextEditingController();
  bool _taxSaving = false;
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
    try {
      final data = await _authProvider.fetchCurrentUser();
      final user = data['user'] as Map<String, dynamic>? ?? {};
      _emailController.text = (user['official_email'] as String? ?? '');
      _nameController.text = (user['name'] as String? ?? '');
      _avatarUrl = user['avatar_url'] as String?;

      final sigData = user['signature_data'] as String?;
      if (sigData != null && sigData.isNotEmpty) {
        if (sigData.startsWith('http') || sigData.startsWith('/storage')) {
          _existingSigUrl = sigData.startsWith('http') ? sigData : '${_api.baseUrl.replaceAll('/api', '')}$sigData';
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
      final isAM = _api.role == 'account_manager';
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
      if (_sigMode == 'draw') {
        if (_strokes.isEmpty && _currentStroke.isEmpty) {
          if (mounted) setState(() => _saving = false);
          return;
        }
        final renderBox = _boundaryKey.currentContext?.findRenderObject() as RenderBox?;
        final size = renderBox?.size ?? const Size(400, 200);
        final pngBytes = await renderSignatureAsPng(strokes: _strokes, currentStroke: _currentStroke, size: size);
        final dir = Directory.systemTemp;
        final file = File('${dir.path}/sig_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(pngBytes);
        await _signatureProvider.uploadSelfSignatureImage(file);
      } else if (_sigMode == 'text') {
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

  void _clearStrokes() => setState(() { _strokes.clear(); _currentStroke.clear(); });

  Future<void> _deleteSignature() async {
    try {
      await _signatureProvider.deleteSelfSignature();
      await _load();
      if (mounted)       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle, color: Colors.green, size: 18), const SizedBox(width: 8), Text(AppLocalizations.of(context)!.signatureDeleted)])));
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

  Widget _modeChip(String value, String label, IconData icon) {
    final selected = _sigMode == value;
    return GestureDetector(
      onTap: () => setState(() => _sigMode = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? ShadColors.crimson : ShadColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? ShadColors.crimson : ShadColors.cardBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: selected ? ShadColors.textOnCrimson : ShadColors.textSecondary),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: selected ? ShadColors.textOnCrimson : ShadColors.textSecondary)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final isAM = _api.role == 'account_manager';
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, fontFamily: 'PlayfairDisplay', color: ShadColors.gold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ═══════════════════════════════════════
          // Section 1: Profile
          // ═══════════════════════════════════════
          _sectionHeader(Icons.person_outline, l10n.settingsProfile),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ShadColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ShadColors.cardBorder),
            ),
            child: Column(children: [
              // Avatar
              GestureDetector(
                onTap: _pickAvatar,
                child: Stack(children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: ShadColors.crimson,
                    backgroundImage: _avatarUrl != null ? NetworkImage(_api.resolveFileUrl(_avatarUrl!)) : null,
                    child: _avatarUrl == null
                        ? const Icon(Icons.person, size: 40, color: ShadColors.gold)
                        : null,
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: ShadColors.gold, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, size: 14, color: ShadColors.background),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: _pickAvatar,
                child: Text(l10n.profileChangePicture, style: const TextStyle(fontSize: 11, color: ShadColors.gold, fontFamily: 'Archivo')),
              ),
              const SizedBox(height: 12),
              // Name field
              _settingsField(
                controller: _nameController,
                label: l10n.settingsName,
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 12),
              // Email field (SA only)
              if (!isAM)
                _settingsField(
                  controller: _emailController,
                  label: l10n.settingsOfficialEmail,
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
              if (!isAM) const SizedBox(height: 16),
              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ShadColors.gold,
                    foregroundColor: ShadColors.background,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _saving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Text(l10n.settingsSaveChanges, style: const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Archivo')),
                ),
              ),
            ]),
          ),

          // ═══════════════════════════════════════
          // Section 2: Signature (SA only)
          // ═══════════════════════════════════════
          if (!isAM) ...[
            const SizedBox(height: 20),
            _sectionHeader(Icons.draw_outlined, l10n.signatureTitle),
            const SizedBox(height: 8),

            // Card 1: Current signature
            if (_existingSigUrl != null || _existingSigText != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ShadColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ShadColors.cardBorder),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.verified, size: 14, color: ShadColors.success),
                    const SizedBox(width: 6),
                    Text(l10n.signatureCurrentSignature, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ShadColors.gold, fontFamily: 'Archivo')),
                    const Spacer(),
                    GestureDetector(
                      onTap: _deleteSignature,
                      child: const Icon(Icons.delete_outline, size: 16, color: ShadColors.error),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  if (_existingSigUrl != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ShadColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: ShadColors.cardBorder),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(_existingSigUrl!, height: 50, fit: BoxFit.contain),
                      ),
                    ),
                  if (_existingSigText != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: ShadColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: ShadColors.cardBorder),
                      ),
                      child: Center(
                        child: Text(_existingSigText!, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w400, fontFamily: 'DancingScript', color: ShadColors.gold)),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 12),
            ],

            // Card 2: New signature
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ShadColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ShadColors.cardBorder),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.add_circle_outline, size: 14, color: ShadColors.gold),
                  const SizedBox(width: 6),
                  Text(
                    (_existingSigUrl != null || _existingSigText != null) ? l10n.settingsNewSignature : l10n.settingsAddYourSignature,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ShadColors.gold, fontFamily: 'Archivo'),
                  ),
                ]),
                const SizedBox(height: 12),

                // Mode chips
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _modeChip('draw', l10n.signatureDrawMode, Icons.brush),
                  const SizedBox(width: 8),
                  _modeChip('text', l10n.signatureTextMode, Icons.text_fields),
                ]),
                const SizedBox(height: 10),

                // Upload image button (always visible)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image, size: 16, color: ShadColors.gold),
                    label: Text(l10n.settingsUploadSignatureImage, style: const TextStyle(color: ShadColors.gold, fontSize: 12, fontFamily: 'Archivo')),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: ShadColors.gold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Draw mode
                if (_sigMode == 'draw') ...[
                  _subLabel(l10n.settingsSignHere),
                  const SizedBox(height: 6),
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: ShadColors.black,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ShadColors.cardBorder),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: GestureDetector(
                        onPanStart: (_) => setState(() => _currentStroke = []),
                        onPanUpdate: (details) => setState(() => _currentStroke.add(details.localPosition)),
                        onPanEnd: (_) => setState(() { _strokes.add(List.from(_currentStroke)); _currentStroke = []; }),
                        child: RepaintBoundary(
                          key: _boundaryKey,
                          child: CustomPaint(
                            painter: _SigPainter(strokes: _strokes, currentStroke: _currentStroke),
                            size: Size.infinite,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(
                      onPressed: _clearStrokes,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: Text(l10n.signatureClear, style: const TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ShadColors.textSecondary,
                        side: const BorderSide(color: ShadColors.cardBorder),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    )),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _saveSignature,
                        icon: _saving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check_circle, size: 18),
                        label: Text(l10n.signatureSaveSignature, style: const TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ShadColors.crimson,
                          foregroundColor: ShadColors.textOnCrimson,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ]),
                ],

                // Text mode
                if (_sigMode == 'text') ...[
                  _subLabel(l10n.signatureTypeYourName),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ShadColors.black,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ShadColors.cardBorder),
                    ),
                    child: TextField(
                      controller: _sigTextController,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w400, fontFamily: 'DancingScript', color: ShadColors.gold),
                      decoration: InputDecoration(
                        hintText: l10n.settingsSignatureHint,
                        hintStyle: const TextStyle(color: ShadColors.textDisabled, fontSize: 18),
                        border: InputBorder.none,
                      ),
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _saveSignature,
                      icon: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle, size: 18),
                      label: Text(l10n.signatureSaveSignature, style: const TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ShadColors.crimson,
                        foregroundColor: ShadColors.textOnCrimson,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ]),
            ),
          ],
          const SizedBox(height: 32),

          // ═══════════════════════════════════════
          // Section 3: System settings (SA only)
          // ═══════════════════════════════════════
          if (!isAM) ...[
            _sectionHeader(Icons.settings_suggest_outlined, l10n.settingsSystemSettings),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ShadColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ShadColors.cardBorder),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l10n.settingsCorporateTax, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, fontFamily: 'PlayfairDisplay')),
                const SizedBox(height: 4),
                Text(l10n.settingsCorporateTaxDesc, style: TextStyle(fontSize: 11, color: ShadColors.textSecondary)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: _settingsField(
                      controller: _taxController,
                      label: l10n.settingsTaxRate,
                      icon: Icons.percent,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('%', style: TextStyle(fontSize: 14, color: ShadColors.textSecondary)),
                ]),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _taxSaving ? null : _saveTax,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ShadColors.gold,
                      foregroundColor: ShadColors.background,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _taxSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(l10n.settingsSaveTax, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'Archivo')),
                  ),
                ),
              ]),
            ),
          ],

          // ═══════════════════════════════════════
          // Section 4: Contract clauses (SA only)
          // ═══════════════════════════════════════
          if (!isAM) ...[
            const SizedBox(height: 20),
            _sectionHeader(Icons.description_outlined, l10n.adminSettings_clauses),
            const SizedBox(height: 4),
            Text(l10n.adminSettings_clausesDescription, style: TextStyle(fontSize: 11, color: ShadColors.textSecondary)),
            const SizedBox(height: 8),
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
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(children: [
      Icon(icon, size: 16, color: ShadColors.gold),
      const SizedBox(width: 6),
      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ShadColors.gold, fontFamily: 'PlayfairDisplay')),
    ]);
  }

  Widget _subLabel(String text) {
    return Text(text, style: const TextStyle(fontSize: 11, color: ShadColors.textSecondary, fontFamily: 'Archivo'));
  }

  Widget _settingsField({required TextEditingController controller, required String label, required IconData icon, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 13, color: ShadColors.textPrimary, fontFamily: 'Archivo'),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, color: ShadColors.textSecondary, fontFamily: 'Archivo'),
        prefixIcon: Icon(icon, size: 18, color: ShadColors.textSecondary),
        filled: true,
        fillColor: ShadColors.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: ShadColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: ShadColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: ShadColors.gold),
        ),
      ),
    );
  }
}

class _SigPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;
  _SigPainter({required this.strokes, required this.currentStroke});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = ShadColors.cardBorder.withAlpha(40);
    for (double x = 0; x < size.width; x += 20) {
      for (double y = 0; y < size.height; y += 20) {
        canvas.drawCircle(Offset(x, y), 1, bgPaint);
      }
    }
    final paint = Paint()
      ..color = ShadColors.gold
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) { _drawStroke(canvas, stroke, paint); }
    _drawStroke(canvas, currentStroke, paint);
  }

  void _drawStroke(Canvas canvas, List<Offset> points, Paint paint) {
    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }
  }

  @override
  bool shouldRepaint(_SigPainter oldDelegate) => true;
}
