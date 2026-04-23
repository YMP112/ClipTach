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
    required this.onPolygonPointMove,
    required this.onPolygonPointDelete,
    required this.handMode,
    required this.emptyHint,
  });

  final EditorState state;
  final ValueChanged<Offset> onStrokeStart;
  final ValueChanged<Offset> onStrokeUpdate;
  final ValueChanged<Offset> onObjectMove;
  final ValueChanged<Offset> onPolygonPointTap;
  final void Function(int index, Offset point) onPolygonPointMove;
  final ValueChanged<int> onPolygonPointDelete;
  final bool handMode;
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
  Size _viewportSize = Size.zero;
  bool _needsAutoCenter = true;
  int? _dragPolygonIndex;

  @override
  void didUpdateWidget(covariant CanvasView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.sourceImage != widget.state.sourceImage) {
      _needsAutoCenter = true;
    }
    if (oldWidget.state.phase != widget.state.phase) {
      _needsAutoCenter = true;
    }
    if (_needsAutoCenter && _viewportSize != Size.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _autoCenterIfNeeded();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          final delta = event.scrollDelta.dy > 0 ? 0.92 : 1.08;
          final mouse = event.localPosition;
          final oldZoom = _zoom;
          final newZoom = (_zoom * delta).clamp(0.2, 8).toDouble();
          setState(() {
            _zoom = newZoom;
            if (oldZoom != 0) {
              final worldX = (mouse.dx - _pan.dx) / oldZoom;
              final worldY = (mouse.dy - _pan.dy) / oldZoom;
              _pan = Offset(
                mouse.dx - worldX * newZoom,
                mouse.dy - worldY * newZoom,
              );
            }
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
        _dragPolygonIndex = null;
      },
      onPointerCancel: (_) {
        _activePointers = (_activePointers - 1).clamp(0, 9999);
        _isRightMousePanning = false;
        _lastPanPointer = null;
        _dragPolygonIndex = null;
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
          if (widget.handMode) {
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
          if (widget.handMode) {
            if (details.focalPointDelta != Offset.zero) {
              setState(() {
                _pan += details.focalPointDelta;
              });
            }
            return;
          }

          if (widget.state.phase == EditorPhase.mask &&
              widget.state.maskTool == MaskTool.brush) {
            widget.onStrokeUpdate(_toImageSpace(details.localFocalPoint));
            return;
          }
          if (widget.state.phase == EditorPhase.mask &&
              widget.state.maskTool == MaskTool.polygonKeep &&
              _dragPolygonIndex != null) {
            widget.onPolygonPointMove(
              _dragPolygonIndex!,
              _toImageSpace(details.localFocalPoint),
            );
            return;
          }
          if (details.focalPointDelta != Offset.zero) {
            widget.onObjectMove(details.focalPointDelta / _zoom);
          }
        },
        onTapDown: (details) {
          if (widget.state.sourceImage == null ||
              widget.state.phase != EditorPhase.mask ||
              widget.handMode ||
              widget.state.maskTool != MaskTool.polygonKeep) {
            return;
          }
          _dragPolygonIndex = _hitPolygonVertex(details.localPosition);
          if (_dragPolygonIndex != null) {
            return;
          }
          widget.onPolygonPointTap(_toImageSpace(details.localPosition));
        },
        onDoubleTapDown: (details) {
          if (widget.state.sourceImage == null ||
              widget.state.phase != EditorPhase.mask ||
              widget.handMode ||
              widget.state.maskTool != MaskTool.polygonKeep) {
            return;
          }
          final index = _hitPolygonVertex(details.localPosition);
          if (index != null) {
            widget.onPolygonPointDelete(index);
          }
        },
        onSecondaryTapDown: (details) {
          if (widget.state.sourceImage == null ||
              widget.state.phase != EditorPhase.mask ||
              widget.handMode ||
              widget.state.maskTool != MaskTool.polygonKeep) {
            return;
          }
          final index = _hitPolygonVertex(details.localPosition);
          if (index != null) {
            widget.onPolygonPointDelete(index);
          }
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final nextSize = Size(constraints.maxWidth, constraints.maxHeight);
            if (nextSize != _viewportSize) {
              _viewportSize = nextSize;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) {
                  return;
                }
                _autoCenterIfNeeded();
              });
            }
            return CustomPaint(
              painter: _CanvasPainter(
                state: widget.state,
                zoom: _zoom,
                pan: _pan,
                emptyHint: widget.emptyHint,
              ),
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    );
  }

  void _autoCenterIfNeeded() {
    if (!_needsAutoCenter || _viewportSize == Size.zero) {
      return;
    }
    final source = widget.state.sourceImage;
    if (source == null) {
      return;
    }

    final targetX = widget.state.phase == EditorPhase.object
        ? widget.state.objectPivotX + widget.state.transform.translateX
        : source.width / 2;
    final targetY = widget.state.phase == EditorPhase.object
        ? widget.state.objectPivotY + widget.state.transform.translateY
        : source.height / 2;

    setState(() {
      _pan = Offset(
        _viewportSize.width / 2 - (targetX * _zoom),
        _viewportSize.height / 2 - (targetY * _zoom),
      );
      _needsAutoCenter = false;
    });
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

  int? _hitPolygonVertex(Offset local) {
    final list = widget.state.polygonDraft;
    if (list.isEmpty) {
      return null;
    }
    final imagePoint = _toImageSpace(local);
    const hitRadius = 10.0;
    final radiusInImageSpace = hitRadius / _zoom;
    final thresholdSq = radiusInImageSpace * radiusInImageSpace;
    for (var i = 0; i < list.length; i++) {
      final d = list[i] - imagePoint;
      if (d.dx * d.dx + d.dy * d.dy <= thresholdSq) {
        return i;
      }
    }
    return null;
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
        Offset((size.width - textPainter.width) / 2,
            (size.height - textPainter.height) / 2),
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
          _drawPolygonDraft(canvas, state.polygonDraft, zoom);
        }
      }
    } else {
      final extracted = state.extractedImage;
      if (extracted != null) {
        final baseW = state.objectBaseWidth <= 0
            ? extracted.width.toDouble()
            : state.objectBaseWidth;
        final scale =
            ((baseW + state.transform.scalePx) / baseW).clamp(0.05, 20.0);
        final skew = math.tan(state.transform.skewDeg * math.pi / 180);
        final m = Matrix4.identity()
          ..translateByDouble(
            state.objectPivotX + state.transform.translateX,
            state.objectPivotY + state.transform.translateY,
            0,
            1,
          )
          ..rotateZ(state.transform.rotationDeg * math.pi / 180)
          ..setEntry(0, 1, skew)
          ..scaleByDouble(scale, scale, 1, 1)
          ..translateByDouble(-state.objectPivotX, -state.objectPivotY, 0, 1);

        canvas.save();
        canvas.transform(m.storage);
        canvas.drawImage(extracted, Offset.zero, Paint());
        canvas.restore();
      }
    }

    canvas.restore();
  }

  void _drawPolygonDraft(Canvas canvas, List<Offset> points, double zoom) {
    final safeZoom = zoom <= 0 ? 1.0 : zoom;
    final vertexRadius = 6.0 / safeZoom;
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
      canvas.drawCircle(p, vertexRadius, vertexPaint);
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
        canvas.drawCircle(
            stroke.points.first, math.max(1, stroke.brushSize / 2), paint);
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
