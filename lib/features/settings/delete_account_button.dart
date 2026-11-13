import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/api_client.dart';
import '../../core/luxe/lx_icons.dart';
import '../../core/luxe/tokens.dart';
import '../../core/reverb_service.dart';
import '../../core/widgets/luxe/luxe_widgets.dart';
import '../../providers/auth_provider.dart';

/// In-app account deletion — App Store Guideline 5.1.1(v): an app that lets
/// people create an account must also let them delete it from inside the
/// app. Shared by settings_page.dart (client/sub_user),
/// am/settings/admin_settings_page.dart (account manager, assistant, super
/// admin) and profile_page.dart (staff_member, accountant). Each of those has
/// a test that fails if the button goes missing; the merge of the Luxe
/// redesign dropped it once and the app was rejected for it.
///
/// Button → confirmation dialog that re-asks for the password →
/// [AuthProvider.deleteAccount] → socket torn down → /login, with a
/// "your account has been deleted" message waiting there.
class DeleteAccountButton extends StatelessWidget {
  final AuthProvider authProvider;

  /// An extra consequence spelled out in the dialog — e.g. a client owner's
  /// sub-users losing access along with them.
  final String? warning;

  final ReverbService? reverb;

  const DeleteAccountButton({super.key, required this.authProvider, this.warning, this.reverb});

  Future<void> _start(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    // Grabbed before the await: the root ScaffoldMessenger outlives this
    // screen, so the confirmation shows up on /login instead of vanishing
    // with the page that asked for it.
    final messenger = ScaffoldMessenger.of(context);

    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DeleteAccountDialog(authProvider: authProvider, warning: warning),
    );
    if (deleted != true) return;

    // See client_dashboard_screen.dart's _logout — a socket left open under
    // the now-deleted identity 401s on reconnect and bounces the app to
    // /login a second time.
    (reverb ?? ReverbService()).disconnect();
    if (!context.mounted) return;
    context.go('/login');
    messenger.showSnackBar(SnackBar(
      content: Row(children: [
        const LxIcon('check', size: 18, color: Lx.ok),
        const SizedBox(width: 8),
        Expanded(child: Text(l10n.deleteAccount_done)),
      ]),
      duration: const Duration(seconds: 6),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LuxeButton(
        key: const ValueKey('delete-account'),
        label: l10n.deleteAccount_button,
        kind: LuxeButtonKind.danger,
        size: LuxeButtonSize.lg,
        lxIcon: 'trash',
        onPressed: () => _start(context),
      ),
      const SizedBox(height: 6),
      Text(
        l10n.deleteAccount_hint,
        textAlign: TextAlign.center,
        style: Lx.text(context, size: 12, color: Lx.faint),
      ),
    ]);
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  final AuthProvider authProvider;
  final String? warning;
  const _DeleteAccountDialog({required this.authProvider, this.warning});

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _passwordController = TextEditingController();
  bool _obscured = true;
  bool _deleting = false;
  String? _passwordError;
  String? _error;

  bool get _canSubmit => !_deleting && _passwordController.text.isNotEmpty;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _deleting = true;
      _passwordError = null;
      _error = null;
    });
    try {
      await widget.authProvider.deleteAccount(_passwordController.text);
      if (mounted) Navigator.of(context).pop(true);
      return;
    } on ValidationException catch (e) {
      // Our own string for the wrong-password case: the backend's message
      // isn't localized (no Accept-Language is sent), so it'd be English
      // inside an otherwise Arabic dialog.
      final errors = e.data?['errors'];
      if (errors is Map && errors.containsKey('password')) {
        _passwordError = l10n.deleteAccount_wrongPassword;
      } else {
        _error = e.message;
      }
    } on AuthException {
      // The session was already gone; ApiClient's onSessionExpired is taking
      // the app to /login, nothing left to do here.
      if (mounted) Navigator.of(context).pop(false);
      return;
    } on ConnectionException {
      _error = l10n.connectionFailedMessage;
    } on ServerException catch (e) {
      // e.g. a 403 when the backend refuses this particular account — its
      // message says why, which beats a generic failure.
      _error = e.message;
    } on RateLimitException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = l10n.deleteAccount_failed;
    }
    if (mounted) setState(() => _deleting = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return LuxeFormTheme(
      child: AlertDialog(
        icon: const LxIcon('alert', size: 34, color: Lx.crimsonInk),
        title: Text(l10n.deleteAccount_title),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.deleteAccount_body, style: Lx.text(context, size: 14, color: Lx.ink2, height: 1.4)),
            if (widget.warning != null) ...[
              const SizedBox(height: 12),
              Text(widget.warning!, style: Lx.text(context, size: 14, color: Lx.wait)),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: _obscured,
              enabled: !_deleting,
              autocorrect: false,
              enableSuggestions: false,
              textDirection: TextDirection.ltr,
              style: Lx.text(context, size: 15),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (_canSubmit) _submit();
              },
              decoration: InputDecoration(
                labelText: l10n.deleteAccount_passwordLabel,
                errorText: _passwordError,
                suffixIcon: IconButton(
                  icon: Icon(_obscured ? Icons.visibility_off : Icons.visibility, size: 18, color: Lx.muted),
                  onPressed: () => setState(() => _obscured = !_obscured),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: Lx.text(context, size: 13, color: Lx.danger)),
            ],
          ]),
        ),
        actions: [
          TextButton(
            onPressed: _deleting ? null : () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: _canSubmit ? _submit : null,
            child: _deleting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Text(l10n.deleteAccount_confirm),
          ),
        ],
      ),
    );
  }
}
