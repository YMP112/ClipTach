import 'dart:ui' as ui;

import 'package:cliptach/features/editor/domain/editor_state.dart';
import 'package:cliptach/features/editor/infrastructure/auto_assist_service.dart';
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
