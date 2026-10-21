import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/api_client.dart';
import '../../../core/app_log.dart';
import '../../../core/luxe/lx_icons.dart';
import '../../../core/luxe/tokens.dart';
import '../../../core/widgets/luxe/luxe_widgets.dart';
import '../../../core/widgets/client_type_badge.dart';
import '../../../core/widgets/password_field.dart';
import '../../../providers/client_provider.dart';
import 'package:shadapp_client/generated/app_localizations.dart';

class ClientDetailPage extends StatefulWidget {
  final int clientId;
  // Optional so this screen can be pumped in a widget test with a mocked
  // ClientProvider instead of hitting the network.
  final ClientProvider? clientProvider;
  final ApiClient? api;
  const ClientDetailPage({super.key, required this.clientId, this.clientProvider, this.api});

  @override
  State<ClientDetailPage> createState() => _ClientDetailPageState();
}

class _ClientDetailPageState extends State<ClientDetailPage> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final ClientProvider _clientProvider = widget.clientProvider ?? ClientProvider();
  final _nameCtrl = TextEditingController();
  final _personCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _industryCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
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
    _addressCtrl.dispose();
    _passwordCtrl.dispose();
    _dateOfBirthController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _clientProvider.fetchClientRaw(widget.clientId);
      final client = data['client'] as Map<String, dynamic>? ?? {};
      _nameCtrl.text = (client['company_name'] as String? ?? '');
      _personCtrl.text = (client['contact_person'] as String? ?? '');
      _phoneCtrl.text = (client['phone'] as String? ?? '');
      _countryCtrl.text = (client['country'] as String? ?? '');
      _industryCtrl.text = (client['industry'] as String? ?? '');
      _addressCtrl.text = (client['address'] as String? ?? '');
      _dateOfBirthController.text = (client['date_of_birth'] as String? ?? '');
      _emailCtrl.text = (client['email'] as String? ?? '');
      _status = client['status'] as String? ?? 'inactive';
      _clientType = client['client_type'] as String?;
      _isBusiness = _clientType != 'individual';
      _avatarUrl = client['avatar_url'] as String?;
      _createdAt = client['created_at'] as String?;
      _subUsers = client['sub_users'] as List<dynamic>? ?? [];
    } catch (e, s) {
      AppLog.error('client_detail_page._load', e, s);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.single.path == null) return;
    final file = File(result.files.single.path!);
    try {
      await _clientProvider.uploadAvatar(widget.clientId, file);
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ ${AppLocalizations.of(context)!.clientDetailImageChanged}')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppLocalizations.of(context)!.clientDetailImageChangeFailed}: $e')));
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _clientProvider.updateClient(widget.clientId, {
        'company_name': _nameCtrl.text.trim(),
        'contact_person': _personCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'country': _countryCtrl.text.trim(),
        'industry': _industryCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
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

  /// Mockup `.pgh`: 10px (.22em) uppercase faint group label.
  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Text(text.toUpperCase(), style: Lx.text(context, size: 10, color: Lx.faint).copyWith(letterSpacing: 2.2)),
    );
  }

  /// Mockup `.doc` row: muted label, value on the other side.
  Widget _infoRow(String label, String value, {bool last = false, bool ltr = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: Lx.line))),
      child: Row(children: [
        Text(label, style: Lx.text(context, size: 12.5, color: Lx.muted)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(value, textAlign: TextAlign.end, textDirection: ltr ? TextDirection.ltr : null, style: Lx.text(context, size: 13.5)),
        ),
      ]),
    );
  }

  /// Mockup `.chip2` / `.chip2.on`.
  Widget _typeChip(String label, bool on, VoidCallback onTap) => GestureDetector(
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
    if (_loading) return const Scaffold(backgroundColor: Lx.page, body: Center(child: CircularProgressIndicator(color: Lx.crimsonInk)));
    final l10n = AppLocalizations.of(context)!;
    final active = _status == 'active';
    final name = _nameCtrl.text;

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
        body: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 2, 16, 28),
          children: [
            // Header in the workspace `.wsh` language: 64px `.av` (tap to
            // change), serif name + `.tagr`, email, and the `.pill` status.
            Row(children: [
              GestureDetector(
                key: const ValueKey('client-avatar'),
                onTap: _pickAvatar,
                child: _avatarUrl != null
                    ? CircleAvatar(radius: 32, backgroundImage: NetworkImage(_api.resolveFileUrl(_avatarUrl!)))
                    : Container(
                        width: 64,
                        height: 64,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: const Color(0xFF262626), shape: BoxShape.circle, border: Border.all(color: Lx.line2)),
                        child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: const TextStyle(fontFamily: Lx.serif, fontStyle: FontStyle.italic, fontSize: 26, color: Lx.ink)),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Lx.display(context, size: 22))),
                    const SizedBox(width: 8),
                    ClientTypeBadge(clientType: _clientType, compact: true),
                  ]),
                  Text(_emailCtrl.text, textDirection: TextDirection.ltr, style: Lx.text(context, size: 12.5, color: Lx.muted)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(Lx.rPill), border: Border.all(color: active ? const Color(0x668FB98B) : Lx.line2)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      LuxeStatusDot(status: active ? LxStatus.ok : LxStatus.off),
                      const SizedBox(width: 7),
                      Text(active ? l10n.clientDetailActive : l10n.clientDetailInactive, style: Lx.text(context, size: 11, color: Lx.ink2)),
                    ]),
                  ),
                ]),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: LuxeButton(label: l10n.profileChangePicture, size: LuxeButtonSize.sm, onPressed: _pickAvatar),
              ),
            ),

            _sectionLabel(l10n.clientDetailFixedInfo),
            LuxeCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Column(children: [
                _infoRow(l10n.clientDetailEmail, _emailCtrl.text, ltr: true),
                _infoRow(l10n.clientDetailRegisteredDate, _formatCreatedAt()),
                _infoRow(l10n.clientDetailSpaceStatus, active ? l10n.clientDetailActive : l10n.clientDetailInactive, last: true),
              ]),
            ),

            _sectionLabel(l10n.createClientType),
            Wrap(spacing: 8, children: [
              _typeChip(l10n.clientDetailCompany, _isBusiness, () => setState(() => _isBusiness = true)),
              _typeChip(l10n.clientDetailIndividual, !_isBusiness, () => setState(() => _isBusiness = false)),
            ]),

            _sectionLabel(l10n.clientDetailEditableData),
            TextField(controller: _nameCtrl, decoration: InputDecoration(labelText: l10n.clientDetailCompanyName)),
            _gap(),
            TextField(controller: _personCtrl, decoration: InputDecoration(labelText: l10n.clientDetailContactPerson)),
            _gap(),
            TextField(controller: _phoneCtrl, decoration: InputDecoration(labelText: l10n.clientDetailPhone), keyboardType: TextInputType.phone, textDirection: TextDirection.ltr),
            _gap(),
            TextField(controller: _countryCtrl, decoration: InputDecoration(labelText: l10n.clientDetailCountry)),
            _gap(),
            TextField(controller: _industryCtrl, decoration: InputDecoration(labelText: l10n.clientDetailIndustry)),
            _gap(),
            TextField(controller: _addressCtrl, maxLines: 2, minLines: 1, decoration: InputDecoration(labelText: l10n.clientDetailAddress)),
            _gap(),
            GestureDetector(
              key: const ValueKey('client-detail-dob'),
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
                Text(l10n.clientDetailDateOfBirth, style: Lx.text(context, size: 12, color: Lx.muted)),
                Container(
                  padding: const EdgeInsets.only(top: 6, bottom: 9),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Lx.line2))),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        _dateOfBirthController.text.isNotEmpty ? _dateOfBirthController.text : l10n.clientDetailSelectDate,
                        style: Lx.text(context, size: 15, color: _dateOfBirthController.text.isNotEmpty ? Lx.ink : Lx.faint),
                      ),
                    ),
                    const LxIcon('cal', size: 18, color: Lx.muted),
                  ]),
                ),
              ]),
            ),

            _sectionLabel(l10n.clientDetailResetPassword),
            PasswordField(
              controller: _passwordCtrl,
              labelText: l10n.clientDetailNewPassword,
              hintText: l10n.clientDetailLeaveBlank,
              required: false,
            ),

            if (_subUsers.isNotEmpty) ...[
              _sectionLabel(l10n.clientDetailSubUsersCount(_subUsers.length)),
              LuxeCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: Column(children: [
                  for (var i = 0; i < _subUsers.length; i++)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(border: i == _subUsers.length - 1 ? null : const Border(bottom: BorderSide(color: Lx.line))),
                      child: Row(children: [
                        LuxeAvatar(initial: ((_subUsers[i]['name'] as String?) ?? '?').isEmpty ? '?' : (_subUsers[i]['name'] as String).substring(0, 1).toUpperCase(), size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(_subUsers[i]['name'] ?? '', style: Lx.text(context, size: 13.5)),
                            Text(_subUsers[i]['email'] ?? '', overflow: TextOverflow.ellipsis, style: Lx.text(context, size: 12.5, color: Lx.muted)),
                          ]),
                        ),
                      ]),
                    ),
                ]),
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Text(l10n.clientDetailSaveChanges, style: Lx.text(context, size: 14, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: LuxeButton(label: l10n.clientDetailCancel, size: LuxeButtonSize.lg, kind: LuxeButtonKind.quiet, onPressed: () => Navigator.pop(context)),
            ),
          ],
        ),
      ),
    );
  }
}
