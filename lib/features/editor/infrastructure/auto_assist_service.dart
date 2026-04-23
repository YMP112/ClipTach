import 'dart:math' as math;
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
  Future<AutoAssistSuggestion> suggest(
    ui.Image source, {
    List<BrushStroke> keepHints = const <BrushStroke>[],
    List<BrushStroke> eraseHints = const <BrushStroke>[],
  }) async {
    final raw = await source.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (raw == null) {
      return _fallback(source.width.toDouble(), source.height.toDouble());
    }

    final bytes = raw.buffer.asUint8List();
    final w = source.width;
    final h = source.height;
    const gridStep = 2;
    final gridW = ((w - 1) ~/ gridStep) + 1;
    final gridH = ((h - 1) ~/ gridStep) + 1;
    final gridSize = gridW * gridH;
    final foreground = List<bool>.filled(gridSize, false);

    final borderMean = _estimateBorderMeanColor(bytes, w, h);
    final borderStd = _estimateBorderDistanceStd(bytes, w, h, borderMean);
    final threshold = math.max(24.0, borderStd * 2.0 + 9.0);

    for (var gy = 0; gy < gridH; gy++) {
      final y = gy * gridStep;
      for (var gx = 0; gx < gridW; gx++) {
        final x = gx * gridStep;
        if (_nearBorder(x, y, w, h, 0.035)) {
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
          foreground[gy * gridW + gx] = true;
        }
      }
    }

    final labels = List<int>.filled(gridSize, -1);
    final components = _labelComponents(foreground, labels, gridW, gridH);
    if (components.isEmpty) {
      return _fallback(w.toDouble(), h.toDouble());
    }

    final keepHits = _collectHintHits(
      hints: keepHints,
      labels: labels,
      gridW: gridW,
      gridH: gridH,
      gridStep: gridStep,
      maxX: w - 1,
      maxY: h - 1,
    );
    final eraseHits = _collectHintHits(
      hints: eraseHints,
      labels: labels,
      gridW: gridW,
      gridH: gridH,
      gridStep: gridStep,
      maxX: w - 1,
      maxY: h - 1,
    );

    final minArea = math.max(10, (gridSize * 0.0015).round());
    final main = _selectMainComponent(
      components: components,
      keepHits: keepHits,
      eraseHits: eraseHits,
      gridCenterX: gridW / 2,
      gridCenterY: gridH / 2,
      minArea: minArea,
    );
    if (main == null) {
      return _fallback(w.toDouble(), h.toDouble());
    }

    final keepPoints = _buildKeepPoints(
      labels: labels,
      mainId: main.id,
      gridW: gridW,
      gridH: gridH,
      gridStep: gridStep,
      component: main,
    );
    if (keepPoints.length < 20) {
      return _fallback(w.toDouble(), h.toDouble());
    }

    final erasePoints = _buildBorderPoints(w.toDouble(), h.toDouble());
    final shortSide = math.min(w, h).toDouble();
    final keepBrush = (shortSide / 70).clamp(8.0, 18.0);
    final eraseBrush = (shortSide / 42).clamp(16.0, 28.0);

    return AutoAssistSuggestion(
      keepStrokes: <BrushStroke>[
        BrushStroke(points: keepPoints, brushSize: keepBrush),
      ],
      eraseStrokes: <BrushStroke>[
        BrushStroke(points: erasePoints, brushSize: eraseBrush),
      ],
    );
  }

  List<_Component> _labelComponents(
    List<bool> foreground,
    List<int> labels,
    int gridW,
    int gridH,
  ) {
    final components = <_Component>[];
    final stack = <int>[];

    for (var i = 0; i < foreground.length; i++) {
      if (!foreground[i] || labels[i] != -1) {
        continue;
      }

      final id = components.length;
      final component = _Component(id: id);
      labels[i] = id;
      stack.add(i);

      while (stack.isNotEmpty) {
        final current = stack.removeLast();
        final gx = current % gridW;
        final gy = current ~/ gridW;
        component.add(gx, gy);

        _tryVisit(gx - 1, gy, gridW, gridH, id, foreground, labels, stack);
        _tryVisit(gx + 1, gy, gridW, gridH, id, foreground, labels, stack);
        _tryVisit(gx, gy - 1, gridW, gridH, id, foreground, labels, stack);
        _tryVisit(gx, gy + 1, gridW, gridH, id, foreground, labels, stack);
      }
      components.add(component);
    }
    return components;
  }

  void _tryVisit(
    int gx,
    int gy,
    int gridW,
    int gridH,
    int id,
    List<bool> foreground,
    List<int> labels,
    List<int> stack,
  ) {
    if (gx < 0 || gy < 0 || gx >= gridW || gy >= gridH) {
      return;
    }
    final idx = gy * gridW + gx;
    if (!foreground[idx] || labels[idx] != -1) {
      return;
    }
    labels[idx] = id;
    stack.add(idx);
  }

  Map<int, int> _collectHintHits({
    required List<BrushStroke> hints,
    required List<int> labels,
    required int gridW,
    required int gridH,
    required int gridStep,
    required int maxX,
    required int maxY,
  }) {
    final hits = <int, int>{};
    for (final stroke in hints) {
      if (stroke.points.isEmpty) {
        continue;
      }
      final stride = math.max(1, stroke.points.length ~/ 30);
      for (var i = 0; i < stroke.points.length; i += stride) {
        final p = stroke.points[i];
        final x = p.dx.round().clamp(0, maxX);
        final y = p.dy.round().clamp(0, maxY);
        final gx = x ~/ gridStep;
        final gy = y ~/ gridStep;
        if (gx < 0 || gy < 0 || gx >= gridW || gy >= gridH) {
          continue;
        }
        final id = labels[gy * gridW + gx];
        if (id >= 0) {
          hits[id] = (hits[id] ?? 0) + 1;
        }
      }
    }
    return hits;
  }

  _Component? _selectMainComponent({
    required List<_Component> components,
    required Map<int, int> keepHits,
    required Map<int, int> eraseHits,
    required double gridCenterX,
    required double gridCenterY,
    required int minArea,
  }) {
    _Component? best;
    var bestScore = double.negativeInfinity;

    for (final c in components) {
      if (c.area < minArea) {
        continue;
      }
      final keep = keepHits[c.id] ?? 0;
      final erase = eraseHits[c.id] ?? 0;
      final dx = c.centerX - gridCenterX;
      final dy = c.centerY - gridCenterY;
      final centerDistance = math.sqrt(dx * dx + dy * dy);
      final density = c.area / math.max(1, c.boxArea);

      final score = c.area.toDouble() +
          keep * 3500.0 -
          erase * 5000.0 -
          centerDistance * 1.1 +
          density * 240.0;

      if (score > bestScore) {
        bestScore = score;
        best = c;
      }
    }

    return best;
  }

  List<Offset> _buildKeepPoints({
    required List<int> labels,
    required int mainId,
    required int gridW,
    required int gridH,
    required int gridStep,
    required _Component component,
  }) {
    final points = <Offset>[];
    const baseSpacing = 3;
    final spacing = component.area > 20000
        ? baseSpacing + 2
        : (component.area > 7000 ? baseSpacing + 1 : baseSpacing);

    for (var gy = component.minY; gy <= component.maxY; gy++) {
      for (var gx = component.minX; gx <= component.maxX; gx++) {
        if ((gx - component.minX) % spacing != 0 ||
            (gy - component.minY) % spacing != 0) {
          continue;
        }
        final idx = gy * gridW + gx;
        if (labels[idx] != mainId) {
          continue;
        }
        points.add(
            Offset((gx * gridStep).toDouble(), (gy * gridStep).toDouble()));
      }
    }

    if (points.isEmpty) {
      return points;
    }

    final padX = ((component.maxX - component.minX) * 0.04).round();
    final padY = ((component.maxY - component.minY) * 0.04).round();
    final minX = math.max(0, component.minX - padX);
    final minY = math.max(0, component.minY - padY);
    final maxX = math.min(gridW - 1, component.maxX + padX);
    final maxY = math.min(gridH - 1, component.maxY + padY);

    final expanded = <Offset>[];
    for (var gy = minY; gy <= maxY; gy += spacing) {
      for (var gx = minX; gx <= maxX; gx += spacing) {
        final idx = gy * gridW + gx;
        if (labels[idx] == mainId) {
          expanded.add(
              Offset((gx * gridStep).toDouble(), (gy * gridStep).toDouble()));
        }
      }
    }
    return expanded.isNotEmpty ? expanded : points;
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

  (double, double, double) _estimateBorderMeanColor(
    Uint8List bytes,
    int w,
    int h,
  ) {
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
    final variance =
        distances.map((d) => (d - avg) * (d - avg)).reduce((a, b) => a + b) /
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

class _Component {
  _Component({required this.id});

  final int id;
  int area = 0;
  int minX = 1 << 30;
  int minY = 1 << 30;
  int maxX = -1;
  int maxY = -1;
  int sumX = 0;
  int sumY = 0;

  void add(int x, int y) {
    area++;
    sumX += x;
    sumY += y;
    if (x < minX) minX = x;
    if (y < minY) minY = y;
    if (x > maxX) maxX = x;
    if (y > maxY) maxY = y;
  }

  double get centerX => area == 0 ? 0 : sumX / area;
  double get centerY => area == 0 ? 0 : sumY / area;
  int get boxArea => (maxX - minX + 1) * (maxY - minY + 1);
}
