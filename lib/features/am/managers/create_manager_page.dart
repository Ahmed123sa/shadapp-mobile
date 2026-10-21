import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api_client.dart';
import '../../../core/luxe/lx_icons.dart';
import '../../../core/luxe/tokens.dart';
import '../../../core/widgets/luxe/luxe_widgets.dart';
import '../../../core/widgets/password_field.dart';
import '../../../providers/manager_provider.dart';
import 'package:shadapp_client/generated/app_localizations.dart';

class CreateManagerPage extends StatefulWidget {
  final int? managerId;
  // Optional so this screen can be pumped in a widget test with a mocked
  // ManagerProvider instead of hitting the network.
  final ManagerProvider? managerProvider;
  const CreateManagerPage({super.key, this.managerId, this.managerProvider});

  @override
  State<CreateManagerPage> createState() => _CreateManagerPageState();
}

class _CreateManagerPageState extends State<CreateManagerPage> {
  late final ManagerProvider _managerProvider = widget.managerProvider ?? ManagerProvider();
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _dobController = TextEditingController();
  DateTime? _dob;
  bool _autoPassword = true;
  bool _loading = false;
  bool _saving = false;
  String? _errorMsg;

  bool get _isEdit => widget.managerId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _loadManager();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _loadManager() async {
    setState(() => _loading = true);
    try {
      final data = await _managerProvider.fetchManagerRaw(widget.managerId!);
      final m = data['manager'] as Map<String, dynamic>? ?? data;
      _nameCtrl.text = (m['name'] as String?) ?? '';
      _emailCtrl.text = (m['email'] as String?) ?? '';
      _phoneCtrl.text = (m['phone'] as String?) ?? '';
      if (m['date_of_birth'] != null && (m['date_of_birth'] as String).isNotEmpty) {
        final parsed = DateTime.tryParse((m['date_of_birth'] as String).substring(0, 10));
        if (parsed != null) {
          _dob = parsed;
          _dobController.text = '${parsed.year}/${parsed.month}/${parsed.day}';
        }
      }
    } catch (_) {
      if (!mounted) return;
      _errorMsg = AppLocalizations.of(context)!.createManagerFailedToLoad;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    _errorMsg = null;
    try {
      final payload = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        if (_dob != null) 'date_of_birth': _dob!.toIso8601String(),
      };
      Map<String, dynamic> res;
      if (_isEdit) {
        if (_passwordCtrl.text.trim().isNotEmpty) {
          payload['password'] = _passwordCtrl.text.trim();
        }
        res = await _managerProvider.updateManager(widget.managerId!, payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.createManagerUpdated)));
          Navigator.pop(context, true);
        }
        return;
      } else {
        if (!_autoPassword) {
          payload['password'] = _passwordCtrl.text.trim();
        }
        res = await _managerProvider.createManager(payload);
      }
      final creds = (res['credentials'] is Map) ? res['credentials'] as Map<String, dynamic> : null;
      if (mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => Dialog(
            backgroundColor: Lx.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Lx.line2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(AppLocalizations.of(ctx)!.createManagerCreated, style: const TextStyle(fontFamily: Lx.serif, fontSize: 16, fontWeight: FontWeight.w700, color: Lx.crimsonInk)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Lx.page, borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Text(AppLocalizations.of(ctx)!.emailLabel, style: const TextStyle(fontSize: 12, color: Lx.muted)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(creds?['email'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Lx.ink), textDirection: TextDirection.ltr)),
                    InkWell(
                      onTap: () => ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(AppLocalizations.of(ctx)!.createManagerEmailCopied))),
                      child: Text(AppLocalizations.of(ctx)!.createManagerCopy, style: const TextStyle(fontSize: 11, color: Lx.crimsonInk)),
                    ),
                  ]),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Lx.page, borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Text(AppLocalizations.of(ctx)!.createManagerPassword, style: const TextStyle(fontSize: 12, color: Lx.muted)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(creds?['password'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Lx.ink), textDirection: TextDirection.ltr)),
                    InkWell(
                      onTap: () => ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(AppLocalizations.of(ctx)!.createManagerPasswordCopied))),
                      child: Text(AppLocalizations.of(ctx)!.createManagerCopy, style: const TextStyle(fontSize: 11, color: Lx.crimsonInk)),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () { Navigator.pop(ctx); context.pop(true); },
                    child: Text(AppLocalizations.of(ctx)!.createManagerOk),
                  ),
                ),
              ]),
            ),
          ),
        );
      }
    } on ValidationException catch (e) {
      _errorMsg = e.message;
    } catch (_) {
      if (!mounted) return;
      _errorMsg = _isEdit ? AppLocalizations.of(context)!.createManagerUpdateFailed : AppLocalizations.of(context)!.createManagerCreateFailed;
    }
    if (mounted) setState(() => _saving = false);
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text.toUpperCase(), style: TextStyle(fontSize: 10, color: Lx.faint, letterSpacing: 1.2, fontWeight: FontWeight.w500)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final l10n = AppLocalizations.of(context)!;
    return LuxeFormTheme(
      child: Scaffold(
      backgroundColor: Lx.page,
      appBar: AppBar(
        backgroundColor: Lx.page,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Lx.muted),
        title: const SizedBox.shrink(),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 28),
          children: [
            LuxePageTitle(_isEdit ? l10n.createManagerEditTitle : l10n.createManagerCreateTitle),
            if (_errorMsg != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Lx.danger.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Lx.danger.withAlpha(80)),
                ),
                child: Text(_errorMsg!, style: const TextStyle(color: Lx.danger, fontSize: 12)),
              ),

            _sectionLabel(l10n.createManagerBasicData),
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(labelText: l10n.createManagerName, hintText: 'Mohamed Ali'),
              textCapitalization: TextCapitalization.words,
              validator: (v) => v == null || v.trim().isEmpty ? l10n.createManagerNameRequired : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _emailCtrl,
              decoration: InputDecoration(labelText: l10n.createManagerEmailField, hintText: 'manager@domain.com'),
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return l10n.createManagerEmailRequired;
                if (!v.contains('@')) return l10n.createManagerEmailInvalid;
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _phoneCtrl,
              decoration: InputDecoration(labelText: l10n.createManagerPhone, hintText: '+966501234567'),
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(height: 16),

            _sectionLabel(l10n.createManagerAdditionalDetails),
            // `.f2` date row: label, value on the underline, calendar icon.
            GestureDetector(
              key: const ValueKey('manager-dob'),
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _dob ?? DateTime(1990),
                  firstDate: DateTime(1920),
                  lastDate: DateTime.now(),
                  locale: Localizations.localeOf(context),
                );
                if (d != null) {
                  setState(() {
                    _dob = d;
                    _dobController.text = '${d.day}/${d.month}/${d.year}';
                  });
                }
              },
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l10n.createManagerDateOfBirth, style: Lx.text(context, size: 12, color: Lx.muted)),
                Container(
                  padding: const EdgeInsets.only(top: 6, bottom: 9),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Lx.line2))),
                  child: Row(children: [
                    Expanded(
                      child: Text(_dobController.text.isNotEmpty ? _dobController.text : l10n.createManagerSelectDate,
                          style: Lx.text(context, size: 15, color: _dobController.text.isNotEmpty ? Lx.ink : Lx.faint)),
                    ),
                    const LxIcon('cal', size: 18, color: Lx.muted),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 6),

            if (!_isEdit) ...[
              // Mockup `.opt` + `.sw2`.
              Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Lx.line))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l10n.createManagerAutoPassword, style: Lx.text(context, size: 13.5, weight: FontWeight.w500)),
                      Text(l10n.createManagerAutoPasswordHint, style: Lx.text(context, size: 12.5, color: Lx.muted)),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  LuxeToggle(key: const ValueKey('manager-auto-password'), value: _autoPassword, onChanged: (v) => setState(() => _autoPassword = v)),
                ]),
              ),
              if (!_autoPassword) ...[
                const SizedBox(height: 14),
                PasswordField(controller: _passwordCtrl),
              ],
            ],
            if (_isEdit) ...[
              _sectionLabel(l10n.createManagerResetPassword),
              PasswordField(
                controller: _passwordCtrl,
                labelText: l10n.createManagerNewPassword,
                hintText: l10n.createManagerLeaveBlank,
                required: false,
              ),
            ],
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Text(_isEdit ? l10n.saveChanges : l10n.createManagerCreateButton, style: Lx.text(context, size: 14, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: LuxeButton(label: l10n.cancel, size: LuxeButtonSize.lg, kind: LuxeButtonKind.quiet, onPressed: () => Navigator.pop(context)),
            ),
          ],
        ),
      ),
    ));
  }
}
