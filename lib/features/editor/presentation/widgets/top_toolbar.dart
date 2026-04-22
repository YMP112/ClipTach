import 'package:flutter/material.dart';

class TopToolbar extends StatelessWidget {
  const TopToolbar({
    super.key,
    required this.onOpenImage,
    required this.onLoadProject,
    required this.onSaveProject,
    required this.onExportPng,
    required this.onUndo,
    required this.onRedo,
    required this.onReset,
    required this.onToggleLanguage,
    required this.openImageLabel,
    required this.loadProjectLabel,
    required this.saveProjectLabel,
    required this.exportPngLabel,
    required this.undoLabel,
    required this.redoLabel,
    required this.resetLabel,
    required this.languageLabel,
  });

  final VoidCallback onOpenImage;
  final VoidCallback onLoadProject;
  final VoidCallback onSaveProject;
  final VoidCallback onExportPng;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onReset;
  final VoidCallback onToggleLanguage;
  final String openImageLabel;
  final String loadProjectLabel;
  final String saveProjectLabel;
  final String exportPngLabel;
  final String undoLabel;
  final String redoLabel;
  final String resetLabel;
  final String languageLabel;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 8,
        children: [
          FilledButton.tonalIcon(
            onPressed: onOpenImage,
            icon: const Icon(Icons.image_outlined),
            label: Text(openImageLabel),
          ),
          OutlinedButton.icon(
            onPressed: onLoadProject,
            icon: const Icon(Icons.folder_open),
            label: Text(loadProjectLabel),
          ),
          OutlinedButton.icon(
            onPressed: onSaveProject,
            icon: const Icon(Icons.save_outlined),
            label: Text(saveProjectLabel),
          ),
          OutlinedButton.icon(
            onPressed: onExportPng,
            icon: const Icon(Icons.download_outlined),
            label: Text(exportPngLabel),
          ),
          OutlinedButton.icon(
            onPressed: onUndo,
            icon: const Icon(Icons.undo),
            label: Text(undoLabel),
          ),
          OutlinedButton.icon(
            onPressed: onRedo,
            icon: const Icon(Icons.redo),
            label: Text(redoLabel),
          ),
          OutlinedButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.restart_alt),
            label: Text(resetLabel),
          ),
          OutlinedButton.icon(
            onPressed: onToggleLanguage,
            icon: const Icon(Icons.language),
            label: Text(languageLabel),
          ),
        ],
      ),
    );
  }
}
