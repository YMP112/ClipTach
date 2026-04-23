import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/models/export_options.dart';
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
    final sourceRaw =
        await source.toByteData(format: ui.ImageByteFormat.rawRgba);
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

  Future<double> computeMaskCoverage(ui.Image mask) async {
    final raw = await mask.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (raw == null) {
      return 0;
    }
    final bytes = raw.buffer.asUint8List();
    if (bytes.isEmpty) {
      return 0;
    }
    var selected = 0;
    for (var i = 0; i < bytes.length; i += 4) {
      if (bytes[i] > 8) {
        selected++;
      }
    }
    final total = mask.width * mask.height;
    if (total <= 0) {
      return 0;
    }
    return selected / total;
  }

  Future<Uint8List> exportPng({
    required ui.Image extractedImage,
    required ObjectTransform transform,
    required double objectBaseWidth,
    required double objectPivotX,
    required double objectPivotY,
    required ExportOptions options,
  }) async {
    final workWidth = extractedImage.width * 3;
    final workHeight = extractedImage.height * 3;
    final workOffsetX = extractedImage.width.toDouble();
    final workOffsetY = extractedImage.height.toDouble();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final baseW = objectBaseWidth <= 0
        ? extractedImage.width.toDouble()
        : objectBaseWidth;
    final scale = ((baseW + transform.scalePx) / baseW).clamp(0.05, 20.0);
    final skew = math.tan(transform.skewDeg * math.pi / 180);

    final matrix = Matrix4.identity()
      ..translateByDouble(
        workOffsetX + objectPivotX + transform.translateX,
        workOffsetY + objectPivotY + transform.translateY,
        0,
        1,
      )
      ..rotateZ(transform.rotationDeg * math.pi / 180)
      ..setEntry(0, 1, skew)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(
          -objectPivotX - workOffsetX, -objectPivotY - workOffsetY, 0, 1);

    canvas.save();
    canvas.transform(matrix.storage);
    canvas.drawImage(
      extractedImage,
      Offset(workOffsetX, workOffsetY),
      Paint(),
    );
    canvas.restore();

    final rendered =
        await recorder.endRecording().toImage(workWidth, workHeight);
    final bbox = await _computeNonTransparentBounds(rendered);
    if (bbox == null) {
      throw StateError('No non-transparent object to export');
    }

    final margin = options.mode == ExportMode.withMargins
        ? options.marginPx.clamp(0, 10000)
        : 0;

    final cropRecorder = ui.PictureRecorder();
    final cropCanvas = Canvas(cropRecorder);
    final outputWidth = bbox.width + (margin * 2);
    final outputHeight = bbox.height + (margin * 2);

    final srcRect = Rect.fromLTWH(
      bbox.left.toDouble(),
      bbox.top.toDouble(),
      bbox.width.toDouble(),
      bbox.height.toDouble(),
    );
    final dstRect = Rect.fromLTWH(
      margin.toDouble(),
      margin.toDouble(),
      bbox.width.toDouble(),
      bbox.height.toDouble(),
    );

    cropCanvas.drawImageRect(rendered, srcRect, dstRect, Paint());

    final output = await cropRecorder.endRecording().toImage(
          outputWidth,
          outputHeight,
        );
    final pngBytes = await output.toByteData(format: ui.ImageByteFormat.png);
    if (pngBytes == null) {
      throw StateError('Failed to encode png');
    }
    return pngBytes.buffer.asUint8List();
  }

  Future<_AlphaBounds?> _computeNonTransparentBounds(ui.Image image) async {
    final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (raw == null) {
      return null;
    }
    final bytes = raw.buffer.asUint8List();
    final w = image.width;
    final h = image.height;
    var minX = w;
    var minY = h;
    var maxX = -1;
    var maxY = -1;

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final alpha = bytes[(y * w + x) * 4 + 3];
        if (alpha <= 8) {
          continue;
        }
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }

    if (maxX < minX || maxY < minY) {
      return null;
    }
    return _AlphaBounds(
      left: minX,
      top: minY,
      width: maxX - minX + 1,
      height: maxY - minY + 1,
    );
  }
}

class _AlphaBounds {
  _AlphaBounds({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final int left;
  final int top;
  final int width;
  final int height;
}
