import 'package:shared_preferences/shared_preferences.dart';

class RecentProjectsService {
  static const _key = 'recent_projects_v1';
  static const _maxItems = 10;

  Future<List<String>> readRecentProjects() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? <String>[];
  }

  Future<void> addRecentProject(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_key) ?? <String>[];
    final updated = <String>[path, ...current.where((p) => p != path)];
    await prefs.setStringList(_key, updated.take(_maxItems).toList(growable: false));
  }
}
