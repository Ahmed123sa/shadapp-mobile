import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api_client.dart';
import '../../../core/app_log.dart';
import '../../../core/luxe/lx_icons.dart';
import '../../../core/luxe/tokens.dart';
import '../../../core/widgets/luxe/luxe_widgets.dart';
import '../../../core/widgets/password_field.dart';
import '../../../data/client_repository.dart';
import '../../../providers/client_provider.dart';
import 'package:shadapp_client/generated/app_localizations.dart';

class CreateClientPage extends StatefulWidget {
  final ApiClient? api;
  // Optional, same pattern as LoginPage.authProvider — defaults to a
  // ClientProvider built from the same ApiClient, so existing tests that
  // pump CreateClientPage(api: api) keep working unchanged.
  final ClientProvider? clientProvider;
  const CreateClientPage({super.key, this.api, this.clientProvider});

  @override
  State<CreateClientPage> createState() => _CreateClientPageState();
}

class _CreateClientPageState extends State<CreateClientPage> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final ClientProvider _clientProvider =
      widget.clientProvider ?? ClientProvider(repository: ClientRepository(api: _api));
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _personController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _countryController = TextEditingController();
  final _industryController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _dateOfBirth;
  File? _avatarFile;
  bool _isBusiness = true;
  bool _autoPassword = true;
  bool _saving = false;
  String? _errorMsg;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    _errorMsg = null;
    final failMsg = AppLocalizations.of(context)!.clientCreateFailed;
    try {
      final res = await _clientProvider.createClient({
        'company_name': _nameController.text.trim(),
        'contact_person': _personController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'country': _countryController.text.trim(),
        'industry': _industryController.text.trim(),
        if (_addressController.text.trim().isNotEmpty) 'address': _addressController.text.trim(),
        'client_type': _isBusiness ? 'business' : 'individual',
        if (_dateOfBirth != null) 'date_of_birth': _dateOfBirth!.toIso8601String(),
        if (!_autoPassword) 'password': _passwordController.text.trim(),
        if (_notesController.text.trim().isNotEmpty) 'notes': _notesController.text.trim(),
        'send_email': true,
      });
      final creds = (res['credentials'] is Map) ? res['credentials'] as Map<String, dynamic> : null;
      final clientId = res['client']?['id'] as int?;
      if (clientId != null && _avatarFile != null) {
        try {
          await _clientProvider.uploadAvatar(clientId, _avatarFile!);
        } catch (e, s) {
          // The client itself was created successfully; only the avatar
          // upload failed, so this deliberately doesn't fail the whole flow.
          AppLog.error('create_client_page._submit(avatar)', e, s);
        }
      }
      if (mounted) {
        try {
          await showDialog(
            context: context,
            barrierColor: const Color(0x8C000000),
            builder: (ctx) {
              final l = AppLocalizations.of(ctx)!;
              // Mockup `.doc` rows inside a sheet-style dialog: label, value
              // (LTR), and a quiet "Copy" link.
              Widget row(String label, String value, String copied, {bool last = false}) => Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: Lx.line))),
                    child: Row(children: [
                      SizedBox(width: 72, child: Text(label, style: Lx.text(ctx, size: 12.5, color: Lx.muted))),
                      Expanded(child: Text(value, textDirection: TextDirection.ltr, style: Lx.text(ctx, size: 13.5))),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: value));
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(copied)));
                        },
                        child: Container(
                          padding: const EdgeInsets.only(bottom: 1),
                          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Lx.line2))),
                          child: Text(l.createClientCopy, style: Lx.text(ctx, size: 12.5, color: Lx.ink2)),
                        ),
                      ),
                    ]),
                  );
              return Dialog(
                backgroundColor: Lx.sheet,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Lx.rSheet), side: const BorderSide(color: Lx.line2)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const LuxeStatusDot(status: LxStatus.ok),
                      const SizedBox(width: 8),
                      Expanded(child: Text(l.createClientSuccess, style: Lx.display(ctx, size: 22))),
                    ]),
                    const SizedBox(height: 10),
                    LuxeCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      child: Column(children: [
                        row(l.createClientEmail, '${creds?['email'] ?? ''}', l.createClientEmailCopied),
                        row(l.createClientPassword, '${creds?['password'] ?? ''}', l.createClientPasswordCopied, last: true),
                      ]),
                    ),
                    Text(l.createClientCredentialsSent, style: Lx.text(ctx, size: 11, color: Lx.faint)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: LuxeButton(
                        label: l.createClientOk,
                        kind: LuxeButtonKind.primary,
                        size: LuxeButtonSize.lg,
                        onPressed: () {
                          Navigator.pop(ctx);
                          context.pop(true);
                        },
                      ),
                    ),
                  ]),
                ),
              );
            },
          );
        } catch (e, s) {
          AppLog.error('create_client_page._submit(successDialog)', e, s);
        }
      }
    } on ValidationException catch (e) {
      _errorMsg = e.message;
    } catch (_) {
      _errorMsg = failMsg;
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.single.path == null) return;
    setState(() => _avatarFile = File(result.files.single.path!));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _personController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _countryController.dispose();
    _industryController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    _dateOfBirthController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Mockup `.pgh`: 10px (.22em) uppercase faint group label (margin 16 0 2).
  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Text(text.toUpperCase(), style: Lx.text(context, size: 10, color: Lx.faint).copyWith(letterSpacing: 2.2)),
    );
  }

  /// Mockup `.chip2` / `.chip2.on` (crimson .2 fill, .5 border).
  Widget _typeChip(String label, bool on, VoidCallback onTap, {Key? key}) => GestureDetector(
        key: key,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
          decoration: BoxDecoration(
            color: on ? const Color(0x33941414) : Colors.transparent,
            borderRadius: BorderRadius.circular(Lx.rPill),
            border: Border.all(color: on ? const Color(0x80941414) : Lx.line2),
          ),
          child: Text(label, style: Lx.text(context, size: 12, color: on ? Lx.ink : Lx.ink2)),
        ),
      );

  Widget _gap() => const SizedBox(height: 14);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final h1 = Lx.display(context, size: 28).copyWith(height: 1.2);
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
            padding: const EdgeInsetsDirectional.fromSTEB(16, 2, 16, 28),
            children: [
              // Staff mockup head(): eyebrow + serif title + crimson ".".
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 6, 0, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l10n.clientsNewEyebrow.toUpperCase(), style: Lx.text(context, size: 10.5, color: Lx.faint).copyWith(letterSpacing: 2.73)),
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: l10n.amNewClient),
                      TextSpan(text: '.', style: h1.copyWith(color: Lx.crimsonInk, fontStyle: FontStyle.normal)),
                    ]),
                    key: const ValueKey('lx-page-title'),
                    style: h1,
                  ),
                ]),
              ),
              if (_errorMsg != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(top: 8, bottom: 4),
                  decoration: BoxDecoration(
                    color: Lx.crimson.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x59941414)),
                  ),
                  child: Text(_errorMsg!, style: Lx.text(context, size: 12.5, color: Lx.danger)),
                ),
              // Avatar: 64px `.av` + "Add image" button (settings profile row).
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Row(children: [
                  GestureDetector(
                    onTap: _pickAvatar,
                    child: _avatarFile != null
                        ? CircleAvatar(radius: 32, backgroundImage: FileImage(_avatarFile!))
                        : Container(
                            width: 64,
                            height: 64,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: const Color(0xFF262626), shape: BoxShape.circle, border: Border.all(color: Lx.line2)),
                            child: const LxIcon('users', size: 24, color: Lx.muted),
                          ),
                  ),
                  const SizedBox(width: 16),
                  LuxeButton(label: l10n.createClientAddImage, lxIcon: 'up', size: LuxeButtonSize.sm, onPressed: _pickAvatar),
                ]),
              ),

              _sectionLabel(l10n.createClientType),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(spacing: 8, children: [
                  _typeChip(l10n.createClientCompany, _isBusiness, () => setState(() => _isBusiness = true), key: const ValueKey('client-type-business')),
                  _typeChip(l10n.createClientIndividual, !_isBusiness, () => setState(() => _isBusiness = false), key: const ValueKey('client-type-individual')),
                ]),
              ),

              _sectionLabel(l10n.createClientCompanyData),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: l10n.companyName, hintText: l10n.companyNameHint),
                validator: (v) => v == null || v.trim().isEmpty ? l10n.companyNameRequired : null,
              ),
              _gap(),
              TextFormField(
                controller: _personController,
                decoration: InputDecoration(labelText: l10n.contactPerson, hintText: l10n.contactPersonHint),
                validator: (v) => v == null || v.trim().isEmpty ? l10n.contactPersonRequired : null,
              ),
              _gap(),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: l10n.email, hintText: l10n.emailHint),
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return l10n.emailRequired;
                  if (!v.contains('@')) return l10n.emailInvalid;
                  return null;
                },
              ),
              _gap(),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(labelText: l10n.phone, hintText: l10n.phoneHint),
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return l10n.phoneRequired;
                  if (v.trim().length < 10) return l10n.phoneMinLength;
                  return null;
                },
              ),

              _sectionLabel(l10n.createClientAdditionalDetails),
              TextFormField(controller: _countryController, decoration: InputDecoration(labelText: l10n.country, hintText: l10n.countryHint)),
              _gap(),
              TextFormField(controller: _industryController, decoration: InputDecoration(labelText: l10n.industry, hintText: l10n.industryHint)),
              _gap(),
              TextFormField(controller: _addressController, maxLines: 2, minLines: 1, decoration: InputDecoration(labelText: l10n.address, hintText: l10n.addressHint)),
              _gap(),
              // `.f2` date row: label, value on the underline, calendar icon.
              GestureDetector(
                key: const ValueKey('client-dob'),
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _dateOfBirth ?? DateTime(2000),
                    firstDate: DateTime(1950),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) {
                    setState(() {
                      _dateOfBirth = d;
                      _dateOfBirthController.text = '${d.day}/${d.month}/${d.year}';
                    });
                  }
                },
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l10n.createClientDateOfBirth, style: Lx.text(context, size: 12, color: Lx.muted)),
                  Container(
                    padding: const EdgeInsets.only(top: 6, bottom: 9),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Lx.line2))),
                    child: Row(children: [
                      Expanded(
                        child: Text(
                          _dateOfBirthController.text.isNotEmpty ? _dateOfBirthController.text : l10n.createClientSelectDate,
                          style: Lx.text(context, size: 15, color: _dateOfBirthController.text.isNotEmpty ? Lx.ink : Lx.faint),
                        ),
                      ),
                      const LxIcon('cal', size: 18, color: Lx.muted),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              // Mockup `.opt` + `.sw2`.
              Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Lx.line))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l10n.createClientAutoPassword, style: Lx.text(context, size: 13.5, weight: FontWeight.w500)),
                      Text(l10n.createClientAutoPasswordEmailHint, style: Lx.text(context, size: 12.5, color: Lx.muted)),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  LuxeToggle(key: const ValueKey('client-auto-password'), value: _autoPassword, onChanged: (v) => setState(() => _autoPassword = v)),
                ]),
              ),
              if (!_autoPassword) ...[
                _gap(),
                PasswordField(controller: _passwordController),
              ],
              _gap(),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                minLines: 1,
                decoration: InputDecoration(labelText: l10n.createClientNotes, hintText: l10n.createClientNotesHint),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Text(l10n.createClientCreateButton, style: Lx.text(context, size: 14, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: LuxeButton(label: l10n.createClientCancel, size: LuxeButtonSize.lg, kind: LuxeButtonKind.quiet, onPressed: () => Navigator.pop(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
