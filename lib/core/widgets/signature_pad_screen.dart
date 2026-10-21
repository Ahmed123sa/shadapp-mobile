import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../luxe/tokens.dart';

class SignaturePadScreen extends StatefulWidget {
  final String? title;
  const SignaturePadScreen({super.key, this.title});

  static Future<Uint8List?> show(BuildContext context, {String? title}) {
    return Navigator.of(context).push<Uint8List?>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => SignaturePadScreen(title: title),
      ),
    );
  }

  @override
  State<SignaturePadScreen> createState() => _SignaturePadScreenState();
}

class _SignaturePadScreenState extends State<SignaturePadScreen> {
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Rotate to landscape for full horizontal signature experience
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    // Restore natural portrait orientation on exit
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  void _clear() {
    setState(() {
      _strokes.clear();
      _currentStroke.clear();
    });
  }

  Future<void> _save() async {
    final allStrokes = [..._strokes];
    if (_currentStroke.isNotEmpty) allStrokes.add(_currentStroke);
    if (allStrokes.isEmpty) return;

    setState(() => _saving = true);
    try {
      final pngBytes = await renderSignaturePng(allStrokes);
      if (pngBytes != null && mounted) {
        Navigator.of(context).pop(pngBytes);
      }
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasStrokes = _strokes.isNotEmpty || _currentStroke.isNotEmpty;

    // Luxe pad (mockup `.pad`, full screen): dark page, line-2 bordered box
    // with the baseline, × and "Sign here", ink drawn in white so it shows.
    // The saved PNG is still rendered in black by renderSignaturePng, for
    // the white contract PDF.
    return Scaffold(
      backgroundColor: Lx.page,
      appBar: AppBar(
        backgroundColor: Lx.page,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          key: const ValueKey('sig-pad-close'),
          icon: const Icon(Icons.close, size: 20, color: Lx.muted),
          onPressed: () => Navigator.of(context).pop(null),
        ),
        title: Text(widget.title ?? l10n.signatureDrawSignature, style: Lx.display(context, size: 18)),
        centerTitle: true,
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, thickness: 1, color: Lx.line)),
        actions: [
          TextButton(
            onPressed: hasStrokes ? _clear : null,
            child: Text(l10n.signatureClear, style: Lx.text(context, size: 12.5, color: hasStrokes ? Lx.muted : Lx.faint)),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 12, 8),
            child: ElevatedButton(
              onPressed: (!hasStrokes || _saving) ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: Lx.crimson,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF2A2827),
                disabledForegroundColor: Lx.faint,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              child: _saving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(l10n.signatureSaveSignature, style: Lx.text(context, size: 13, color: Colors.white)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Lx.line2),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Baseline, × and the "Sign here" hint behind the ink
              Positioned(
                bottom: 40,
                left: 32,
                right: 32,
                child: Column(children: [
                  const Divider(height: 1, thickness: 1, color: Lx.line2),
                  const SizedBox(height: 6),
                  Text(l10n.settingsSignHere, style: Lx.text(context, size: 11, color: Lx.faint)),
                ]),
              ),
              Positioned(left: 34, bottom: 46, child: Text('×', style: Lx.text(context, size: 16, color: Lx.faint))),

              // Interactive signature gesture canvas
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (details) {
                  setState(() {
                    _currentStroke = [details.localPosition];
                  });
                },
                onPanUpdate: (details) {
                  setState(() {
                    _currentStroke.add(details.localPosition);
                  });
                },
                onPanEnd: (_) {
                  setState(() {
                    _strokes.add(List.from(_currentStroke));
                    _currentStroke.clear();
                  });
                },
                child: CustomPaint(
                  painter: _FullscreenSigPainter(
                    strokes: _strokes,
                    currentStroke: _currentStroke,
                  ),
                  size: Size.infinite,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FullscreenSigPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;

  _FullscreenSigPainter({required this.strokes, required this.currentStroke});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Lx.ink
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length < 2) {
        if (stroke.isNotEmpty) {
          canvas.drawCircle(stroke.first, 2.0, paint..style = PaintingStyle.fill);
          paint.style = PaintingStyle.stroke;
        }
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    if (currentStroke.length >= 2) {
      final path = Path()..moveTo(currentStroke.first.dx, currentStroke.first.dy);
      for (int i = 1; i < currentStroke.length; i++) {
        path.lineTo(currentStroke[i].dx, currentStroke[i].dy);
      }
      canvas.drawPath(path, paint);
    } else if (currentStroke.isNotEmpty) {
      canvas.drawCircle(currentStroke.first, 2.0, paint..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(covariant _FullscreenSigPainter oldDelegate) => true;
}

/// Renders [allStrokes] as a black-on-transparent PNG cropped to the ink.
Future<Uint8List?> renderSignaturePng(List<List<Offset>> allStrokes) async {
  if (allStrokes.isEmpty) return null;
  double minX = double.infinity;
  double minY = double.infinity;
  double maxX = double.negativeInfinity;
  double maxY = double.negativeInfinity;

  for (final stroke in allStrokes) {
    for (final point in stroke) {
      if (point.dx < minX) minX = point.dx;
      if (point.dy < minY) minY = point.dy;
      if (point.dx > maxX) maxX = point.dx;
      if (point.dy > maxY) maxY = point.dy;
    }
  }

  if (minX.isInfinite || maxX.isInfinite || minX > maxX || minY > maxY) return null;

  const double padding = 24.0;
  final double width = (maxX - minX) + padding * 2;
  final double height = (maxY - minY) + padding * 2;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  // Translate coordinates to center within cropped bounding box
  canvas.translate(-minX + padding, -minY + padding);

  final paint = Paint()
    ..color = Colors.black
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = 3.5
    ..style = PaintingStyle.stroke;

  for (final stroke in allStrokes) {
    if (stroke.length < 2) {
      if (stroke.isNotEmpty) {
        canvas.drawCircle(stroke.first, 2.0, paint..style = PaintingStyle.fill);
        paint.style = PaintingStyle.stroke;
      }
      continue;
    }
    final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
    for (int i = 1; i < stroke.length; i++) {
      path.lineTo(stroke[i].dx, stroke[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  final picture = recorder.endRecording();
  final img = await picture.toImage(
    width.toInt().clamp(40, 4000),
    height.toInt().clamp(30, 4000),
  );
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  return byteData?.buffer.asUint8List();
}
