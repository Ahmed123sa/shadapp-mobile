import 'package:flutter/material.dart';
import '../../../core/api_client.dart';
import '../../../core/theme.dart';

class ContractBuilder extends StatefulWidget {
  final VoidCallback? onCreated;
  final bool isAdditional;
  final int? contractId;
  final Map<String, dynamic>? contractData;

  const ContractBuilder({super.key, this.onCreated, this.isAdditional = false, this.contractId, this.contractData});

  @override
  State<ContractBuilder> createState() => _ContractBuilderState();

  static Future<void> show(BuildContext context, {VoidCallback? onCreated, bool isAdditional = false, int? contractId, Map<String, dynamic>? contractData}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => ContractBuilder(onCreated: onCreated, isAdditional: isAdditional, contractId: contractId, contractData: contractData),
      ),
    );
  }
}

class _ContractBuilderState extends State<ContractBuilder> {
  final _api = ApiClient();
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
  static const _currencyLabels = {
    'SAR': 'ريال سعودي', 'USD': 'دولار أمريكي', 'EUR': 'يورو',
    'AED': 'درهم إماراتي', 'EGP': 'جنيه مصري', 'KWD': 'دينار كويتي',
    'QAR': 'ريال قطري', 'BHD': 'دينار بحريني', 'OMR': 'ريال عماني',
  };
  String _selectedCurrency = 'SAR';

  final List<Map<String, String>> _hardcodedFixed = const [
    {'content': 'يقر الطرفان بأهليتهما القانونية للتعاقد', 'type': 'fixed'},
    {'content': 'يلتزم الطرف الأول بتقديم الخدمات المتفق عليها', 'type': 'fixed'},
    {'content': 'يلتزم الطرف الثاني بسداد القيمة المتفق عليها', 'type': 'fixed'},
    {'content': 'يلتزم الطرفان بالسرية التامة', 'type': 'fixed'},
  ];

  final List<Map<String, dynamic>> _hardcodedOptional = const [
    {'content': 'يحق للطرفين إنهاء العقد بإشعار خطي قبل 30 يوماً', 'selected': false},
    {'content': 'لا تتحمل الشركة مسؤولية أي تأخير ناتج عن ظروف قاهرة', 'selected': false},
    {'content': 'تكون حقوق الملكية الفكرية مملوكة للطرف الأول', 'selected': false},
    {'content': 'يحق للطرف الأول تعديل الأسعار بعد 12 شهراً', 'selected': false},
    {'content': 'يخضع العقد للقوانين واللوائح المحلية', 'selected': false},
    {'content': 'يتم حل النزاعات عن طريق التحكيم', 'selected': false},
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
      final data = await _api.get('/contract-clause-templates');
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
      if (_fixedClauses.isEmpty) _fixedClauses = _hardcodedFixed.map((f) => Map<String, dynamic>.from(f)).toList();
      if (_optionalClauses.isEmpty) _optionalClauses = _hardcodedOptional.map((o) => Map<String, dynamic>.from(o)).toList();
    }
    if (mounted) setState(() => _templatesLoading = false);
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty || _api.workspaceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال عنوان العقد')));
      return;
    }
    final value = double.tryParse(_valueController.text);
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال قيمة العقد')));
      return;
    }

    setState(() => _saving = true);

    final clauses = <Map<String, dynamic>>[];
    for (final f in _fixedClauses) {
      clauses.add({'content': f['content'], 'type': 'fixed', 'sort_order': clauses.length + 1});
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
        await _api.put('/contracts/${widget.contractId}', payload);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث العقد')));
        Navigator.pop(context);
        widget.onCreated?.call();
      } else {
        final data = await _api.post('/workspaces/${_api.workspaceId}/contracts', payload);
        if (!mounted) return;
        final contractId = data['contract']['id'] as int;
        try {
          await _api.post('/contracts/$contractId/send');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم إنشاء وإرسال العقد')));
        } catch (_) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ تم إنشاء العقد ولكن فشل الإرسال')));
        }
        Navigator.pop(context);
        widget.onCreated?.call();
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEditing ? 'فشل تحديث العقد' : 'فشل إنشاء العقد')));
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
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(children: [
              Text(_isEditing ? 'تعديل العقد' : widget.isAdditional ? 'إنشاء عقد خدمة إضافية' : 'إنشاء عقد جديد', style: ShadTypography.cardTitle),
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
                  decoration: const InputDecoration(labelText: 'عنوان العقد *', hintText: 'مثال: عقد صيانة إضافي'),
                ),
                const SizedBox(height: 12),

                // Value
                TextField(
                  controller: _valueController,
                  decoration: InputDecoration(labelText: 'قيمة العقد *', prefixText: '$_selectedCurrency '),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey(_selectedCurrency),
                  initialValue: _selectedCurrency,
                  decoration: const InputDecoration(labelText: 'العملة'),
                  items: _currencies.map((c) => DropdownMenuItem(
                    value: c,
                    child: Text('$c — ${_currencyLabels[c] ?? ''}'),
                  )).toList(),
                  onChanged: (v) { if (v != null) setState(() => _selectedCurrency = v); },
                ),
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
                        decoration: const InputDecoration(labelText: 'تاريخ البداية'),
                        child: Text(_startDate != null ? '${_startDate!.year}/${_startDate!.month}/${_startDate!.day}' : 'اختيار تاريخ'),
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
                        decoration: const InputDecoration(labelText: 'تاريخ النهاية'),
                        child: Text(_endDate != null ? '${_endDate!.year}/${_endDate!.month}/${_endDate!.day}' : 'اختيار تاريخ'),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 24),

                // Fixed Clauses
                Text('البنود الثابتة', style: ShadTypography.sectionHeader),
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
                Text('البنود الاختيارية', style: ShadTypography.sectionHeader),
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
                Text('بنود مخصصة', style: ShadTypography.sectionHeader),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _customClauseController,
                      decoration: const InputDecoration(hintText: 'اكتب بند جديد...', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
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
                Text('المستندات المطلوبة من العميل', style: ShadTypography.sectionHeader),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _requiredDocController,
                      decoration: const InputDecoration(hintText: 'اسم المستند...', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
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
                  : Text(_isEditing ? 'حفظ التعديلات' : 'إنشاء وإرسال'),
            ),
          ),
        ],
      ),
    );
  }
}
