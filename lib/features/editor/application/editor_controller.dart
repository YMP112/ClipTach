import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/project_model.dart';
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
  ),
);

class EditorController extends StateNotifier<EditorState> {
  EditorController({
    required ImageProcessingService imageProcessingService,
    required AutoAssistService autoAssistService,
    required FileIoService fileIoService,
    required ProjectArchiveService projectArchiveService,
    required RecentProjectsService recentProjectsService,
  })  : _imageProcessingService = imageProcessingService,
        _autoAssistService = autoAssistService,
        _fileIoService = fileIoService,
        _projectArchiveService = projectArchiveService,
        _recentProjectsService = recentProjectsService,
        super(const EditorState());

  final ImageProcessingService _imageProcessingService;
  final AutoAssistService _autoAssistService;
  final FileIoService _fileIoService;
  final ProjectArchiveService _projectArchiveService;
  final RecentProjectsService _recentProjectsService;

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
    state = state.copyWith(
      polygonDraft: <Offset>[...state.polygonDraft, point],
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
    final stroke = BrushStroke(points: <Offset>[point], brushSize: state.brushSize);
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

  Future<void> extractObject() async {
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
    state = state.copyWith(
      extractedImage: extracted,
      phase: EditorPhase.object,
      polygonDraft: const <Offset>[],
      showMask: false,
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
    state = state.copyWith(phase: phase);
  }

  void updateTransform({
    double? scale,
    double? rotation,
    double? skew,
    double? translateX,
    double? translateY,
  }) {
    _pushUndo();
    final next = state.transform.copyWith(
      scale: scale,
      rotation: rotation,
      skew: skew,
      translateX: translateX,
      translateY: translateY,
    );
    state = state.copyWith(
      transform: next,
      redoStack: const <EditorSnapshot>[],
    );
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
    final sourceImage = await _imageProcessingService.decodeImage(loaded.sourceBytes);
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
    );
    if (state.phase == EditorPhase.object) {
      await extractObject();
    }
    await _recentProjectsService.addRecentProject(path);
  }

  Future<void> exportPng() async {
    final extracted = state.extractedImage;
    if (extracted == null) {
      return;
    }
    final path = await _fileIoService.pickPngSavePath();
    if (path == null) {
      return;
    }
    final png = await _imageProcessingService.exportPng(
      extractedImage: extracted,
      transform: state.transform,
    );
    await _fileIoService.writeBytes(path, png);
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
}
