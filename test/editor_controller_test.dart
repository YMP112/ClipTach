import 'dart:io';
import 'dart:typed_data';

import 'package:cliptach/core/services/export_preferences_service.dart';
import 'package:cliptach/core/services/project_archive_service.dart';
import 'package:cliptach/core/services/recent_projects_service.dart';
import 'package:cliptach/features/editor/application/editor_controller.dart';
import 'package:cliptach/features/editor/infrastructure/auto_assist_service.dart';
import 'package:cliptach/features/editor/infrastructure/file_io_service.dart';
import 'package:cliptach/features/editor/infrastructure/image_processing_service.dart';
import 'package:cliptach/core/models/export_options.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('closed polygon insert index follows the nearest edge', () {
    final controller = _controller();
    const polygon = <Offset>[
      Offset(0, 0),
      Offset(100, 0),
      Offset(100, 100),
      Offset(0, 100),
    ];

    expect(
      controller.debugNearestPolygonInsertIndex(
        polygon,
        const Offset(50, 4),
      ),
      1,
    );
    expect(
      controller.debugNearestPolygonInsertIndex(
        polygon,
        const Offset(98, 50),
      ),
      2,
    );
    expect(
      controller.debugNearestPolygonInsertIndex(
        polygon,
        const Offset(4, 50),
      ),
      4,
    );
  });

  test('file writer creates a non-empty export file', () async {
    final tempDir = await Directory.systemTemp.createTemp('cliptach_export_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    final path = '${tempDir.path}${Platform.pathSeparator}result.png';

    await FileIoService().writeBytes(path, Uint8List.fromList([1, 2, 3]));

    final file = File(path);
    expect(await file.exists(), isTrue);
    expect(await file.length(), 3);
  });

  test('export preferences remember the last export directory', () async {
    SharedPreferences.setMockInitialValues({});
    const options = ExportOptions(
      mode: ExportMode.objectOnly,
      marginPx: 0,
      exportDirectory: r'C:\Exports',
    );

    final service = ExportPreferencesService();
    await service.save(options);
    final loaded = await service.load();

    expect(loaded.mode, ExportMode.objectOnly);
    expect(loaded.marginPx, 0);
    expect(loaded.exportDirectory, r'C:\Exports');
  });
}

EditorController _controller() {
  return EditorController(
    imageProcessingService: ImageProcessingService(),
    autoAssistService: AutoAssistService(),
    fileIoService: FileIoService(),
    projectArchiveService: ProjectArchiveService(),
    recentProjectsService: RecentProjectsService(),
    exportPreferencesService: ExportPreferencesService(),
  );
}
