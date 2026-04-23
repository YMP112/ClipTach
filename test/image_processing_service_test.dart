import 'dart:ui' as ui;

import 'package:cliptach/features/editor/domain/editor_state.dart';
import 'package:cliptach/features/editor/infrastructure/image_processing_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('computeMaskCoverage returns near 0 for empty selection', () async {
    final source = await _solidImage(
      width: 80,
      height: 80,
      color: Colors.black,
    );
    addTearDown(source.dispose);

    final service = ImageProcessingService();
    final mask = await service.buildMaskImage(
      source: source,
      keepStrokes: const <BrushStroke>[],
      eraseStrokes: const <BrushStroke>[],
    );
    addTearDown(mask.dispose);

    final coverage = await service.computeMaskCoverage(mask);
    expect(coverage, lessThan(0.001));
  });

  test('computeMaskCoverage returns near 1 when full image is selected',
      () async {
    final source = await _solidImage(
      width: 80,
      height: 80,
      color: Colors.black,
    );
    addTearDown(source.dispose);

    final service = ImageProcessingService();
    final mask = await service.buildMaskImage(
      source: source,
      keepStrokes: const <BrushStroke>[
        BrushStroke(points: <Offset>[Offset(40, 40)], brushSize: 200),
      ],
      eraseStrokes: const <BrushStroke>[],
    );
    addTearDown(mask.dispose);

    final coverage = await service.computeMaskCoverage(mask);
    expect(coverage, greaterThan(0.99));
  });
}

Future<ui.Image> _solidImage({
  required int width,
  required int height,
  required Color color,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = color,
  );
  final picture = recorder.endRecording();
  return picture.toImage(width, height);
}
