import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api_client.dart';
import '../../../core/app_log.dart';
import '../../../core/theme.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../providers/contract_provider.dart';
import '../widgets/contract_builder.dart';

class ContractsTab extends StatefulWidget {
  final int? workspaceId;
  // Optional so this screen can be pumped in a widget test (e.g. embedded
  // inside am_workspace_page.dart's IndexedStack, which mounts every tab
  // eagerly) with a mocked ApiClient instead of hitting the network. Defaults
  // to the real singleton — zero behavior change for every existing call
  // site.
  final ApiClient? api;
  final ContractProvider? contractProvider;
  const ContractsTab({super.key, this.workspaceId, this.api, this.contractProvider});

  @override
  State<ContractsTab> createState() => _ContractsTabState();
}

class _ContractsTabState extends State<ContractsTab> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final ContractProvider _contractProvider = widget.contractProvider ?? ContractProvider(api: _api);
  List<dynamic> _contracts = [];
  bool _loading = true;
  String? _error;
  String? _clientType;
  String? _wsStatus;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final wsId = widget.workspaceId ?? _api.workspaceId;
    if (wsId == null) return;
    setState(() { if (_contracts.isEmpty) _loading = true; _error = null; });
    try {
      // Dispatched together, then awaited separately — see the matching
      // comment in contracts_page.dart's _load(), which hit the same
      // List-vs-Map typing constraint when moving off Future.wait.
      final contractsFuture = _contractProvider.fetchWorkspaceContractsRaw(wsId);
      final workspaceFuture = _contractProvider.fetchWorkspaceRaw(wsId);
      _contracts = await contractsFuture;
      final ws = (await workspaceFuture)['workspace'] as Map<String, dynamic>?;
      final client = ws?['client'] as Map<String, dynamic>?;
      _clientType = client?['client_type'] as String?;
      _wsStatus = ws?['status'] as String?;
    } on ServerException catch (e) {
      _error = e.message;
    } catch (_) {
      if (mounted) _error = AppLocalizations.of(context)!.contractsLoadFailed;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _action(int id, String action, {bool destructive = false}) async {
    if (destructive) {
      final l10n = AppLocalizations.of(context)!;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(action == 'archive' ? l10n.archive : l10n.completeComplete),
          content: Text(l10n.contractAreYouSure),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.confirm)),
          ],
        ),
      );
      if (confirm != true) return;
    }
    try {
      await _contractProvider.performAction(id, action);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.contractUpdated)));
        await _load();
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.errorOccurred)));
    }
  }

  Future<void> _editContract(Map<String, dynamic> c) async {
            await ContractBuilder.show(context, contractId: c['id'], contractData: c, isAdditional: c['contract_type'] == 'additional', onCreated: _load);
  }

  void _showContractDetail(Map<String, dynamic> c) {
    final l10n = AppLocalizations.of(context)!;
    final clauses = (c['clauses'] as List<dynamic>?) ?? [];
    final docs = (c['required_documents'] as List<dynamic>?) ?? [];
    final hasPdf = c['pdf_url'] != null && (c['pdf_url'] as String).isNotEmpty;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ShadColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollController) => Column(children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: ShadColors.textDisabled, borderRadius: BorderRadius.circular(2)),
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 30),
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Expanded(child: Text(c['title'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'PlayfairDisplay'))),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 20)),
                ]),
                const SizedBox(height: 4),
                Text('${c['value'] ?? 0} ${c['currency'] ?? 'SAR'}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ShadColors.gold, fontFamily: 'PlayfairDisplay')),
                if (_clientType == 'business')
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(l10n.contractValueExclVat, style: const TextStyle(fontSize: 11, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
                  ),
                const SizedBox(height: 6),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: ShadColors.crimson.withAlpha(25), borderRadius: BorderRadius.circular(6)),
                    child: Text(c['status'] ?? '', style: const TextStyle(fontSize: 11, color: ShadColors.crimson, fontWeight: FontWeight.w600)),
                  ),
                  if (c['contract_type'] == 'additional') ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: ShadColors.gold.withAlpha(25), borderRadius: BorderRadius.circular(6)),
                      child: Text(l10n.contractExtraService, style: const TextStyle(fontSize: 11, color: ShadColors.gold, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ]),
                const SizedBox(height: 6),
                if (c['start_date'] != null)
                  Text(c['end_date'] != null
                      ? l10n.contractDateRange(_formatDate(c['start_date']), _formatDate(c['end_date']))
                      : l10n.contractDateFrom(_formatDate(c['start_date'])),
                    style: const TextStyle(fontSize: 12, color: ShadColors.textSecondary)),
                const SizedBox(height: 16),
                if (clauses.isNotEmpty) ...[
                  Text(l10n.contractClausesLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, fontFamily: 'PlayfairDisplay')),
                  const SizedBox(height: 8),
                  ...clauses.map((cl) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white.withAlpha(8), borderRadius: BorderRadius.circular(8), border: Border.all(color: ShadColors.cardBorder)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(color: ShadColors.gold, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(cl['content'] ?? '', style: const TextStyle(fontSize: 13, height: 1.5))),
                    ]),
                  )),
                ],
                if (docs.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(l10n.contractRequiredDocsLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, fontFamily: 'PlayfairDisplay')),
                  const SizedBox(height: 8),
                  ...docs.map((d) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [
                      const Icon(Icons.description_outlined, size: 14, color: ShadColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(d['name'] ?? '', style: const TextStyle(fontSize: 12, color: ShadColors.textSecondary)),
                    ]),
                  )),
                ],
                if (hasPdf) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final url = _api.resolveFileUrl(c['pdf_url'] as String);
                        final uri = Uri.tryParse(url);
                        if (uri != null && await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                      label: Text(l10n.contractDownloadPdf),
                      style: ElevatedButton.styleFrom(backgroundColor: ShadColors.crimson, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _deleteContract(int id) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.contractDeleteTitle),
        content: Text(l10n.contractDeleteConfirmMsg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: ShadColors.error), child: Text(l10n.delete)),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _contractProvider.deleteContract(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.contractDeleted)));
        _load();
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.contractDeleteFailed)));
    }
  }

  Future<void> _companyApproveWithSignature(Map<String, dynamic> contract) async {
    final messenger = ScaffoldMessenger.of(context);
    String? savedSignature;

    try {
      final me = await _contractProvider.fetchCurrentUser();
      final user = me['user'] as Map<String, dynamic>?;
      if (user != null) {
        savedSignature = user['signature_data'] as String?;
      }
    } catch (e, s) {
      // Falls through to the manual signature pad, which is a safe default.
      AppLog.error('contracts_tab._loadSavedSignature', e, s);
    }

    if (!mounted) return;

    if (savedSignature != null && savedSignature.isNotEmpty) {
      final sig = savedSignature;
      final useSaved = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppLocalizations.of(ctx)!.companyApprove),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(AppLocalizations.of(ctx)!.companyApproveTitle(contract['title'] ?? ''), style: ShadTypography.cardBody),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(ctx)!.companyApproveUseSavedSignature, style: const TextStyle(color: ShadColors.textSecondary)),
            const SizedBox(height: 8),
            if (sig.startsWith('http') || sig.startsWith('/storage'))
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  sig.startsWith('http') ? sig : '${_api.baseUrl.replaceAll('/api', '')}$sig',
                  height: 50, fit: BoxFit.contain,
                ),
              )
            else
              Text(sig, style: const TextStyle(fontSize: 24, fontFamily: 'DancingScript')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(ctx)!.cancel)),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppLocalizations.of(ctx)!.confirm)),
          ],
        ),
      );
      if (useSaved != true) return;
      try {
        await _contractProvider.companyApprove(contract['id'] as int);
        if (mounted) {
          messenger.showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.contractUpdated)));
          _load();
        }
      } catch (_) {
        if (mounted) messenger.showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.errorOccurred)));
      }
      return;
    }

    if (!mounted) return;

    final signatureController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx)!.companyApprove),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppLocalizations.of(ctx)!.companyApproveTitle(contract['title'] ?? ''), style: ShadTypography.cardBody),
            const SizedBox(height: 16),
            TextField(
              controller: signatureController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(ctx)!.companySignature,
                hintText: AppLocalizations.of(ctx)!.signatureHint,
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(ctx)!.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final sig = signatureController.text.trim();
              if (sig.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(AppLocalizations.of(ctx)!.enterSignature)));
                return;
              }
              Navigator.pop(ctx, sig);
            },
            child: Text(AppLocalizations.of(ctx)!.confirm),
          ),
        ],
      ),
    );
    if (result == null) return;
    try {
      await _contractProvider.companyApprove(contract['id'] as int, signature: result);
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.contractUpdated)));
        _load();
      }
    } catch (_) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.errorOccurred)));
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return '—';
    final s = date.toString();
    if (s.isEmpty) return '—';
    try {
      final parsed = DateTime.parse(s);
      return '${parsed.year}/${parsed.month}/${parsed.day}';
    } catch (_) {
      return s.split('T')[0];
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isSA = _api.role == 'super_admin';
    final Map<String, List<String>> actionsForStatus = {
      'draft': ['send'],
      'edit_requested': ['send'],
      if (isSA) 'client_approved': ['company-approve'],
      if (isSA) 'company_approved': [],
      if (!isSA) 'company_approved': ['archive'],
    };

    if (_loading) return const LoadingState(itemCount: 3);
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    return Stack(children: [
      if (_contracts.isEmpty)
        Center(child: EmptyState(icon: Icons.description_outlined, title: l10n.noContracts, subtitle: l10n.noContractsSubtitle))
      else
        RefreshIndicator(
          onRefresh: _load,
          child: ListView.builder(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 80),
            itemCount: _contracts.length,
            itemBuilder: (_, i) {
              final c = _contracts[i];
              final rawActions = actionsForStatus[c['status']] ?? [];
              final actions = rawActions.where((a) {
                if (isSA) return a == 'company-approve' || a == 'complete';
                return a != 'company-approve';
              }).toList();
              final editable = c['status'] == 'draft' || c['status'] == 'edit_requested';
              return GestureDetector(
                onTap: () => editable ? _editContract(c) : _showContractDetail(c),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsetsDirectional.fromSTEB(13, 11, 13, 11),
                  decoration: BoxDecoration(
                    color: ShadColors.card,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: ShadColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(c['title'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, fontFamily: 'PlayfairDisplay')),
                          const SizedBox(height: 4),
                          Text(_formatDate(c['created_at'] ?? c['start_date']),
                            style: TextStyle(fontSize: 11, color: ShadColors.textSecondary)),
                        ])),
                        StatusBadge(status: c['status'] ?? ''),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 18),
                          onSelected: (action) {
                            if (action == 'edit') _editContract(c);
                            if (action == 'view') _showContractDetail(c);
                            if (action == 'delete') _deleteContract(c['id']);
                            if (action == 'archive') _action(c['id'], 'archive', destructive: true);
                          },
                          itemBuilder: (_) {
                            final l10n = AppLocalizations.of(context)!;
                            final items = <PopupMenuEntry<String>>[];
                            if (c['status'] == 'draft' || c['status'] == 'edit_requested') {
                              items.add(PopupMenuItem(value: 'edit', child: ListTile(leading: const Icon(Icons.edit, size: 18), title: Text(l10n.edit), dense: true)));
                              items.add(PopupMenuItem(value: 'delete', child: ListTile(leading: const Icon(Icons.delete, size: 18, color: ShadColors.error), title: Text(l10n.delete, style: const TextStyle(color: ShadColors.error)), dense: true)));
                            } else {
                              items.add(PopupMenuItem(value: 'view', child: ListTile(leading: const Icon(Icons.visibility, size: 18), title: Text(l10n.contractViewDetails), dense: true)));
                            }
                            if (c['status'] == 'company_approved') {
                              items.add(PopupMenuItem(value: 'archive', child: ListTile(leading: const Icon(Icons.archive, size: 18), title: Text(l10n.archive), dense: true)));
                            }
                            return items;
                          },
                        ),
                      ]),
                      const SizedBox(height: 6),
                      Text('${c['value'] ?? 0} ${c['currency'] as String? ?? 'SAR'}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'PlayfairDisplay', color: ShadColors.gold)),
                      if (_clientType == 'business')
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(l10n.contractValueExclVat, style: const TextStyle(fontSize: 10, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
                        ),
                      if (actions.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.only(top: 8),
                          decoration: const BoxDecoration(
                            border: Border(top: BorderSide(color: ShadColors.cardBorder)),
                          ),
                          child: Row(children: actions.map((a) {
                            final isDestructive = a == 'archive' || a == 'complete';
                            final isGold = a == 'company-approve';
                            final isCrimson = a == 'send';
                            String label;
                            Color bgColor;
                            Color textColor;
                            Color borderColor;
                            if (isGold) {
                              label = AppLocalizations.of(context)!.companyApprove;
                              bgColor = ShadColors.goldSoft;
                              textColor = ShadColors.gold;
                              borderColor = ShadColors.goldBorder;
                            } else if (isCrimson) {
                              label = AppLocalizations.of(context)!.send;
                              bgColor = ShadColors.crimson;
                              textColor = Colors.white;
                              borderColor = ShadColors.crimson;
                            } else {
                              label = isDestructive
                                ? (a == 'archive' ? AppLocalizations.of(context)!.archive : AppLocalizations.of(context)!.completeComplete)
                                : a;
                              bgColor = Colors.white.withAlpha(10);
                              textColor = ShadColors.textSecondary;
                              borderColor = ShadColors.inputBorder;
                            }
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2.5),
                                child: GestureDetector(
                                  onTap: isGold
                                    ? () => _companyApproveWithSignature(c)
                                    : () => _action(c['id'], a, destructive: isDestructive),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    decoration: BoxDecoration(
                                      color: bgColor,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: borderColor),
                                    ),
                                    child: Center(child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: textColor))),
                                  ),
                                ),
                              ),
                            );
                          }).toList()),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      if (_api.role != 'super_admin')
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: GestureDetector(
            onTap: () {
              final isActive = _wsStatus == 'active';
              ContractBuilder.show(context, isAdditional: isActive, onCreated: _load);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: ShadColors.crimson,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.add, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  _wsStatus == 'active' ? l10n.contractExtraService : l10n.contractCreateMain,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ]),
            ),
          ),
        ),
    ]);
  }
}
