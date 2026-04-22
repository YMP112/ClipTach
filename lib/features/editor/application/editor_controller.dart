import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/project_model.dart';
import '../../../core/services/project_archive_service.dart';
import '../domain/editor_state.dart';
import '../infrastructure/file_io_service.dart';
import '../infrastructure/image_processing_service.dart';

final editorControllerProvider =
    StateNotifierProvider<EditorController, EditorState>(
  (ref) => EditorController(
    imageProcessingService: ImageProcessingService(),
    fileIoService: FileIoService(),
    projectArchiveService: ProjectArchiveService(),
  ),
);

class EditorController extends StateNotifier<EditorState> {
  EditorController({
    required ImageProcessingService imageProcessingService,
    required FileIoService fileIoService,
    required ProjectArchiveService projectArchiveService,
  })  : _imageProcessingService = imageProcessingService,
        _fileIoService = fileIoService,
        _projectArchiveService = projectArchiveService,
        super(const EditorState());

  final ImageProcessingService _imageProcessingService;
  final FileIoService _fileIoService;
  final ProjectArchiveService _projectArchiveService;

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

  void setMarkMode(MarkMode mode) {
    state = state.copyWith(markMode: mode);
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
      showMask: false,
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
      showMask: state.showMask,
      phase: state.phase,
      transform: state.transform,
    );
    final bytes = _projectArchiveService.encode(
      model: model,
      sourceBytes: state.sourceBytes!,
    );
    await _fileIoService.writeBytes(path, bytes);
  }

  Future<void> loadProject() async {
    final path = await _fileIoService.pickProjectOpenPath();
    if (path == null) {
      return;
    }
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
      showMask: loaded.model.showMask,
      phase: loaded.model.phase,
      transform: loaded.model.transform,
    );
    if (state.phase == EditorPhase.object) {
      await extractObject();
    }
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
}
