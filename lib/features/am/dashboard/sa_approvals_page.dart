import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/client_type_badge.dart';

class SaApprovalsPage extends StatefulWidget {
  const SaApprovalsPage({super.key});

  @override
  State<SaApprovalsPage> createState() => _SaApprovalsPageState();
}

class _SaApprovalsPageState extends State<SaApprovalsPage> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _contracts = [];
  List<Map<String, dynamic>> _payments = [];
  bool _loading = true;
  int _filterIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _contracts = await _fetchContracts(['sent', 'client_approved']);
      try {
        List<dynamic> allPayments = [];
        int pPage = 1;
        while (true) {
          final pd = await _api.get('/payments/pending?page=$pPage');
          final batch = safeList(pd['payments']);
          if (batch.isEmpty) break;
          allPayments.addAll(batch);
          final lastPage = (pd['payments'] is Map ? pd['payments']['last_page'] : null) ?? 1;
          if (pPage >= lastPage) break;
          pPage++;
        }
        _payments = allPayments.cast<Map<String, dynamic>>().map((p) => {
          ...p,
          'type': 'payment',
          'workspace_id': p['workspace_id'] ?? p['workspace']?['id'],
        }).toList();
      } catch (_) {
        _payments = [];
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<List<Map<String, dynamic>>> _fetchContracts(List<String> statuses) async {
    final results = <Map<String, dynamic>>[];
    try {
      List<dynamic> allClients = [];
      int page = 1;
      while (true) {
        final data = await _api.get('/clients?page=$page');
        final batch = safeList(data['clients']);
        if (batch.isEmpty) break;
        allClients.addAll(batch);
        final lastPage = (data['clients'] is Map ? data['clients']['last_page'] : null) ?? 1;
        if (page >= lastPage) break;
        page++;
      }
      for (final client in allClients) {
        final ws = client['workspace'] as Map<String, dynamic>?;
        if (ws == null) continue;
        try {
          List<dynamic> allContracts = [];
          int cPage = 1;
          while (true) {
            final cd = await _api.get('/workspaces/${ws['id']}/contracts?page=$cPage');
            final batch = safeList(cd['contracts']);
            if (batch.isEmpty) break;
            allContracts.addAll(batch);
            final lastPage = (cd['contracts'] is Map ? cd['contracts']['last_page'] : null) ?? 1;
            if (cPage >= lastPage) break;
            cPage++;
          }
          for (final c in allContracts) {
            if (statuses.contains(c['status'])) {
              results.add({
                'title': c['title'] ?? '',
                'value': c['value'] ?? 0,
                'currency': c['currency'] ?? 'SAR',
                'company': client['company_name'] ?? '',
                'client': client,
                'workspace_id': ws['id'],
                'type': 'contract',
              });
            }
          }
        } catch (_) {
          continue;
        }
      }
    } catch (_) {}
    return results;
  }

  List<Map<String, dynamic>> get _filteredItems {
    switch (_filterIndex) {
      case 1: return _contracts;
      case 2: return _payments.cast<Map<String, dynamic>>();
      default: return [..._contracts, ..._payments.cast<Map<String, dynamic>>()];
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _contracts.length + _payments.length;
    return RefreshIndicator(
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(children: [
                  Text('الموافقات المعلّقة', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: ShadColors.crimson.withAlpha(30), borderRadius: BorderRadius.circular(10)),
                    child: Text('$total', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ShadColors.gold, fontFamily: 'PlayfairDisplay')),
                  ),
                ]),
                const SizedBox(height: 12),
                _buildPillsFilter(total),
                const SizedBox(height: 12),
                if (_filteredItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text('لا توجد موافقات معلّقة', style: TextStyle(fontSize: 13, color: ShadColors.textDisabled, fontFamily: 'Archivo'))),
                  )
                else
                  ..._filteredItems.map((item) => _approvalCard(item)),
              ],
            ),
    );
  }

  Widget _buildPillsFilter(int total) {
    final filters = [
      ('الكل', total),
      ('عقود', _contracts.length),
      ('دفعات', _payments.length),
    ];
    return Row(
      children: filters.asMap().entries.map((entry) {
        final i = entry.key;
        final (label, count) = entry.value;
        final active = _filterIndex == i;
        return Padding(
          padding: const EdgeInsets.only(left: 6),
          child: GestureDetector(
            onTap: () => setState(() => _filterIndex = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: active ? ShadColors.gold.withAlpha(25) : ShadColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: active ? ShadColors.gold : ShadColors.cardBorder),
              ),
              child: Text('$label ($count)', style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? ShadColors.gold : ShadColors.textSecondary, fontFamily: 'Archivo')),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _approvalCard(Map<String, dynamic> item) {
    final isContract = item['type'] == 'contract';
    final title = isContract ? 'اعتماد عقد — ${item['title']}' : 'اعتماد دفعة — ${item['company'] ?? ''}';
    final subtitle = isContract
        ? '${item['company']} • ${double.tryParse(item['value']?.toString() ?? '')?.toStringAsFixed(0) ?? '0'} ${item['currency'] ?? ''}'
        : '${item['currency'] ?? ''} ${(double.tryParse(item['amount']?.toString() ?? '') ?? 0).toStringAsFixed(0)}';

    return GestureDetector(
      onTap: () {
        final wsId = item['workspace_id'];
        if (wsId == null) return;
        final tab = isContract ? 2 : 3;
        context.push('/am/workspace/$wsId?tab=$tab');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: ShadColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ShadColors.cardBorder),
        ),
        child: Row(children: [
          Container(
            width: 3,
            height: 56,
            decoration: BoxDecoration(
              color: isContract ? ShadColors.gold : ShadColors.sent,
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'Archivo'))),
                  const SizedBox(width: 6),
                  ClientTypeBadge(clientType: (item['client'] as Map<String, dynamic>?)?['client_type'] as String?, compact: true),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (isContract ? ShadColors.gold : ShadColors.sent).withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(isContract ? 'عقد' : 'دفعة', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: isContract ? ShadColors.gold : ShadColors.sent, fontFamily: 'Archivo')),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 10, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
