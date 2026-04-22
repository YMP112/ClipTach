import '../../features/editor/domain/editor_state.dart';

class ProjectModel {
  ProjectModel({
    required this.version,
    required this.sourceName,
    required this.keepStrokes,
    required this.eraseStrokes,
    required this.brushSize,
    required this.markMode,
    required this.maskTool,
    required this.showMask,
    required this.phase,
    required this.transform,
  });

  final int version;
  final String sourceName;
  final List<BrushStroke> keepStrokes;
  final List<BrushStroke> eraseStrokes;
  final double brushSize;
  final MarkMode markMode;
  final MaskTool maskTool;
  final bool showMask;
  final EditorPhase phase;
  final ObjectTransform transform;

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'sourceName': sourceName,
      'keepStrokes': keepStrokes.map((s) => s.toJson()).toList(growable: false),
      'eraseStrokes':
          eraseStrokes.map((s) => s.toJson()).toList(growable: false),
      'brushSize': brushSize,
      'markMode': markMode.name,
      'maskTool': maskTool.name,
      'showMask': showMask,
      'phase': phase.name,
      'transform': transform.toJson(),
    };
  }

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    final keepRaw = (json['keepStrokes'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
    final eraseRaw = (json['eraseStrokes'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
    return ProjectModel(
      version: (json['version'] as num?)?.toInt() ?? 1,
      sourceName: json['sourceName'] as String? ?? 'image.png',
      keepStrokes:
          keepRaw.map(BrushStroke.fromJson).toList(growable: false),
      eraseStrokes:
          eraseRaw.map(BrushStroke.fromJson).toList(growable: false),
      brushSize: (json['brushSize'] as num?)?.toDouble() ?? 18,
      markMode: MarkMode.values.firstWhere(
        (e) => e.name == json['markMode'],
        orElse: () => MarkMode.keep,
      ),
      maskTool: MaskTool.values.firstWhere(
        (e) => e.name == json['maskTool'],
        orElse: () => MaskTool.brush,
      ),
      showMask: json['showMask'] as bool? ?? true,
      phase: EditorPhase.values.firstWhere(
        (e) => e.name == json['phase'],
        orElse: () => EditorPhase.mask,
      ),
      transform: ObjectTransform.fromJson(
        json['transform'] as Map<String, dynamic>?,
      ),
    );
  }
}
