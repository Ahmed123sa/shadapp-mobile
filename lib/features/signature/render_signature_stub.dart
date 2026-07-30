import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

Future<Uint8List> renderSignatureAsPng({
  required List<List<Offset>> strokes,
  required List<Offset> currentStroke,
  required Size size,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  final bgPaint = Paint()..color = Colors.grey.withAlpha(40);
  for (double x = 0; x < size.width; x += 20) {
    for (double y = 0; y < size.height; y += 20) {
      canvas.drawCircle(Offset(x, y), 1, bgPaint);
    }
  }

  final paint = Paint()
    ..color = const Color(0xFFC8A461)
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  for (final stroke in strokes) {
    _drawStroke(canvas, stroke, paint);
  }
  _drawStroke(canvas, currentStroke, paint);

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) throw Exception('فشل تحويل الرسم');
  return byteData.buffer.asUint8List();
}

void _drawStroke(Canvas canvas, List<Offset> points, Paint paint) {
  for (int i = 0; i < points.length - 1; i++) {
    canvas.drawLine(points[i], points[i + 1], paint);
  }
}
