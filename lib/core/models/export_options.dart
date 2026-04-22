enum ExportMode { withMargins, objectOnly }

class ExportOptions {
  const ExportOptions({
    required this.mode,
    required this.marginPx,
    this.exportDirectory,
  });

  final ExportMode mode;
  final int marginPx;
  final String? exportDirectory;

  ExportOptions copyWith({
    ExportMode? mode,
    int? marginPx,
    String? exportDirectory,
  }) {
    return ExportOptions(
      mode: mode ?? this.mode,
      marginPx: marginPx ?? this.marginPx,
      exportDirectory: exportDirectory ?? this.exportDirectory,
    );
  }
}
