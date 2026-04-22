enum ExportMode { withMargins, objectOnly }

class ExportOptions {
  const ExportOptions({
    required this.mode,
    required this.marginPx,
  });

  final ExportMode mode;
  final int marginPx;

  ExportOptions copyWith({
    ExportMode? mode,
    int? marginPx,
  }) {
    return ExportOptions(
      mode: mode ?? this.mode,
      marginPx: marginPx ?? this.marginPx,
    );
  }
}
