import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api_client.dart';
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
            InkWell(
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
                    _dobController.text = '${d.year}/${d.month}/${d.day}';
                  });
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: InputDecorator(
                decoration: InputDecoration(labelText: l10n.createManagerDateOfBirth),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_dobController.text.isNotEmpty ? _dobController.text : l10n.createManagerSelectDate,
                        style: TextStyle(fontSize: 14, color: _dobController.text.isNotEmpty ? Lx.ink : Lx.faint)),
                    const Icon(Icons.calendar_today, size: 18, color: Lx.crimsonInk),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (!_isEdit) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Lx.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Lx.line2),
                ),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l10n.createManagerAutoPassword, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Lx.ink)),
                      const SizedBox(height: 2),
                      Text(l10n.createManagerAutoPasswordHint, style: const TextStyle(fontSize: 10, color: Lx.muted)),
                    ]),
                  ),
                  Switch(
                    value: _autoPassword,
                    activeTrackColor: Lx.crimson,
                    onChanged: (v) => setState(() => _autoPassword = v),
                  ),
                ]),
              ),
              if (!_autoPassword) ...[
                const SizedBox(height: 10),
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
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.check, size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(_isEdit ? l10n.saveChanges : l10n.createManagerCreateButton),
                      ]),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
            ),
          ],
        ),
      ),
    ));
  }
}
