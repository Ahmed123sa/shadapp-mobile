import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api_client.dart';
import '../../../core/app_log.dart';
import '../../../core/luxe/lx_icons.dart';
import '../../../core/luxe/tokens.dart';
import '../../../core/theme.dart' show statusLabels;
import '../../../core/widgets/luxe/luxe_widgets.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/error_state.dart';
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
            await ContractBuilder.show(context, contractId: c['id'], contractData: c, isAdditional: c['contract_type'] == 'additional', onCreated: _load, api: _api, contractProvider: _contractProvider, workspaceId: widget.workspaceId ?? _api.workspaceId);
  }

  /// Mockup step index for a status: steps before it are done, it is "now".
  int _stepFor(String status) {
    switch (status) {
      case 'sent':
        return 1;
      case 'client_approved':
        return 2;
      case 'company_approved':
        return 3;
      case 'completed':
      case 'active':
        return 4;
      default:
        return 0;
    }
  }

  String _shortDate(dynamic date) {
    final t = DateTime.tryParse(date?.toString() ?? '')?.toLocal();
    if (t == null) return '';
    return DateFormat('d MMM', Localizations.localeOf(context).toString()).format(t);
  }

  Future<void> _openPdf(Map<String, dynamic> c) async {
    final url = _api.resolveFileUrl(c['pdf_url'] as String);
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Contract details in the mockup's sheet language: `.sheet` + `.grab`,
  /// h3 serif 22, `.kind`, `.amt`, the step bar, numbered clause rows
  /// (`.clr`) and `.doc` rows for required documents.
  void _showContractDetail(Map<String, dynamic> c) {
    final l10n = AppLocalizations.of(context)!;
    final clauses = (c['clauses'] as List<dynamic>?) ?? [];
    final docs = (c['required_documents'] as List<dynamic>?) ?? [];
    final hasPdf = c['pdf_url'] != null && (c['pdf_url'] as String).isNotEmpty;
    final status = c['status'] as String? ?? '';
    final amt = num.tryParse('${c['value'] ?? 0}');
    final steps = [l10n.contractStepSent, l10n.contractStepClientApproved, l10n.contractStepCompanyApproved, l10n.contractStepActive];

    showLuxeSheet<void>(context, builder: (ctx) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LuxeKind(c['contract_type'] == 'additional' ? l10n.contractKindAdditional : l10n.contractKindMain),
        const SizedBox(height: 4),
        Text(c['title'] ?? '', key: const ValueKey('contract-sheet-title'), style: Lx.display(ctx, size: 22)),
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Text.rich(TextSpan(children: [
              TextSpan(text: amt != null ? lxFormatMoney(amt) : '${c['value'] ?? 0}', style: Lx.display(ctx, size: 20)),
              TextSpan(text: ' ${c['currency'] ?? 'SAR'}', style: Lx.text(ctx, size: 11, color: Lx.muted)),
            ])),
          ),
        ),
        if (_clientType == 'business')
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(l10n.contractValueExclVat, style: Lx.text(ctx, size: 11, color: Lx.faint)),
          ),
        if (c['start_date'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              c['end_date'] != null
                  ? l10n.contractDateRange(_formatDate(c['start_date']), _formatDate(c['end_date']))
                  : l10n.contractDateFrom(_formatDate(c['start_date'])),
              style: Lx.text(ctx, size: 12.5, color: Lx.muted),
            ),
          ),
        LuxeLabeledSteps(labels: steps, current: _stepFor(status)),
        if (clauses.isNotEmpty) ...[
          const SizedBox(height: 22),
          LuxeKind(l10n.contractClausesLabel),
          const SizedBox(height: 4),
          for (var i = 0; i < clauses.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(border: i == clauses.length - 1 ? null : const Border(bottom: BorderSide(color: Lx.line))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 20, child: Text('${i + 1}', style: Lx.text(ctx, size: 11, color: Lx.faint, height: 1.8))),
                const SizedBox(width: 10),
                Expanded(child: Text('${clauses[i]['content'] ?? ''}', style: Lx.text(ctx, size: 13, height: 1.6))),
              ]),
            ),
        ],
        if (docs.isNotEmpty) ...[
          const SizedBox(height: 18),
          LuxeKind(l10n.contractRequiredDocsLabel),
          const SizedBox(height: 4),
          for (var i = 0; i < docs.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(border: i == docs.length - 1 ? null : const Border(bottom: BorderSide(color: Lx.line))),
              child: Row(children: [
                const LxIcon('doc', size: 18, color: Lx.muted),
                const SizedBox(width: 10),
                Expanded(child: Text('${docs[i]['name'] ?? ''}', style: Lx.text(ctx, size: 13.5))),
              ]),
            ),
        ],
        if (hasPdf) ...[
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: LuxeButton(
              key: const ValueKey('contract-sheet-pdf'),
              label: l10n.contractDownloadPdf,
              lxIcon: 'down',
              kind: LuxeButtonKind.primary,
              size: LuxeButtonSize.lg,
              onPressed: () => _openPdf(c),
            ),
          ),
        ],
      ]);
    });
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
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Lx.crimson, foregroundColor: Colors.white), child: Text(l10n.delete)),
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
    // signature_url: the backend's signed link for showing an uploaded
    // image. /storage/... doesn't exist in production (23 Sept 2026).
    String? savedSignatureUrl;

    try {
      final me = await _contractProvider.fetchCurrentUser();
      final user = me['user'] as Map<String, dynamic>?;
      if (user != null) {
        savedSignature = user['signature_data'] as String?;
        savedSignatureUrl = user['signature_url'] as String?;
      }
    } catch (e, s) {
      // Falls through to the manual signature pad, which is a safe default.
      AppLog.error('contracts_tab._loadSavedSignature', e, s);
    }

    if (!mounted) return;

    if (savedSignature != null && savedSignature.isNotEmpty) {
      final sig = savedSignature;
      final sigUrl = savedSignatureUrl;
      final useSaved = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppLocalizations.of(ctx)!.companyApprove),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(AppLocalizations.of(ctx)!.companyApproveTitle(contract['title'] ?? ''), style: Lx.text(ctx, size: 14)),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(ctx)!.companyApproveUseSavedSignature, style: Lx.text(ctx, size: 13.5, color: Lx.muted)),
            const SizedBox(height: 8),
            if (sig.startsWith('http') || sig.startsWith('/storage'))
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LuxeSignatureInk(
                  child: Image.network(
                    sigUrl ?? (sig.startsWith('http') ? sig : '${_api.baseUrl.replaceAll('/api', '')}$sig'),
                    height: 50, fit: BoxFit.contain,
                  ),
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
            Text(AppLocalizations.of(ctx)!.companyApproveTitle(contract['title'] ?? ''), style: Lx.text(ctx, size: 14)),
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
    final canManage = _api.canDo('can_manage_contracts');
    final Map<String, List<String>> actionsForStatus = {
      'draft': ['send'],
      'edit_requested': ['send'],
      // The super admin always can; an account manager only when the super
      // admin granted can_approve_contracts (STAFF_TEAMS_PLAN.md ف١).
      if (_api.canCompanyApprove) 'client_approved': ['company-approve'],
      if (isSA) 'company_approved': [],
      if (!isSA) 'company_approved': ['archive'],
    };

    if (_loading) return const LoadingState(itemCount: 3);
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final newBtn = (_api.role != 'super_admin' && canManage)
        ? Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              width: double.infinity,
              child: LuxeButton(
                key: const ValueKey('contracts-new'),
                label: _wsStatus == 'active' ? l10n.contractExtraService : l10n.contractCreateMain,
                lxIcon: 'plus',
                kind: LuxeButtonKind.primary,
                size: LuxeButtonSize.lg,
                onPressed: () {
                  final isActive = _wsStatus == 'active';
                  ContractBuilder.show(context, isAdditional: isActive, onCreated: _load, api: _api, contractProvider: _contractProvider, workspaceId: widget.workspaceId ?? _api.workspaceId);
                },
              ),
            ),
          )
        : const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: _load,
      color: Lx.crimsonInk,
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 24),
        children: [
          newBtn,
          if (_contracts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(children: [
                Text(l10n.noContracts, style: Lx.display(context, size: 20)),
                const SizedBox(height: 8),
                Text(l10n.noContractsSubtitle, textAlign: TextAlign.center, style: Lx.text(context, size: 13.5, color: Lx.muted)),
              ]),
            )
          else
            ..._contracts.map((c) {
              final rawActions = actionsForStatus[c['status']] ?? [];
              final actions = rawActions.where((a) {
                if (isSA) return a == 'company-approve' || a == 'complete';
                if (a == 'company-approve') return _api.canCompanyApprove;
                return canManage;
              }).toList();
              final editable = c['status'] == 'draft' || c['status'] == 'edit_requested';
              final status = c['status'] as String? ?? '';
              final dot = (status == 'company_approved' || status == 'completed')
                  ? LxStatus.ok
                  : (status == 'rejected' || status == 'cancelled')
                      ? LxStatus.bad
                      : (status == 'sent' || status == 'client_approved')
                          ? LxStatus.wait
                          : LxStatus.off;
              final amt = num.tryParse('${c['value'] ?? 0}');
              final hasPdf = c['pdf_url'] != null && (c['pdf_url'] as String).isNotEmpty;
              final inFlow = const {'sent', 'client_approved', 'company_approved', 'completed', 'active'}.contains(status);
              final when = _shortDate(c['company_signed_at'] ?? c['updated_at'] ?? c['created_at']);
              final sub = [statusLabels(l10n)[status] ?? status, when].where((e) => e.isNotEmpty).join(' · ');
              final steps = [l10n.contractStepSent, l10n.contractStepClientApproved, l10n.contractStepCompanyApproved, l10n.contractStepActive];
              final buttons = <Widget>[
                for (final a in actions)
                  LuxeButton(
                    label: a == 'company-approve'
                        ? l10n.companyApprove
                        : a == 'send'
                            ? l10n.send
                            : a == 'archive'
                                ? l10n.archive
                                : a == 'complete'
                                    ? l10n.completeComplete
                                    : a,
                    size: LuxeButtonSize.sm,
                    kind: (a == 'company-approve' || a == 'send') ? LuxeButtonKind.primary : LuxeButtonKind.outline,
                    onPressed: a == 'company-approve'
                        ? () => _companyApproveWithSignature(c)
                        : () => _action(c['id'], a, destructive: a == 'archive' || a == 'complete'),
                  ),
                if (editable && canManage && !isSA)
                  LuxeButton(
                    key: ValueKey('contract-delete-${c['id']}'),
                    label: l10n.delete,
                    size: LuxeButtonSize.sm,
                    kind: LuxeButtonKind.danger,
                    onPressed: () => _deleteContract(c['id']),
                  ),
                if (hasPdf)
                  LuxeButton(
                    key: ValueKey('contract-pdf-${c['id']}'),
                    label: l10n.contractDownloadPdfShort,
                    lxIcon: 'eye',
                    size: LuxeButtonSize.sm,
                    onPressed: () => _openPdf(c),
                  ),
              ];
              // Mockup case 2: `.card` (`.ap` when it waits on the company),
              // kind Main/Additional, title, "status · date", `.amt`, the
              // four-step bar, then `.acts` (flex 1 each, gap 8).
              return LuxeCard(
                key: ValueKey('contract-card-${c['id']}'),
                attention: status == 'client_approved',
                onTap: () => editable ? _editContract(c) : _showContractDetail(c),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  LuxeKind(c['contract_type'] == 'additional' ? l10n.contractKindAdditional : l10n.contractKindMain),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 2),
                    child: Text(c['title'] ?? '', style: Lx.text(context, size: 16)),
                  ),
                  if (sub.isNotEmpty) Text(sub, style: Lx.text(context, size: 12.5, color: Lx.muted)),
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text.rich(TextSpan(children: [
                        TextSpan(text: amt != null ? lxFormatMoney(amt) : '${c['value'] ?? 0}', style: Lx.display(context, size: 20)),
                        TextSpan(text: ' ${c['currency'] as String? ?? 'SAR'}', style: Lx.text(context, size: 11, color: Lx.muted)),
                      ])),
                    ),
                  ),
                  if (_clientType == 'business')
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(l10n.contractValueExclVat, style: Lx.text(context, size: 10.5, color: Lx.faint)),
                    ),
                  if (inFlow)
                    LuxeLabeledSteps(labels: steps, current: _stepFor(status))
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        LuxeStatusDot(status: dot),
                        const SizedBox(width: 7),
                        Text(statusLabels(l10n)[status] ?? status, style: Lx.text(context, size: 12, color: Lx.ink2)),
                      ]),
                    ),
                  if (buttons.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Row(children: [
                        for (var i = 0; i < buttons.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(child: buttons[i]),
                        ],
                      ]),
                    ),
                ]),
              );
            }),
        ],
      ),
    );
  }
}
