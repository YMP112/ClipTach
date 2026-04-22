import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/models/export_options.dart';
import '../../../core/models/project_model.dart';
import '../../../core/services/export_preferences_service.dart';
import '../../../core/services/project_archive_service.dart';
import '../../../core/services/recent_projects_service.dart';
import '../domain/editor_state.dart';
import '../infrastructure/auto_assist_service.dart';
import '../infrastructure/file_io_service.dart';
import '../infrastructure/image_processing_service.dart';

final editorControllerProvider =
    StateNotifierProvider<EditorController, EditorState>(
  (ref) => EditorController(
    imageProcessingService: ImageProcessingService(),
    autoAssistService: AutoAssistService(),
    fileIoService: FileIoService(),
    projectArchiveService: ProjectArchiveService(),
    recentProjectsService: RecentProjectsService(),
    exportPreferencesService: ExportPreferencesService(),
  ),
);

class EditorController extends StateNotifier<EditorState> {
  EditorController({
    required ImageProcessingService imageProcessingService,
    required AutoAssistService autoAssistService,
    required FileIoService fileIoService,
    required ProjectArchiveService projectArchiveService,
    required RecentProjectsService recentProjectsService,
    required ExportPreferencesService exportPreferencesService,
  })  : _imageProcessingService = imageProcessingService,
        _autoAssistService = autoAssistService,
        _fileIoService = fileIoService,
        _projectArchiveService = projectArchiveService,
        _recentProjectsService = recentProjectsService,
        _exportPreferencesService = exportPreferencesService,
        super(const EditorState());

  final ImageProcessingService _imageProcessingService;
  final AutoAssistService _autoAssistService;
  final FileIoService _fileIoService;
  final ProjectArchiveService _projectArchiveService;
  final RecentProjectsService _recentProjectsService;
  final ExportPreferencesService _exportPreferencesService;

  Future<void> openImage() async {
    final opened = await _fileIoService.pickImage();
    if (opened == null) {
      return;
    }
    final image = await _imageProcessingService.decodeImage(opened.bytes);
    state = EditorState(
      sourceName: opened.fileName,
      sourceBytes: opened.bytes,
      sourceImage: image,
      objectPivotX: image.width / 2,
      objectPivotY: image.height / 2,
    );
  }

  Future<void> openImageBytes({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final image = await _imageProcessingService.decodeImage(bytes);
    state = EditorState(
      sourceName: fileName,
      sourceBytes: bytes,
      sourceImage: image,
      objectPivotX: image.width / 2,
      objectPivotY: image.height / 2,
    );
  }

  void setMarkMode(MarkMode mode) {
    state = state.copyWith(markMode: mode);
  }

  void setMaskTool(MaskTool tool) {
    state = state.copyWith(maskTool: tool);
  }

  void addPolygonPoint(Offset point) {
    if (!state.hasImage || state.phase != EditorPhase.mask) {
      return;
    }
    final next = <Offset>[...state.polygonDraft];
    if (next.length >= 3) {
      next.insert(_nearestPolygonInsertIndex(next, point), point);
    } else {
      next.add(point);
    }
    state = state.copyWith(
      polygonDraft: next,
      clearExtractedImage: true,
    );
  }

  void updatePolygonPoint(int index, Offset point) {
    if (!state.hasImage || state.phase != EditorPhase.mask) {
      return;
    }
    if (index < 0 || index >= state.polygonDraft.length) {
      return;
    }
    final next = <Offset>[...state.polygonDraft];
    next[index] = point;
    state = state.copyWith(polygonDraft: next, clearExtractedImage: true);
  }

  void removeLastPolygonPoint() {
    if (state.polygonDraft.isEmpty) {
      return;
    }
    state = state.copyWith(
      polygonDraft:
          state.polygonDraft.sublist(0, state.polygonDraft.length - 1),
      clearExtractedImage: true,
    );
  }

  void clearPolygonDraft() {
    state = state.copyWith(polygonDraft: const <Offset>[]);
  }

  void applyPolygonKeep() {
    if (!state.hasImage || state.phase != EditorPhase.mask) {
      return;
    }
    if (state.polygonDraft.length < 3) {
      return;
    }

    _pushUndo();
    final polygonStroke = BrushStroke(
      points: _rasterizePolygon(state.polygonDraft),
      brushSize: 4,
    );

    state = state.copyWith(
      keepStrokes: <BrushStroke>[...state.keepStrokes, polygonStroke],
      polygonDraft: const <Offset>[],
      redoStack: const <EditorSnapshot>[],
      clearExtractedImage: true,
    );
  }

  void setBrushSize(double size) {
    state = state.copyWith(brushSize: size);
  }

  void setShowMask(bool show) {
    state = state.copyWith(showMask: show);
  }

  void startStroke(Offset point) {
    if (!state.hasImage || state.phase != EditorPhase.mask) {
      return;
    }
    if (state.maskTool != MaskTool.brush) {
      return;
    }
    _pushUndo();
    final stroke =
        BrushStroke(points: <Offset>[point], brushSize: state.brushSize);
    if (state.markMode == MarkMode.keep) {
      state = state.copyWith(
        keepStrokes: <BrushStroke>[...state.keepStrokes, stroke],
        redoStack: const <EditorSnapshot>[],
        clearExtractedImage: true,
      );
    } else {
      state = state.copyWith(
        eraseStrokes: <BrushStroke>[...state.eraseStrokes, stroke],
        redoStack: const <EditorSnapshot>[],
        clearExtractedImage: true,
      );
    }
  }

  void appendStrokePoint(Offset point) {
    if (!state.hasImage || state.phase != EditorPhase.mask) {
      return;
    }
    if (state.maskTool != MaskTool.brush) {
      return;
    }
    if (state.markMode == MarkMode.keep) {
      if (state.keepStrokes.isEmpty) {
        return;
      }
      final list = <BrushStroke>[...state.keepStrokes];
      final last = list.removeLast();
      list.add(
        BrushStroke(
          brushSize: last.brushSize,
          points: <Offset>[...last.points, point],
        ),
      );
      state = state.copyWith(keepStrokes: list, clearExtractedImage: true);
    } else {
      if (state.eraseStrokes.isEmpty) {
        return;
      }
      final list = <BrushStroke>[...state.eraseStrokes];
      final last = list.removeLast();
      list.add(
        BrushStroke(
          brushSize: last.brushSize,
          points: <Offset>[...last.points, point],
        ),
      );
      state = state.copyWith(eraseStrokes: list, clearExtractedImage: true);
    }
  }

  Future<void> extractObject({bool preserveTransform = false}) async {
    final source = state.sourceImage;
    if (source == null) {
      return;
    }
    final mask = await _imageProcessingService.buildMaskImage(
      source: source,
      keepStrokes: state.keepStrokes,
      eraseStrokes: state.eraseStrokes,
    );
    final extracted = await _imageProcessingService.extractObject(
      source: source,
      mask: mask,
    );
    final metrics = await _computeObjectMetrics(extracted);
    state = state.copyWith(
      extractedImage: extracted,
      phase: EditorPhase.object,
      polygonDraft: const <Offset>[],
      showMask: false,
      transform: preserveTransform ? state.transform : const ObjectTransform(),
      objectBaseWidth: metrics.baseWidth,
      objectBaseHeight: metrics.baseHeight,
      objectPivotX: metrics.pivotX,
      objectPivotY: metrics.pivotY,
    );
  }

  Future<void> autoAssist() async {
    final source = state.sourceImage;
    if (source == null || state.phase != EditorPhase.mask) {
      return;
    }
    _pushUndo();
    final suggestion = await _autoAssistService.suggest(source);
    state = state.copyWith(
      keepStrokes: <BrushStroke>[
        ...state.keepStrokes,
        ...suggestion.keepStrokes,
      ],
      eraseStrokes: <BrushStroke>[
        ...state.eraseStrokes,
        ...suggestion.eraseStrokes,
      ],
      redoStack: const <EditorSnapshot>[],
      clearExtractedImage: true,
    );
  }

  void setPhase(EditorPhase phase) {
    state = state.copyWith(
      phase: phase,
      showMask: phase == EditorPhase.mask ? true : state.showMask,
    );
  }

  void updateTransform({
    double? scalePx,
    double? rotationDeg,
    double? skewDeg,
    double? translateX,
    double? translateY,
  }) {
    _pushUndo();
    final next = state.transform.copyWith(
      scalePx: scalePx,
      rotationDeg: rotationDeg,
      skewDeg: skewDeg,
      translateX: translateX,
      translateY: translateY,
    );
    state = state.copyWith(
      transform: next,
      redoStack: const <EditorSnapshot>[],
    );
  }

  void resetRotation() {
    updateTransform(rotationDeg: 0);
  }

  void resetSkew() {
    updateTransform(skewDeg: 0);
  }

  void resetScalePx() {
    updateTransform(scalePx: 0);
  }

  void nudgeRotation(double deltaDeg) {
    updateTransform(rotationDeg: state.transform.rotationDeg + deltaDeg);
  }

  void nudgeSkew(double deltaDeg) {
    updateTransform(skewDeg: state.transform.skewDeg + deltaDeg);
  }

  void moveObjectBy(Offset delta) {
    final t = state.transform;
    state = state.copyWith(
      transform: t.copyWith(
        translateX: t.translateX + delta.dx,
        translateY: t.translateY + delta.dy,
      ),
    );
  }

  Future<void> saveProject() async {
    if (!state.hasImage || state.sourceBytes == null) {
      return;
    }
    final path = await _fileIoService.pickProjectSavePath();
    if (path == null) {
      return;
    }
    final model = ProjectModel(
      version: 1,
      sourceName: state.sourceName ?? 'image.png',
      keepStrokes: state.keepStrokes,
      eraseStrokes: state.eraseStrokes,
      brushSize: state.brushSize,
      markMode: state.markMode,
      maskTool: state.maskTool,
      showMask: state.showMask,
      phase: state.phase,
      transform: state.transform,
    );
    final bytes = _projectArchiveService.encode(
      model: model,
      sourceBytes: state.sourceBytes!,
    );
    await _fileIoService.writeBytes(path, bytes);
    await _recentProjectsService.addRecentProject(path);
  }

  Future<void> loadProject() async {
    final path = await _fileIoService.pickProjectOpenPath();
    if (path == null) {
      return;
    }
    await loadProjectFromPath(path);
  }

  Future<void> loadProjectFromPath(String path) async {
    final bytes = await _fileIoService.readBytes(path);
    final loaded = _projectArchiveService.decode(bytes);
    final sourceImage =
        await _imageProcessingService.decodeImage(loaded.sourceBytes);
    state = EditorState(
      sourceName: loaded.model.sourceName,
      sourceBytes: loaded.sourceBytes,
      sourceImage: sourceImage,
      keepStrokes: loaded.model.keepStrokes,
      eraseStrokes: loaded.model.eraseStrokes,
      brushSize: loaded.model.brushSize,
      markMode: loaded.model.markMode,
      maskTool: loaded.model.maskTool,
      showMask: loaded.model.showMask,
      phase: loaded.model.phase,
      transform: loaded.model.transform,
      objectPivotX: sourceImage.width / 2,
      objectPivotY: sourceImage.height / 2,
    );
    if (state.phase == EditorPhase.object) {
      await extractObject(preserveTransform: true);
    }
    await _recentProjectsService.addRecentProject(path);
  }

  Future<void> exportPng({
    required String path,
    required ExportOptions options,
  }) async {
    final extracted = state.extractedImage;
    if (extracted == null) {
      throw StateError(
          'Nothing to export. Extract the object before exporting.');
    }
    final png = await _imageProcessingService.exportPng(
      extractedImage: extracted,
      transform: state.transform,
      objectBaseWidth: state.objectBaseWidth,
      objectPivotX: state.objectPivotX,
      objectPivotY: state.objectPivotY,
      options: options,
    );
    await _fileIoService.writeBytes(path, png);
  }

  String exportPathForDirectory(String directory) {
    return p.join(
        directory, _fileIoService.pngFileName(suggestedExportFileName()));
  }

  int _nearestPolygonInsertIndex(List<Offset> polygon, Offset point) {
    var bestIndex = polygon.length;
    var bestDistanceSq = double.infinity;

    for (var i = 0; i < polygon.length; i++) {
      final start = polygon[i];
      final end = polygon[(i + 1) % polygon.length];
      final distanceSq = _distanceToSegmentSquared(point, start, end);
      if (distanceSq < bestDistanceSq) {
        bestDistanceSq = distanceSq;
        bestIndex = i + 1;
      }
    }

    return bestIndex;
  }

  double _distanceToSegmentSquared(Offset point, Offset start, Offset end) {
    final segment = end - start;
    final lengthSq = segment.dx * segment.dx + segment.dy * segment.dy;
    if (lengthSq == 0) {
      final d = point - start;
      return d.dx * d.dx + d.dy * d.dy;
    }

    final rawT = ((point.dx - start.dx) * segment.dx +
            (point.dy - start.dy) * segment.dy) /
        lengthSq;
    final t = rawT.clamp(0.0, 1.0);
    final projection = Offset(
      start.dx + segment.dx * t,
      start.dy + segment.dy * t,
    );
    final d = point - projection;
    return d.dx * d.dx + d.dy * d.dy;
  }

  Future<ExportOptions> loadExportOptions() {
    return _exportPreferencesService.load();
  }

  Future<void> saveExportOptions(ExportOptions options) {
    return _exportPreferencesService.save(options);
  }

  Future<String?> pickExportDirectory({String? initialDirectory}) {
    return _fileIoService.pickExportDirectory(
      initialDirectory: initialDirectory,
    );
  }

  @visibleForTesting
  int debugNearestPolygonInsertIndex(List<Offset> polygon, Offset point) {
    return _nearestPolygonInsertIndex(polygon, point);
  }

  String suggestedExportFileName() {
    final sourceName = state.sourceName ?? 'image.png';
    final base = p.basenameWithoutExtension(sourceName);
    return '${base}_clear.png';
  }

  void resetAll() {
    state = const EditorState();
  }

  void undo() {
    if (state.undoStack.isEmpty) {
      return;
    }
    final current = _snapshotOf(state);
    final undo = <EditorSnapshot>[...state.undoStack];
    final previous = undo.removeLast();
    state = _applySnapshot(
      snapshot: previous,
      undoStack: undo,
      redoStack: <EditorSnapshot>[...state.redoStack, current],
    );
  }

  void redo() {
    if (state.redoStack.isEmpty) {
      return;
    }
    final current = _snapshotOf(state);
    final redo = <EditorSnapshot>[...state.redoStack];
    final next = redo.removeLast();
    state = _applySnapshot(
      snapshot: next,
      undoStack: <EditorSnapshot>[...state.undoStack, current],
      redoStack: redo,
    );
  }

  void _pushUndo() {
    final history = <EditorSnapshot>[...state.undoStack, _snapshotOf(state)];
    state = state.copyWith(undoStack: history);
  }

  EditorSnapshot _snapshotOf(EditorState s) {
    return EditorSnapshot(
      keepStrokes: s.keepStrokes,
      eraseStrokes: s.eraseStrokes,
      brushSize: s.brushSize,
      markMode: s.markMode,
      maskTool: s.maskTool,
      polygonDraft: s.polygonDraft,
      showMask: s.showMask,
      phase: s.phase,
      transform: s.transform,
    );
  }

  EditorState _applySnapshot({
    required EditorSnapshot snapshot,
    required List<EditorSnapshot> undoStack,
    required List<EditorSnapshot> redoStack,
  }) {
    return state.copyWith(
      keepStrokes: snapshot.keepStrokes,
      eraseStrokes: snapshot.eraseStrokes,
      brushSize: snapshot.brushSize,
      markMode: snapshot.markMode,
      maskTool: snapshot.maskTool,
      polygonDraft: snapshot.polygonDraft,
      showMask: snapshot.showMask,
      phase: snapshot.phase,
      transform: snapshot.transform,
      undoStack: undoStack,
      redoStack: redoStack,
      clearExtractedImage: true,
    );
  }

  Future<Uint8List?> debugExportCurrentPngBytes() async {
    final extracted = state.extractedImage;
    if (extracted == null) {
      return null;
    }
    return _imageProcessingService.exportPng(
      extractedImage: extracted,
      transform: state.transform,
      objectBaseWidth: state.objectBaseWidth,
      objectPivotX: state.objectPivotX,
      objectPivotY: state.objectPivotY,
      options: const ExportOptions(mode: ExportMode.objectOnly, marginPx: 0),
    );
  }

  List<Offset> _rasterizePolygon(List<Offset> polygon) {
    if (polygon.length < 3) {
      return const <Offset>[];
    }

    double minX = polygon.first.dx;
    double maxX = polygon.first.dx;
    double minY = polygon.first.dy;
    double maxY = polygon.first.dy;

    for (final p in polygon) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }

    final points = <Offset>[];
    for (double y = minY.floorToDouble(); y <= maxY.ceilToDouble(); y += 2) {
      for (double x = minX.floorToDouble(); x <= maxX.ceilToDouble(); x += 2) {
        if (_pointInPolygon(Offset(x, y), polygon)) {
          points.add(Offset(x, y));
        }
      }
    }
    return points;
  }

  bool _pointInPolygon(Offset p, List<Offset> polygon) {
    var inside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final pi = polygon[i];
      final pj = polygon[j];
      final intersects = ((pi.dy > p.dy) != (pj.dy > p.dy)) &&
          (p.dx <
              (pj.dx - pi.dx) * (p.dy - pi.dy) / ((pj.dy - pi.dy) + 0.000001) +
                  pi.dx);
      if (intersects) {
        inside = !inside;
      }
    }
    return inside;
  }

  Future<_ObjectMetrics> _computeObjectMetrics(ui.Image image) async {
    final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (raw == null) {
      return _ObjectMetrics(
        baseWidth: image.width.toDouble(),
        baseHeight: image.height.toDouble(),
        pivotX: image.width / 2,
        pivotY: image.height / 2,
      );
    }

    final bytes = raw.buffer.asUint8List();
    final w = image.width;
    final h = image.height;
    var minX = w;
    var minY = h;
    var maxX = 0;
    var maxY = 0;
    var count = 0;

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final a = bytes[(y * w + x) * 4 + 3];
        if (a <= 8) {
          continue;
        }
        count++;
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }

    if (count == 0 || maxX <= minX || maxY <= minY) {
      return _ObjectMetrics(
        baseWidth: image.width.toDouble(),
        baseHeight: image.height.toDouble(),
        pivotX: image.width / 2,
        pivotY: image.height / 2,
      );
    }

    final baseW = (maxX - minX + 1).toDouble();
    final baseH = (maxY - minY + 1).toDouble();
    final pivotX = minX + baseW / 2;
    final pivotY = minY + baseH / 2;

    return _ObjectMetrics(
      baseWidth: baseW,
      baseHeight: baseH,
      pivotX: pivotX,
      pivotY: pivotY,
    );
  }
}

class _ObjectMetrics {
  _ObjectMetrics({
    required this.baseWidth,
    required this.baseHeight,
    required this.pivotX,
    required this.pivotY,
  });

  final double baseWidth;
  final double baseHeight;
  final double pivotX;
  final double pivotY;
}
