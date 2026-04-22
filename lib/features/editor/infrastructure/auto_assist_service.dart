import 'dart:typed_data';
import 'dart:ui' as ui;

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

    final borderLuma = _estimateBorderLuma(bytes, w, h);
    final keepPoints = <Offset>[];

    const step = 8;
    const diffThreshold = 24.0;
    for (var y = step; y < h - step; y += step) {
      for (var x = step; x < w - step; x += step) {
        if (_nearBorder(x, y, w, h, 0.08)) {
          continue;
        }
        final idx = (y * w + x) * 4;
        final luma = _luma(bytes[idx], bytes[idx + 1], bytes[idx + 2]);
        if ((luma - borderLuma).abs() >= diffThreshold) {
          keepPoints.add(Offset(x.toDouble(), y.toDouble()));
        }
      }
    }

    final erasePoints = _buildBorderPoints(w.toDouble(), h.toDouble());
    if (keepPoints.isEmpty) {
      return _fallback(w.toDouble(), h.toDouble());
    }

    return AutoAssistSuggestion(
      keepStrokes: <BrushStroke>[
        BrushStroke(points: keepPoints, brushSize: 18),
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

  double _estimateBorderLuma(Uint8List bytes, int w, int h) {
    double total = 0;
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
        total += _luma(bytes[idx], bytes[idx + 1], bytes[idx + 2]);
        count++;
      }
    }
    if (count == 0) {
      return 127;
    }
    return total / count;
  }

  bool _nearBorder(int x, int y, int w, int h, double ratio) {
    final marginX = w * ratio;
    final marginY = h * ratio;
    return x < marginX || x > w - marginX || y < marginY || y > h - marginY;
  }

  double _luma(int r, int g, int b) => 0.2126 * r + 0.7152 * g + 0.0722 * b;
}
