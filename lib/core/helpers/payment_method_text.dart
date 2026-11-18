// What staff read about where a payment was sent: the company account the
// client picked (when he picked one) and the fee he paid on top of the amount.

/// The picked company account's name, else [legacy] (the generic method label).
String paymentMethodName(Map<dynamic, dynamic> p, String legacy) {
  final pm = p['payment_method'];
  final label = pm is Map ? '${pm['label'] ?? ''}'.trim() : '';
  return label.isNotEmpty ? label : legacy;
}

/// The fee the client paid on top of `amount`, or null when there was none.
double? paymentFee(Map<dynamic, dynamic> p) {
  final fee = double.tryParse('${p['fee_amount'] ?? ''}');
  return fee != null && fee > 0 ? fee : null;
}
