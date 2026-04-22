import 'package:shared_preferences/shared_preferences.dart';

import '../models/export_options.dart';

class ExportPreferencesService {
  static const _modeKey = 'export_mode_v1';
  static const _marginKey = 'export_margin_px_v1';
  static const _directoryKey = 'export_directory_v1';

  Future<ExportOptions> load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeRaw = prefs.getString(_modeKey);
    final margin = prefs.getInt(_marginKey) ?? 50;
    final directory = prefs.getString(_directoryKey);
    final mode = modeRaw == ExportMode.objectOnly.name
        ? ExportMode.objectOnly
        : ExportMode.withMargins;
    return ExportOptions(
      mode: mode,
      marginPx: margin < 0 ? 0 : margin,
      exportDirectory:
          directory == null || directory.isEmpty ? null : directory,
    );
  }

  Future<void> save(ExportOptions options) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, options.mode.name);
    await prefs.setInt(_marginKey, options.marginPx < 0 ? 0 : options.marginPx);
    final directory = options.exportDirectory;
    if (directory == null || directory.isEmpty) {
      await prefs.remove(_directoryKey);
    } else {
      await prefs.setString(_directoryKey, directory);
    }
  }
}
