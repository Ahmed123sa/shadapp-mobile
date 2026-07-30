import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/password_field.dart';
import '../../../core/widgets/shad_logo.dart';

class CreateManagerPage extends StatefulWidget {
  final int? managerId;
  const CreateManagerPage({super.key, this.managerId});

  @override
  State<CreateManagerPage> createState() => _CreateManagerPageState();
}

class _CreateManagerPageState extends State<CreateManagerPage> {
  final _api = ApiClient();
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
      final data = await _api.get('/account-managers/${widget.managerId}');
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
      _errorMsg = 'فشل تحميل بيانات المدير';
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
        res = await _api.put('/account-managers/${widget.managerId}', payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث المدير بنجاح')));
          Navigator.pop(context, true);
        }
        return;
      } else {
        if (!_autoPassword) {
          payload['password'] = _passwordCtrl.text.trim();
        }
        res = await _api.post('/account-managers', payload);
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
                const Text('تم إنشاء المدير بنجاح', style: TextStyle(fontFamily: 'PlayfairDisplay', fontSize: 16, fontWeight: FontWeight.w700, color: ShadColors.gold)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: ShadColors.black, borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Text('البريد', style: TextStyle(fontSize: 12, color: ShadColors.textSecondary)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(creds?['email'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ShadColors.textPrimary), textDirection: TextDirection.ltr)),
                    InkWell(
                      onTap: () => ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('تم نسخ البريد'))),
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
                      onTap: () => ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('تم نسخ كلمة المرور'))),
                      child: const Text('نسخ', style: TextStyle(fontSize: 11, color: ShadColors.gold)),
                    ),
                  ]),
                ),
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
      }
    } on ValidationException catch (e) {
      _errorMsg = e.message;
    } catch (_) {
      _errorMsg = _isEdit ? 'فشل تحديث المدير' : 'فشل إنشاء المدير';
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
                Text(_isEdit ? 'تعديل مدير' : 'إضافة مدير جديد',
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

            _sectionLabel('البيانات الأساسية'),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'الاسم', hintText: 'Mohamed Ali'),
              textCapitalization: TextCapitalization.words,
              validator: (v) => v == null || v.trim().isEmpty ? 'الاسم مطلوب' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'البريد الإلكتروني', hintText: 'manager@domain.com'),
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'البريد الإلكتروني مطلوب';
                if (!v.contains('@')) return 'البريد الإلكتروني غير صالح';
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(labelText: 'رقم الهاتف', hintText: '+966501234567'),
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(height: 16),

            _sectionLabel('تفاصيل إضافية'),
            InkWell(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _dob ?? DateTime(1990),
                  firstDate: DateTime(1920),
                  lastDate: DateTime.now(),
                  locale: const Locale('ar'),
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
                decoration: const InputDecoration(labelText: 'تاريخ الميلاد'),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_dobController.text.isNotEmpty ? _dobController.text : 'اختر التاريخ',
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
                      const Text('كلمة المرور التلقائية', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ShadColors.textPrimary)),
                      const SizedBox(height: 2),
                      const Text('سيتم إنشاؤها تلقائياً', style: TextStyle(fontSize: 10, color: ShadColors.textSecondary)),
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
              _sectionLabel('إعادة تعيين كلمة المرور'),
              PasswordField(
                controller: _passwordCtrl,
                labelText: 'كلمة مرور جديدة',
                hintText: 'اتركه فارغاً إذا لم تُرِد التغيير',
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
                        Text(_isEdit ? 'حفظ التعديلات' : 'إنشاء المدير'),
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
