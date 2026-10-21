import 'dart:math';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../core/luxe/tokens.dart';
import '../../core/theme.dart' show ShadColors;

// Shared look of the login mockup (design/mobile/login-mobile-mockup.html),
// used by the forgot-password screen so both screens are the same "card on a
// breathing background" — the mockup draws them with the same `.bg`, `.c1`,
// `.c2`, gold particles, `.card`, `.f`, `.go` and `.links`.

/// Mockup `.bg` (breathing gradient) + gold particles + `.c1` / `.c2`
/// circles, with [child] on top. [animate] false keeps it still (tests).
class AuthBackdrop extends StatefulWidget {
  final Widget child;
  final bool animate;
  const AuthBackdrop({super.key, required this.child, this.animate = true});

  @override
  State<AuthBackdrop> createState() => _AuthBackdropState();
}

class _AuthBackdropState extends State<AuthBackdrop> with TickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(vsync: this, duration: const Duration(milliseconds: 4000));
  late final AnimationController _drift = AnimationController(vsync: this, duration: const Duration(seconds: 60));
  final _random = Random();
  late final List<_Dot> _dots = List.generate(
    20,
    (_) => _Dot(
      x: _random.nextDouble(),
      y: _random.nextDouble(),
      size: _random.nextDouble() * 4 + 2,
      speedX: (_random.nextDouble() - 0.5) * 0.003,
      speedY: (_random.nextDouble() - 0.5) * 0.003,
      opacity: _random.nextDouble() * 0.4 + 0.2,
      phase: _random.nextDouble() * 2 * pi,
    ),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _breath.repeat(reverse: true);
      _drift.repeat();
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      AnimatedBuilder(
        animation: _breath,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_breath.value);
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  for (var i = 0; i < ShadColors.loginGradientFrom.length; i++)
                    Color.lerp(ShadColors.loginGradientFrom[i], ShadColors.loginGradientTo[i], t)!,
                ],
              ),
            ),
          );
        },
      ),
      AnimatedBuilder(
        animation: _drift,
        builder: (context, _) => CustomPaint(painter: _DotPainter(dots: _dots, t: _drift.value)),
      ),
      Positioned(
        top: -60,
        right: -40,
        child: Container(width: 160, height: 160, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x1F941414))),
      ),
      Positioned(
        bottom: -50,
        left: -30,
        child: Container(width: 120, height: 120, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x14D4AF37))),
      ),
      widget.child,
    ]);
  }
}

/// Mockup `.card`: rgba(30,30,30,.7) glass, blur 16, r24, gold .16 border,
/// soft gold glow; padding 28.
class AuthCard extends StatelessWidget {
  final Widget child;
  const AuthCard({super.key, required this.child});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xB31E1E1E),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0x29D4AF37)),
              boxShadow: const [
                BoxShadow(color: Color(0x0FD4AF37), blurRadius: 40, spreadRadius: -5),
                BoxShadow(color: Color(0x4D000000), blurRadius: 20, offset: Offset(0, 10)),
              ],
            ),
            child: child,
          ),
        ),
      );
}

/// Mockup `.logo` (72px, r14, #161616, "d." serif italic 46) + h1 "Shad."
/// (serif 34, spacing .04em, crimson-ink ".").
class AuthLogo extends StatelessWidget {
  const AuthLogo({super.key});
  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
          key: const ValueKey('auth-logo'),
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x14F0F0F0)),
          ),
          child: const Text.rich(
            TextSpan(children: [
              TextSpan(text: 'd'),
              TextSpan(text: '.', style: TextStyle(fontStyle: FontStyle.normal, color: Lx.crimsonInk)),
            ]),
            style: TextStyle(fontFamily: Lx.serif, fontStyle: FontStyle.italic, fontSize: 46, height: 1, color: Lx.ink),
          ),
        ),
        const SizedBox(height: 12),
        const Text.rich(
          TextSpan(children: [
            TextSpan(text: 'Shad'),
            TextSpan(text: '.', style: TextStyle(color: Lx.crimsonInk)),
          ]),
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: Lx.serif, fontSize: 34, fontWeight: FontWeight.w500, letterSpacing: 1.36, color: Lx.ink),
        ),
      ]);
}

/// Mockup `.f`: 11px muted label, 46px input (r12, line-2 border, .03 fill,
/// gold .5 on focus).
Widget authField(
  BuildContext context, {
  required String label,
  required TextEditingController controller,
  required String hint,
  TextInputType? keyboardType,
  bool enabled = true,
  ValueChanged<String>? onSubmitted,
}) {
  const radius = BorderRadius.all(Radius.circular(12));
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: Lx.text(context, size: 11, color: Lx.muted)),
    const SizedBox(height: 6),
    TextField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      autocorrect: false,
      textDirection: TextDirection.ltr,
      onSubmitted: onSubmitted,
      style: const TextStyle(fontSize: 14, color: Colors.white, fontFamily: Lx.sans),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withAlpha(60)),
        filled: true,
        fillColor: Colors.white.withAlpha(8),
        constraints: const BoxConstraints(minHeight: 46),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: const OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: Lx.line2)),
        enabledBorder: const OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: Lx.line2)),
        disabledBorder: const OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: Lx.line2)),
        focusedBorder: const OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: Color(0x80D4AF37))),
      ),
    ),
  ]);
}

/// Mockup `.go`: 48px, r14, #a51a1a → #941414, white 14/500.
class AuthButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  const AuthButton({super.key, required this.label, required this.onPressed, this.loading = false});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: Opacity(
          opacity: loading ? 0.6 : 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFA51A1A), Color(0xFF941414)]),
            ),
            child: ElevatedButton(
              onPressed: loading ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                elevation: 0,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Text(label, style: Lx.text(context, size: 14, weight: FontWeight.w500, color: Colors.white)),
            ),
          ),
        ),
      );
}

/// Mockup `.links`: 12px, white .62, centred.
class AuthLink extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const AuthLink({super.key, required this.label, this.onTap});
  @override
  Widget build(BuildContext context) => Center(
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), minimumSize: Size.zero),
          child: Text(label, style: Lx.text(context, size: 12, color: Colors.white.withAlpha(158))),
        ),
      );
}

/// Mockup `.err` (crimson .12 / .2, gold text) and `.ok` (ok .1 / .35).
Widget authNotice(BuildContext context, String text, {required bool ok, Key? key}) => Container(
      key: key,
      width: double.infinity,
      padding: EdgeInsets.all(ok ? 12 : 10),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: ok ? const Color(0x1A8FB98B) : const Color(0x1F941414),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ok ? const Color(0x598FB98B) : const Color(0x33941414)),
      ),
      child: Text(text, style: Lx.text(context, size: ok ? 12.5 : 12, color: ok ? Lx.ink : const Color(0xFFD4AF37), height: 1.6)),
    );

class _Dot {
  final double x, y, size, speedX, speedY, opacity, phase;
  const _Dot({required this.x, required this.y, required this.size, required this.speedX, required this.speedY, required this.opacity, required this.phase});
}

class _DotPainter extends CustomPainter {
  final List<_Dot> dots;
  final double t;
  _DotPainter({required this.dots, required this.t});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in dots) {
      final px = ((p.x + p.speedX * t * 200 + sin(t * 2 * pi + p.phase) * 0.02) % 1.0) * size.width;
      final py = ((p.y + p.speedY * t * 200 + cos(t * 2 * pi + p.phase) * 0.02) % 1.0) * size.height;
      paint.color = const Color(0xFFD4AF37).withAlpha((p.opacity * 255).toInt());
      canvas.drawCircle(Offset(px, py), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DotPainter old) => old.t != t;
}
