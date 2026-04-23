import 'dart:ui' as ui;

import 'package:cliptach/features/editor/domain/editor_state.dart';
import 'package:cliptach/features/editor/infrastructure/auto_assist_service.dart';
import 'package:cliptach/features/editor/infrastructure/image_processing_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('auto assist follows keep hint when multiple candidates exist',
      () async {
    final image = await _buildSyntheticScene();
    addTearDown(image.dispose);

    final service = AutoAssistService();
    final withoutHint = await service.suggest(image);
    final withHint = await service.suggest(
      image,
      keepHints: const <BrushStroke>[
        BrushStroke(points: <Offset>[Offset(190, 60)], brushSize: 12),
      ],
    );

    final baseCenter = _meanX(withoutHint.keepStrokes.first.points);
    final hintedCenter = _meanX(withHint.keepStrokes.first.points);

    expect(baseCenter, lessThan(130));
    expect(hintedCenter, greaterThan(150));
  });

  test('auto assist mask is dense on selected object area', () async {
    final image = await _buildSingleObjectScene();
    addTearDown(image.dispose);

    final assist = AutoAssistService();
    final suggestion = await assist.suggest(image);

    final processing = ImageProcessingService();
    final mask = await processing.buildMaskImage(
      source: image,
      keepStrokes: suggestion.keepStrokes,
      eraseStrokes: suggestion.eraseStrokes,
    );
    addTearDown(mask.dispose);

    final objectCoverage = await _coverageInRect(
      mask,
      const Rect.fromLTWH(20, 20, 88, 94),
    );
    expect(objectCoverage, greaterThan(0.90));
  });
}

double _meanX(List<Offset> points) {
  final sum = points.fold<double>(0, (acc, p) => acc + p.dx);
  return sum / points.length;
}

Future<ui.Image> _buildSyntheticScene() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  const width = 240.0;
  const height = 140.0;
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, width, height),
    Paint()..color = Colors.white,
  );

  canvas.drawRect(
    const Rect.fromLTWH(20, 20, 88, 94),
    Paint()..color = const Color(0xFFD83A3A),
  );
  canvas.drawRect(
    const Rect.fromLTWH(165, 35, 56, 56),
    Paint()..color = const Color(0xFF2C75D8),
  );

  final picture = recorder.endRecording();
  return picture.toImage(width.toInt(), height.toInt());
}

Future<ui.Image> _buildSingleObjectScene() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  const width = 240.0;
  const height = 140.0;
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, width, height),
    Paint()..color = Colors.white,
  );
  canvas.drawRect(
    const Rect.fromLTWH(20, 20, 88, 94),
    Paint()..color = const Color(0xFFD83A3A),
  );

  final picture = recorder.endRecording();
  return picture.toImage(width.toInt(), height.toInt());
}

Future<double> _coverageInRect(ui.Image image, Rect rect) async {
  final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (raw == null) {
    return 0;
  }
  final bytes = raw.buffer.asUint8List();
  var selected = 0;
  var total = 0;
  final left = rect.left.floor();
  final top = rect.top.floor();
  final right = rect.right.ceil();
  final bottom = rect.bottom.ceil();

  for (var y = top; y < bottom; y++) {
    for (var x = left; x < right; x++) {
      final idx = (y * image.width + x) * 4;
      if (bytes[idx] > 8) {
        selected++;
      }
      total++;
    }
  }

  if (total == 0) {
    return 0;
  }
  return selected / total;
}
