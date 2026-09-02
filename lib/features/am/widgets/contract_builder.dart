import 'package:flutter/material.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../../core/api_client.dart';
import '../../../core/app_log.dart';
import '../../../core/theme.dart';
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(24, 0, 24, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(children: [
              Text(_isEditing ? l10n.contractBuilderEditTitle : widget.isAdditional ? l10n.contractBuilderCreateExtraTitle : l10n.contractBuilderCreateNewTitle, style: ShadTypography.cardTitle),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ]),
          ),
          const Divider(),
          Expanded(
            child: _templatesLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
              children: [
                // Title
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(labelText: '${l10n.contractTitle} *', hintText: l10n.contractBuilderTitleHint),
                ),
                const SizedBox(height: 12),

                // Value
                TextField(
                  controller: _valueController,
                  decoration: InputDecoration(labelText: l10n.contractValue, prefixText: '$_selectedCurrency '),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey(_selectedCurrency),
                  initialValue: _selectedCurrency,
                  decoration: InputDecoration(labelText: l10n.contractCurrency),
                  items: _currencies.map((c) => DropdownMenuItem(
                    value: c,
                    child: Text('$c — ${_currencyLabels(l10n)[c] ?? ''}'),
                  )).toList(),
                  onChanged: (v) { if (v != null) setState(() => _selectedCurrency = v); },
                ),
                if (_showContractDates) ...[
                  const SizedBox(height: 12),
                  // Dates
                  Row(children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 3650)));
                          if (d != null) setState(() => _startDate = d);
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(labelText: l10n.contractStartDateLabel),
                          child: Text(_startDate != null ? '${_startDate!.year}/${_startDate!.month}/${_startDate!.day}' : l10n.contractBuilderSelectDate),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final d = await showDatePicker(context: context, initialDate: (_startDate ?? DateTime.now()).add(const Duration(days: 30)), firstDate: _startDate ?? DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 3650)));
                          if (d != null) setState(() => _endDate = d);
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(labelText: l10n.contractEndDateLabel),
                          child: Text(_endDate != null ? '${_endDate!.year}/${_endDate!.month}/${_endDate!.day}' : l10n.contractBuilderSelectDate),
                        ),
                      ),
                    ),
                  ]),
                ],
                const SizedBox(height: 24),

                // Fixed Clauses
                Text(l10n.contractBuilderFixedClauses, style: ShadTypography.sectionHeader),
                const SizedBox(height: 8),
                ..._fixedClauses.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.check_circle, size: 18, color: ShadColors.success),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f['content']!, style: ShadTypography.cardBody.copyWith(color: ShadColors.textSecondary))),
                  ]),
                )),
                const SizedBox(height: 16),

                // Optional Clauses
                Text(l10n.contractBuilderOptionalClauses, style: ShadTypography.sectionHeader),
                const SizedBox(height: 8),
                ..._optionalClauses.map((o) => CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(o['content'], style: ShadTypography.cardBody),
                  value: o['selected'],
                  onChanged: (v) => setState(() => o['selected'] = v),
                )),
                const SizedBox(height: 16),

                // Custom Clauses
                Text(l10n.contractBuilderCustomClauses, style: ShadTypography.sectionHeader),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _customClauseController,
                      decoration: InputDecoration(hintText: l10n.contractBuilderCustomClauseHint, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: ShadColors.primary),
                    onPressed: () {
                      final text = _customClauseController.text.trim();
                      if (text.isNotEmpty) {
                        setState(() { _customClauses.add(text); _customClauseController.clear(); });
                      }
                    },
                  ),
                ]),
                ..._customClauses.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.circle, size: 6, color: ShadColors.textDisabled),
                    const SizedBox(width: 8),
                    Expanded(child: Text(e.value, style: ShadTypography.cardBody)),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: ShadColors.error),
                      onPressed: () => setState(() => _customClauses.removeAt(e.key)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ]),
                )),
                const SizedBox(height: 16),

                // Required Documents
                Text(l10n.contractRequiredDocs, style: ShadTypography.sectionHeader),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _requiredDocController,
                      decoration: InputDecoration(hintText: l10n.contractBuilderDocNameHint, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: ShadColors.primary),
                    onPressed: () {
                      final text = _requiredDocController.text.trim();
                      if (text.isNotEmpty) {
                        setState(() { _requiredDocs.add(text); _requiredDocController.clear(); });
                      }
                    },
                  ),
                ]),
                ..._requiredDocs.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.description, size: 16, color: ShadColors.gold),
                    const SizedBox(width: 8),
                    Expanded(child: Text(e.value, style: ShadTypography.cardBody)),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: ShadColors.error),
                      onPressed: () => setState(() => _requiredDocs.removeAt(e.key)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ]),
                )),
                const SizedBox(height: 24),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Text(_isEditing ? l10n.contractBuilderSaveChanges : l10n.contractBuilderCreateAndSend),
            ),
          ),
        ],
      ),
    );
  }
}
