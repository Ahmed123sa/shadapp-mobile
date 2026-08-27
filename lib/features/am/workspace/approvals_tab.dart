import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../models/approval.dart';
import '../../../providers/approval_provider.dart';

class ApprovalsTab extends StatefulWidget {
  final int? workspaceId;
  // Optional so this screen can be pumped in a widget test with a mocked
  // ApprovalProvider instead of hitting the network.
  final ApprovalProvider? approvalProvider;
  final ApiClient? api;
  const ApprovalsTab({super.key, this.workspaceId, this.approvalProvider, this.api});

  @override
  State<ApprovalsTab> createState() => _ApprovalsTabState();
}

class _ApprovalsTabState extends State<ApprovalsTab> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final ApprovalProvider _approvalProvider = widget.approvalProvider ?? ApprovalProvider();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  List<Approval> _approvals = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  List<File> _selectedFiles = [];
  List<String> _selectedFileNames = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final wsId = widget.workspaceId ?? _api.workspaceId;
    if (wsId == null) return;
    setState(() { _loading = true; _error = null; });
    await _approvalProvider.fetchApprovals(wsId);
    _approvals = _approvalProvider.approvals;
    if (_approvalProvider.error != null && mounted) {
      _error = AppLocalizations.of(context)?.approvalLoadFailed;
    }
    if (mounted) setState(() => _loading = false);
  }

  void _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any, allowMultiple: true);
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFiles = result.files.where((f) => f.path != null).map((f) => File(f.path!)).toList();
        _selectedFileNames = result.files.map((f) => f.name).toList();
      });
    }
  }

  Future<void> _create() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || widget.workspaceId == null) return;
    setState(() => _sending = true);
    try {
      final fields = <String, dynamic>{
        'title': title,
        'description': _descController.text.trim(),
      };
      await _approvalProvider.create(widget.workspaceId!, fields, files: _selectedFiles.isNotEmpty ? _selectedFiles : null);
      if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle, color: Colors.green, size: 18), const SizedBox(width: 8), Text(AppLocalizations.of(context)!.approvalRequestSent)])));
        _titleController.clear();
        _descController.clear();
        setState(() { _selectedFiles = []; _selectedFileNames = []; });
        _load();
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.approvalSendFailed)));
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _respond(int id, String action, String? reason) async {
    try {
      await _approvalProvider.respond(id, action: action, reason: reason);
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            Icon(action == 'approved' ? Icons.check_circle : Icons.edit, color: action == 'approved' ? Colors.green : Colors.orange, size: 18),
            const SizedBox(width: 8),
            Text(action == 'approved' ? l10n.approvalApproved : l10n.approvalEditRequested),
          ]),
        ));
        _load();
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.approvalActionFailed)));
    }
  }

  Future<void> _showEditRequestDialog(int id) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        final l10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(l10n.approvalEditTitle),
          content: TextField(controller: c, maxLines: 3, decoration: InputDecoration(hintText: l10n.approvalEditReasonHint)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, c.text), child: Text(l10n.approvalSendDialogButton)),
          ],
        );
      },
    );
    if (reason != null && mounted) _respond(id, 'edit_requested', reason.isEmpty ? null : reason);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final isSA = _api.role == 'super_admin';
    final l10n = AppLocalizations.of(context)!;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!isSA)
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l10n.approvalCreateTitle, style: ShadTypography.cardTitle),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(labelText: l10n.approvalTitleLabel, hintText: l10n.approvalTitleHint),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descController,
                    decoration: InputDecoration(labelText: l10n.approvalDescription, hintText: l10n.approvalDescriptionHint),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _pickFile,
                    icon: Icon(Icons.attach_file, size: 18),
                    label: Text(_selectedFileNames.isNotEmpty ? l10n.approvalFileCount(_selectedFileNames.length) : l10n.approvalAttachFiles),
                  ),
                  if (_selectedFileNames.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(spacing: 4, runSpacing: 2, children: _selectedFileNames.map((n) => Chip(
                        label: Text(n, style: const TextStyle(fontSize: 10)),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () {
                          final idx = _selectedFileNames.indexOf(n);
                          setState(() {
                            _selectedFiles.removeAt(idx);
                            _selectedFileNames.removeAt(idx);
                          });
                        },
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      )).toList()),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _sending ? null : _create,
                      child: _sending
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(l10n.approvalSendButton),
                    ),
                  ),
                ]),
              ),
            ),
          Text(l10n.approvalPreviousRequests, style: ShadTypography.sectionHeader),
          const SizedBox(height: 8),
          if (_approvals.isEmpty)
            EmptyState(icon: Icons.check_circle_outlined, title: l10n.approvalEmpty)
          else
            ..._approvals.map((a) {
              final hasCertificate = a.hasCertificate;
              final status = a.status;
              final accentColor = status == 'approved' ? ShadColors.success :
                  status == 'rejected' || status == 'edit_requested' ? ShadColors.error : ShadColors.gold;
              final createdAt = a.createdAt;
              final requestedByName = a.requestedByName ?? '';
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: ShadColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ShadColors.cardBorder),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 5,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                  ),
                  Expanded(child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                            a.title,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'PlayfairDisplay'),
                          ),
                          if (a.description != null && a.description!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(a.description!, style: const TextStyle(fontSize: 12, color: ShadColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                          const SizedBox(height: 8),
                          Row(children: [
                            if (requestedByName.isNotEmpty) ...[
                              Icon(Icons.person_outline, size: 13, color: ShadColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(requestedByName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: ShadColors.textSecondary)),
                              const SizedBox(width: 12),
                            ],
                            if (createdAt != null) ...[
                              Icon(Icons.access_time, size: 13, color: ShadColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(createdAt.split('T')[0], style: const TextStyle(fontSize: 12, color: ShadColors.textSecondary)),
                            ],
                          ]),
                          if (a.referenceNo != null) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: ShadColors.gold.withAlpha(20),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('${l10n.approvalReference}: ${a.referenceNo}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: ShadColors.gold)),
                            ),
                          ],
                        ])),
                        const SizedBox(width: 10),
                        StatusBadge(status: status),
                      ]),
                      if (hasCertificate)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: InkWell(
                            onTap: () async {
                              final url = _api.resolveFileUrl(a.certificatePdfUrl!);
                              final uri = Uri.tryParse(url);
                              if (uri != null && await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } else {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.approvalFileOpenFailed)));
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: ShadColors.gold.withAlpha(15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: ShadColors.gold.withAlpha(40)),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.picture_as_pdf, size: 18, color: ShadColors.gold),
                                const SizedBox(width: 8),
                                Text(l10n.approvalCertificate, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ShadColors.gold)),
                              ]),
                            ),
                          ),
                        ),
                      if (a.actionTaken) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: a.actionResult == 'approved' ? ShadColors.successLight : ShadColors.errorLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: a.actionResult == 'approved' ? ShadColors.success.withAlpha(40) : ShadColors.error.withAlpha(40),
                            ),
                          ),
                          child: Row(children: [
                            Icon(
                              a.actionResult == 'approved' ? Icons.check_circle : Icons.cancel,
                              size: 18, color: a.actionResult == 'approved' ? ShadColors.success : ShadColors.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(
                              a.actionResult == 'approved' ? l10n.approvalApproved : l10n.approvalEditRequested,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: a.actionResult == 'approved' ? ShadColors.success : ShadColors.error),
                            )),
                          ]),
                        ),
                      ],
                      if (status == 'edit_requested' && a.reason != null && a.reason!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: ShadColors.gold.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: ShadColors.gold.withAlpha(40)),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(l10n.approvalEditReasonLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ShadColors.gold)),
                            const SizedBox(height: 4),
                            Text(a.reason!, style: const TextStyle(fontSize: 12, color: ShadColors.textPrimary)),
                          ]),
                        ),
                      ],
                      if (status == 'pending' && !isSA && a.requestedBy != _api.userId)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _respond(a.id, 'approved', null),
                                icon: const Icon(Icons.check, size: 15),
                                label: Text(l10n.approve, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ShadColors.success,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _showEditRequestDialog(a.id),
                                icon: const Icon(Icons.edit, size: 15),
                                label: Text(l10n.approvalRequestEdit, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ]),
                        ),
                    ]),
                  )),
                ]),
              );
            }),
        ],
      ),
    );
  }
}
