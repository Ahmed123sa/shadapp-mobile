import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/api_client.dart';
import '../../core/luxe/lx_icons.dart';
import '../../core/luxe/tokens.dart';
import '../../core/theme.dart';
import '../../core/widgets/luxe/luxe_widgets.dart';
import '../../core/widgets/loading_state.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';
import '../../models/approval.dart';
import '../../providers/approval_provider.dart';

class ApprovalsPage extends StatefulWidget {
  final int? workspaceId;
  // Optional so this screen can be pumped in a widget test with a mocked
  // ApprovalProvider instead of hitting the network.
  final ApprovalProvider? approvalProvider;
  final ApiClient? api;
  const ApprovalsPage({super.key, this.workspaceId, this.approvalProvider, this.api});

  @override
  State<ApprovalsPage> createState() => _ApprovalsPageState();
}

class _ApprovalsPageState extends State<ApprovalsPage> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final ApprovalProvider _approvalProvider = widget.approvalProvider ?? ApprovalProvider();
  List<Approval> _approvals = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final wsId = widget.workspaceId ?? _api.workspaceId;
    if (wsId == null) {
      _error = AppLocalizations.of(context)!.approvals_noWorkspace;
      if (mounted) setState(() => _loading = false);
      return;
    }
    await _approvalProvider.fetchApprovals(wsId);
    if (!mounted) return;
    if (_approvalProvider.error != null) {
      _error = AppLocalizations.of(context)!.approvals_failedToLoad;
    } else {
      _approvals = _approvalProvider.approvals;
    }
    setState(() => _loading = false);
  }

  Future<void> _respond(int id, String action) async {
    final l10n = AppLocalizations.of(context)!;
    if (action == 'edit_requested') {
      final reason = await _showEditRequestDialog();
      if (reason == null) return;
      try {
        await _approvalProvider.respond(id, action: action, reason: reason);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.edit, color: Colors.orange, size: 18), const SizedBox(width: 8), Text(l10n.approvals_editRequested)])));
          _load();
        }
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.approvals_actionFailed)));
      }
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.approvals_confirmApproval),
          content: Text(l10n.approvals_confirmApprovalMsg),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Lx.crimson, foregroundColor: Colors.white),
              child: Text(l10n.approve),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      try {
        await _approvalProvider.respond(id, action: action);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle, color: Colors.green, size: 18), const SizedBox(width: 8), Text(l10n.approvals_approved)])));
          _load();
        }
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.approvals_actionFailed)));
      }
    }
  }

  Future<String?> _showEditRequestDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.approvals_requestEdit),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l10n.approvals_mentionChanges, style: const TextStyle(fontSize: 12, color: ShadColors.textSecondary)),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(hintText: l10n.approvals_exampleChanges),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: ShadColors.gold),
            child: Text(l10n.send),
          ),
        ],
      ),
    );
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    final l10n = AppLocalizations.of(context)!;

    final sorted = List<Approval>.from(_approvals);
    sorted.sort((a, b) {
      final aCompleted = a.status == 'completed' || a.status == 'approved';
      final bCompleted = b.status == 'completed' || b.status == 'approved';
      if (aCompleted && !bCompleted) return 1;
      if (!aCompleted && bCompleted) return -1;
      return 0;
    });

    if (sorted.isEmpty) {
      return EmptyState(icon: Icons.check_circle_outlined, title: l10n.approvals_empty);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
        children: [
          LuxePageTitle(l10n.dashboard_tab_approvals),
          ...sorted.map((a) {
            final status = a.status;
            final isPending = status == 'pending';
            final dot = status == 'approved' || status == 'completed'
                ? LxStatus.ok
                : isPending
                    ? LxStatus.wait
                    : (status == 'rejected' || status == 'edit_requested')
                        ? LxStatus.bad
                        : LxStatus.off;
            final statusText = statusLabels(l10n)[status] ?? status;
            final sub = [
              if ((a.requestedByName ?? '').isNotEmpty) a.requestedByName!,
              if (a.createdAt != null) a.createdAt!.split('T')[0],
            ].join(' · ');
            final canRespond = _api.canDo('can_respond_approvals');
            final reason = a.reason;

            return LuxeCard(
              key: ValueKey('approval-card-${a.id}'),
              attention: isPending && !a.isCompleted,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.title, style: Lx.text(context, size: 15, weight: FontWeight.w500)),
                if (a.description != null && a.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(a.description!, style: Lx.text(context, size: 12.5, color: Lx.muted), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                if (sub.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(sub, style: Lx.text(context, size: 12.5, color: Lx.muted)),
                ],
                if (a.referenceNo != null) ...[
                  const SizedBox(height: 2),
                  Text('${l10n.approvals_referenceNo}: ${a.referenceNo}', style: Lx.text(context, size: 11.5, color: Lx.faint)),
                ],
                const SizedBox(height: 8),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  LuxeStatusDot(status: dot),
                  const SizedBox(width: 7),
                  Text(statusText, style: Lx.text(context, size: 12, color: Lx.ink2)),
                ]),
                if (a.hasCertificate)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: InkWell(
                      key: ValueKey('approval-certificate-${a.id}'),
                      onTap: () async {
                        final uri = Uri.tryParse(_api.resolveFileUrl(a.certificatePdfUrl!));
                        if (uri != null && await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } else {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.approvals_fileOpenFailed)));
                        }
                      },
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const LxIcon('doc', size: 16, color: Lx.ink2),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.only(bottom: 1),
                          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Lx.line2))),
                          child: Text(l10n.approvals_certificate, style: Lx.text(context, size: 12.5, color: Lx.ink2)),
                        ),
                      ]),
                    ),
                  ),
                if (a.actionTaken) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    LuxeStatusDot(status: a.actionResult == 'approved' ? LxStatus.ok : LxStatus.bad),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        a.actionResult == 'approved' ? l10n.approvals_approvedLabel : l10n.approvals_requestedEditLabel,
                        style: Lx.text(context, size: 12.5, color: a.actionResult == 'approved' ? Lx.ok : Lx.danger),
                      ),
                    ),
                  ]),
                ],
                if (reason != null && reason.isNotEmpty && status == 'edit_requested') ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: Lx.line2)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l10n.approvals_editReasonLabel, style: Lx.text(context, size: 11, color: Lx.crimsonInk)),
                      const SizedBox(height: 4),
                      Text(reason, style: Lx.text(context, size: 12.5, color: Lx.ink2)),
                    ]),
                  ),
                ],
                // subuser-review-plan.md م٦ — responding to an approval
                // request maps to can_respond_approvals, per the plan's
                // action table.
                if (!a.isCompleted && isPending && canRespond)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Row(children: [
                      Expanded(
                        child: LuxeButton(
                          key: ValueKey('approval-edit-${a.id}'),
                          label: l10n.approvals_requestEditButton,
                          size: LuxeButtonSize.sm,
                          onPressed: () => _respond(a.id, 'edit_requested'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: LuxeButton(
                          key: ValueKey('approval-approve-${a.id}'),
                          label: l10n.approvals_approveButton,
                          kind: LuxeButtonKind.primary,
                          size: LuxeButtonSize.sm,
                          onPressed: () => _respond(a.id, 'approved'),
                        ),
                      ),
                    ]),
                  )
                else if (!a.isCompleted && isPending)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: LuxeHint(l10n.subuserActionNeedsOwner),
                  ),
              ]),
            );
          }),
        ],
      ),
    );
  }
}
