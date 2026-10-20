import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/luxe/tokens.dart';
import '../../providers/auth_provider.dart';

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
  const ForgotPasswordPage({super.key, this.api, this.authProvider});

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

    return Scaffold(
      backgroundColor: ShadColors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: ShadColors.card.withAlpha(180),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: ShadColors.gold.withAlpha(40)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      key: const ValueKey('forgot-logo'),
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF161616),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Lx.line),
                      ),
                      child: const Text.rich(
                        TextSpan(children: [
                          TextSpan(text: 'd'),
                          TextSpan(text: '.', style: TextStyle(fontStyle: FontStyle.normal, color: Lx.crimsonInk)),
                        ]),
                        style: TextStyle(fontFamily: Lx.serif, fontStyle: FontStyle.italic, fontSize: 36, height: 1, color: Lx.ink),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.forgotPasswordTitle,
                    textAlign: TextAlign.center,
                    style: Lx.display(context, size: 22),
                  ),
                  const SizedBox(height: 20),

                  if (_sent) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Lx.ok.withAlpha(26),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Lx.ok.withAlpha(90)),
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.mark_email_read_outlined, size: 18, color: Lx.ok),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.forgotPasswordSent,
                            style: const TextStyle(fontSize: 12, color: ShadColors.textPrimary, height: 1.5),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => context.go('/login'),
                        child: Text(l10n.forgotPasswordBackToLogin),
                      ),
                    ),
                  ] else ...[
                    Text(
                      l10n.forgotPasswordSubtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: ShadColors.textSecondary, height: 1.5),
                    ),
                    const SizedBox(height: 20),

                    if (_error != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: ShadColors.crimson.withAlpha(30),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: ShadColors.crimson.withAlpha(50)),
                        ),
                        child: Text(_error!, key: const ValueKey('forgot-error'), style: Lx.text(context, size: 12, color: ShadColors.gold)),
                      ),
                    ],

                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textDirection: TextDirection.ltr,
                      autocorrect: false,
                      enabled: !_loading,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: l10n.email,
                        hintText: l10n.emailHint,
                        prefixIcon: const Icon(Icons.email_outlined, size: 18),
                      ),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                              )
                            : Text(l10n.forgotPasswordSubmit),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _loading ? null : () => context.go('/login'),
                      child: Text(
                        l10n.forgotPasswordBackToLogin,
                        style: const TextStyle(fontSize: 12, color: ShadColors.gold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
