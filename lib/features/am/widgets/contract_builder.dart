import 'package:flutter/material.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../../core/api_client.dart';
import '../../../core/app_log.dart';
import '../../../core/luxe/lx_icons.dart';
import '../../../core/luxe/tokens.dart';
import '../../../core/widgets/luxe/luxe_widgets.dart';
import '../../../data/system_settings_repository.dart';
import '../../../providers/contract_provider.dart';
import '../../../providers/system_settings_provider.dart';

/// Reads a system-setting flag that the backend stores as a string ('1'/'0').
///
/// Tolerant on purpose: the same value is read by the dashboard too, and a
/// Laravel cast or API Resource change could start sending a real bool or int
/// instead of the string. Returns false for null/unparseable rather than
/// throwing, since a missing setting should fall back to the caller's default.
bool asSettingFlag(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  final s = value.toString().trim().toLowerCase();
  return s == '1' || s == 'true';
}

class ContractBuilder extends StatefulWidget {
  final VoidCallback? onCreated;
  final bool isAdditional;
  final int? contractId;
  final Map<String, dynamic>? contractData;
  // Optional so this screen can be pumped in a widget test with a mocked
  // ApiClient instead of hitting the network. Defaults to the real
  // singleton — zero behavior change for every existing call site.
  final ApiClient? api;
  final ContractProvider? contractProvider;
  final SystemSettingsProvider? systemSettingsProvider;

  const ContractBuilder({super.key, this.onCreated, this.isAdditional = false, this.contractId, this.contractData, this.api, this.contractProvider, this.systemSettingsProvider});

  @override
  State<ContractBuilder> createState() => _ContractBuilderState();

  static Future<void> show(BuildContext context, {VoidCallback? onCreated, bool isAdditional = false, int? contractId, Map<String, dynamic>? contractData, ApiClient? api, ContractProvider? contractProvider, SystemSettingsProvider? systemSettingsProvider}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Lx.sheet,
      barrierColor: const Color(0x8C000000),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Lx.rSheet)),
        side: BorderSide(color: Lx.line2),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => ContractBuilder(onCreated: onCreated, isAdditional: isAdditional, contractId: contractId, contractData: contractData, api: api, contractProvider: contractProvider, systemSettingsProvider: systemSettingsProvider),
      ),
    );
  }
}

class _ContractBuilderState extends State<ContractBuilder> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final ContractProvider _contractProvider = widget.contractProvider ?? ContractProvider(api: _api);
  // Same wiring as admin_settings_page.dart — the repository takes the
  // injected ApiClient so widget tests exercise this through their mocked
  // http client instead of the real singleton.
  late final SystemSettingsProvider _systemSettingsProvider =
      widget.systemSettingsProvider ?? SystemSettingsProvider(repository: SystemSettingsRepository(api: _api));
  final _titleController = TextEditingController();
  final _valueController = TextEditingController();
  final _customClauseController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _saving = false;
  bool _templatesLoading = true;
  List<String> _customClauses = [];
  List<String> _requiredDocs = [];
  final _requiredDocController = TextEditingController();

  List<Map<String, dynamic>> _fixedClauses = [];
  List<Map<String, dynamic>> _optionalClauses = [];
  bool _showContractDates = true;

  bool get _isEditing => widget.contractId != null;

  void _populateFromContract(Map<String, dynamic> data) {
    _titleController.text = data['title'] ?? '';
    _valueController.text = (data['value'] ?? 0).toString();
    _selectedCurrency = data['currency'] as String? ?? 'SAR';
    if (data['start_date'] != null) _startDate = DateTime.tryParse(data['start_date'].toString());
    if (data['end_date'] != null) _endDate = DateTime.tryParse(data['end_date'].toString());
    final clauses = data['clauses'] as List<dynamic>? ?? [];
    _fixedClauses = clauses.where((c) => c['type'] == 'fixed').map((c) => {'content': c['content'], 'type': 'fixed'}).toList().cast<Map<String, dynamic>>();
    _optionalClauses = clauses.where((c) => c['type'] == 'optional').map((c) => {'content': c['content'], 'selected': true}).toList();
    _customClauses = clauses.where((c) => c['type'] == 'custom').map((c) => c['content'] as String).toList();
    final docs = data['required_documents'] as List<dynamic>? ?? [];
    _requiredDocs = docs.map((d) => d is Map ? d['name'] as String : d.toString()).toList();
  }

  static const _currencies = ['SAR', 'USD', 'EUR', 'AED', 'EGP', 'KWD', 'QAR', 'BHD', 'OMR'];
  String _selectedCurrency = 'SAR';

  Map<String, String> _currencyLabels(AppLocalizations l10n) => {
    'SAR': l10n.contractBuilderCurrencyNameSAR, 'USD': l10n.contractBuilderCurrencyNameUSD, 'EUR': l10n.contractBuilderCurrencyNameEUR,
    'AED': l10n.contractBuilderCurrencyNameAED, 'EGP': l10n.contractBuilderCurrencyNameEGP, 'KWD': l10n.contractBuilderCurrencyNameKWD,
    'QAR': l10n.contractBuilderCurrencyNameQAR, 'BHD': l10n.contractBuilderCurrencyNameBHD, 'OMR': l10n.contractBuilderCurrencyNameOMR,
  };

  List<Map<String, String>> _hardcodedFixedClauses(AppLocalizations l10n) => [
    {'content': l10n.contractBuilderClauseFallback1, 'type': 'fixed'},
    {'content': l10n.contractBuilderClauseFallback2, 'type': 'fixed'},
    {'content': l10n.contractBuilderClauseFallback3, 'type': 'fixed'},
    {'content': l10n.contractBuilderClauseFallback4, 'type': 'fixed'},
  ];

  List<Map<String, dynamic>> _hardcodedOptionalClauses(AppLocalizations l10n) => [
    {'content': l10n.contractBuilderClauseOptional1, 'selected': false},
    {'content': l10n.contractBuilderClauseOptional2, 'selected': false},
    {'content': l10n.contractBuilderClauseOptional3, 'selected': false},
    {'content': l10n.contractBuilderClauseOptional4, 'selected': false},
    {'content': l10n.contractBuilderClauseOptional5, 'selected': false},
    {'content': l10n.contractBuilderClauseOptional6, 'selected': false},
  ];

  @override
  void initState() {
    super.initState();
    if (_isEditing && widget.contractData != null) {
      _populateFromContract(widget.contractData!);
    }
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    try {
      // Deliberately non-blocking and non-fatal: if the setting can't be read
      // the builder still opens, just with the default (dates shown). Logged
      // rather than swallowed so a persistently failing /settings is
      // diagnosable instead of silently changing what the form shows.
      try {
        final settingsRes = await _systemSettingsProvider.fetchSettings();
        final settings = settingsRes['settings'];
        if (settings is Map && settings['show_contract_dates'] != null) {
          final val = settings['show_contract_dates']['value'];
          if (val != null && mounted) {
            setState(() => _showContractDates = asSettingFlag(val));
          }
        }
      } catch (e, s) {
        AppLog.error('contract_builder._loadTemplates(settings)', e, s);
      }

      final data = await _contractProvider.fetchClauseTemplates();
      final templates = data['templates'] as List<dynamic>? ?? [];

      if (_isEditing) {
        final existingContents = <String>{
          ..._fixedClauses.map((c) => (c['content'] as String?)?.trim() ?? ''),
          ..._optionalClauses.map((c) => (c['content'] as String?)?.trim() ?? ''),
          ..._customClauses,
        };
        for (final t in templates) {
          final content = (t['content'] as String?)?.trim() ?? '';
          if (content.isEmpty || existingContents.contains(content)) continue;
          existingContents.add(content);
          if (t['type'] == 'fixed') {
            _fixedClauses.add({'content': content, 'type': 'fixed'});
          } else if (t['type'] == 'optional') {
            _optionalClauses.add({'content': content, 'selected': false});
          }
        }
      } else {
        final seen = <String>{};
        for (final t in templates) {
          final content = (t['content'] as String?)?.trim() ?? '';
          if (content.isEmpty || seen.contains(content)) continue;
          seen.add(content);
          if (t['type'] == 'fixed') {
            _fixedClauses.add({'content': content, 'type': 'fixed'});
          } else if (t['type'] == 'optional') {
            _optionalClauses.add({'content': content, 'selected': false});
          }
        }
      }
    } catch (_) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        if (_fixedClauses.isEmpty) _fixedClauses = _hardcodedFixedClauses(l10n).map((f) => Map<String, dynamic>.from(f)).toList();
        if (_optionalClauses.isEmpty) _optionalClauses = _hardcodedOptionalClauses(l10n).map((o) => Map<String, dynamic>.from(o)).toList();
      }
    }
    if (mounted) setState(() => _templatesLoading = false);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    if (_titleController.text.trim().isEmpty || _api.workspaceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.contractBuilderTitleRequired)));
      return;
    }
    final value = double.tryParse(_valueController.text);
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.contractBuilderValueRequired)));
      return;
    }

    setState(() => _saving = true);

    final clauses = <Map<String, dynamic>>[];
    if (_isEditing) {
      for (final f in _fixedClauses) {
        clauses.add({'content': f['content'], 'type': 'fixed', 'sort_order': clauses.length + 1});
      }
    }
    for (final o in _optionalClauses) {
      if (o['selected'] == true) {
        clauses.add({'content': o['content'], 'type': 'optional', 'sort_order': clauses.length + 1});
      }
    }
    for (int i = 0; i < _customClauses.length; i++) {
      clauses.add({'content': _customClauses[i], 'type': 'custom', 'sort_order': clauses.length + 1});
    }

    final requiredDocs = _requiredDocs.map((name) => {'name': name}).toList();

    try {
      final payload = {
        'title': _titleController.text.trim(),
        'value': value,
        'currency': _selectedCurrency,
        'clauses': clauses,
        'required_documents': requiredDocs,
        if (_startDate != null) 'start_date': _startDate!.toIso8601String(),
        if (_endDate != null) 'end_date': _endDate!.toIso8601String(),
        if (widget.isAdditional) 'contract_type': 'additional',
      };
      if (_isEditing) {
        await _contractProvider.update(widget.contractId!, payload);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.contractBuilderUpdated)));
        Navigator.pop(context);
        widget.onCreated?.call();
      } else {
        final data = await _contractProvider.create(_api.workspaceId!, payload);
        if (!mounted) return;
        final contractId = data['contract']['id'] as int;
        try {
          await _contractProvider.send(contractId);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle, color: Colors.green, size: 18), const SizedBox(width: 8), Text(l10n.contractBuilderCreatedAndSent)])));
        } catch (_) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.warning, color: Colors.orange, size: 18), const SizedBox(width: 8), Text(l10n.contractBuilderCreatedSendFailed)])));
        }
        Navigator.pop(context);
        widget.onCreated?.call();
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEditing ? l10n.contractBuilderUpdateFailed : l10n.contractBuilderCreateFailed)));
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _valueController.dispose();
    _customClauseController.dispose();
    _requiredDocController.dispose();
    super.dispose();
  }

  /// Mockup `.pgh`: 10px (.22em) uppercase faint group label.
  Widget _pgh(String text) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 6),
        child: Text(text.toUpperCase(), style: Lx.text(context, size: 10, color: Lx.faint).copyWith(letterSpacing: 2.2)),
      );

  /// `.f2` date field: label, value on the underline, calendar icon.
  Widget _dateField(String label, DateTime? value, VoidCallback onTap, Key key) => GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Lx.text(context, size: 12, color: Lx.muted)),
          Container(
            padding: const EdgeInsets.only(top: 6, bottom: 9),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Lx.line2))),
            child: Row(children: [
              Expanded(
                child: Text(
                  value != null ? '${value.day}/${value.month}/${value.year}' : AppLocalizations.of(context)!.contractBuilderSelectDate,
                  style: Lx.text(context, size: 15, color: value != null ? Lx.ink : Lx.faint),
                ),
              ),
              const LxIcon('cal', size: 18, color: Lx.muted),
            ]),
          ),
        ]),
      );

  /// A `.doc`-style list row with an optional remove (trash) action.
  Widget _row({required Widget lead, required String text, VoidCallback? onRemove, bool last = false, bool faint = false}) => Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: Lx.line))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          lead,
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: Lx.text(context, size: 13, color: faint ? Lx.ink2 : Lx.ink, height: 1.6))),
          if (onRemove != null)
            InkResponse(
              onTap: onRemove,
              radius: 16,
              child: const Padding(padding: EdgeInsets.all(3), child: LxIcon('trash', size: 15, color: Lx.danger)),
            ),
        ]),
      );

  /// Input + "+" add button (custom clauses / required documents).
  Widget _adder(TextEditingController c, String hint, VoidCallback onAdd, Key key) => Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: TextField(controller: c, decoration: InputDecoration(hintText: hint), onSubmitted: (_) => onAdd())),
        const SizedBox(width: 10),
        LuxeButton(key: key, label: '+', size: LuxeButtonSize.sm, onPressed: onAdd),
      ]);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Widget numCell(int i) => SizedBox(width: 18, child: Text('${i + 1}', style: Lx.text(context, size: 11, color: Lx.faint, height: 1.9)));
    return LuxeFormTheme(
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(20, 10, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(children: [
          // Mockup sheet: `.grab` + h3 serif 22.
          Center(
            child: Container(width: 38, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Lx.line2, borderRadius: BorderRadius.circular(2))),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              _isEditing ? l10n.contractBuilderEditTitle : widget.isAdditional ? l10n.contractBuilderCreateExtraTitle : l10n.contractBuilderCreateNewTitle,
              style: Lx.display(context, size: 22),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: _templatesLoading
                ? const Center(child: CircularProgressIndicator(color: Lx.crimsonInk))
                : ListView(
                    children: [
                      TextField(
                        controller: _titleController,
                        decoration: InputDecoration(labelText: '${l10n.contractTitle} *', hintText: l10n.contractBuilderTitleHint),
                      ),
                      const SizedBox(height: 14),
                      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _valueController,
                            decoration: InputDecoration(labelText: l10n.contractValue),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            key: ValueKey(_selectedCurrency),
                            initialValue: _selectedCurrency,
                            dropdownColor: Lx.sheet,
                            isExpanded: true,
                            decoration: InputDecoration(labelText: l10n.contractCurrency),
                            // Menu shows "EGP — Egyptian pound", the field just the code.
                            selectedItemBuilder: (_) => _currencies.map((c) => Text(c, style: Lx.text(context, size: 15))).toList(),
                            items: _currencies.map((c) => DropdownMenuItem(value: c, child: Text('$c — ${_currencyLabels(l10n)[c] ?? ''}', style: Lx.text(context, size: 14)))).toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _selectedCurrency = v);
                            },
                          ),
                        ),
                      ]),
                      if (_showContractDates) ...[
                        const SizedBox(height: 14),
                        Row(children: [
                          Expanded(
                            child: _dateField(l10n.contractStartDateLabel, _startDate, () async {
                              final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 3650)));
                              if (d != null) setState(() => _startDate = d);
                            }, const ValueKey('cb-start')),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _dateField(l10n.contractEndDateLabel, _endDate, () async {
                              final d = await showDatePicker(context: context, initialDate: (_startDate ?? DateTime.now()).add(const Duration(days: 30)), firstDate: _startDate ?? DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 3650)));
                              if (d != null) setState(() => _endDate = d);
                            }, const ValueKey('cb-end')),
                          ),
                        ]),
                      ],

                      // Fixed clauses — always included.
                      _pgh(l10n.contractBuilderFixedClauses),
                      for (var i = 0; i < _fixedClauses.length; i++)
                        _row(lead: numCell(i), text: _fixedClauses[i]['content']!, last: i == _fixedClauses.length - 1, faint: true),

                      // Optional clauses — mockup `.cbx` (18px, r5, crimson when on).
                      if (_optionalClauses.isNotEmpty) _pgh(l10n.contractBuilderOptionalClauses),
                      for (var i = 0; i < _optionalClauses.length; i++)
                        GestureDetector(
                          key: ValueKey('cb-optional-$i'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _optionalClauses[i]['selected'] = !(_optionalClauses[i]['selected'] == true)),
                          child: _row(
                            lead: Container(
                              width: 18,
                              height: 18,
                              margin: const EdgeInsets.only(top: 2),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _optionalClauses[i]['selected'] == true ? Lx.crimson : Colors.transparent,
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: _optionalClauses[i]['selected'] == true ? Lx.crimson : Lx.line2),
                              ),
                              child: _optionalClauses[i]['selected'] == true ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
                            ),
                            text: '${_optionalClauses[i]['content']}',
                            last: i == _optionalClauses.length - 1,
                          ),
                        ),

                      // Custom clauses.
                      _pgh(l10n.contractBuilderCustomClauses),
                      _adder(_customClauseController, l10n.contractBuilderCustomClauseHint, () {
                        final text = _customClauseController.text.trim();
                        if (text.isNotEmpty) setState(() { _customClauses.add(text); _customClauseController.clear(); });
                      }, const ValueKey('cb-add-clause')),
                      for (var i = 0; i < _customClauses.length; i++)
                        _row(lead: numCell(i), text: _customClauses[i], onRemove: () => setState(() => _customClauses.removeAt(i)), last: i == _customClauses.length - 1),

                      // Required documents.
                      _pgh(l10n.contractRequiredDocs),
                      _adder(_requiredDocController, l10n.contractBuilderDocNameHint, () {
                        final text = _requiredDocController.text.trim();
                        if (text.isNotEmpty) setState(() { _requiredDocs.add(text); _requiredDocController.clear(); });
                      }, const ValueKey('cb-add-doc')),
                      for (var i = 0; i < _requiredDocs.length; i++)
                        _row(
                          lead: const Padding(padding: EdgeInsets.only(top: 2), child: LxIcon('doc', size: 16, color: Lx.muted)),
                          text: _requiredDocs[i],
                          onRemove: () => setState(() => _requiredDocs.removeAt(i)),
                          last: i == _requiredDocs.length - 1,
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),
          ),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Text(_isEditing ? l10n.contractBuilderSaveChanges : l10n.contractBuilderCreateAndSend, style: Lx.text(context, size: 14, color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }
}
