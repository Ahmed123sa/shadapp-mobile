import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shadapp_client/generated/app_localizations.dart';

import '../../core/locale_provider.dart';
import '../../core/theme.dart';

/// Self-service signup for new client companies.
///
/// Registration is *requested*, not granted: the form collects the same
/// fields an AM fills in on [CreateClientPage], then hands the request to
/// staff for review. Nothing is logged in here — on success the user is sent
/// back to /login and waits for the approval email.
///
/// There is no `POST /clients/register` endpoint yet, so [_sendRequest]
/// deliberately simulates the round trip (see the note there) rather than
/// pretending a call happened. The payload it builds is already in the shape
/// the backend expects, so wiring it up later is a one-line change.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with TickerProviderStateMixin {
  /// How long the fake submit takes. Long enough to read as real work, short
  /// enough not to feel broken. Replace with the real request, not with a
  /// smaller number.
  static const _submitDelay = Duration(seconds: 2);

  final _formKey = GlobalKey<FormState>();

  final _companyController = TextEditingController();
  final _personController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _countryController = TextEditingController();
  final _industryController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _loading = false;
  bool _passwordVisible = false;
  bool _confirmVisible = false;
  String? _error;

  /// Stays [AutovalidateMode.disabled] until the first submit, so the form
  /// doesn't turn red while it's still being filled in for the first time.
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  late final AnimationController _cardController;
  late final Animation<double> _cardFade;
  late final Animation<Offset> _cardSlide;
  late final AnimationController _breathController;
  late final Animation<double> _breath;
  late final AnimationController _shakeController;

  @override
  void initState() {
    super.initState();

    _cardController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
    _cardFade = CurvedAnimation(parent: _cardController, curve: Curves.easeOut);
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _cardController, curve: Curves.easeOutCubic));

    // Same slow background drift as the login screen, so the two feel like
    // one flow rather than two unrelated screens.
    _breathController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 4000))
          ..repeat(reverse: true);
    _breath = CurvedAnimation(parent: _breathController, curve: Curves.easeInOut);

    _shakeController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  }

  @override
  void dispose() {
    _companyController.dispose();
    _personController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _countryController.dispose();
    _industryController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _cardController.dispose();
    _breathController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  // ── Submit ──────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_loading) return;
    final l10n = AppLocalizations.of(context)!;
    FocusScope.of(context).unfocus();

    setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _error = l10n.register_errFixFields);
      _shakeController.forward(from: 0);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    await _sendRequest();
    if (!mounted) return;

    setState(() => _loading = false);
    await _showSuccessDialog();
  }

  /// Placeholder for the registration request.
  ///
  /// The backend has no public signup route yet, so this builds the payload
  /// (identical in shape to what `POST /clients` takes) and waits. When the
  /// endpoint lands, swap the delay for the call and let its exceptions
  /// surface into [_error] the way LoginPage handles them — the caller
  /// already has the loading/error plumbing for it.
  Future<void> _sendRequest() async {
    final payload = <String, dynamic>{
      'company_name': _companyController.text.trim(),
      'contact_person': _personController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      if (_countryController.text.trim().isNotEmpty) 'country': _countryController.text.trim(),
      if (_industryController.text.trim().isNotEmpty) 'industry': _industryController.text.trim(),
      'password': _passwordController.text,
    };

    // Until there's somewhere to POST this, show the payload in debug builds
    // so the field mapping can be checked against the backend contract. The
    // password is redacted — it must never reach the console or a log sink.
    if (kDebugMode) {
      debugPrint('[register_screen] would submit: '
          '${{...payload, 'password': '***'}}');
    }

    await Future<void>.delayed(_submitDelay);
  }

  Future<void> _showSuccessDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withAlpha(200),
      builder: (dialogContext) => _SuccessDialog(
        onDismiss: () {
          Navigator.of(dialogContext).pop();
          // go() rather than pop(): the request is filed, so there is nothing
          // to come back to on this screen.
          context.go('/login');
        },
      ),
    );
  }

  // ── Validators ──────────────────────────────────────────────────────────

  String? _requiredValidator(String? value, String message) =>
      (value == null || value.trim().isEmpty) ? message : null;

  String? _emailValidator(String? value, String message) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return message;
    // Deliberately loose — the backend is the real authority on whether an
    // address is deliverable. This only catches obvious typos.
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v) ? null : message;
  }

  String? _phoneValidator(String? value, String message) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return message;
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 7 ? null : message;
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: ShadColors.surfaceDarker,
      // resizeToAvoidBottomInset keeps the focused field above the keyboard;
      // the form is long enough that the default would clip the last fields.
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _breath,
            builder: (context, _) => DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    for (var i = 0; i < ShadColors.loginGradientFrom.length; i++)
                      Color.lerp(ShadColors.loginGradientFrom[i], ShadColors.loginGradientTo[i],
                          _breath.value)!,
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            top: -70,
            left: -50,
            child: _Blob(color: ShadColors.crimson.withAlpha(30), size: 180),
          ),
          Positioned(
            bottom: -60,
            right: -40,
            child: _Blob(color: ShadColors.gold.withAlpha(20), size: 140),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildTopBar(isAr),
                Expanded(
                  child: FadeTransition(
                    opacity: _cardFade,
                    child: SlideTransition(
                      position: _cardSlide,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                        child: AnimatedBuilder(
                          animation: _shakeController,
                          builder: (context, child) {
                            final v = _shakeController.value;
                            return Transform.translate(
                              offset: Offset(sin(v * pi * 4) * 10 * (1 - v), 0),
                              child: child,
                            );
                          },
                          child: _buildCard(l10n, isAr),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(bool isAr) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 20, color: Colors.white70),
            // The register screen can be reached as a deep link with nothing
            // beneath it, so don't rely on pop() having somewhere to go.
            onPressed: _loading ? null : () => context.go('/login'),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.language, size: 20, color: Colors.white54),
            onPressed: () => context.read<LocaleProvider>().toggle(),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(AppLocalizations l10n, bool isAr) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          decoration: BoxDecoration(
            color: ShadColors.card.withAlpha(180),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: ShadColors.gold.withAlpha(50)),
            boxShadow: [
              BoxShadow(
                color: ShadColors.gold.withAlpha(15),
                blurRadius: 40,
                spreadRadius: -5,
              ),
              BoxShadow(
                color: Colors.black.withAlpha(80),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            autovalidateMode: _autovalidate,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset('assets/images/logo.jpg',
                        width: 60, height: 60, fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.register_title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.register_subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: Colors.white.withAlpha(140),
                  ),
                ),
                const SizedBox(height: 22),

                if (_error != null) ...[
                  _ErrorBanner(message: _error!),
                  const SizedBox(height: 16),
                ],

                _SectionLabel(text: l10n.register_sectionCompany),
                const SizedBox(height: 12),
                _buildField(
                  label: l10n.register_companyName,
                  hint: l10n.register_companyNameHint,
                  controller: _companyController,
                  icon: Icons.business_outlined,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => _requiredValidator(v, l10n.register_errCompanyName),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildField(
                        label: l10n.register_country,
                        hint: l10n.register_countryHint,
                        controller: _countryController,
                        icon: Icons.public_outlined,
                        optionalLabel: l10n.register_optional,
                        textCapitalization: TextCapitalization.words,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildField(
                        label: l10n.register_industry,
                        hint: l10n.register_industryHint,
                        controller: _industryController,
                        icon: Icons.category_outlined,
                        optionalLabel: l10n.register_optional,
                        textCapitalization: TextCapitalization.words,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),
                _SectionLabel(text: l10n.register_sectionContact),
                const SizedBox(height: 12),
                _buildField(
                  label: l10n.register_contactPerson,
                  hint: l10n.register_contactPersonHint,
                  controller: _personController,
                  icon: Icons.person_outline,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => _requiredValidator(v, l10n.register_errContactPerson),
                ),
                const SizedBox(height: 14),
                _buildField(
                  label: l10n.emailLabel,
                  hint: l10n.register_emailHint,
                  controller: _emailController,
                  icon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  forceLtr: true,
                  validator: (v) => _emailValidator(v, l10n.register_errEmail),
                ),
                const SizedBox(height: 14),
                _buildField(
                  label: l10n.register_phone,
                  hint: l10n.register_phoneHint,
                  controller: _phoneController,
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  forceLtr: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-() ]')),
                  ],
                  validator: (v) => _phoneValidator(v, l10n.register_errPhone),
                ),

                const SizedBox(height: 22),
                _SectionLabel(text: l10n.register_sectionSecurity),
                const SizedBox(height: 12),
                _buildField(
                  label: l10n.register_password,
                  hint: l10n.register_passwordHint,
                  controller: _passwordController,
                  icon: Icons.lock_outline,
                  obscure: !_passwordVisible,
                  onToggleObscure: () => setState(() => _passwordVisible = !_passwordVisible),
                  forceLtr: true,
                  validator: (v) =>
                      (v ?? '').length >= 8 ? null : l10n.register_errPassword,
                ),
                const SizedBox(height: 14),
                _buildField(
                  label: l10n.register_confirmPassword,
                  hint: l10n.register_passwordHint,
                  controller: _confirmController,
                  icon: Icons.lock_person_outlined,
                  obscure: !_confirmVisible,
                  onToggleObscure: () => setState(() => _confirmVisible = !_confirmVisible),
                  forceLtr: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  validator: (v) =>
                      v == _passwordController.text ? null : l10n.register_errConfirmPassword,
                ),

                const SizedBox(height: 26),
                _SubmitButton(
                  loading: _loading,
                  label: l10n.register_submit,
                  loadingLabel: l10n.register_sending,
                  onPressed: _submit,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l10n.register_haveAccount,
                      style: TextStyle(fontSize: 12, color: Colors.white.withAlpha(130)),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: _loading ? null : () => context.go('/login'),
                      child: Text(
                        l10n.register_signIn,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: ShadColors.gold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    String? optionalLabel,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    TextInputAction textInputAction = TextInputAction.next,
    ValueChanged<String>? onSubmitted,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    bool forceLtr = false,
    FormFieldValidator<String>? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.white.withAlpha(140)),
              ),
            ),
            if (optionalLabel != null) ...[
              const SizedBox(width: 6),
              Text(
                optionalLabel,
                style: TextStyle(fontSize: 9, color: Colors.white.withAlpha(70)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          enabled: !_loading,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          textInputAction: textInputAction,
          onFieldSubmitted: onSubmitted,
          obscureText: obscure,
          validator: validator,
          // Email, phone and passwords are always typed left-to-right even in
          // the Arabic locale; free-text fields follow the locale.
          textDirection: forceLtr ? TextDirection.ltr : null,
          style: const TextStyle(fontSize: 13, color: Colors.white),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: TextStyle(fontSize: 12, color: Colors.white.withAlpha(60)),
            prefixIcon: Icon(icon, size: 17, color: Colors.white.withAlpha(110)),
            prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            suffixIcon: onToggleObscure == null
                ? null
                : IconButton(
                    icon: Icon(obscure ? Icons.visibility : Icons.visibility_off,
                        size: 17, color: Colors.white.withAlpha(110)),
                    onPressed: onToggleObscure,
                  ),
            filled: true,
            fillColor: Colors.white.withAlpha(8),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            errorStyle: const TextStyle(fontSize: 10, color: ShadColors.error),
            border: _fieldBorder(Colors.white.withAlpha(20)),
            enabledBorder: _fieldBorder(Colors.white.withAlpha(20)),
            disabledBorder: _fieldBorder(Colors.white.withAlpha(12)),
            focusedBorder: _fieldBorder(ShadColors.gold, width: 1.5),
            errorBorder: _fieldBorder(ShadColors.error),
            focusedErrorBorder: _fieldBorder(ShadColors.error, width: 1.5),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _fieldBorder(Color color, {double width = 1}) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );
}

// ── Pieces ────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 12, color: ShadColors.crimson),
        const SizedBox(width: 8),
        Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: ShadColors.gold.withAlpha(200),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: Colors.white.withAlpha(15))),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: ShadColors.crimson.withAlpha(30),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ShadColors.crimson.withAlpha(60)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: ShadColors.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(fontSize: 11, color: ShadColors.gold, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double size;
  const _Blob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

/// Crimson submit button that swaps its label for a spinner + status text
/// while the request is in flight, so the 2s wait reads as progress.
class _SubmitButton extends StatefulWidget {
  final bool loading;
  final String label;
  final String loadingLabel;
  final VoidCallback onPressed;

  const _SubmitButton({
    required this.loading,
    required this.label,
    required this.loadingLabel,
    required this.onPressed,
  });

  @override
  State<_SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<_SubmitButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    // Listener, not GestureDetector: a GestureDetector here would put a
    // second tap recognizer in the arena with the button's own, and whichever
    // loses is silently dropped. Listener only observes pointer events, so
    // the press always reaches ElevatedButton.onPressed.
    return Listener(
      onPointerDown: (_) {
        if (!widget.loading) setState(() => _scale = 0.97);
      },
      onPointerUp: (_) => setState(() => _scale = 1.0),
      onPointerCancel: (_) => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: widget.loading ? null : widget.onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: ShadColors.crimson,
              foregroundColor: Colors.white,
              disabledBackgroundColor: ShadColors.crimson.withAlpha(140),
              disabledForegroundColor: Colors.white70,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
              shadowColor: ShadColors.crimson.withAlpha(90),
            ),
            child: widget.loading
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(widget.loadingLabel,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  )
                : Text(widget.label,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}

/// "Request sent — an admin will review it" confirmation.
///
/// Modal and undismissable on purpose: the only way out is the button, which
/// returns to /login. Anything else would leave the user staring at a filled
/// form they must not submit twice.
class _SuccessDialog extends StatefulWidget {
  final VoidCallback onDismiss;
  const _SuccessDialog({required this.onDismiss});

  @override
  State<_SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<_SuccessDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _checkScale;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
    _scale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.5, curve: Curves.easeOutBack),
    );
    _checkScale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 1, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: ScaleTransition(
          scale: _scale,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
            decoration: BoxDecoration(
              color: ShadColors.card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: ShadColors.gold.withAlpha(70)),
              boxShadow: [
                BoxShadow(color: ShadColors.gold.withAlpha(25), blurRadius: 50, spreadRadius: -8),
                BoxShadow(
                    color: Colors.black.withAlpha(140),
                    blurRadius: 30,
                    offset: const Offset(0, 12)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _checkScale,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ShadColors.success.withAlpha(30),
                      border: Border.all(color: ShadColors.success.withAlpha(90), width: 2),
                    ),
                    child: const Icon(Icons.check_rounded, size: 38, color: ShadColors.success),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.register_successTitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.register_successBody,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.6,
                    color: ShadColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: ShadColors.goldSoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ShadColors.goldBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule, size: 14, color: ShadColors.gold),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          l10n.register_successNote,
                          style: const TextStyle(fontSize: 11, color: ShadColors.gold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: widget.onDismiss,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ShadColors.crimson,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(l10n.register_successAction,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
