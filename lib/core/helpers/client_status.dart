/// Whether a client (a raw `/clients` list item) has approved a contract.
///
/// 23 Sept 2026 — the client cards used `signed_at` for this, but that only
/// records the client saving a profile signature, so a paid, active client
/// could show as "Not contracted". The backend now sends
/// `has_signed_contract`; `signed_at` is only a fallback for an older
/// server that doesn't send it yet. An active workspace always means a
/// contract was approved (the workspace can't activate without one).
bool clientHasSignedContract(Map<String, dynamic> client) {
  final ws = client['workspace'] as Map<String, dynamic>?;
  if (ws?['status'] == 'active') return true;
  final flag = client['has_signed_contract'];
  if (flag is bool) return flag;
  if (flag is num) return flag != 0;
  return client['signed_at'] != null;
}
