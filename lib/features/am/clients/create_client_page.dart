import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/password_field.dart';
import '../../../core/widgets/shad_logo.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
 
class CreateClientPage extends StatefulWidget {
  const CreateClientPage({super.key});

  @override
  State<CreateClientPage> createState() => _CreateClientPageState();
}

class _CreateClientPageState extends State<CreateClientPage> {
  final _api = ApiClient();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _personController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _countryController = TextEditingController();
  final _industryController = TextEditingController();
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
      final res = await _api.post('/clients', {
        'company_name': _nameController.text.trim(),
        'contact_person': _personController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'country': _countryController.text.trim(),
        'industry': _industryController.text.trim(),
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
          await _api.multipartPost('/clients/$clientId/profile', {}, file: _avatarFile!, fileField: 'avatar');
        } catch (_) {}
      }
      if (mounted) {
        try {
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
                  const Text('✓ تم إنشاء العميل بنجاح', style: TextStyle(fontFamily: 'PlayfairDisplay', fontSize: 16, fontWeight: FontWeight.w700, color: ShadColors.gold)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: ShadColors.black, borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      const Text('البريد', style: TextStyle(fontSize: 12, color: ShadColors.textSecondary)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(creds?['email'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ShadColors.textPrimary), textDirection: TextDirection.ltr)),
                      InkWell(
                        onTap: () {
                          final messenger = ScaffoldMessenger.of(ctx);
                          messenger.showSnackBar(const SnackBar(content: Text('✅ تم نسخ البريد')));
                        },
                        child: const Text('نسخ', style: TextStyle(fontSize: 11, color: ShadColors.gold)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: ShadColors.black, borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      const Text('كلمة المرور', style: TextStyle(fontSize: 12, color: ShadColors.textSecondary)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(creds?['password'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ShadColors.textPrimary), textDirection: TextDirection.ltr)),
                      InkWell(
                        onTap: () {
                          final messenger = ScaffoldMessenger.of(ctx);
                          messenger.showSnackBar(const SnackBar(content: Text('✅ تم نسخ كلمة المرور')));
                        },
                        child: const Text('نسخ', style: TextStyle(fontSize: 11, color: ShadColors.gold)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  const Text('تم إرسال بيانات الدخول للعميل عبر البريد الإلكتروني', style: TextStyle(fontSize: 10, color: ShadColors.textSecondary)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () { Navigator.pop(ctx); context.pop(true); },
                      child: const Text('حسناً'),
                    ),
                  ),
                ]),
              ),
            ),
          );
        } catch (_) {}
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
    _passwordController.dispose();
    _dateOfBirthController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text.toUpperCase(), style: TextStyle(fontSize: 10, color: ShadColors.textDisabled, letterSpacing: 1.2, fontWeight: FontWeight.w500)),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                const Text('إضافة عميل جديد', style: TextStyle(fontFamily: 'PlayfairDisplay', fontSize: 15, fontWeight: FontWeight.w700)),
                const Text('New Client', style: TextStyle(fontSize: 10, color: ShadColors.textSecondary)),
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

            Center(
              child: GestureDetector(
                onTap: _pickAvatar,
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: ShadColors.crimson,
                  backgroundImage: _avatarFile != null ? FileImage(_avatarFile!) : null,
                  child: _avatarFile == null ? const Icon(Icons.person_add, size: 40, color: ShadColors.gold) : null,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton.icon(
                onPressed: _pickAvatar,
                icon: const Icon(Icons.camera_alt, size: 16, color: ShadColors.gold),
                label: const Text('إضافة صورة', style: TextStyle(color: ShadColors.gold)),
              ),
            ),
            const SizedBox(height: 16),

            _sectionLabel('نوع العميل'),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isBusiness = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _isBusiness ? ShadColors.crimson.withAlpha(40) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _isBusiness ? ShadColors.crimson.withAlpha(80) : ShadColors.inputBorder),
                    ),
                    child: Column(children: [
                      const Text('🏢', style: TextStyle(fontSize: 18)),
                      const SizedBox(height: 3),
                      Text('شركة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _isBusiness ? ShadColors.textPrimary : ShadColors.textSecondary)),
                      const Text('Business', style: TextStyle(fontSize: 9, color: ShadColors.textDisabled)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isBusiness = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: !_isBusiness ? ShadColors.crimson.withAlpha(40) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: !_isBusiness ? ShadColors.crimson.withAlpha(80) : ShadColors.inputBorder),
                    ),
                    child: Column(children: [
                      const Text('👤', style: TextStyle(fontSize: 18)),
                      const SizedBox(height: 3),
                      Text('فرد', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: !_isBusiness ? ShadColors.textPrimary : ShadColors.textSecondary)),
                      const Text('Individual', style: TextStyle(fontSize: 9, color: ShadColors.textDisabled)),
                    ]),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 16),

            _sectionLabel('بيانات الشركة'),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: AppLocalizations.of(context)!.companyName, hintText: AppLocalizations.of(context)!.companyNameHint),
              validator: (v) => v == null || v.trim().isEmpty ? AppLocalizations.of(context)!.companyNameRequired : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _personController,
              decoration: InputDecoration(labelText: AppLocalizations.of(context)!.contactPerson, hintText: AppLocalizations.of(context)!.contactPersonHint),
              validator: (v) => v == null || v.trim().isEmpty ? AppLocalizations.of(context)!.contactPersonRequired : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(labelText: AppLocalizations.of(context)!.email, hintText: AppLocalizations.of(context)!.emailHint),
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return AppLocalizations.of(context)!.emailRequired;
                if (!v.contains('@')) return AppLocalizations.of(context)!.emailInvalid;
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(labelText: AppLocalizations.of(context)!.phone, hintText: AppLocalizations.of(context)!.phoneHint),
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return AppLocalizations.of(context)!.phoneRequired;
                if (v.trim().length < 10) return AppLocalizations.of(context)!.phoneMinLength;
                return null;
              },
            ),
            const SizedBox(height: 16),

            _sectionLabel('تفاصيل إضافية'),
            TextFormField(
              controller: _countryController,
              decoration: InputDecoration(labelText: AppLocalizations.of(context)!.country, hintText: AppLocalizations.of(context)!.countryHint),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _industryController,
              decoration: InputDecoration(labelText: AppLocalizations.of(context)!.industry, hintText: AppLocalizations.of(context)!.industryHint),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _dateOfBirth ?? DateTime(2000),
                  firstDate: DateTime(1950),
                  lastDate: DateTime.now(),
                );
                if (d != null) setState(() {
                  _dateOfBirth = d;
                  _dateOfBirthController.text = '${d.year}/${d.month}/${d.day}';
                });
              },
              borderRadius: BorderRadius.circular(10),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'تاريخ الميلاد'),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_dateOfBirthController.text.isNotEmpty ? _dateOfBirthController.text : 'اختر التاريخ',
                        style: TextStyle(fontSize: 14, color: _dateOfBirthController.text.isNotEmpty ? ShadColors.textPrimary : ShadColors.textDisabled)),
                    const Icon(Icons.calendar_today, size: 18, color: ShadColors.gold),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

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
                    const Text('كلمة المرور التلقائية', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ShadColors.textPrimary)),
                    const SizedBox(height: 2),
                    const Text('سيتم إرسالها للعميل عبر الإيميل', style: TextStyle(fontSize: 10, color: ShadColors.textSecondary)),
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
              PasswordField(controller: _passwordController),
            ],
            const SizedBox(height: 10),
            TextFormField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'ملاحظات', hintText: 'أي معلومات إضافية عن العميل...'),
              onChanged: (_) {},
            ),
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
                        const Text('إنشاء العميل'),
                      ]),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
