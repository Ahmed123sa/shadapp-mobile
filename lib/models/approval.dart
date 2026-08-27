/// Data shape for an approval request, as returned by
/// `/workspaces/:id/approvals`. Covers the client-facing read/respond flow
/// (approvals_page.dart) — the AM-side creation flow (approvals_tab.dart,
/// multipart file upload) is a separate concern left for its own migration.
class Approval {
  final int id;
  final String status;
  final String title;
  final String? description;
  final String? createdAt;
  final String? requestedByName;
  final String? referenceNo;
  final bool actionTaken;
  final String? actionResult;
  final String? reason;
  final String? certificatePdfUrl;
  /// Raw requester user id (distinct from [requestedByName]) — used by
  /// am/workspace/approvals_tab.dart to hide the approve/reject buttons on a
  /// request the current user made themselves.
  final int? requestedBy;

  const Approval({
    required this.id,
    this.status = 'pending',
    this.title = '',
    this.description,
    this.createdAt,
    this.requestedByName,
    this.referenceNo,
    this.actionTaken = false,
    this.actionResult,
    this.reason,
    this.certificatePdfUrl,
    this.requestedBy,
  });

  bool get isCompleted => status == 'approved' || status == 'completed' || status == 'edit_requested';
  bool get hasCertificate => certificatePdfUrl != null && certificatePdfUrl!.isNotEmpty;

  factory Approval.fromJson(Map<String, dynamic> json) {
    // A plain `as Map<String, dynamic>?` cast throws if the runtime map isn't
    // exactly that generic instantiation — real jsonDecode output always is,
    // but this guards against any other caller (or a hand-built test map)
    // passing a Map<dynamic, dynamic> instead, same defensive spirit as the
    // _str/_int helpers below.
    final certificateRaw = json['certificate'];
    final certificate = certificateRaw is Map ? Map<String, dynamic>.from(certificateRaw) : null;
    return Approval(
      id: _int(json['id']) ?? 0,
      status: _str(json['status']) ?? 'pending',
      title: _str(json['title']) ?? '',
      description: _str(json['description']),
      createdAt: _str(json['created_at']),
      requestedByName: _str(json['requested_by_name']),
      referenceNo: _idStr(json['reference_no']),
      actionTaken: json['action_taken'] == true,
      actionResult: _str(json['action_result']),
      reason: _str(json['reason']),
      certificatePdfUrl: certificate != null ? _str(certificate['pdf_url']) : null,
      requestedBy: _int(json['requested_by']),
    );
  }
}

String? _str(dynamic value) => value is String ? value : null;

String? _idStr(dynamic value) => value?.toString();

int? _int(dynamic value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}
