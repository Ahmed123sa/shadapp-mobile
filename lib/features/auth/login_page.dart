import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/api_client.dart';
import '../../core/locale_provider.dart';
import '../../core/theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _api = ApiClient();
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

  // ── SHAD: Single mysterious reveal (once, 3s) ──
  late AnimationController _shimmerController;
  bool _shimmerComplete = false;

  // ── SHAD: Static glow after reveal ──
  late AnimationController _logoGlowController;
  late Animation<double> _logoGlowAnim;

  // ── "Shorter Road.": Letter-by-letter staggered reveal ──
  late AnimationController _roadRevealController;

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

    // ── SHAD reveal: once, 3 seconds ──
    _shimmerController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3000),
    );
    _shimmerController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _shimmerComplete = true);
        _logoGlowController.forward();
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _roadRevealController.forward();
        });
      }
    });

    // ── SHAD glow: fades in after reveal ──
    _logoGlowController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000),
    );
    _logoGlowAnim = CurvedAnimation(parent: _logoGlowController, curve: Curves.easeOut);

    // ── "Shorter Road." letter reveal: 1.4s, starts after SHAD ──
    _roadRevealController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400),
    );

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
    // SHAD reveal starts slightly after card enters
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _shimmerController.forward();
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
    _shimmerController.dispose();
    _logoGlowController.dispose();
    _roadRevealController.dispose();
    _shakeController.dispose();
    _breathController.dispose();
    _focusGlowController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final l10n = AppLocalizations.of(context)!;
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      _error.value = l10n.enterEmailAndPassword;
      _shakeController.forward(from: 0);
      return;
    }
    _loading.value = true;
    _error.value = null;
    try {
      final body = {
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
      };

      Map<String, dynamic> data;
      bool isClient = false;

      try {
        data = await _api.post('/auth/login', body);
      } on Exception {
        data = await _api.post('/auth/client/login', body);
        isClient = true;
      }

      await _api.setToken(data['token']);

      if (isClient) {
        final loginType = data['login_type'] as String? ?? 'client';
        if (loginType == 'sub_user') {
          await _api.setRole('sub_user');
          final subUser = data['sub_user'] as Map<String, dynamic>;
          final clientData = data['client'] as Map<String, dynamic>;
          final wsId = data['workspace_id'] as int?;
          await _api.setUserData(id: clientData['id'] as int, name: subUser['name'] as String, workspace: wsId);
          await _api.setSubUserId(subUser['id'] as int);
        } else {
          await _api.setRole('client');
          final client = data['client'] as Map<String, dynamic>;
          final wsId = data['workspace_id'] as int?;
          await _api.setUserData(id: client['id'], name: client['company_name'], workspace: wsId);
        }
      } else {
        final user = data['user'] as Map<String, dynamic>;
        final role = user['role'] as String;
        await _api.setRole(role);
        await _api.setUserData(id: user['id'], name: user['name'], avatar: user['avatar_url'] as String?);
      }

      if (!mounted) return;
      context.go(isClient ? '/dashboard' : '/am/dashboard');
    } on AuthException {
      _error.value = l10n.sessionExpiredMessage;
      _shakeController.forward(from: 0);
    } on ValidationException catch (e) {
      _error.value = e.message;
      _shakeController.forward(from: 0);
    } on ServerException {
      _error.value = l10n.serverErrorMessage;
      _shakeController.forward(from: 0);
    } catch (_) {
      _error.value = l10n.invalidCredentialsMessage;
      _shakeController.forward(from: 0);
    } finally {
      _loading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final size = MediaQuery.of(context).size;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
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
                    Color.lerp(const Color(0xFF1A1A1A), const Color(0xFF1E1418), t)!,
                    Color.lerp(const Color(0xFF0D0D0D), const Color(0xFF120E0E), t)!,
                    Color.lerp(const Color(0xFF141414), const Color(0xFF1A1414), t)!,
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
                              icon: const Icon(Icons.language, size: 20, color: Colors.white54),
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
                                      color: const Color(0xFF1E1E1E).withAlpha(180),
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
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: Image.asset(
                                          'assets/images/logo.jpg',
                                          width: 72, height: 72,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                      const SizedBox(height: 12),

                                      // ── SHAD: Mysterious Reveal + Glow ──
                                      AnimatedBuilder(
                                        animation: Listenable.merge([
                                          _shimmerController,
                                          _logoGlowAnim,
                                        ]),
                                        builder: (context, _) {
                                          if (_shimmerComplete) {
                                            // After reveal: plain white + gold glow
                                            final glow = _logoGlowAnim.value;
                                            return Text('SHAD', style: TextStyle(
                                              fontSize: 26, fontWeight: FontWeight.w700,
                                              letterSpacing: 6, color: Colors.white,
                                              fontFamily: 'PlayfairDisplay',
                                              shadows: [
                                                Shadow(
                                                  color: ShadColors.gold.withAlpha((glow * 100).toInt()),
                                                  blurRadius: lerpDouble(0, 8, glow)!,
                                                ),
                                              ],
                                            ));
                                          }
                                          // During reveal: gold sweep diagonal
                                          return ShaderMask(
                                            blendMode: BlendMode.srcIn,
                                            shaderCallback: (bounds) {
                                              return LinearGradient(
                                                colors: const [
                                                  Colors.white30, Colors.white, ShadColors.gold,
                                                  Colors.white, Colors.white30,
                                                ],
                                                stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
                                                begin: const Alignment(-1.0, -1.0),
                                                end: const Alignment(1.0, 1.0),
                                                transform: _SlidingGradient(
                                                  slidePercent: _shimmerController.value,
                                                ),
                                              ).createShader(bounds);
                                            },
                                            child: const Text('SHAD', style: TextStyle(
                                              fontSize: 26, fontWeight: FontWeight.w700,
                                              letterSpacing: 6, color: Colors.white,
                                              fontFamily: 'PlayfairDisplay',
                                            )),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 4),

                                      // ── "Shorter Road.": Letter-by-letter reveal ──
                                      _StaggeredText(
                                        text: 'Shorter Road.',
                                        animation: _roadRevealController,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: ShadColors.gold.withAlpha(180),
                                          fontFamily: 'PlayfairDisplay',
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                      const SizedBox(height: 28),

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
                                            child: Text(error, style: TextStyle(
                                              fontSize: 12, color: ShadColors.gold,
                                              fontFamily: isAr ? 'NotoSansArabic' : 'Archivo',
                                            )),
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
                                        onPressed: () {},
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero, minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: Text(
                                          l10n.forgotPassword,
                                          style: TextStyle(fontSize: 11, color: Colors.white.withAlpha(100),
                                            fontFamily: isAr ? 'NotoSansArabic' : 'Archivo'),
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
        Text(label, style: TextStyle(
          fontSize: 11, color: Colors.white.withAlpha(120),
          fontFamily: Localizations.localeOf(context).languageCode == 'ar' ? 'NotoSansArabic' : 'Archivo',
        )),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          obscureText: obscure && !_passwordVisible,
          style: const TextStyle(fontSize: 13, color: Colors.white),
          textDirection: TextDirection.ltr,
          onSubmitted: obscure ? (_) => _login() : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withAlpha(60)),
            filled: true,
            fillColor: Colors.white.withAlpha(8),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withAlpha(20)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withAlpha(20)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: ShadColors.gold, width: 1.5),
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
          child: ElevatedButton(
            onPressed: widget.loading ? null : widget.onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: ShadColors.crimson,
              foregroundColor: Colors.white,
              disabledBackgroundColor: ShadColors.crimson.withAlpha(120),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
              shadowColor: ShadColors.crimson.withAlpha(80),
            ),
            child: widget.loading
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Text(widget.label, style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    fontFamily: Localizations.localeOf(context).languageCode == 'ar' ? 'NotoSansArabic' : 'Archivo')),
          ),
        ),
      ),
    );
  }
}

// ── Shimmer Gradient Transform (single axis) ──
class _SlidingGradient extends GradientTransform {
  final double slidePercent;
  const _SlidingGradient({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * (2 * slidePercent - 1), 0, 0);
  }
}

// ── Staggered Letter Reveal ──
class _StaggeredText extends StatelessWidget {
  final String text;
  final Animation<double> animation;
  final TextStyle style;
  const _StaggeredText({required this.text, required this.animation, required this.style});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final chars = text.split('');
        final staggerInterval = 0.85 / max(chars.length, 1);
        return Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: TextDirection.ltr,
          children: List.generate(chars.length, (i) {
            final charStart = i * staggerInterval;
            final charEnd = min(charStart + 0.25, 1.0);
            final localProgress = ((animation.value - charStart) / (charEnd - charStart)).clamp(0.0, 1.0);
            final eased = Curves.easeOut.transform(localProgress);
            return Opacity(
              opacity: eased * 0.7,
              child: Transform.translate(
                offset: Offset(0, (1 - eased) * 6),
                child: Text(chars[i], style: style),
              ),
            );
          }),
        );
      },
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
