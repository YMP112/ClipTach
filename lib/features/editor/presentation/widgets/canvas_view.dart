import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../domain/editor_state.dart';

class CanvasView extends StatefulWidget {
  const CanvasView({
    super.key,
    required this.state,
    required this.onStrokeStart,
    required this.onStrokeUpdate,
    required this.onObjectMove,
    required this.onPolygonPointTap,
    required this.emptyHint,
  });

  final EditorState state;
  final ValueChanged<Offset> onStrokeStart;
  final ValueChanged<Offset> onStrokeUpdate;
  final ValueChanged<Offset> onObjectMove;
  final ValueChanged<Offset> onPolygonPointTap;
  final String emptyHint;

  @override
  State<CanvasView> createState() => _CanvasViewState();
}

class _CanvasViewState extends State<CanvasView> {
  double _zoom = 1;
  Offset _pan = Offset.zero;
  bool _isRightMousePanning = false;
  Offset? _lastPanPointer;
  Offset? _lastScaleFocal;
  double _lastScale = 1;
  int _activePointers = 0;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          final delta = event.scrollDelta.dy > 0 ? 0.92 : 1.08;
          setState(() {
            _zoom = (_zoom * delta).clamp(0.2, 8);
          });
        }
      },
      onPointerDown: (event) {
        _activePointers++;
        if (event.buttons == kSecondaryMouseButton) {
          _isRightMousePanning = true;
          _lastPanPointer = event.localPosition;
        }
      },
      onPointerMove: (event) {
        if (_isRightMousePanning && _lastPanPointer != null) {
          setState(() {
            _pan += event.localDelta;
          });
          _lastPanPointer = event.localPosition;
        }
      },
      onPointerUp: (_) {
        _activePointers = (_activePointers - 1).clamp(0, 9999);
        _isRightMousePanning = false;
        _lastPanPointer = null;
      },
      onPointerCancel: (_) {
        _activePointers = (_activePointers - 1).clamp(0, 9999);
        _isRightMousePanning = false;
        _lastPanPointer = null;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: (details) {
          _lastScaleFocal = details.localFocalPoint;
          _lastScale = _zoom;
          if (widget.state.sourceImage == null ||
              _isRightMousePanning ||
              _activePointers > 1) {
            return;
          }
          if (widget.state.phase == EditorPhase.mask &&
              widget.state.maskTool == MaskTool.brush) {
            widget.onStrokeStart(_toImageSpace(details.localFocalPoint));
          }
        },
        onScaleUpdate: (details) {
          if (widget.state.sourceImage == null || _isRightMousePanning) {
            return;
          }

          final isMultiTouch = _activePointers > 1 || details.scale != 1.0;
          if (isMultiTouch) {
            setState(() {
              _zoom = (_lastScale * details.scale).clamp(0.2, 8);
              if (_lastScaleFocal != null) {
                _pan += details.localFocalPoint - _lastScaleFocal!;
                _lastScaleFocal = details.localFocalPoint;
              }
            });
            return;
          }

          if (widget.state.phase == EditorPhase.mask &&
              widget.state.maskTool == MaskTool.brush) {
            widget.onStrokeUpdate(_toImageSpace(details.localFocalPoint));
            return;
          }
          if (details.focalPointDelta != Offset.zero) {
            widget.onObjectMove(details.focalPointDelta / _zoom);
          }
        },
        onTapDown: (details) {
          if (widget.state.sourceImage == null ||
              widget.state.phase != EditorPhase.mask ||
              widget.state.maskTool != MaskTool.polygonKeep) {
            return;
          }
          widget.onPolygonPointTap(_toImageSpace(details.localPosition));
        },
        child: CustomPaint(
          painter: _CanvasPainter(
            state: widget.state,
            zoom: _zoom,
            pan: _pan,
            emptyHint: widget.emptyHint,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  Offset _toImageSpace(Offset local) {
    final source = widget.state.sourceImage;
    if (source == null) {
      return local;
    }
    final x = ((local.dx - _pan.dx) / _zoom)
        .clamp(0.0, source.width.toDouble())
        .toDouble();
    final y = ((local.dy - _pan.dy) / _zoom)
        .clamp(0.0, source.height.toDouble())
        .toDouble();
    return Offset(x, y);
  }
}

class _CanvasPainter extends CustomPainter {
  _CanvasPainter({
    required this.state,
    required this.zoom,
    required this.pan,
    required this.emptyHint,
  });

  final EditorState state;
  final double zoom;
  final Offset pan;
  final String emptyHint;

  @override
  void paint(Canvas canvas, Size size) {
    _drawCheckerboard(canvas, size);

    final source = state.sourceImage;
    if (source == null) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: emptyHint,
          style: const TextStyle(fontSize: 16, color: Color(0xFF5D6875)),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width - 40);
      textPainter.paint(
        canvas,
        Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2),
      );
      return;
    }

    canvas.save();
    canvas.translate(pan.dx, pan.dy);
    canvas.scale(zoom);

    if (state.phase == EditorPhase.mask) {
      canvas.drawImage(source, Offset.zero, Paint());
      if (state.showMask) {
        _drawStrokeList(canvas, state.keepStrokes, const Color(0x9900D878));
        _drawStrokeList(canvas, state.eraseStrokes, const Color(0x99FF3B30));
        if (state.polygonDraft.isNotEmpty) {
          _drawPolygonDraft(canvas, state.polygonDraft);
        }
      }
    } else {
      final extracted = state.extractedImage;
      if (extracted != null) {
        final w = extracted.width.toDouble();
        final h = extracted.height.toDouble();
        final m = Matrix4.identity()
          ..translateByDouble(
            w / 2 + state.transform.translateX,
            h / 2 + state.transform.translateY,
            0,
            1,
          )
          ..rotateZ(state.transform.rotation)
          ..setEntry(0, 1, state.transform.skew)
          ..scaleByDouble(state.transform.scale, state.transform.scale, 1, 1)
          ..translateByDouble(-w / 2, -h / 2, 0, 1);

        canvas.save();
        canvas.transform(m.storage);
        canvas.drawImage(extracted, Offset.zero, Paint());
        canvas.restore();
      }
    }

    canvas.restore();
  }

  void _drawPolygonDraft(Canvas canvas, List<Offset> points) {
    final border = Paint()
      ..color = const Color(0xFF007AFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..isAntiAlias = true;
    final fill = Paint()
      ..color = const Color(0x33007AFF)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final vertexPaint = Paint()
      ..color = const Color(0xFF007AFF)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    if (points.length >= 3) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      path.close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, border);
    } else if (points.length >= 2) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, border);
    }

    for (final p in points) {
      canvas.drawCircle(p, 3.5, vertexPaint);
    }
  }

  void _drawStrokeList(Canvas canvas, List<BrushStroke> list, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    for (final stroke in list) {
      paint.strokeWidth = stroke.brushSize;
      for (var i = 1; i < stroke.points.length; i++) {
        canvas.drawLine(stroke.points[i - 1], stroke.points[i], paint);
      }
      if (stroke.points.length == 1) {
        canvas.drawCircle(stroke.points.first, math.max(1, stroke.brushSize / 2), paint);
      }
    }
  }

  void _drawCheckerboard(Canvas canvas, Size size) {
    const tile = 24.0;
    final dark = Paint()..color = const Color(0xFFD3D7DE);
    final light = Paint()..color = const Color(0xFFE8ECF2);
    canvas.drawRect(Offset.zero & size, light);
    for (double y = 0; y < size.height; y += tile) {
      for (double x = 0; x < size.width; x += tile) {
        final even = ((x / tile).floor() + (y / tile).floor()) % 2 == 0;
        if (even) {
          canvas.drawRect(Rect.fromLTWH(x, y, tile, tile), dark);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CanvasPainter oldDelegate) {
    return oldDelegate.state != state ||
        oldDelegate.zoom != zoom ||
        oldDelegate.pan != pan ||
        oldDelegate.emptyHint != emptyHint;
  }
}
