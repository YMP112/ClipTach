import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../domain/editor_state.dart';

class ImageProcessingService {
  Future<ui.Image> decodeImage(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    } catch (_) {
      throw StateError(
        'Failed to decode image. Please use PNG/JPG/WebP and verify the file is valid.',
      );
    }
  }

  Future<ui.Image> buildMaskImage({
    required ui.Image source,
    required List<BrushStroke> keepStrokes,
    required List<BrushStroke> eraseStrokes,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(source.width.toDouble(), source.height.toDouble());

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.black,
    );

    final keepPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final erasePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (final stroke in keepStrokes) {
      for (final point in stroke.points) {
        canvas.drawCircle(point, stroke.brushSize / 2, keepPaint);
      }
    }

    for (final stroke in eraseStrokes) {
      for (final point in stroke.points) {
        canvas.drawCircle(point, stroke.brushSize / 2, erasePaint);
      }
    }

    return recorder.endRecording().toImage(source.width, source.height);
  }

  Future<ui.Image> extractObject({
    required ui.Image source,
    required ui.Image mask,
  }) async {
    final sourceRaw = await source.toByteData(format: ui.ImageByteFormat.rawRgba);
    final maskRaw = await mask.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (sourceRaw == null || maskRaw == null) {
      throw StateError('Failed to read image bytes');
    }

    final output = Uint8List(source.width * source.height * 4);
    for (var i = 0; i < output.length; i += 4) {
      final alpha = maskRaw.getUint8(i);
      if (alpha <= 8) {
        output[i] = 0;
        output[i + 1] = 0;
        output[i + 2] = 0;
        output[i + 3] = 0;
      } else {
        output[i] = sourceRaw.getUint8(i);
        output[i + 1] = sourceRaw.getUint8(i + 1);
        output[i + 2] = sourceRaw.getUint8(i + 2);
        output[i + 3] = alpha;
      }
    }

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      output,
      source.width,
      source.height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  Future<Uint8List> exportPng({
    required ui.Image extractedImage,
    required ObjectTransform transform,
    required double objectBaseWidth,
    required double objectPivotX,
    required double objectPivotY,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final baseW = objectBaseWidth <= 0 ? extractedImage.width.toDouble() : objectBaseWidth;
    final scale = ((baseW + transform.scalePx) / baseW).clamp(0.05, 20.0);
    final skew = math.tan(transform.skewDeg * math.pi / 180);

    final matrix = Matrix4.identity()
      ..translateByDouble(
        objectPivotX + transform.translateX,
        objectPivotY + transform.translateY,
        0,
        1,
      )
      ..rotateZ(transform.rotationDeg * math.pi / 180)
      ..setEntry(0, 1, skew)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-objectPivotX, -objectPivotY, 0, 1);

    canvas.save();
    canvas.transform(matrix.storage);
    canvas.drawImage(extractedImage, Offset.zero, Paint());
    canvas.restore();

    final image = await recorder.endRecording().toImage(
          extractedImage.width,
          extractedImage.height,
        );
    final pngBytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (pngBytes == null) {
      throw StateError('Failed to encode png');
    }
    return pngBytes.buffer.asUint8List();
  }
}
