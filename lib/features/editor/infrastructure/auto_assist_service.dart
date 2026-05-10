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
    bool allowMultiObject = false,
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

    final borderSamples = _collectBorderSamples(bytes, w, h);
    final borderCenters = _clusterBorderColors(borderSamples, count: 3);
    final threshold = _computeForegroundThreshold(borderSamples, borderCenters);

    for (var gy = 0; gy < gridH; gy++) {
      final y = gy * gridStep;
      for (var gx = 0; gx < gridW; gx++) {
        final x = gx * gridStep;
        if (_nearBorder(x, y, w, h, 0.035)) {
          continue;
        }
        final idx = (y * w + x) * 4;
        final d = _minDistanceToCenters(
          bytes[idx].toDouble(),
          bytes[idx + 1].toDouble(),
          bytes[idx + 2].toDouble(),
          borderCenters,
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
    final selectedIds = _selectComponentIds(
      components: components,
      keepHits: keepHits,
      eraseHits: eraseHits,
      gridCenterX: gridW / 2,
      gridCenterY: gridH / 2,
      minArea: minArea,
      allowMultiObject: allowMultiObject,
    );
    if (selectedIds.isEmpty) {
      return _fallback(w.toDouble(), h.toDouble());
    }

    final keepPoints = _buildKeepPoints(
      labels: labels,
      gridW: gridW,
      gridH: gridH,
      gridStep: gridStep,
      selectedIds: selectedIds,
    );
    if (keepPoints.length < 20) {
      return _fallback(w.toDouble(), h.toDouble());
    }

    final shortSide = math.min(w, h).toDouble();
    // Keep auto-assist fill dense enough to avoid "holey" masks.
    final keepBrush = (shortSide / 18).clamp(20.0, 42.0);

    return AutoAssistSuggestion(
      keepStrokes: <BrushStroke>[
        BrushStroke(points: keepPoints, brushSize: keepBrush),
      ],
      eraseStrokes: const <BrushStroke>[],
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

  Set<int> _selectComponentIds({
    required List<_Component> components,
    required Map<int, int> keepHits,
    required Map<int, int> eraseHits,
    required double gridCenterX,
    required double gridCenterY,
    required int minArea,
    required bool allowMultiObject,
  }) {
    final selected = <int>{};

    if (allowMultiObject && keepHits.isNotEmpty) {
      for (final c in components) {
        if (c.area < minArea) {
          continue;
        }
        final keep = keepHits[c.id] ?? 0;
        final erase = eraseHits[c.id] ?? 0;
        if (keep > 0 && erase == 0) {
          selected.add(c.id);
        }
      }
      if (selected.isNotEmpty) {
        return selected;
      }
    }

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

    if (best == null) {
      return selected;
    }
    selected.add(best.id);
    return selected;
  }

  List<Offset> _buildKeepPoints({
    required List<int> labels,
    required int gridW,
    required int gridH,
    required int gridStep,
    required Set<int> selectedIds,
  }) {
    final points = <Offset>[];
    var totalArea = 0;
    for (var gy = 0; gy < gridH; gy++) {
      for (var gx = 0; gx < gridW; gx++) {
        if (selectedIds.contains(labels[gy * gridW + gx])) {
          totalArea++;
        }
      }
    }
    final spacing = totalArea > 50000 ? 2 : 1;

    for (var gy = 0; gy < gridH; gy++) {
      for (var gx = 0; gx < gridW; gx++) {
        final id = labels[gy * gridW + gx];
        if (!selectedIds.contains(id)) {
          continue;
        }
        if (spacing > 1 && ((gx + gy) % spacing != 0)) {
          continue;
        }
        points.add(Offset(
          (gx * gridStep).toDouble(),
          (gy * gridStep).toDouble(),
        ));
      }
    }

    return points;
  }

  AutoAssistSuggestion _fallback(double w, double h) {
    final keep = <Offset>[];
    for (double y = h * 0.2; y <= h * 0.8; y += 6) {
      for (double x = w * 0.2; x <= w * 0.8; x += 6) {
        keep.add(Offset(x, y));
      }
    }
    final brush = (math.min(w, h) / 10).clamp(18.0, 34.0);
    return AutoAssistSuggestion(
      keepStrokes: <BrushStroke>[BrushStroke(points: keep, brushSize: brush)],
      eraseStrokes: const <BrushStroke>[],
    );
  }

  List<(double, double, double)> _collectBorderSamples(
    Uint8List bytes,
    int w,
    int h, {
    int step = 4,
  }) {
    final samples = <(double, double, double)>[];
    const marginPercent = 0.1;
    final marginX = (w * marginPercent).floor();
    final marginY = (h * marginPercent).floor();

    for (var y = 0; y < h; y += step) {
      for (var x = 0; x < w; x += step) {
        final isBorder =
            x < marginX || x > w - marginX || y < marginY || y > h - marginY;
        if (!isBorder) {
          continue;
        }
        final idx = (y * w + x) * 4;
        samples.add((
          bytes[idx].toDouble(),
          bytes[idx + 1].toDouble(),
          bytes[idx + 2].toDouble(),
        ));
      }
    }
    if (samples.isEmpty) {
      return <(double, double, double)>[(127, 127, 127)];
    }
    return samples;
  }

  List<(double, double, double)> _clusterBorderColors(
    List<(double, double, double)> samples, {
    int count = 3,
  }) {
    if (samples.length <= count) {
      return samples;
    }
    final centers = <(double, double, double)>[];
    final step = math.max(1, samples.length ~/ count);
    for (var i = 0; i < count; i++) {
      centers.add(samples[math.min(samples.length - 1, i * step)]);
    }

    for (var iter = 0; iter < 6; iter++) {
      final sumR = List<double>.filled(count, 0);
      final sumG = List<double>.filled(count, 0);
      final sumB = List<double>.filled(count, 0);
      final hits = List<int>.filled(count, 0);

      for (final s in samples) {
        var bestIndex = 0;
        var bestDist = double.infinity;
        for (var i = 0; i < centers.length; i++) {
          final c = centers[i];
          final d = _colorDistance(s.$1, s.$2, s.$3, c.$1, c.$2, c.$3);
          if (d < bestDist) {
            bestDist = d;
            bestIndex = i;
          }
        }
        sumR[bestIndex] += s.$1;
        sumG[bestIndex] += s.$2;
        sumB[bestIndex] += s.$3;
        hits[bestIndex]++;
      }

      for (var i = 0; i < count; i++) {
        if (hits[i] == 0) {
          continue;
        }
        centers[i] = (
          sumR[i] / hits[i],
          sumG[i] / hits[i],
          sumB[i] / hits[i],
        );
      }
    }

    return centers;
  }

  double _computeForegroundThreshold(
    List<(double, double, double)> borderSamples,
    List<(double, double, double)> borderCenters,
  ) {
    final distances = <double>[];
    for (final s in borderSamples) {
      distances.add(_minDistanceToCenters(s.$1, s.$2, s.$3, borderCenters));
    }
    if (distances.isEmpty) {
      return 24;
    }
    final avg = distances.reduce((a, b) => a + b) / distances.length;
    final variance =
        distances.map((d) => (d - avg) * (d - avg)).reduce((a, b) => a + b) /
            distances.length;
    final std = math.sqrt(variance);
    return (avg + std * 2.1 + 5).clamp(18.0, 78.0);
  }

  double _minDistanceToCenters(
    double r,
    double g,
    double b,
    List<(double, double, double)> centers,
  ) {
    var best = double.infinity;
    for (final c in centers) {
      final d = _colorDistance(r, g, b, c.$1, c.$2, c.$3);
      if (d < best) {
        best = d;
      }
    }
    return best;
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
