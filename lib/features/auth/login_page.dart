import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/api_client.dart';
import '../../core/app_log.dart';
import '../../core/locale_provider.dart';
import '../../core/luxe/lx_icons.dart';
import '../../core/luxe/tokens.dart';
import '../../core/router.dart' show homeLocationForRole;
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import 'shad_login_motion.dart';

class LoginPage extends StatefulWidget {
  final ApiClient? api;
  // Optional so existing call sites (and the widget tests, which pump
  // LoginPage(api: api) with no provider tree above it) keep working
  // unchanged — defaults to an AuthProvider built from the same ApiClient.
  final AuthProvider? authProvider;
  const LoginPage({super.key, this.api, this.authProvider});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final ApiClient _api = widget.api ?? ApiClient();
  late final AuthProvider _authProvider = widget.authProvider ?? AuthProvider(api: _api);
  bool _passwordVisible = false;
  final ValueNotifier<String?> _error = ValueNotifier<String?>(null);
  final ValueNotifier<bool> _loading = ValueNotifier<bool>(false);

  // Existing
  late AnimationController _cardController;
  late AnimationController _particlesController;
  late AnimationController _fieldsController;
  late Animation<double> _cardFade;
  late Animation<Offset> _cardSlide;
  late Animation<double> _fieldsFade;

  // Goes up on every failed sign-in so the tagline plays its "loop back and
  // straighten" motion (see ShadTagline).
  int _errorTick = 0;

  // ── Card Shake on Error ──
  late AnimationController _shakeController;

  // ── Breathing Background ──
  late AnimationController _breathController;
  late Animation<double> _breathAnimation;

  // ── Focus Glow ──
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  late AnimationController _focusGlowController;
  late Animation<double> _focusGlowAnim;

  final List<_Particle> _particles = [];
  final _random = Random();

  @override
  void initState() {
    super.initState();

    _cardController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _cardFade = CurvedAnimation(parent: _cardController, curve: Curves.easeOut);
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _cardController, curve: Curves.easeOutCubic));

    _fieldsController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fieldsFade = CurvedAnimation(parent: _fieldsController, curve: Curves.easeOut);

    _particlesController = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();

    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

    _breathController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 4000),
    )..repeat(reverse: true);
    _breathAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );

    _focusGlowController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300),
    );
    _focusGlowAnim = CurvedAnimation(parent: _focusGlowController, curve: Curves.easeOut);

    _emailFocus.addListener(_onFocusChange);
    _passwordFocus.addListener(_onFocusChange);

    for (int i = 0; i < 20; i++) {
      _particles.add(_Particle(
        x: _random.nextDouble(), y: _random.nextDouble(),
        size: _random.nextDouble() * 4 + 2,
        speedX: (_random.nextDouble() - 0.5) * 0.003,
        speedY: (_random.nextDouble() - 0.5) * 0.003,
        opacity: _random.nextDouble() * 0.4 + 0.2,
        phase: _random.nextDouble() * 2 * pi,
      ));
    }

    _cardController.forward();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _fieldsController.forward();
    });
  }

  void _onFocusChange() {
    if (_emailFocus.hasFocus || _passwordFocus.hasFocus) {
      _focusGlowController.forward();
    } else {
      _focusGlowController.reverse();
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _error.dispose();
    _loading.dispose();
    _cardController.dispose();
    _particlesController.dispose();
    _fieldsController.dispose();
    _shakeController.dispose();
    _breathController.dispose();
    _focusGlowController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _signalError() {
    _shakeController.forward(from: 0);
    if (mounted) setState(() => _errorTick++);
  }

  Future<void> _login() async {
    if (_loading.value) return;
    final l10n = AppLocalizations.of(context)!;
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      _error.value = l10n.enterEmailAndPassword;
      _signalError();
      return;
    }
    _loading.value = true;
    _error.value = null;
    // After a good sign-in the loader keeps running while the next screen
    // opens, so the button is only released when the attempt failed.
    var signedIn = false;
    try {
      // Staff-vs-client endpoint selection, the sub_user branch, and storing
      // the token/role/user data all live in AuthProvider.authenticate() now
      // — this screen only reacts to success/failure. See AuthProvider for
      // the exact fallback rules (they're unchanged from what used to be
      // inline here).
      await _authProvider.authenticate(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;
      signedIn = true;
      context.go(homeLocationForRole(_authProvider.role));
    } on ValidationException {
      // The only case that genuinely means the email/password were rejected.
      _error.value = l10n.invalidCredentialsMessage;
      _signalError();
    } on AuthException {
      _error.value = l10n.invalidCredentialsMessage;
      _signalError();
    } on RateLimitException {
      _error.value = l10n.tooManyAttemptsMessage;
      _signalError();
    } on ConnectionException {
      _error.value = l10n.connectionFailedMessage;
      _signalError();
    } on ServerException {
      _error.value = l10n.serverErrorMessage;
      _signalError();
    } catch (e, s) {
      // Anything reaching here is unclassified, so don't guess at a cause the
      // way this used to by blaming the credentials. Surface the real error in
      // debug builds so it can actually be diagnosed.
      AppLog.error('login_page._login', e, s);
      _error.value = kDebugMode ? '$e' : l10n.serverErrorMessage;
      _signalError();
    } finally {
      if (!signedIn) _loading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final size = MediaQuery.of(context).size;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: ShadColors.surfaceDarker,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Breathing Gradient Background ──
          AnimatedBuilder(
            animation: _breathAnimation,
            builder: (context, _) {
              final t = _breathAnimation.value;
              return Container(
                decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [
                    for (var i = 0; i < ShadColors.loginGradientFrom.length; i++)
                      Color.lerp(ShadColors.loginGradientFrom[i], ShadColors.loginGradientTo[i], t)!,
                  ],
                )),
              );
            },
          ),

          // ── Floating Particles ──
          AnimatedBuilder(
            animation: _particlesController,
            builder: (context, _) => CustomPaint(
              size: size,
              painter: _ParticlePainter(particles: _particles, animValue: _particlesController.value),
            ),
          ),

          // ── Decorative Circles ──
          Positioned(
            top: -60, right: -40,
            child: Container(
              width: 160, height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ShadColors.crimson.withAlpha(30),
              ),
            ),
          ),
          Positioned(
            bottom: -50, left: -30,
            child: Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ShadColors.gold.withAlpha(20),
              ),
            ),
          ),

          // ── Content ──
          SafeArea(
            child: FadeTransition(
              opacity: _cardFade,
              child: SlideTransition(
                position: _cardSlide,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: AnimatedBuilder(
                      animation: _shakeController,
                      builder: (context, child) {
                        final v = _shakeController.value;
                        final shakeX = sin(v * pi * 4) * 10 * (1 - v);
                        return Transform.translate(
                          offset: Offset(shakeX, 0),
                          child: child,
                        );
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Align(
                            alignment: isAr ? Alignment.topRight : Alignment.topLeft,
                            child: IconButton(
                              icon: LxIcon('lang', size: 18, color: Colors.white.withAlpha(128)),
                              onPressed: () => context.read<LocaleProvider>().toggle(),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // ── Glass Card with Focus Glow ──
                          ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                              child: AnimatedBuilder(
                                animation: _focusGlowAnim,
                                builder: (context, child) {
                                  final g = _focusGlowAnim.value;
                                  return Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(28),
                                    decoration: BoxDecoration(
                                      color: ShadColors.card.withAlpha(180),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        width: 1,
                                        color: Color.lerp(
                                          ShadColors.gold.withAlpha(40),
                                          ShadColors.gold.withAlpha(120),
                                          g,
                                        )!,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color.lerp(
                                            ShadColors.gold.withAlpha(15),
                                            ShadColors.gold.withAlpha(40),
                                            g,
                                          )!,
                                          blurRadius: lerpDouble(40, 70, g)!,
                                          spreadRadius: -5,
                                        ),
                                        BoxShadow(
                                          color: Colors.black.withAlpha(80),
                                          blurRadius: 20,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: child,
                                  );
                                },
                                child: FadeTransition(
                                  opacity: _fieldsFade,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // ── Luxe mark: "d." in a dark rounded square ──
                                      Container(
                                        key: const ValueKey('login-logo'),
                                        width: 72, height: 72,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF161616),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: Lx.line),
                                        ),
                                        child: Text.rich(
                                          const TextSpan(children: [
                                            TextSpan(text: 'd'),
                                            TextSpan(text: '.', style: TextStyle(fontStyle: FontStyle.normal, color: Lx.crimsonInk)),
                                          ]),
                                          style: const TextStyle(
                                            fontFamily: Lx.serif, fontStyle: FontStyle.italic,
                                            fontSize: 46, height: 1, color: Lx.ink,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),

                                      // ── Shad.: still, white with the crimson dot ──
                                      const Text.rich(
                                        TextSpan(children: [
                                          TextSpan(text: 'Shad'),
                                          TextSpan(text: '.', style: TextStyle(color: Lx.crimsonInk)),
                                        ]),
                                        key: ValueKey('login-title'),
                                        style: TextStyle(
                                          fontSize: 34, fontWeight: FontWeight.w500,
                                          letterSpacing: 1.4, color: Colors.white,
                                          fontFamily: Lx.serif,
                                        ),
                                      ),

                                      // ── "Shorter Road.": a twisted line that straightens into the word ──
                                      Align(
                                        heightFactor: 0.75,
                                        child: ShadTagline(
                                          key: const ValueKey('login-tagline'),
                                          errorTick: _errorTick,
                                          style: TextStyle(
                                            fontSize: 19,
                                            color: ShadColors.gold.withAlpha(180),
                                            fontFamily: Lx.serif,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 14),

                                      ValueListenableBuilder<String?>(
                                        valueListenable: _error,
                                        builder: (context, error, _) {
                                          if (error == null) return const SizedBox.shrink();
                                          return Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(10),
                                            margin: const EdgeInsets.only(bottom: 14),
                                            decoration: BoxDecoration(
                                              color: ShadColors.crimson.withAlpha(30),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: ShadColors.crimson.withAlpha(50)),
                                            ),
                                            child: Text(error, key: const ValueKey('login-error'), style: Lx.text(context, size: 12, color: ShadColors.gold)),
                                          );
                                        },
                                      ),

                                      _buildField(
                                        label: l10n.emailLabel,
                                        controller: _emailController,
                                        hint: 'example@domain.com',
                                        keyboardType: TextInputType.emailAddress,
                                        focusNode: _emailFocus,
                                      ),
                                      const SizedBox(height: 14),

                                      _buildField(
                                        label: l10n.passwordLabel,
                                        controller: _passwordController,
                                        hint: '••••••••',
                                        obscure: true,
                                        focusNode: _passwordFocus,
                                      ),
                                      const SizedBox(height: 22),

                                      ValueListenableBuilder<bool>(
                                        valueListenable: _loading,
                                        builder: (context, loading, _) => _LoginButton(
                                          loading: loading,
                                          onPressed: _login,
                                          label: l10n.loginButton,
                                        ),
                                      ),
                                      const SizedBox(height: 14),

                                      TextButton(
                                        // This button existed but was wired to
                                        // an empty callback — it looked
                                        // functional and silently did nothing.
                                        onPressed: () => context.push('/forgot-password'),
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero, minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: Text(
                                          l10n.forgotPassword,
                                          style: Lx.text(context, size: 12, color: Colors.white.withAlpha(158)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    bool obscure = false,
    FocusNode? focusNode,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Lx.text(context, size: 11, color: Lx.muted)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          obscureText: obscure && !_passwordVisible,
          style: const TextStyle(fontSize: 14, color: Colors.white, fontFamily: Lx.sans),
          textDirection: TextDirection.ltr,
          onSubmitted: obscure ? (_) => _login() : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withAlpha(60)),
            filled: true,
            fillColor: Colors.white.withAlpha(8),
            constraints: const BoxConstraints(minHeight: 46),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Lx.line2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Lx.line2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: ShadColors.gold.withAlpha(128)),
            ),
            suffixIcon: obscure
                ? IconButton(
                    icon: Icon(_passwordVisible ? Icons.visibility_off : Icons.visibility,
                      size: 18, color: Colors.white.withAlpha(120)),
                    onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

// ── Login Button with Scale Animation ──
class _LoginButton extends StatefulWidget {
  final bool loading;
  final VoidCallback onPressed;
  final String label;
  const _LoginButton({required this.loading, required this.onPressed, required this.label});

  @override
  State<_LoginButton> createState() => _LoginButtonState();
}

class _LoginButtonState extends State<_LoginButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.95),
      onTapUp: (_) { setState(() => _scale = 1.0); widget.onPressed(); },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: SizedBox(
          width: double.infinity,
          // Loading is not disabled: the button keeps its full colour and the
          // line loader says it is working.
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFFA51A1A), Color(0xFF941414)],
              ),
            ),
            child: ElevatedButton(
              key: const ValueKey('login-submit'),
              onPressed: widget.loading ? null : widget.onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                elevation: 0,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.loading) ...[
                    const ShadButtonLoader(key: ValueKey('login-loader')),
                    const SizedBox(width: 8),
                  ],
                  Text(widget.label, style: Lx.text(context, size: 14, weight: FontWeight.w500, color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Particle Data ──
class _Particle {
  double x, y;
  final double size;
  final double speedX, speedY;
  final double opacity;
  final double phase;
  _Particle({required this.x, required this.y, required this.size,
    required this.speedX, required this.speedY, required this.opacity, required this.phase});
}

// ── Particle Painter ──
class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double animValue;
  _ParticlePainter({required this.particles, required this.animValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in particles) {
      final px = ((p.x + p.speedX * animValue * 200 + sin(animValue * 2 * pi + p.phase) * 0.02) % 1.0) * size.width;
      final py = ((p.y + p.speedY * animValue * 200 + cos(animValue * 2 * pi + p.phase) * 0.02) % 1.0) * size.height;
      paint.color = ShadColors.gold.withAlpha((p.opacity * 255).toInt());
      canvas.drawCircle(Offset(px, py), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => oldDelegate.animValue != animValue;
}
