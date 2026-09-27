// Reverb and FCM both deliver the same notification to the onboarding screen,
// but with different shapes: the broadcast carries the notification's
// toDatabase() fields (contract_id / payment_id), FCM carries data.type
// ("contract.received", "payment.approved"...) plus data.id. Toasts are keyed
// by the entity they're about, not by the source, so the second copy of the
// same event maps to the same key and is dropped.
//
// 'any' means "no usable id" — e.g. the workspace-activation broadcast
// (PaymentReviewedNotification with workspaceActivated) carries only
// workspace_id, while its FCM copy carries the payment id.

String toastKeyFromBroadcast(Map<String, dynamic> payload) {
  if (payload['contract_id'] != null) return 'contract:${payload['contract_id']}';
  if (payload['payment_id'] != null) return 'payment:${payload['payment_id']}';
  return 'any';
}

String toastKeyFromFcm(Map<String, dynamic> data) {
  final type = data['type'] as String? ?? '';
  final id = data['contract_id'] ?? data['payment_id'] ?? data['id'];
  if (id == null || '$id'.isEmpty) return 'any';
  if (type.startsWith('contract.')) return 'contract:$id';
  if (type.startsWith('payment.')) return 'payment:$id';
  return 'any';
}

/// Decides whether a toast with [key] should show, given the toasts already
/// shown within [window]. Mutates [recent]. Pure, so it's unit-testable.
bool shouldShowToast(
  Map<String, DateTime> recent,
  String key, [
  DateTime? now,
  Duration window = const Duration(seconds: 5),
]) {
  final current = now ?? DateTime.now();
  recent.removeWhere((_, t) => current.difference(t) >= window);
  if (recent.containsKey(key)) return false;
  if (key == 'any' && recent.isNotEmpty) return false;
  if (recent.containsKey('any')) return false;
  recent[key] = current;
  return true;
}