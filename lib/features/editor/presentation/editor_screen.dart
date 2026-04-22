import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../app.dart';
import '../../../core/models/export_options.dart';
import '../../../core/services/recent_projects_service.dart';
import '../../../l10n/app_localizations.dart';
import '../infrastructure/file_io_service.dart';
import '../application/editor_controller.dart';
import '../domain/editor_state.dart';
import 'widgets/canvas_view.dart';
import 'widgets/top_toolbar.dart';

enum EditorLaunchActionType { none, openImage, loadProject, loadProjectPath }

class EditorLaunchAction {
  const EditorLaunchAction._({
    required this.type,
    this.projectPath,
  });

  const EditorLaunchAction.none() : this._(type: EditorLaunchActionType.none);

  const EditorLaunchAction.openImage()
      : this._(type: EditorLaunchActionType.openImage);

  const EditorLaunchAction.loadProject()
      : this._(type: EditorLaunchActionType.loadProject);

  const EditorLaunchAction.loadProjectPath(String path)
      : this._(type: EditorLaunchActionType.loadProjectPath, projectPath: path);

  final EditorLaunchActionType type;
  final String? projectPath;
}

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({
    super.key,
    this.launchAction = const EditorLaunchAction.none(),
  });

  final EditorLaunchAction launchAction;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  var _launchHandled = false;
  var _handMode = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_launchHandled) {
      return;
    }
    _launchHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = ref.read(editorControllerProvider.notifier);
      final fileIo = FileIoService();
      try {
        switch (widget.launchAction.type) {
          case EditorLaunchActionType.none:
            break;
          case EditorLaunchActionType.openImage:
            final opened = await fileIo.pickImage();
            if (opened != null) {
              await controller.openImageBytes(
                fileName: opened.fileName,
                bytes: opened.bytes,
              );
            }
            break;
          case EditorLaunchActionType.loadProject:
            await controller.loadProject();
            break;
          case EditorLaunchActionType.loadProjectPath:
            final path = widget.launchAction.projectPath;
            if (path != null && path.isNotEmpty) {
              await controller.loadProjectFromPath(path);
            }
            break;
        }
      } catch (e) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final state = ref.watch(editorControllerProvider);
    final controller = ref.read(editorControllerProvider.notifier);
    final loc = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TopToolbar(
              onOpenImage: () => _guardAsync(context, controller.openImage),
              onLoadProject: () => _guardAsync(context, controller.loadProject),
              onSaveProject: () => _guardAsync(context, controller.saveProject),
              onExportPng: () =>
                  _guardAsync(context, () => _exportFlow(controller)),
              onUndo: controller.undo,
              onRedo: controller.redo,
              onReset: controller.resetAll,
              onToggleLanguage: () {
                final current = ref.read(localeProvider);
                ref.read(localeProvider.notifier).state =
                    current.languageCode == 'he'
                        ? const Locale('en')
                        : const Locale('he');
              },
              openImageLabel: loc.t('openImage'),
              loadProjectLabel: loc.t('loadProject'),
              saveProjectLabel: loc.t('saveProject'),
              exportPngLabel: loc.t('exportPng'),
              undoLabel: loc.t('undo'),
              redoLabel: loc.t('redo'),
              resetLabel: loc.t('reset'),
              languageLabel: loc.t('language'),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCCD2DB)),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CanvasView(
                        state: state,
                        emptyHint: loc.t('hintNoImage'),
                        onStrokeStart: controller.startStroke,
                        onStrokeUpdate: controller.appendStrokePoint,
                        onObjectMove: controller.moveObjectBy,
                        onPolygonPointTap: controller.addPolygonPoint,
                        onPolygonPointMove: controller.updatePolygonPoint,
                        handMode: _handMode,
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Card(
                        child: IconButton(
                          tooltip: 'מצב יד',
                          onPressed: () {
                            setState(() {
                              _handMode = !_handMode;
                            });
                          },
                          icon: Icon(
                            _handMode
                                ? Icons.pan_tool_alt
                                : Icons.pan_tool_outlined,
                          ),
                        ),
                      ),
                    ),
                    if (state.phase == EditorPhase.object)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'מצב יד',
                                  onPressed: () {
                                    setState(() {
                                      _handMode = !_handMode;
                                    });
                                  },
                                  icon: Icon(
                                    _handMode
                                        ? Icons.pan_tool_alt
                                        : Icons.pan_tool_outlined,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: '${loc.t('rotate')} -5',
                                  onPressed: () => controller.nudgeRotation(-5),
                                  icon: const Icon(Icons.rotate_left),
                                ),
                                IconButton(
                                  tooltip: '${loc.t('rotate')} +5',
                                  onPressed: () => controller.nudgeRotation(5),
                                  icon: const Icon(Icons.rotate_right),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: '${loc.t('skew')} -2',
                                  onPressed: () => controller.nudgeSkew(-2),
                                  icon: const Icon(Icons.format_italic),
                                ),
                                IconButton(
                                  tooltip: '${loc.t('skew')} +2',
                                  onPressed: () => controller.nudgeSkew(2),
                                  icon: const Icon(Icons.title),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (state.phase == EditorPhase.mask)
              _MaskControls(state: state, controller: controller, loc: loc)
            else
              _ObjectControls(
                state: state,
                controller: controller,
                loc: loc,
                onBackToMask: () {
                  setState(() {
                    _handMode = false;
                  });
                  controller.setPhase(EditorPhase.mask);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _guardAsync(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _exportFlow(EditorController controller) async {
    final initial = await controller.loadExportOptions();
    if (!mounted) {
      return;
    }
    final loc = AppLocalizations.of(context);
    final result = await showDialog<_ExportDialogResult>(
      context: context,
      builder: (_) => _ExportDialog(
        initial: initial,
        suggestedFileName: controller.suggestedExportFileName(),
        onPickDirectory: controller.pickExportDirectory,
        labels: _ExportDialogLabels(
          title: 'ייצוא PNG',
          location: 'מיקום ייצוא',
          noPath: 'לא נבחר נתיב',
          choose: 'בחר...',
          mode: 'מצב ייצוא',
          withMargins: 'עם שוליים',
          objectOnly: 'אובייקט בלבד',
          objectOnlyHint: 'אובייקט בלבד (מלבן צמוד)',
          marginsPx: 'שוליים (px):',
          cancel: 'ביטול',
          export: loc.t('exportPng'),
          choosePathError: 'בחר נתיב ייצוא.',
          marginError: 'ערך שוליים חייב להיות מספר שלם לא שלילי.',
        ),
      ),
    );
    if (result == null) {
      return;
    }

    final exportPath = controller.exportPathForDirectory(result.directory);
    await controller.saveExportOptions(result.options);
    await controller.exportPng(
      path: exportPath,
      options: result.options,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('יוצא בהצלחה: ${result.path}')),
    );
  }
}

class _MaskControls extends StatelessWidget {
  const _MaskControls({
    required this.state,
    required this.controller,
    required this.loc,
  });

  final EditorState state;
  final EditorController controller;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SegmentedButton<MarkMode>(
                  segments: [
                    ButtonSegment(
                      value: MarkMode.keep,
                      label: Text(loc.t('keep')),
                      icon: const Icon(Icons.brush),
                    ),
                    ButtonSegment(
                      value: MarkMode.erase,
                      label: Text(loc.t('erase')),
                      icon: const Icon(Icons.auto_fix_off),
                    ),
                  ],
                  selected: {state.markMode},
                  onSelectionChanged: (value) =>
                      controller.setMarkMode(value.first),
                ),
                const SizedBox(width: 12),
                SegmentedButton<MaskTool>(
                  segments: [
                    ButtonSegment(
                      value: MaskTool.brush,
                      label: Text(loc.t('brushTool')),
                      icon: const Icon(Icons.brush_outlined),
                    ),
                    ButtonSegment(
                      value: MaskTool.polygonKeep,
                      label: Text(loc.t('polygonKeepTool')),
                      icon: const Icon(Icons.polyline_outlined),
                    ),
                  ],
                  selected: {state.maskTool},
                  onSelectionChanged: (value) =>
                      controller.setMaskTool(value.first),
                ),
                const SizedBox(width: 12),
                Checkbox(
                  value: state.showMask,
                  onChanged: (value) => controller.setShowMask(value ?? false),
                ),
                Text(loc.t('showMask')),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: state.hasImage
                      ? () async {
                          try {
                            await controller.autoAssist();
                          } catch (e) {
                            if (!context.mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        }
                      : null,
                  icon: const Icon(Icons.auto_fix_high),
                  label: Text(loc.t('autoAssist')),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: state.hasImage ? controller.extractObject : null,
                  icon: const Icon(Icons.cut),
                  label: Text(loc.t('extractObject')),
                ),
              ],
            ),
          ),
          Row(
            children: [
              if (state.maskTool == MaskTool.polygonKeep) ...[
                OutlinedButton.icon(
                  onPressed: state.polygonDraft.isNotEmpty
                      ? controller.clearPolygonDraft
                      : null,
                  icon: const Icon(Icons.clear),
                  label: Text(loc.t('clearPolygon')),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: state.polygonDraft.isNotEmpty
                      ? controller.removeLastPolygonPoint
                      : null,
                  icon: const Icon(Icons.undo),
                  label: const Text('מחק נקודה'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: state.polygonDraft.length >= 3
                      ? controller.applyPolygonKeep
                      : null,
                  icon: const Icon(Icons.check),
                  label: Text(loc.t('applyPolygon')),
                ),
                const SizedBox(width: 12),
              ],
              Text(
                  '${loc.t('brushSize')}: ${state.brushSize.toStringAsFixed(0)}'),
              Expanded(
                child: Slider(
                  value: state.brushSize,
                  min: 4,
                  max: 80,
                  onChanged: controller.setBrushSize,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ObjectControls extends StatelessWidget {
  const _ObjectControls({
    required this.state,
    required this.controller,
    required this.loc,
    required this.onBackToMask,
  });

  final EditorState state;
  final EditorController controller;
  final AppLocalizations loc;
  final VoidCallback onBackToMask;

  @override
  Widget build(BuildContext context) {
    final baseW = state.objectBaseWidth <= 0 ? 1.0 : state.objectBaseWidth;
    final baseH = state.objectBaseHeight <= 0 ? 1.0 : state.objectBaseHeight;
    final scale = ((baseW + state.transform.scalePx) / baseW)
        .clamp(0.05, 20.0)
        .toDouble();
    final currentW = baseW * scale;
    final currentH = baseH * scale;
    final scalePercent = scale * 100;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        children: [
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: onBackToMask,
                icon: const Icon(Icons.edit),
                label: Text(loc.t('editMask')),
              ),
              const SizedBox(width: 8),
              Text(loc.t('editObject')),
              const SizedBox(width: 16),
              Text(
                '${currentW.round()} x ${currentH.round()} px '
                '(${scalePercent.toStringAsFixed(0)}%)',
              ),
            ],
          ),
          _NumberValueRow(
            label: 'Width (px)',
            value: currentW,
            onSubmit: controller.setObjectWidthPx,
            onReset: controller.resetScalePx,
            resetLabel: 'Original',
          ),
          _NumberValueRow(
            label: 'Height (px)',
            value: currentH,
            onSubmit: controller.setObjectHeightPx,
            onReset: controller.resetScalePx,
            resetLabel: 'Original',
          ),
          _NumberValueRow(
            label: '${loc.t('scale')} (%)',
            value: scalePercent,
            onSubmit: (value) =>
                controller.setObjectWidthPx(baseW * (value / 100)),
            onReset: controller.resetScalePx,
            resetLabel: '100',
          ),
          _NumberValueRow(
            label: '${loc.t('rotate')} (°)',
            value: state.transform.rotationDeg,
            onSubmit: (value) => controller.updateTransform(rotationDeg: value),
            onReset: controller.resetRotation,
          ),
          _NumberValueRow(
            label: '${loc.t('skew')} (°)',
            value: state.transform.skewDeg,
            onSubmit: (value) => controller.updateTransform(skewDeg: value),
            onReset: controller.resetSkew,
          ),
        ],
      ),
    );
  }
}

class _NumberValueRow extends StatelessWidget {
  const _NumberValueRow({
    required this.label,
    required this.value,
    required this.onSubmit,
    required this.onReset,
    this.resetLabel = '0',
  });

  final String label;
  final double value;
  final ValueChanged<double> onSubmit;
  final VoidCallback onReset;
  final String resetLabel;

  @override
  Widget build(BuildContext context) {
    final valueText = value.toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label)),
          Expanded(
            child: TextFormField(
              key: ValueKey('$label-$valueText'),
              initialValue: valueText,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              onFieldSubmitted: (text) {
                final parsed = double.tryParse(text.trim());
                if (parsed != null) {
                  onSubmit(parsed);
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onReset,
            child: Text(resetLabel),
          ),
        ],
      ),
    );
  }
}

class _ExportDialogResult {
  _ExportDialogResult({
    required this.directory,
    required this.fileName,
    required this.options,
  });

  final String directory;
  final String fileName;
  final ExportOptions options;

  String get path => p.join(directory, fileName);
}

class _ExportDialog extends StatefulWidget {
  const _ExportDialog({
    required this.initial,
    required this.suggestedFileName,
    required this.onPickDirectory,
    required this.labels,
  });

  final ExportOptions initial;
  final String suggestedFileName;
  final Future<String?> Function({String? initialDirectory}) onPickDirectory;
  final _ExportDialogLabels labels;

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  late ExportMode _mode;
  late TextEditingController _marginController;
  String? _directory;
  String? _error;

  @override
  void initState() {
    super.initState();
    _mode = widget.initial.mode;
    _directory = widget.initial.exportDirectory;
    _marginController = TextEditingController(
      text: widget.initial.marginPx.toString(),
    );
  }

  @override
  void dispose() {
    _marginController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.labels.title),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.labels.location),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _directory ?? widget.labels.noPath,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () async {
                    final directory = await widget.onPickDirectory(
                      initialDirectory: _directory,
                    );
                    if (!mounted || directory == null) {
                      return;
                    }
                    setState(() {
                      _directory = directory;
                    });
                  },
                  child: Text(widget.labels.choose),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('File name: ${widget.suggestedFileName}'),
            const SizedBox(height: 12),
            Text(widget.labels.mode),
            const SizedBox(height: 6),
            SegmentedButton<ExportMode>(
              segments: [
                ButtonSegment(
                  value: ExportMode.withMargins,
                  label: Text(widget.labels.withMargins),
                ),
                ButtonSegment(
                  value: ExportMode.objectOnly,
                  label: Text(widget.labels.objectOnly),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (selection) {
                setState(() => _mode = selection.first);
              },
            ),
            if (_mode == ExportMode.withMargins)
              Row(
                children: [
                  Text(widget.labels.marginsPx),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _marginController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: false,
                        signed: false,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            if (_mode == ExportMode.objectOnly)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(widget.labels.objectOnlyHint),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.labels.cancel),
        ),
        FilledButton(
          onPressed: _onExport,
          child: Text(widget.labels.export),
        ),
      ],
    );
  }

  Future<void> _onExport() async {
    if (_directory == null || _directory!.isEmpty) {
      final picked = await widget.onPickDirectory(
        initialDirectory: widget.initial.exportDirectory,
      );
      if (!mounted || picked == null || picked.isEmpty) {
        setState(() => _error = widget.labels.choosePathError);
        return;
      }
      _directory = picked;
    }

    final margin = _mode == ExportMode.withMargins
        ? int.tryParse(_marginController.text.trim())
        : 0;
    if (_mode == ExportMode.withMargins && (margin == null || margin < 0)) {
      setState(() => _error = widget.labels.marginError);
      return;
    }

    Navigator.of(context).pop(
      _ExportDialogResult(
        directory: _directory!,
        fileName: widget.suggestedFileName,
        options: ExportOptions(
          mode: _mode,
          marginPx: margin ?? 0,
          exportDirectory: _directory,
        ),
      ),
    );
  }
}

class _ExportDialogLabels {
  const _ExportDialogLabels({
    required this.title,
    required this.location,
    required this.noPath,
    required this.choose,
    required this.mode,
    required this.withMargins,
    required this.objectOnly,
    required this.objectOnlyHint,
    required this.marginsPx,
    required this.cancel,
    required this.export,
    required this.choosePathError,
    required this.marginError,
  });

  final String title;
  final String location;
  final String noPath;
  final String choose;
  final String mode;
  final String withMargins;
  final String objectOnly;
  final String objectOnlyHint;
  final String marginsPx;
  final String cancel;
  final String export;
  final String choosePathError;
  final String marginError;
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _recentService = RecentProjectsService();
  List<String> _recent = const <String>[];

  @override
  void initState() {
    super.initState();
    _refreshRecents();
  }

  Future<void> _refreshRecents() async {
    final projects = await _recentService.readRecentProjects();
    if (!mounted) {
      return;
    }
    setState(() {
      _recent = projects;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(loc.t('appTitle'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.t('homeIntro'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () =>
                      _openEditor(const EditorLaunchAction.openImage()),
                  icon: const Icon(Icons.image_outlined),
                  label: Text(loc.t('openImage')),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      _openEditor(const EditorLaunchAction.loadProject()),
                  icon: const Icon(Icons.folder_open),
                  label: Text(loc.t('loadProject')),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(loc.t('recentProjects')),
            const SizedBox(height: 8),
            Expanded(
              child: _recent.isEmpty
                  ? Center(
                      child: Text(
                        loc.t('noRecentProjects'),
                        style: const TextStyle(color: Color(0xFF5D6875)),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _recent.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final path = _recent[index];
                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: Color(0xFFCCD2DB)),
                          ),
                          title: Text(p.basename(path)),
                          subtitle: Text(path),
                          leading: const Icon(Icons.history),
                          onTap: () => _openEditor(
                            EditorLaunchAction.loadProjectPath(path),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditor(EditorLaunchAction action) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditorScreen(launchAction: action),
      ),
    );
    await _refreshRecents();
  }
}
