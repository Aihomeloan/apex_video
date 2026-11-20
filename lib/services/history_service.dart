import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/history_entry.dart';

/// A video the user deleted. Its files stay on disk in Recently Deleted
/// until it's restored, deleted forever, or 30 days pass.
class TrashedEntry {
  final HistoryEntry entry;
  final DateTime deletedAt;

  const TrashedEntry({required this.entry, required this.deletedAt});

  static const retentionDays = 30;

  int get daysLeft {
    final left = retentionDays - DateTime.now().difference(deletedAt).inDays;
    return left < 0 ? 0 : left;
  }

  bool get isExpired =>
      DateTime.now().difference(deletedAt).inDays >= retentionDays;

  Map<String, dynamic> toJson() => {
        'entry': entry.toJson(),
        'deletedAt': deletedAt.toIso8601String(),
      };

  factory TrashedEntry.fromJson(Map<String, dynamic> json) => TrashedEntry(
        entry: HistoryEntry.fromJson(json['entry'] as Map<String, dynamic>),
        deletedAt: DateTime.parse(json['deletedAt'] as String),
      );
}

class HistoryService {
  static const _key = 'apexvideo_history';
  static const _trashKey = 'apexvideo_trash';

  // ---------------------------------------------------------------------------
  // Path repair
  //
  // iOS moves the app's storage folder whenever a new build is installed
  // (every App Store update, too). The files come along, but any FULL path
  // saved earlier points at the old folder. So when a saved path is gone,
  // look for the same file name in today's History folder and use that.
  // ---------------------------------------------------------------------------

  Future<Directory> _historyDir() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return Directory('${docsDir.path}/history');
  }

  String _baseName(String path) {
    final parts = path.split(RegExp(r'[\\/]'));
    return parts.isEmpty ? path : parts.last;
  }

  /// Returns the entry with every clip path pointing at where the file
  /// actually is now, and whether anything changed.
  Future<(HistoryEntry, bool)> _repair(HistoryEntry e, Directory dir) async {
    var changed = false;
    final fixed = <String>[];
    for (final p in e.clipPaths) {
      if (await File(p).exists()) {
        fixed.add(p);
        continue;
      }
      final candidate = '${dir.path}/${_baseName(p)}';
      if (await File(candidate).exists()) {
        fixed.add(candidate);
        changed = true;
      } else {
        fixed.add(p); // truly missing — leave as-is
      }
    }
    if (!changed) return (e, false);
    return (
      HistoryEntry(
        id: e.id,
        clipPaths: fixed,
        scriptPrompt: e.scriptPrompt,
        createdAt: e.createdAt,
      ),
      true,
    );
  }

  // ---------------------------------------------------------------------------
  // History
  // ---------------------------------------------------------------------------

  Future<List<HistoryEntry>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    final entries = list
        .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
        .toList();

    final dir = await _historyDir();
    var anyChanged = false;
    for (var i = 0; i < entries.length; i++) {
      final (fixed, changed) = await _repair(entries[i], dir);
      if (changed) {
        entries[i] = fixed;
        anyChanged = true;
      }
    }

    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (anyChanged) await _saveHistory(entries);
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
    final historyDir = await _historyDir();
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

      // Only delete the source if it's one of our own temp files. NEVER
      // delete a file the user picked themselves — that could be their
      // only copy of a real screen recording or photo.
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

  /// Permanently deletes a history entry and its files (skips the trash).
  Future<void> deleteEntry(HistoryEntry entry) async {
    await _deleteFiles(entry.clipPaths);
    final entries = await loadHistory();
    entries.removeWhere((e) => e.id == entry.id);
    await _saveHistory(entries);
  }

  /// DEBUG ONLY — adds fake entries with no real video file behind them,
  /// so the trash flow can be tested without spending credits. Only
  /// called from a button that exists in debug builds.
  Future<void> addDebugTestEntries({int count = 3}) async {
    final dir = await _historyDir();
    final entries = await loadHistory();
    final now = DateTime.now();
    for (var i = 0; i < count; i++) {
      final id = 'test_${now.millisecondsSinceEpoch}_$i';
      entries.add(HistoryEntry(
        id: id,
        clipPaths: ['${dir.path}/${id}_0.mp4'],
        scriptPrompt:
            '[TEST] Fake video ${i + 1} — for trash testing, will not play',
        createdAt: now.subtract(Duration(minutes: i)),
      ));
    }
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _saveHistory(entries);
  }

  // ---------------------------------------------------------------------------
  // Recently Deleted (trash)
  // ---------------------------------------------------------------------------

  Future<List<TrashedEntry>> loadTrash() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_trashKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      final items = list
          .map((e) => TrashedEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      final dir = await _historyDir();
      var anyChanged = false;
      for (var i = 0; i < items.length; i++) {
        final (fixed, changed) = await _repair(items[i].entry, dir);
        if (changed) {
          items[i] = TrashedEntry(entry: fixed, deletedAt: items[i].deletedAt);
          anyChanged = true;
        }
      }

      items.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
      if (anyChanged) await _saveTrash(items);
      return items;
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveTrash(List<TrashedEntry> items) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(items.map((t) => t.toJson()).toList());
    await prefs.setString(_trashKey, raw);
  }

  /// Moves a video out of History into Recently Deleted. Files are kept.
  Future<TrashedEntry> moveToTrash(HistoryEntry entry) async {
    final entries = await loadHistory();
    entries.removeWhere((e) => e.id == entry.id);
    await _saveHistory(entries);

    final item = TrashedEntry(entry: entry, deletedAt: DateTime.now());
    final trash = await loadTrash();
    trash.removeWhere((t) => t.entry.id == entry.id);
    trash.insert(0, item);
    await _saveTrash(trash);
    return item;
  }

  /// Puts a video back into History, at its original date.
  Future<void> restoreFromTrash(TrashedEntry item) async {
    final trash = await loadTrash();
    trash.removeWhere((t) => t.entry.id == item.entry.id);
    await _saveTrash(trash);

    final entries = await loadHistory();
    entries.removeWhere((e) => e.id == item.entry.id);
    entries.add(item.entry);
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _saveHistory(entries);
  }

  /// Permanently deletes one video from Recently Deleted.
  Future<void> deleteForever(TrashedEntry item) async {
    await _deleteFiles(item.entry.clipPaths);
    final trash = await loadTrash();
    trash.removeWhere((t) => t.entry.id == item.entry.id);
    await _saveTrash(trash);
  }

  /// Permanently deletes everything in Recently Deleted.
  Future<void> emptyTrash() async {
    final trash = await loadTrash();
    for (final t in trash) {
      await _deleteFiles(t.entry.clipPaths);
    }
    await _saveTrash([]);
  }

  /// Removes anything that has been in Recently Deleted for 30+ days.
  Future<void> purgeExpiredTrash() async {
    final trash = await loadTrash();
    final expired = trash.where((t) => t.isExpired).toList();
    if (expired.isEmpty) return;
    for (final t in expired) {
      await _deleteFiles(t.entry.clipPaths);
    }
    trash.removeWhere((t) => t.isExpired);
    await _saveTrash(trash);
  }

  Future<void> _deleteFiles(List<String> paths) async {
    final dir = await _historyDir();
    for (final path in paths) {
      for (final p in [path, '${dir.path}/${_baseName(path)}']) {
        try {
          final f = File(p);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
    }
  }
}
