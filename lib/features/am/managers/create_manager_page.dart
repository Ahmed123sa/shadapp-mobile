import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/password_field.dart';
import '../../../core/widgets/shad_logo.dart';
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
            backgroundColor: ShadColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: ShadColors.goldBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(AppLocalizations.of(ctx)!.createManagerCreated, style: const TextStyle(fontFamily: 'PlayfairDisplay', fontSize: 16, fontWeight: FontWeight.w700, color: ShadColors.gold)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: ShadColors.black, borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Text(AppLocalizations.of(ctx)!.emailLabel, style: const TextStyle(fontSize: 12, color: ShadColors.textSecondary)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(creds?['email'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ShadColors.textPrimary), textDirection: TextDirection.ltr)),
                    InkWell(
                      onTap: () => ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(AppLocalizations.of(ctx)!.createManagerEmailCopied))),
                      child: Text(AppLocalizations.of(ctx)!.createManagerCopy, style: const TextStyle(fontSize: 11, color: ShadColors.gold)),
                    ),
                  ]),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: ShadColors.black, borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Text(AppLocalizations.of(ctx)!.createManagerPassword, style: const TextStyle(fontSize: 12, color: ShadColors.textSecondary)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(creds?['password'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ShadColors.textPrimary), textDirection: TextDirection.ltr)),
                    InkWell(
                      onTap: () => ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(AppLocalizations.of(ctx)!.createManagerPasswordCopied))),
                      child: Text(AppLocalizations.of(ctx)!.createManagerCopy, style: const TextStyle(fontSize: 11, color: ShadColors.gold)),
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
      child: Text(text.toUpperCase(), style: TextStyle(fontSize: 10, color: ShadColors.textDisabled, letterSpacing: 1.2, fontWeight: FontWeight.w500)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ShadLogo(size: 20, showText: false),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_isEdit ? l10n.createManagerEditTitle : l10n.createManagerCreateTitle,
                    style: const TextStyle(fontFamily: 'PlayfairDisplay', fontSize: 15, fontWeight: FontWeight.w700)),
                Text(_isEdit ? 'Edit Manager' : 'New Manager',
                    style: const TextStyle(fontSize: 10, color: ShadColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_errorMsg != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: ShadColors.errorLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ShadColors.error.withAlpha(80)),
                ),
                child: Text(_errorMsg!, style: const TextStyle(color: ShadColors.error, fontSize: 12)),
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
                        style: TextStyle(fontSize: 14, color: _dobController.text.isNotEmpty ? ShadColors.textPrimary : ShadColors.textDisabled)),
                    const Icon(Icons.calendar_today, size: 18, color: ShadColors.gold),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (!_isEdit) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ShadColors.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ShadColors.cardBorder),
                ),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l10n.createManagerAutoPassword, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ShadColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(l10n.createManagerAutoPasswordHint, style: const TextStyle(fontSize: 10, color: ShadColors.textSecondary)),
                    ]),
                  ),
                  Switch(
                    value: _autoPassword,
                    activeTrackColor: ShadColors.crimson,
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
    );
  }
}
