import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../domain/editor_state.dart';

class ImageProcessingService {
  Future<ui.Image> decodeImage(Uint8List bytes) async {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, completer.complete);
    return completer.future;
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
      output[i] = sourceRaw.getUint8(i);
      output[i + 1] = sourceRaw.getUint8(i + 1);
      output[i + 2] = sourceRaw.getUint8(i + 2);
      output[i + 3] = maskRaw.getUint8(i);
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
  }) async {
    final w = extractedImage.width.toDouble();
    final h = extractedImage.height.toDouble();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final matrix = Matrix4.identity()
      ..translateByDouble(
        w / 2 + transform.translateX,
        h / 2 + transform.translateY,
        0,
        1,
      )
      ..rotateZ(transform.rotation)
      ..setEntry(0, 1, transform.skew)
      ..scaleByDouble(transform.scale, transform.scale, 1, 1)
      ..translateByDouble(-w / 2, -h / 2, 0, 1);

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
