import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../app.dart';
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
              onExportPng: () => _guardAsync(context, controller.exportPng),
              onUndo: controller.undo,
              onRedo: controller.redo,
              onReset: controller.resetAll,
              onToggleLanguage: () {
                final current = ref.read(localeProvider);
                ref.read(localeProvider.notifier).state =
                    current.languageCode == 'he' ? const Locale('en') : const Locale('he');
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
                child: CanvasView(
                  state: state,
                  emptyHint: loc.t('hintNoImage'),
                  onStrokeStart: controller.startStroke,
                  onStrokeUpdate: controller.appendStrokePoint,
                  onObjectMove: controller.moveObjectBy,
                  onPolygonPointTap: controller.addPolygonPoint,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (state.phase == EditorPhase.mask)
              _MaskControls(state: state, controller: controller, loc: loc)
            else
              _ObjectControls(state: state, controller: controller, loc: loc),
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
                onSelectionChanged: (value) => controller.setMarkMode(value.first),
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
                onSelectionChanged: (value) => controller.setMaskTool(value.first),
              ),
              const SizedBox(width: 12),
              Checkbox(
                value: state.showMask,
                onChanged: (value) => controller.setShowMask(value ?? false),
              ),
              Text(loc.t('showMask')),
              const Spacer(),
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
                FilledButton.tonalIcon(
                  onPressed:
                      state.polygonDraft.length >= 3 ? controller.applyPolygonKeep : null,
                  icon: const Icon(Icons.check),
                  label: Text(loc.t('applyPolygon')),
                ),
                const SizedBox(width: 12),
              ],
              Text('${loc.t('brushSize')}: ${state.brushSize.toStringAsFixed(0)}'),
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
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => controller.setPhase(EditorPhase.mask),
                icon: const Icon(Icons.edit),
                label: Text(loc.t('editMask')),
              ),
              const SizedBox(width: 8),
              Text(loc.t('editObject')),
            ],
          ),
          Row(
            children: [
              SizedBox(width: 72, child: Text(loc.t('scale'))),
              Expanded(
                child: Slider(
                  value: state.transform.scale,
                  min: 0.2,
                  max: 3,
                  onChanged: (value) => controller.updateTransform(scale: value),
                ),
              ),
            ],
          ),
          Row(
            children: [
              SizedBox(width: 72, child: Text(loc.t('rotate'))),
              Expanded(
                child: Slider(
                  value: state.transform.rotation,
                  min: -3.14,
                  max: 3.14,
                  onChanged: (value) => controller.updateTransform(rotation: value),
                ),
              ),
            ],
          ),
          Row(
            children: [
              SizedBox(width: 72, child: Text(loc.t('skew'))),
              Expanded(
                child: Slider(
                  value: state.transform.skew,
                  min: -0.8,
                  max: 0.8,
                  onChanged: (value) => controller.updateTransform(skew: value),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
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
                  onPressed: () => _openEditor(const EditorLaunchAction.openImage()),
                  icon: const Icon(Icons.image_outlined),
                  label: Text(loc.t('openImage')),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openEditor(const EditorLaunchAction.loadProject()),
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
