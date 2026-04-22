import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app.dart';
import '../../../l10n/app_localizations.dart';
import '../application/editor_controller.dart';
import '../domain/editor_state.dart';
import 'widgets/canvas_view.dart';
import 'widgets/top_toolbar.dart';

class EditorScreen extends ConsumerWidget {
  const EditorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          Row(
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
          Row(
            children: [
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
