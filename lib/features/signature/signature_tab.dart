import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../providers/client_provider.dart';
import '../../providers/signature_provider.dart';
import 'signature_editor.dart';

/// "More → Signature" inside the client dashboard (the dashboard draws the
/// back row above it). All of the page lives in [SignatureEditor].
class SignatureTab extends StatefulWidget {
  // Optional so this screen can be pumped in a widget test with mocked
  // providers instead of hitting the network.
  final ClientProvider? clientProvider;
  final SignatureProvider? signatureProvider;
  final ApiClient? api;
  const SignatureTab({super.key, this.clientProvider, this.signatureProvider, this.api});

  @override
  State<SignatureTab> createState() => _SignatureTabState();
}

class _SignatureTabState extends State<SignatureTab> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final ClientProvider _clientProvider = widget.clientProvider ?? ClientProvider();
  late final SignatureProvider _signatureProvider = widget.signatureProvider ?? SignatureProvider();

  @override
  Widget build(BuildContext context) =>
      SignatureEditor(clientProvider: _clientProvider, signatureProvider: _signatureProvider, api: _api);
}
