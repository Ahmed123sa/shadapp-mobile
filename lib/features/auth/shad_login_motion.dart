import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/luxe/tokens.dart';
import '../../core/theme.dart';

// Shad sign-in motion. The idea: a crooked line is the long way round, a
// straight line is the shorter road, and the dot is where it ends.
//   * ShadTagline: "Shorter Road." is drawn as a twisted line that straightens
//     and then turns into the letters, and the dot drops last.
//   * ShadButtonLoader: the same line, small, inside the sign-in button.

double _clamp01(double v) => v.clamp(0.0, 1.0).toDouble();

double _ease(double t) {
  t = _clamp01(t);
  return t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2;
}

double _back(double t) {
  t = _clamp01(t);
  const c = 1.9;
  return 1 + (c + 1) * pow(t - 1, 3) + c * pow(t - 1, 2);
}

class _TagFrame {
  final double draw; // how much of the line exists (0..1)
  final double rad; // loop radius in logical px (0 = straight)
  final double phase;
  final double reveal; // letters shown left to right (0..1)
  final double lineAlpha;
  final double dot; // 0..1 (drops in)
  const _TagFrame({
    required this.draw,
    required this.rad,
    required this.phase,
    required this.reveal,
    required this.lineAlpha,
    required this.dot,
  });
}

/// "Shorter Road." as motion. Plays once when the screen opens; plays a short
/// "loop back and straighten" again whenever [errorTick] goes up. With
/// animations disabled (accessibility setting) it is just the finished word.
class ShadTagline extends StatefulWidget {
  final String text;
  final TextStyle style;
  final int errorTick;
  const ShadTagline({
    super.key,
    this.text = 'Shorter Road',
    required this.style,
    this.errorTick = 0,
  });

  @override
  State<ShadTagline> createState() => _ShadTaglineState();
}

class _ShadTaglineState extends State<ShadTagline> with TickerProviderStateMixin {
  // A short lead-in so the card has faded in before the line starts.
  static const _leadMs = 700.0;
  static const _introMs = 4200.0;
  static const _errorMs = 1600.0;
  static const _boxHeight = 64.0;
  static const _maxLoop = 18.0;

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4900), // lead + intro
  );
  late final AnimationController _error = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
    } else {
      _intro.forward();
    }
  }

  @override
  void didUpdateWidget(ShadTagline old) {
    super.didUpdateWidget(old);
    if (widget.errorTick != old.errorTick && widget.errorTick > 0) {
      if (MediaQuery.disableAnimationsOf(context)) return;
      _error.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _error.dispose();
    super.dispose();
  }

  _TagFrame _frame() {
    if (_error.isAnimating) {
      final t = _error.value;
      final b = sin(pi * _clamp01(t));
      final ms = t * _errorMs;
      return _TagFrame(
        draw: 1,
        rad: 13 * b,
        phase: -ms / 130,
        reveal: _clamp01(1 - b * 1.4),
        lineAlpha: b > 0.02 ? 1 : 0,
        dot: 1 - 0.3 * b,
      );
    }
    final elapsed = _intro.value * (_leadMs + _introMs);
    final t = (elapsed - _leadMs) / _introMs;
    if (t <= 0) {
      return const _TagFrame(draw: 0, rad: _maxLoop, phase: 0, reveal: 0, lineAlpha: 1, dot: 0);
    }
    // 0-.30 the line is drawn in loops, .22-.56 the loops open into a straight line,
    // .52-.86 the straight line turns into the letters, .84-1 the dot drops.
    return _TagFrame(
      draw: _ease(t / 0.3),
      rad: _maxLoop * (1 - _ease((t - 0.22) / 0.34)),
      phase: -elapsed / 150,
      reveal: _ease((t - 0.52) / 0.34),
      lineAlpha: 1,
      dot: _back((t - 0.84) / 0.16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final tp = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    final textW = tp.width;
    final textH = tp.height;
    final dotStyle = widget.style.copyWith(color: Lx.crimsonInk);

    return Semantics(
      label: '${widget.text}.',
      excludeSemantics: true,
      child: Directionality(
        // The tagline is English wherever the app language is.
        textDirection: TextDirection.ltr,
        child: AnimatedBuilder(
          animation: Listenable.merge([_intro, _error]),
          builder: (context, _) {
            final f = _frame();
            return Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: textW,
                  height: _boxHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      ClipRect(
                        clipper: _RevealClipper(f.reveal),
                        // overflow: visible, because the default clip cuts the italic
                        // last letter at the measured width.
                        child: Text(widget.text, style: widget.style, maxLines: 1, softWrap: false, overflow: TextOverflow.visible),
                      ),
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _TwistedLinePainter(
                            length: textW,
                            midY: _boxHeight / 2 + textH * 0.12,
                            rad: f.rad,
                            phase: f.phase,
                            draw: f.draw,
                            reveal: f.reveal,
                            alpha: f.lineAlpha,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 3),
                Opacity(
                  opacity: _clamp01(f.dot * 2),
                  child: Transform.translate(
                    offset: Offset(0, (1 - f.dot) * -16),
                    child: Transform.scale(
                      scale: max(f.dot, 0.0),
                      child: Text('.', style: dotStyle),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RevealClipper extends CustomClipper<Rect> {
  final double reveal;
  _RevealClipper(this.reveal);

  @override
  // Italic letters lean past the measured width, so the last one needs room
  // on the right once the word is fully written.
  Rect getClip(Size size) => Rect.fromLTRB(-8, -size.height, size.width * reveal + 12 * reveal, size.height * 2);

  @override
  bool shouldReclip(covariant _RevealClipper old) => old.reveal != reveal;
}

class _TwistedLinePainter extends CustomPainter {
  final double length;
  final double midY;
  final double rad;
  final double phase;
  final double draw;
  final double reveal;
  final double alpha;
  _TwistedLinePainter({
    required this.length,
    required this.midY,
    required this.rad,
    required this.phase,
    required this.draw,
    required this.reveal,
    required this.alpha,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (draw <= 0 || alpha <= 0) return;
    // The line only exists where the letters have not been written yet.
    final left = reveal <= 0 ? -10000.0 : reveal * length;
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(left, -10000, 10000, 10000));
    final n = max(2, (160 * draw).round());
    const w = pi * 2 * 6.5;
    final path = Path();
    for (var i = 0; i < n; i++) {
      final t = i / 159;
      final a = w * t + phase;
      final taper = sin(pi * min(1.0, t * 1.01));
      final x = t * length - rad * sin(a) * taper;
      final y = midY + rad * (cos(a) - 1) * taper * 0.8;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = ShadColors.gold.withValues(alpha: alpha),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TwistedLinePainter o) =>
      o.rad != rad || o.phase != phase || o.draw != draw || o.reveal != reveal || o.alpha != alpha || o.length != length;
}

/// The loader inside the sign-in button: a line loops, straightens, a dot
/// drops at its end, and it repeats. It keeps running through the navigation
/// after a good sign-in. With animations disabled it is one still frame.
class ShadButtonLoader extends StatefulWidget {
  final Color color;
  const ShadButtonLoader({super.key, this.color = Colors.white});

  @override
  State<ShadButtonLoader> createState() => _ShadButtonLoaderState();
}

class _ShadButtonLoaderState extends State<ShadButtonLoader> with SingleTickerProviderStateMixin {
  static const _cycleMs = 1200.0;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 0.95; // straight line with its dot
    } else {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: 52,
        height: 20,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Transform.flip(
            // The dot sits at the end of the line, in the reading direction.
            flipX: Directionality.of(context) == TextDirection.ltr,
            child: CustomPaint(
              painter: _LoaderPainter(k: _c.value, ms: _c.value * _cycleMs, color: widget.color, still: MediaQuery.disableAnimationsOf(context)),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoaderPainter extends CustomPainter {
  final double k;
  final double ms;
  final Color color;
  final bool still;
  _LoaderPainter({required this.k, required this.ms, required this.color, required this.still});

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn for right-to-left (dot on the left); the widget mirrors it in LTR.
    final r = still ? 0.0 : 6 * (1 - _ease((k - 0.25) / 0.4));
    const x0 = 48.0, x1 = 16.0, n = 40;
    final path = Path();
    for (var i = 0; i < n; i++) {
      final t = i / (n - 1);
      final a = pi * 2 * 2.4 * t - ms / 120;
      final taper = sin(pi * t);
      final x = x0 + (x1 - x0) * t + r * sin(a) * taper;
      final y = 10 + (r * cos(a) - r) * taper * 0.9;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final lineAlpha = still ? 1.0 : 1 - _ease((k - 0.8) / 0.18);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color.withValues(alpha: lineAlpha),
    );
    final d = still ? 1.0 : _back((k - 0.62) / 0.2) * (1 - _ease((k - 0.9) / 0.1));
    if (d > 0) {
      canvas.drawCircle(const Offset(9, 10), 2.8 * d, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _LoaderPainter o) => o.k != k || o.color != color || o.still != still;
}
