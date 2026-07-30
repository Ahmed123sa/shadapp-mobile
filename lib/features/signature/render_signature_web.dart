// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';

Future<Uint8List> renderSignatureAsPng({
  required List<List<Offset>> strokes,
  required List<Offset> currentStroke,
  required Size size,
}) async {
  final w = size.width.toInt();
  final h = size.height.toInt();
  final canvas = html.CanvasElement(width: w, height: h);
  final ctx = canvas.context2D;

  ctx.fillStyle = 'white';
  ctx.fillRect(0, 0, w, h);

  ctx.fillStyle = 'rgba(128, 128, 128, 0.15)';
  for (double x = 0; x < size.width; x += 20) {
    for (double y = 0; y < size.height; y += 20) {
      ctx.beginPath();
      ctx.arc(x, y, 1, 0, 6.283185307179586);
      ctx.fill();
    }
  }

  ctx.strokeStyle = '#C8A461';
  ctx.lineWidth = 3;
  ctx.lineCap = 'round';

  void drawStroke(List<Offset> points) {
    if (points.length < 2) return;
    ctx.beginPath();
    ctx.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      ctx.lineTo(points[i].dx, points[i].dy);
    }
    ctx.stroke();
  }

  for (final stroke in strokes) {
    drawStroke(stroke);
  }
  drawStroke(currentStroke);

  final blob = await canvas.toBlob('image/png');


  final completer = Completer<Uint8List>();
  final reader = html.FileReader();
  reader.onLoad.listen((_) => completer.complete(reader.result as Uint8List));
  reader.onError.listen((_) => completer.completeError('فشل قراءة الملف'));
  reader.readAsArrayBuffer(blob);
  return completer.future;
}
