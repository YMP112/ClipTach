import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../../../core/services/project_archive_service.dart';

class OpenedImage {
  OpenedImage({
    required this.fileName,
    required this.bytes,
  });

  final String fileName;
  final Uint8List bytes;
}

class FileIoService {
  Future<OpenedImage?> pickImage() async {
    final result = await FilePicker.platform
        .pickFiles(
          type: FileType.image,
          withData: false,
        )
        .timeout(
          const Duration(minutes: 2),
          onTimeout: () =>
              throw TimeoutException('Image picker timed out. Please retry.'),
        );
    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.first;
    final path = file.path;
    if (path != null && path.isNotEmpty) {
      final bytes = await File(path).readAsBytes();
      return OpenedImage(fileName: file.name, bytes: bytes);
    }

    final bytes = file.bytes;
    if (bytes != null) {
      return OpenedImage(fileName: file.name, bytes: bytes);
    }

    throw StateError('Unable to read selected image file bytes.');
  }

  Future<String?> pickProjectSavePath() {
    return FilePicker.platform.saveFile(
      dialogTitle: 'Save ClipTach Project',
      fileName: 'project.${ProjectArchiveService.extension}',
    );
  }

  Future<String?> pickPngSavePath({String? defaultFileName}) {
    return FilePicker.platform.saveFile(
      dialogTitle: 'ייצוא PNG',
      fileName: defaultFileName ?? 'result_clear.png',
    );
  }

  Future<String?> pickProjectOpenPath() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [ProjectArchiveService.extension],
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    return result.files.single.path;
  }

  Future<void> writeBytes(String path, Uint8List bytes) {
    return _writeBytesChecked(path, bytes);
  }

  Future<Uint8List> readBytes(String path) {
    return File(path).readAsBytes();
  }

  Future<void> _writeBytesChecked(String path, Uint8List bytes) async {
    final file = File(path);
    final dir = file.parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    await file.writeAsBytes(bytes, flush: true);
    final exists = await file.exists();
    if (!exists) {
      throw FileSystemException('Export failed: file was not created', path);
    }
    final length = await file.length();
    if (length == 0) {
      throw FileSystemException('Export failed: file is empty', path);
    }
  }
}
