import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/shad_logo.dart';

/// Request a password reset link.
///
/// The link in the email opens the dashboard in a browser rather than deep
/// linking back into the app — see ResetPasswordNotification on the backend
/// for why. So this screen's whole job is to trigger the email; the actual
/// password change happens on the web, and the user then signs in here with
/// the new password.
class ForgotPasswordPage extends StatefulWidget {
  final ApiClient? api;
  const ForgotPasswordPage({super.key, this.api});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  late final ApiClient _api = widget.api ?? ApiClient();

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

    final body = {'email': email};

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

    for (final path in ['/auth/forgot-password', '/auth/client/forgot-password']) {
      try {
        await _api.post(path, body);
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
                color: ShadColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ShadColors.goldBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: ShadLogo(size: 56, showText: false)),
                  const SizedBox(height: 16),
                  Text(
                    l10n.forgotPasswordTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: ShadColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_sent) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ShadColors.successLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: ShadColors.success.withAlpha(80)),
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.mark_email_read_outlined, size: 18, color: ShadColors.success),
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
                          color: ShadColors.errorLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: ShadColors.error.withAlpha(80)),
                        ),
                        child: Text(_error!, style: const TextStyle(color: ShadColors.error, fontSize: 12)),
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
