import 'package:flutter/material.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/api_client.dart';
import '../../core/luxe/lx_icons.dart';
import '../../core/luxe/tokens.dart';
import '../../core/widgets/luxe/luxe_widgets.dart';
import '../../providers/client_provider.dart';
import '../../providers/signature_provider.dart';
import 'signature_editor.dart';

/// Standalone `/signature` route, opened from the "signature required"
/// dialog. Same page as the dashboard's signature tab ([SignatureEditor]),
/// plus a back row; after a successful save it confirms and returns
/// `true` to whoever pushed it, so they can retry the approval.
class SignaturePage extends StatefulWidget {
  // Optional so this screen can be pumped in a widget test with mocked
  // providers instead of hitting the network.
  final ClientProvider? clientProvider;
  final SignatureProvider? signatureProvider;
  final ApiClient? api;
  const SignaturePage({super.key, this.clientProvider, this.signatureProvider, this.api});

  @override
  State<SignaturePage> createState() => _SignaturePageState();
}

class _SignaturePageState extends State<SignaturePage> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final ClientProvider _clientProvider = widget.clientProvider ?? ClientProvider();
  late final SignatureProvider _signatureProvider = widget.signatureProvider ?? SignatureProvider();
  bool _signed = false;

  void _onSaved() {
    setState(() => _signed = true);
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) Navigator.pop(context, true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Lx.page,
      body: SafeArea(
        child: Stack(children: [
          Column(children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: InkWell(
                key: const ValueKey('signature-back'),
                onTap: () => Navigator.maybePop(context),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 4),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const LxIcon('back', size: 16, color: Lx.muted),
                    const SizedBox(width: 6),
                    Text(l10n.onboarding_back, style: Lx.text(context, size: 13, color: Lx.muted)),
                  ]),
                ),
              ),
            ),
            Expanded(
              child: SignatureEditor(
                clientProvider: _clientProvider,
                signatureProvider: _signatureProvider,
                api: _api,
                onSaved: _onSaved,
              ),
            ),
          ]),
          if (_signed) _buildSuccessOverlay(l10n),
        ]),
      ),
    );
  }

  Widget _buildSuccessOverlay(AppLocalizations l10n) {
    return Container(
      color: const Color(0x8C000000),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutBack,
          builder: (_, v, __) => Transform.scale(
            scale: v,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: LuxeCard(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Lx.ok)),
                    child: const LxIcon('check', size: 26, color: Lx.ok),
                  ),
                  const SizedBox(height: 14),
                  Text(l10n.signature_saved, style: Lx.display(context, size: 20)),
                  const SizedBox(height: 4),
                  Text(l10n.signature_saved_willReturn, textAlign: TextAlign.center, style: Lx.text(context, size: 12.5, color: Lx.muted)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
