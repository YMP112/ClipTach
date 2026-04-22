import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

enum MarkMode { keep, erase }

enum EditorPhase { mask, object }

enum MaskTool { brush, polygonKeep }

@immutable
class BrushStroke {
  const BrushStroke({
    required this.points,
    required this.brushSize,
  });

  final List<Offset> points;
  final double brushSize;

  Map<String, dynamic> toJson() {
    return {
      'brushSize': brushSize,
      'points': points
          .map((p) => {'x': p.dx, 'y': p.dy})
          .toList(growable: false),
    };
  }

  factory BrushStroke.fromJson(Map<String, dynamic> json) {
    final rawPoints = (json['points'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
    return BrushStroke(
      brushSize: (json['brushSize'] as num?)?.toDouble() ?? 16,
      points: rawPoints
          .map((p) => Offset(
                (p['x'] as num?)?.toDouble() ?? 0,
                (p['y'] as num?)?.toDouble() ?? 0,
              ))
          .toList(growable: false),
    );
  }
}

@immutable
class ObjectTransform {
  const ObjectTransform({
    this.translateX = 0,
    this.translateY = 0,
    this.scale = 1,
    this.rotation = 0,
    this.skew = 0,
  });

  final double translateX;
  final double translateY;
  final double scale;
  final double rotation;
  final double skew;

  ObjectTransform copyWith({
    double? translateX,
    double? translateY,
    double? scale,
    double? rotation,
    double? skew,
  }) {
    return ObjectTransform(
      translateX: translateX ?? this.translateX,
      translateY: translateY ?? this.translateY,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      skew: skew ?? this.skew,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'translateX': translateX,
      'translateY': translateY,
      'scale': scale,
      'rotation': rotation,
      'skew': skew,
    };
  }

  factory ObjectTransform.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const ObjectTransform();
    }
    return ObjectTransform(
      translateX: (json['translateX'] as num?)?.toDouble() ?? 0,
      translateY: (json['translateY'] as num?)?.toDouble() ?? 0,
      scale: (json['scale'] as num?)?.toDouble() ?? 1,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
      skew: (json['skew'] as num?)?.toDouble() ?? 0,
    );
  }
}

@immutable
class EditorSnapshot {
  const EditorSnapshot({
    required this.keepStrokes,
    required this.eraseStrokes,
    required this.brushSize,
    required this.markMode,
    required this.maskTool,
    required this.polygonDraft,
    required this.showMask,
    required this.phase,
    required this.transform,
  });

  final List<BrushStroke> keepStrokes;
  final List<BrushStroke> eraseStrokes;
  final double brushSize;
  final MarkMode markMode;
  final MaskTool maskTool;
  final List<Offset> polygonDraft;
  final bool showMask;
  final EditorPhase phase;
  final ObjectTransform transform;
}

@immutable
class EditorState {
  const EditorState({
    this.sourceName,
    this.sourceBytes,
    this.sourceImage,
    this.extractedImage,
    this.keepStrokes = const <BrushStroke>[],
    this.eraseStrokes = const <BrushStroke>[],
    this.brushSize = 18,
    this.markMode = MarkMode.keep,
    this.maskTool = MaskTool.brush,
    this.polygonDraft = const <Offset>[],
    this.showMask = true,
    this.phase = EditorPhase.mask,
    this.transform = const ObjectTransform(),
    this.undoStack = const <EditorSnapshot>[],
    this.redoStack = const <EditorSnapshot>[],
  });

  final String? sourceName;
  final Uint8List? sourceBytes;
  final ui.Image? sourceImage;
  final ui.Image? extractedImage;
  final List<BrushStroke> keepStrokes;
  final List<BrushStroke> eraseStrokes;
  final double brushSize;
  final MarkMode markMode;
  final MaskTool maskTool;
  final List<Offset> polygonDraft;
  final bool showMask;
  final EditorPhase phase;
  final ObjectTransform transform;
  final List<EditorSnapshot> undoStack;
  final List<EditorSnapshot> redoStack;

  bool get hasImage => sourceImage != null;

  EditorState copyWith({
    String? sourceName,
    Uint8List? sourceBytes,
    ui.Image? sourceImage,
    ui.Image? extractedImage,
    List<BrushStroke>? keepStrokes,
    List<BrushStroke>? eraseStrokes,
    double? brushSize,
    MarkMode? markMode,
    MaskTool? maskTool,
    List<Offset>? polygonDraft,
    bool? showMask,
    EditorPhase? phase,
    ObjectTransform? transform,
    List<EditorSnapshot>? undoStack,
    List<EditorSnapshot>? redoStack,
    bool clearExtractedImage = false,
  }) {
    return EditorState(
      sourceName: sourceName ?? this.sourceName,
      sourceBytes: sourceBytes ?? this.sourceBytes,
      sourceImage: sourceImage ?? this.sourceImage,
      extractedImage:
          clearExtractedImage ? null : (extractedImage ?? this.extractedImage),
      keepStrokes: keepStrokes ?? this.keepStrokes,
      eraseStrokes: eraseStrokes ?? this.eraseStrokes,
      brushSize: brushSize ?? this.brushSize,
      markMode: markMode ?? this.markMode,
      maskTool: maskTool ?? this.maskTool,
      polygonDraft: polygonDraft ?? this.polygonDraft,
      showMask: showMask ?? this.showMask,
      phase: phase ?? this.phase,
      transform: transform ?? this.transform,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
    );
  }
}
