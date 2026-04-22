import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/editor_state.dart';

class AutoAssistSuggestion {
  const AutoAssistSuggestion({
    required this.keepStrokes,
    required this.eraseStrokes,
  });

  final List<BrushStroke> keepStrokes;
  final List<BrushStroke> eraseStrokes;
}

class AutoAssistService {
  Future<AutoAssistSuggestion> suggest(ui.Image source) async {
    final raw = await source.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (raw == null) {
      return _fallback(source.width.toDouble(), source.height.toDouble());
    }

    final bytes = raw.buffer.asUint8List();
    final w = source.width;
    final h = source.height;

    final borderMean = _estimateBorderMeanColor(bytes, w, h);
    final borderStd = _estimateBorderDistanceStd(bytes, w, h, borderMean);
    final threshold = math.max(26.0, borderStd * 2.2 + 10);

    final keepPoints = <Offset>[];
    int minX = w;
    int minY = h;
    int maxX = 0;
    int maxY = 0;
    var fgCount = 0;

    for (var y = 2; y < h - 2; y += 2) {
      for (var x = 2; x < w - 2; x += 2) {
        if (_nearBorder(x, y, w, h, 0.04)) {
          continue;
        }
        final idx = (y * w + x) * 4;
        final d = _colorDistance(
          bytes[idx].toDouble(),
          bytes[idx + 1].toDouble(),
          bytes[idx + 2].toDouble(),
          borderMean.$1,
          borderMean.$2,
          borderMean.$3,
        );
        if (d > threshold) {
          fgCount++;
          if (x < minX) minX = x;
          if (y < minY) minY = y;
          if (x > maxX) maxX = x;
          if (y > maxY) maxY = y;
        }
      }
    }

    if (fgCount < 150 || maxX <= minX || maxY <= minY) {
      return _fallback(w.toDouble(), h.toDouble());
    }

    final padX = ((maxX - minX) * 0.06).round();
    final padY = ((maxY - minY) * 0.06).round();
    minX = (minX - padX).clamp(0, w - 1);
    minY = (minY - padY).clamp(0, h - 1);
    maxX = (maxX + padX).clamp(0, w - 1);
    maxY = (maxY + padY).clamp(0, h - 1);

    for (var y = minY; y <= maxY; y += 6) {
      for (var x = minX; x <= maxX; x += 6) {
        keepPoints.add(Offset(x.toDouble(), y.toDouble()));
      }
    }

    final erasePoints = _buildBorderPoints(w.toDouble(), h.toDouble());

    return AutoAssistSuggestion(
      keepStrokes: <BrushStroke>[
        BrushStroke(points: keepPoints, brushSize: 12),
      ],
      eraseStrokes: <BrushStroke>[
        BrushStroke(points: erasePoints, brushSize: 20),
      ],
    );
  }

  AutoAssistSuggestion _fallback(double w, double h) {
    final keep = <Offset>[];
    for (double y = h * 0.25; y <= h * 0.75; y += 10) {
      for (double x = w * 0.25; x <= w * 0.75; x += 10) {
        keep.add(Offset(x, y));
      }
    }
    return AutoAssistSuggestion(
      keepStrokes: <BrushStroke>[BrushStroke(points: keep, brushSize: 16)],
      eraseStrokes: <BrushStroke>[
        BrushStroke(points: _buildBorderPoints(w, h), brushSize: 20),
      ],
    );
  }

  List<Offset> _buildBorderPoints(double w, double h) {
    final erase = <Offset>[];
    const step = 16.0;
    for (double x = 0; x <= w; x += step) {
      erase.add(Offset(x, 0));
      erase.add(Offset(x, h));
    }
    for (double y = 0; y <= h; y += step) {
      erase.add(Offset(0, y));
      erase.add(Offset(w, y));
    }
    return erase;
  }

  (double, double, double) _estimateBorderMeanColor(Uint8List bytes, int w, int h) {
    double totalR = 0;
    double totalG = 0;
    double totalB = 0;
    var count = 0;
    const marginPercent = 0.1;
    final marginX = (w * marginPercent).floor();
    final marginY = (h * marginPercent).floor();

    for (var y = 0; y < h; y += 4) {
      for (var x = 0; x < w; x += 4) {
        final isBorder =
            x < marginX || x > w - marginX || y < marginY || y > h - marginY;
        if (!isBorder) {
          continue;
        }
        final idx = (y * w + x) * 4;
        totalR += bytes[idx];
        totalG += bytes[idx + 1];
        totalB += bytes[idx + 2];
        count++;
      }
    }
    if (count == 0) {
      return (127, 127, 127);
    }
    return (totalR / count, totalG / count, totalB / count);
  }

  double _estimateBorderDistanceStd(
    Uint8List bytes,
    int w,
    int h,
    (double, double, double) mean,
  ) {
    final distances = <double>[];
    const marginPercent = 0.1;
    final marginX = (w * marginPercent).floor();
    final marginY = (h * marginPercent).floor();

    for (var y = 0; y < h; y += 4) {
      for (var x = 0; x < w; x += 4) {
        final isBorder =
            x < marginX || x > w - marginX || y < marginY || y > h - marginY;
        if (!isBorder) {
          continue;
        }
        final idx = (y * w + x) * 4;
        distances.add(
          _colorDistance(
            bytes[idx].toDouble(),
            bytes[idx + 1].toDouble(),
            bytes[idx + 2].toDouble(),
            mean.$1,
            mean.$2,
            mean.$3,
          ),
        );
      }
    }
    if (distances.isEmpty) {
      return 8;
    }
    final avg = distances.reduce((a, b) => a + b) / distances.length;
    final variance = distances
            .map((d) => (d - avg) * (d - avg))
            .reduce((a, b) => a + b) /
        distances.length;
    return math.sqrt(variance);
  }

  bool _nearBorder(int x, int y, int w, int h, double ratio) {
    final marginX = w * ratio;
    final marginY = h * ratio;
    return x < marginX || x > w - marginX || y < marginY || y > h - marginY;
  }

  double _colorDistance(
    double r1,
    double g1,
    double b1,
    double r2,
    double g2,
    double b2,
  ) {
    final dr = r1 - r2;
    final dg = g1 - g2;
    final db = b1 - b2;
    return math.sqrt(dr * dr + dg * dg + db * db);
  }
}
