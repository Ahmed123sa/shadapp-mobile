import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/client_type_badge.dart';
import '../../../core/widgets/password_field.dart';
import 'package:shadapp_client/generated/app_localizations.dart';

class ClientDetailPage extends StatefulWidget {
  final int clientId;
  const ClientDetailPage({super.key, required this.clientId});

  @override
  State<ClientDetailPage> createState() => _ClientDetailPageState();
}

class _ClientDetailPageState extends State<ClientDetailPage> {
  final _api = ApiClient();
  final _nameCtrl = TextEditingController();
  final _personCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _industryCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  DateTime? _dateOfBirth;
  bool _loading = true;
  bool _saving = false;
  String? _avatarUrl;
  String? _status;
  String? _clientType;
  bool _isBusiness = true;
  String? _createdAt;
  List<dynamic> _subUsers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _personCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _countryCtrl.dispose();
    _industryCtrl.dispose();
    _passwordCtrl.dispose();
    _dateOfBirthController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _api.get('/clients/${widget.clientId}');
      final client = data['client'] as Map<String, dynamic>? ?? {};
      _nameCtrl.text = (client['company_name'] as String? ?? '');
      _personCtrl.text = (client['contact_person'] as String? ?? '');
      _phoneCtrl.text = (client['phone'] as String? ?? '');
      _countryCtrl.text = (client['country'] as String? ?? '');
      _industryCtrl.text = (client['industry'] as String? ?? '');
      _dateOfBirthController.text = (client['date_of_birth'] as String? ?? '');
      _emailCtrl.text = (client['email'] as String? ?? '');
      _status = client['status'] as String? ?? 'inactive';
      _clientType = client['client_type'] as String?;
      _isBusiness = _clientType != 'individual';
      _avatarUrl = client['avatar_url'] as String?;
      _createdAt = client['created_at'] as String?;
      _subUsers = client['sub_users'] as List<dynamic>? ?? [];
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.single.path == null) return;
    final file = File(result.files.single.path!);
    try {
      await _api.multipartPost('/clients/${widget.clientId}/profile', {}, file: file, fileField: 'avatar');
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ ${AppLocalizations.of(context)!.clientDetailImageChanged}')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppLocalizations.of(context)!.clientDetailImageChangeFailed}: $e')));
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _api.put('/clients/${widget.clientId}', {
        'company_name': _nameCtrl.text.trim(),
        'contact_person': _personCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'country': _countryCtrl.text.trim(),
        'industry': _industryCtrl.text.trim(),
        if (_dateOfBirth != null) 'date_of_birth': _dateOfBirth!.toIso8601String(),
        'client_type': _isBusiness ? 'business' : 'individual',
        if (_passwordCtrl.text.trim().isNotEmpty) 'password': _passwordCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ ${AppLocalizations.of(context)!.clientDetailSaved}')));
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.clientDetailSaveFailed)));
    }
    if (mounted) setState(() => _saving = false);
  }

  String _formatCreatedAt() {
    if (_createdAt == null || _createdAt!.isEmpty) return '—';
    try {
      final dt = DateTime.parse(_createdAt!);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return _createdAt!.split('T').first;
    }
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text.toUpperCase(), style: TextStyle(fontSize: 10, color: ShadColors.textDisabled, letterSpacing: 1.2, fontWeight: FontWeight.w500)),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: ShadColors.crimson.withAlpha(25),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ShadColors.crimson.withAlpha(40)),
          ),
          child: Icon(icon, size: 14, color: ShadColors.crimson),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 10, color: ShadColors.textSecondary)),
            const SizedBox(height: 1),
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ShadColors.textPrimary)),
          ]),
        ),
      ]),
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
        title: Text(l10n.clientDetailEditTitle, style: const TextStyle(fontFamily: 'PlayfairDisplay', fontSize: 16, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check, size: 22),
            tooltip: l10n.clientDetailSave,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickAvatar,
              child: Stack(children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ShadColors.crimson.withAlpha(25),
                    border: Border.all(color: ShadColors.crimson, width: 2),
                  ),
                  child: _avatarUrl != null
                      ? ClipOval(child: Image.network(_api.resolveFileUrl(_avatarUrl!), width: 72, height: 72, fit: BoxFit.cover))
                      : Center(child: Text(l10n.clientDetailInitials, style: const TextStyle(fontFamily: 'PlayfairDisplay', fontSize: 24, fontWeight: FontWeight.w700, color: ShadColors.gold))),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: ShadColors.gold,
                    ),
                    child: const Icon(Icons.camera_alt, size: 11, color: ShadColors.black),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_nameCtrl.text, style: const TextStyle(fontFamily: 'PlayfairDisplay', fontSize: 17, fontWeight: FontWeight.w700, color: ShadColors.textPrimary)),
              const SizedBox(width: 8),
              ClientTypeBadge(clientType: _clientType),
            ]),
          ),
          const SizedBox(height: 2),
          Center(child: Text(_emailCtrl.text, style: const TextStyle(fontSize: 11, color: ShadColors.textSecondary), textDirection: TextDirection.ltr)),
          const SizedBox(height: 6),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: _status == 'active' ? ShadColors.success.withAlpha(25) : ShadColors.textDisabled.withAlpha(25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: _status == 'active' ? ShadColors.success : ShadColors.textDisabled, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text(_status == 'active' ? l10n.clientDetailActive : l10n.clientDetailInactive, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _status == 'active' ? ShadColors.success : ShadColors.textDisabled)),
              ]),
            ),
          ),
          const SizedBox(height: 16),

          _sectionLabel(l10n.clientDetailFixedInfo),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: ShadColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ShadColors.cardBorder),
            ),
            child: Column(children: [
              _infoRow(Icons.email_outlined, l10n.clientDetailEmail, _emailCtrl.text),
              const Divider(height: 1, color: ShadColors.cardBorder),
              _infoRow(Icons.calendar_today_outlined, l10n.clientDetailRegisteredDate, _formatCreatedAt()),
              const Divider(height: 1, color: ShadColors.cardBorder),
              _infoRow(Icons.bar_chart_outlined, l10n.clientDetailSpaceStatus, _status == 'active' ? l10n.clientDetailActive : l10n.clientDetailInactive),
            ]),
          ),
          const SizedBox(height: 16),

          _sectionLabel(l10n.createClientType),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _isBusiness = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _isBusiness ? ShadColors.crimson.withAlpha(40) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _isBusiness ? ShadColors.crimson.withAlpha(80) : ShadColors.inputBorder),
                  ),
                  child: Column(children: [
                    const Text('🏢', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(l10n.clientDetailCompany, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _isBusiness ? ShadColors.textPrimary : ShadColors.textSecondary)),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _isBusiness = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: !_isBusiness ? ShadColors.crimson.withAlpha(40) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: !_isBusiness ? ShadColors.crimson.withAlpha(80) : ShadColors.inputBorder),
                  ),
                  child: Column(children: [
                    const Text('👤', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(l10n.clientDetailIndividual, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: !_isBusiness ? ShadColors.textPrimary : ShadColors.textSecondary)),
                  ]),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          _sectionLabel(l10n.clientDetailEditableData),
          TextField(controller: _nameCtrl, decoration: InputDecoration(labelText: l10n.clientDetailCompanyName)),
          const SizedBox(height: 10),
          TextField(controller: _personCtrl, decoration: InputDecoration(labelText: l10n.clientDetailContactPerson)),
          const SizedBox(height: 10),
          TextField(controller: _phoneCtrl, decoration: InputDecoration(labelText: l10n.clientDetailPhone), keyboardType: TextInputType.phone, textDirection: TextDirection.ltr),
          const SizedBox(height: 10),
          TextField(controller: _countryCtrl, decoration: InputDecoration(labelText: l10n.clientDetailCountry)),
          const SizedBox(height: 10),
          TextField(controller: _industryCtrl, decoration: InputDecoration(labelText: l10n.clientDetailIndustry)),
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
              decoration: InputDecoration(labelText: l10n.clientDetailDateOfBirth),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_dateOfBirthController.text.isNotEmpty ? _dateOfBirthController.text : l10n.clientDetailSelectDate,
                      style: TextStyle(fontSize: 14, color: _dateOfBirthController.text.isNotEmpty ? ShadColors.textPrimary : ShadColors.textDisabled)),
                  const Icon(Icons.calendar_today, size: 18, color: ShadColors.gold),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          _sectionLabel(l10n.clientDetailResetPassword),
          PasswordField(
            controller: _passwordCtrl,
            labelText: l10n.clientDetailNewPassword,
            hintText: l10n.clientDetailLeaveBlank,
            required: false,
          ),
          const SizedBox(height: 16),

          if (_subUsers.isNotEmpty) ...[
            _sectionLabel(l10n.clientDetailSubUsersCount(_subUsers.length)),
            ..._subUsers.map((su) => Container(
              margin: const EdgeInsets.only(bottom: 7),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ShadColors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ShadColors.cardBorder),
              ),
              child: Row(children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ShadColors.goldSoft,
                    border: Border.all(color: ShadColors.goldBorder),
                  ),
                  child: Center(
                    child: Text(
                      (su['name'] as String? ?? '?').substring(0, 1),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ShadColors.gold),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(su['name'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ShadColors.textPrimary)),
                    Text(su['email'] ?? '', style: const TextStyle(fontSize: 10, color: ShadColors.textSecondary), overflow: TextOverflow.ellipsis),
                  ]),
                ),
              ]),
            )),
          ],

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.check, size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(l10n.clientDetailSaveChanges),
                    ]),
              ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.clientDetailCancel),
            ),
          ),
        ],
      ),
    );
  }
}
