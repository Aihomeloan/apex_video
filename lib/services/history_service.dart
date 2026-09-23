import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/history_entry.dart';

class HistoryService {
  static const _key = 'apexvideo_history';

  Future<List<HistoryEntry>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    final entries = list
        .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  Future<void> _saveHistory(List<HistoryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(entries.map((e) => e.toJson()).toList());
    await prefs.setString(_key, raw);
  }

  Future<HistoryEntry> saveToHistory({
    required List<String> tempClipPaths,
    required String scriptPrompt,
  }) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final historyDir = Directory('${docsDir.path}/history');
    if (!await historyDir.exists()) {
      await historyDir.create(recursive: true);
    }
    final tempDir = await getTemporaryDirectory();

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final permanentPaths = <String>[];
    for (var i = 0; i < tempClipPaths.length; i++) {
      final src = File(tempClipPaths[i]);
      final destPath = '${historyDir.path}/${id}_$i.mp4';
      await src.copy(destPath);
      permanentPaths.add(destPath);

      // Only delete the source if it's one of our own temp files (a
      // Gemini-generated clip). NEVER delete a file the user picked
      // themselves — that could be their only copy of a real screen
      // recording or photo living outside the app entirely.
      if (src.path.startsWith(tempDir.path)) {
        try {
          await src.delete();
        } catch (_) {}
      }
    }

    final entry = HistoryEntry(
      id: id,
      clipPaths: permanentPaths,
      scriptPrompt: scriptPrompt,
      createdAt: DateTime.now(),
    );

    final entries = await loadHistory();
    entries.insert(0, entry);
    await _saveHistory(entries);
    return entry;
  }

  Future<void> deleteEntry(HistoryEntry entry) async {
    for (final path in entry.clipPaths) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    final entries = await loadHistory();
    entries.removeWhere((e) => e.id == entry.id);
    await _saveHistory(entries);
  }
}
