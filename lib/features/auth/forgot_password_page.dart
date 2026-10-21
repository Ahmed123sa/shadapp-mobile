import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/api_client.dart';
import 'package:provider/provider.dart';
import '../../core/locale_provider.dart';
import '../../core/luxe/lx_icons.dart';
import '../../core/luxe/tokens.dart';
import '../../providers/auth_provider.dart';
import 'auth_chrome.dart';

/// Request a password reset link.
///
/// The link in the email opens the dashboard in a browser rather than deep
/// linking back into the app — see ResetPasswordNotification on the backend
/// for why. So this screen's whole job is to trigger the email; the actual
/// password change happens on the web, and the user then signs in here with
/// the new password.
class ForgotPasswordPage extends StatefulWidget {
  final ApiClient? api;
  // Optional so this screen can be pumped in a widget test with a mocked
  // AuthProvider; defaults to wrapping whatever ApiClient (real or test
  // double) is passed via [api], so existing tests that only supply [api]
  // keep working unchanged.
  final AuthProvider? authProvider;
  /// The login mockup's moving background; tests turn it off so
  /// `pumpAndSettle` can settle.
  final bool animateBackground;
  const ForgotPasswordPage({super.key, this.api, this.authProvider, this.animateBackground = true});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  late final ApiClient _api = widget.api ?? ApiClient();
  late final AuthProvider _authProvider = widget.authProvider ?? AuthProvider(api: _api);

  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() => _error = l10n.forgotPasswordEnterEmail);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    // Both endpoints get called, deliberately.
    //
    // Staff and clients live in separate tables behind separate reset
    // brokers, and this screen has no way to know which kind of account the
    // address belongs to — the login screen has the same problem. Rather than
    // ask the user to classify themselves, try both: exactly one can match,
    // the other answers "not registered" and does nothing.
    //
    // Hence `anySucceeded` rather than a plain try/catch. One endpoint
    // failing is the normal, expected case for every successful reset; only
    // *both* failing means the address really has no account anywhere.
    var anySucceeded = false;
    Object? lastError;

    for (final action in [_authProvider.requestPasswordReset, _authProvider.requestClientPasswordReset]) {
      try {
        await action(email);
        anySucceeded = true;
      } catch (e) {
        lastError = e;
      }
    }

    if (!mounted) return;

    if (anySucceeded) {
      setState(() {
        _sent = true;
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = false;
      _error = switch (lastError) {
        RateLimitException() => l10n.tooManyAttemptsMessage,
        ConnectionException() => l10n.connectionFailedMessage,
        ValidationException(message: final m) => m,
        _ => l10n.serverErrorMessage,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Mockup "Forgot password" / "Forgot · sent" screens: the login card on
    // the same background — logo + "Shad.", the lead line, (sent notice),
    // email field, "Send reset link", "Back to sign in".
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: AuthBackdrop(
        animate: widget.animateBackground,
        child: SafeArea(
          child: Stack(children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: AuthCard(
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const AuthLogo(key: ValueKey('forgot-logo')),
                    const SizedBox(height: 14),
                    Text(
                      l10n.forgotPasswordSubtitle,
                      textAlign: TextAlign.center,
                      style: Lx.text(context, size: 13, color: Lx.muted, height: 1.6),
                    ),
                    const SizedBox(height: 22),
                    if (_sent) authNotice(context, l10n.forgotPasswordSent, ok: true, key: const ValueKey('forgot-sent')),
                    if (_error != null) authNotice(context, _error!, ok: false, key: const ValueKey('forgot-error')),
                    authField(
                      context,
                      label: l10n.emailLabel,
                      controller: _emailController,
                      hint: 'example@domain.com',
                      keyboardType: TextInputType.emailAddress,
                      enabled: !_loading,
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 22),
                    AuthButton(label: l10n.forgotPasswordSubmit, loading: _loading, onPressed: _submit),
                    const SizedBox(height: 10),
                    AuthLink(label: l10n.forgotPasswordBackToLogin, onTap: _loading ? null : () => context.go('/login')),
                  ]),
                ),
              ),
            ),
            // Mockup `.lang`: top-start, 38px, globe icon at white .5.
            PositionedDirectional(
              top: 10,
              start: 14,
              child: GestureDetector(
                key: const ValueKey('forgot-lang'),
                onTap: () => context.read<LocaleProvider>().toggle(),
                child: SizedBox(width: 38, height: 38, child: Center(child: LxIcon('lang', size: 18, color: Colors.white.withAlpha(128)))),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
