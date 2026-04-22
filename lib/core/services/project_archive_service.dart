import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../models/project_model.dart';

class LoadedProject {
  LoadedProject({
    required this.model,
    required this.sourceBytes,
  });

  final ProjectModel model;
  final Uint8List sourceBytes;
}

class ProjectArchiveService {
  static const String extension = 'cliptach';
  static const String projectJsonPath = 'project.json';
  static const String sourceImagePath = 'source_image.bin';

  Uint8List encode({
    required ProjectModel model,
    required Uint8List sourceBytes,
  }) {
    final archive = Archive()
      ..addFile(
        ArchiveFile.string(projectJsonPath, jsonEncode(model.toJson())),
      )
      ..addFile(
        ArchiveFile(sourceImagePath, sourceBytes.length, sourceBytes),
      );

    return Uint8List.fromList(ZipEncoder().encode(archive) ?? <int>[]);
  }

  LoadedProject decode(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final jsonFile = archive.files.firstWhere(
      (f) => f.name == projectJsonPath,
      orElse: () => throw StateError('project.json not found'),
    );
    final sourceFile = archive.files.firstWhere(
      (f) => f.name == sourceImagePath,
      orElse: () => throw StateError('source image not found'),
    );

    final jsonString = _contentAsString(jsonFile.content);
    final model = ProjectModel.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
    final sourceBytes = _contentAsBytes(sourceFile.content);
    return LoadedProject(model: model, sourceBytes: sourceBytes);
  }

  String _contentAsString(Object content) {
    if (content is String) {
      return content;
    }
    return utf8.decode(_contentAsBytes(content));
  }

  Uint8List _contentAsBytes(Object content) {
    if (content is Uint8List) {
      return content;
    }
    if (content is List<int>) {
      return Uint8List.fromList(content);
    }
    if (content is List<dynamic>) {
      return Uint8List.fromList(List<int>.from(content));
    }
    throw StateError('Unsupported archive content type: ${content.runtimeType}');
  }
}
