import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_log.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/client_type_badge.dart';
import '../../../providers/approval_provider.dart';
import '../../../providers/client_provider.dart';
import '../../../providers/contract_provider.dart';
import '../../../providers/payment_provider.dart';
import 'package:shadapp_client/generated/app_localizations.dart';

class SaApprovalsPage extends StatefulWidget {
  // Optional so this screen can be pumped in a widget test with mocked
  // providers instead of hitting the network.
  final ClientProvider? clientProvider;
  final ContractProvider? contractProvider;
  final PaymentProvider? paymentProvider;
  final ApprovalProvider? approvalProvider;
  const SaApprovalsPage({super.key, this.clientProvider, this.contractProvider, this.paymentProvider, this.approvalProvider});

  @override
  State<SaApprovalsPage> createState() => _SaApprovalsPageState();
}

class _SaApprovalsPageState extends State<SaApprovalsPage> {
  late final ClientProvider _clientProvider = widget.clientProvider ?? ClientProvider();
  late final ContractProvider _contractProvider = widget.contractProvider ?? ContractProvider();
  late final PaymentProvider _paymentProvider = widget.paymentProvider ?? PaymentProvider();
  late final ApprovalProvider _approvalProvider = widget.approvalProvider ?? ApprovalProvider();
  List<Map<String, dynamic>> _contracts = [];
  List<Map<String, dynamic>> _payments = [];
  // 23 Sept 2026 — the "Approvals" badge on the AM dashboard counts pending
  // Approval records (client-facing approval requests raised from a
  // workspace's own Approvals tab) alongside pending contracts, but this
  // screen used to only list contracts+payments — so the badge could say 2
  // while this list showed 1. See _fetchApprovals.
  List<Map<String, dynamic>> _approvals = [];
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
        final allPayments = await _paymentProvider.fetchAllPendingRaw();
        _payments = allPayments.cast<Map<String, dynamic>>().map((p) => {
          ...p,
          'type': 'payment',
          'workspace_id': p['workspace_id'] ?? p['workspace']?['id'],
        }).toList();
      } catch (e, s) {
        AppLog.error('sa_approvals_page._load(payments)', e, s);
        _payments = [];
      }
      try {
        _approvals = await _fetchApprovals();
      } catch (e, s) {
        AppLog.error('sa_approvals_page._load(approvals)', e, s);
        _approvals = [];
      }
    } catch (e, s) {
      AppLog.error('sa_approvals_page._load', e, s);
    }
    if (mounted) setState(() => _loading = false);
  }

  // One request to /approvals/pending (already scoped server-side to this
  // user's workspaces, same scope as the badge) instead of looping every
  // client's workspace — that loop was N+1 and, since the per-workspace
  // endpoint is paginated at 30, silently missed older pending approvals.
  Future<List<Map<String, dynamic>>> _fetchApprovals() async {
    final raw = await _approvalProvider.fetchAllPendingRaw();
    return raw.whereType<Map>().map((a) {
      final approval = Map<String, dynamic>.from(a);
      final ws = approval['workspace'] is Map ? Map<String, dynamic>.from(approval['workspace'] as Map) : null;
      final client = ws?['client'] is Map ? Map<String, dynamic>.from(ws!['client'] as Map) : null;
      return <String, dynamic>{
        'title': approval['title'] ?? '',
        'company': client?['company_name'] ?? '',
        'client': client,
        'workspace_id': approval['workspace_id'] ?? ws?['id'],
        'type': 'approval',
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchContracts(List<String> statuses) async {
    final results = <Map<String, dynamic>>[];
    try {
      final allClients = await _clientProvider.fetchAllClientsPaginatedRaw();
      for (final client in allClients) {
        final ws = client['workspace'] as Map<String, dynamic>?;
        if (ws == null) continue;
        try {
          final allContracts = await _contractProvider.fetchWorkspaceContractsPaginatedRaw(ws['id'] as int);
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
        } catch (e, s) {
          // One workspace failing shouldn't drop the whole list.
          AppLog.error('sa_approvals_page._loadApprovals(workspace)', e, s);
          continue;
        }
      }
    } catch (e, s) {
      AppLog.error('sa_approvals_page._loadApprovals', e, s);
    }
    return results;
  }

  List<Map<String, dynamic>> get _filteredItems {
    switch (_filterIndex) {
      case 1: return _contracts;
      case 2: return _payments.cast<Map<String, dynamic>>();
      case 3: return _approvals;
      default: return [..._contracts, ..._payments.cast<Map<String, dynamic>>(), ..._approvals];
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final total = _contracts.length + _payments.length + _approvals.length;
    return RefreshIndicator(
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(children: [
                  Text(l10n.amStatPendingApprovals, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
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
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text(l10n.amNoPendingApprovals, style: const TextStyle(fontSize: 13, color: ShadColors.textDisabled, fontFamily: 'Archivo'))),
                  )
                else
                  ..._filteredItems.map((item) => _approvalCard(item)),
              ],
            ),
    );
  }

  Widget _buildPillsFilter(int total) {
    final l10n = AppLocalizations.of(context)!;
    final filters = [
      (l10n.all, total),
      (l10n.saApprovalsContracts, _contracts.length),
      (l10n.saApprovalsPayments, _payments.length),
      (l10n.approvals, _approvals.length),
    ];
    return Row(
      children: filters.asMap().entries.map((entry) {
        final i = entry.key;
        final (label, count) = entry.value;
        final active = _filterIndex == i;
        return Padding(
          padding: const EdgeInsetsDirectional.only(start: 6),
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
    final l10n = AppLocalizations.of(context)!;
    final type = item['type'] as String?;
    final isContract = type == 'contract';
    final isApproval = type == 'approval';
    // 23 Sept 2026 — a third item type (pending Approval records, previously
    // missing from this list entirely — see _fetchApprovals above) alongside
    // the existing contract/payment two-way split.
    final accentColor = isContract ? ShadColors.gold : (isApproval ? ShadColors.purple : ShadColors.sent);
    final typeLabel = isContract ? l10n.saApprovalsContractLabel : (isApproval ? l10n.saApprovalsApprovalLabel : l10n.saApprovalsPaymentLabel);
    final title = isContract
        ? l10n.saApprovalsContractApprovalTitle(item['title'].toString())
        : isApproval
            ? l10n.saApprovalsApprovalPendingTitle(item['title'].toString())
            : l10n.saApprovalsPaymentApprovalTitle(item['company']?.toString() ?? '');
    final subtitle = isContract
        ? '${item['company']} • ${double.tryParse(item['value']?.toString() ?? '')?.toStringAsFixed(0) ?? '0'} ${item['currency'] ?? ''}'
        : isApproval
            ? '${item['company'] ?? ''}'
            : '${item['currency'] ?? ''} ${(double.tryParse(item['amount']?.toString() ?? '') ?? 0).toStringAsFixed(0)}';

    return GestureDetector(
      onTap: () {
        final wsId = item['workspace_id'];
        if (wsId == null) return;
        final tab = isContract ? 2 : (isApproval ? 4 : 3);
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
              color: accentColor,
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
                      color: accentColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(typeLabel, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: accentColor, fontFamily: 'Archivo')),
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
