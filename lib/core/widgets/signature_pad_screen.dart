import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../theme.dart';

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
      final pngBytes = await _renderCroppedTransparentPng(allStrokes);
      if (pngBytes != null && mounted) {
        Navigator.of(context).pop(pngBytes);
      }
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<Uint8List?> _renderCroppedTransparentPng(List<List<Offset>> allStrokes) async {
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasStrokes = _strokes.isNotEmpty || _currentStroke.isNotEmpty;

    return Scaffold(
      backgroundColor: ShadColors.background,
      appBar: AppBar(
        backgroundColor: ShadColors.card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: ShadColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(null),
        ),
        title: Text(
          widget.title ?? l10n.signatureDrawSignature,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ShadColors.textPrimary),
        ),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: hasStrokes ? _clear : null,
            icon: Icon(
              Icons.refresh,
              size: 16,
              color: hasStrokes ? ShadColors.textSecondary : ShadColors.textDisabled,
            ),
            label: Text(
              l10n.signatureClear,
              style: TextStyle(
                color: hasStrokes ? ShadColors.textSecondary : ShadColors.textDisabled,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: ElevatedButton.icon(
              onPressed: (!hasStrokes || _saving) ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check, size: 16),
              label: Text(l10n.signatureSaveSignature, style: const TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: ShadColors.gold,
                foregroundColor: ShadColors.background,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                disabledBackgroundColor: ShadColors.cardBorder,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ShadColors.cardBorder, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Signature guideline and hint in background
              Positioned(
                bottom: 40,
                left: 32,
                right: 32,
                child: Column(
                  children: [
                    Container(
                      height: 1,
                      color: Colors.grey.withAlpha(80),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit, size: 12, color: Colors.grey.withAlpha(140)),
                        const SizedBox(width: 4),
                        Text(
                          l10n.settingsSignHere,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.withAlpha(140),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

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
      ..color = Colors.black
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
