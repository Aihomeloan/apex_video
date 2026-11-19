import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/history_entry.dart';
import '../services/history_service.dart';
import '../services/photo_save_service.dart';
import '../state/project_state.dart';
import 'sequential_video_player.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProjectState>();
    final trashCount = state.trash.length;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('History'),
          actions: [
            // Debug builds only — never appears in release / App Store.
            if (kDebugMode)
              IconButton(
                icon: const Icon(Icons.bug_report_outlined),
                tooltip: 'Add 3 test videos (debug only)',
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await state.historyService.addDebugTestEntries();
                  await state.loadHistory();
                  messenger.hideCurrentSnackBar();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Added 3 test videos')),
                  );
                },
              ),
          ],
          bottom: TabBar(
            indicatorColor: Colors.amber,
            labelColor: Colors.amber,
            tabs: [
              const Tab(text: 'Videos'),
              Tab(
                text: trashCount == 0
                    ? 'Recently Deleted'
                    : 'Recently Deleted ($trashCount)',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildVideosTab(context, state),
            _buildTrashTab(context, state),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Videos tab
  // ---------------------------------------------------------------------------

  Widget _buildVideosTab(BuildContext context, ProjectState state) {
    if (state.history.isEmpty) {
      return const Center(
        child: Text('No saved videos yet',
            style: TextStyle(color: Colors.grey)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.history.length,
      itemBuilder: (context, index) {
        final entry = state.history[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: const CircleAvatar(
              backgroundColor: Color(0xFF1A1A1A),
              child: Icon(Icons.movie_outlined, color: Colors.amber),
            ),
            title: Text(
              entry.scriptPrompt.isEmpty
                  ? '(no script saved)'
                  : entry.scriptPrompt,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
            subtitle: Text(
              '${entry.clipPaths.length} clip(s) · '
              '${_formatDate(entry.createdAt)}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Builder(
                  builder: (btnContext) => IconButton(
                    icon: const Icon(Icons.ios_share, size: 20),
                    tooltip: 'Share',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _share(btnContext, entry),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.download_outlined, size: 20),
                  tooltip: 'Save to Photos',
                  visualDensity: VisualDensity.compact,
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final msg = await _saveClips(entry);
                    messenger.showSnackBar(
                      SnackBar(content: Text(msg)),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: 'Delete',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _moveToTrash(context, state, entry),
                ),
              ],
            ),
            onTap: () => _openViewer(context, entry),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Recently Deleted tab
  // ---------------------------------------------------------------------------

  Widget _buildTrashTab(BuildContext context, ProjectState state) {
    if (state.trash.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Nothing in Recently Deleted.\n'
            'Deleted videos stay here for 30 days.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Videos are deleted forever after 30 days.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () => _confirmEmptyTrash(context, state),
                child: const Text(
                  'Empty',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.trash.length,
            itemBuilder: (context, index) {
              final item = state.trash[index];
              final entry = item.entry;
              final days = item.daysLeft;
              final daysText = days == 0
                  ? 'Deleting soon'
                  : days == 1
                      ? '1 day left'
                      : '$days days left';
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF1A1A1A),
                    child: Icon(Icons.delete_outline, color: Colors.grey),
                  ),
                  title: Text(
                    entry.scriptPrompt.isEmpty
                        ? '(no script saved)'
                        : entry.scriptPrompt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    daysText,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.restore, size: 20),
                        tooltip: 'Restore',
                        visualDensity: VisualDensity.compact,
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await state.restoreFromTrash(item);
                          messenger.hideCurrentSnackBar();
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Video restored')),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_forever_outlined,
                            size: 20, color: Colors.redAccent),
                        tooltip: 'Delete forever',
                        visualDensity: VisualDensity.compact,
                        onPressed: () =>
                            _confirmDeleteForever(context, state, item),
                      ),
                    ],
                  ),
                  onTap: () => _openViewer(context, entry),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  String _formatDate(DateTime d) {
    return '${d.month}/${d.day}/${d.year} ${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  bool _filesExist(HistoryEntry entry) =>
      entry.clipPaths.isNotEmpty &&
      entry.clipPaths.every((p) => File(p).existsSync());

  /// [buttonContext] is the Share button's own context, so iPad knows
  /// where to anchor the share popover (without it, iPad can crash).
  Future<void> _share(BuildContext buttonContext, HistoryEntry entry) async {
    if (!_filesExist(entry)) {
      ScaffoldMessenger.of(buttonContext).showSnackBar(
        const SnackBar(content: Text('This video file is missing.')),
      );
      return;
    }
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin = (box != null && box.hasSize)
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    final files = entry.clipPaths.map((p) => XFile(p)).toList();
    await Share.shareXFiles(
      files,
      text: entry.scriptPrompt,
      sharePositionOrigin: origin,
    );
  }

  /// Saves every clip of this entry to Photos, in order.
  /// Returns a short message for the user.
  Future<String> _saveClips(HistoryEntry entry) async {
    if (entry.clipPaths.isEmpty) {
      return 'There are no clips to save.';
    }
    for (final p in entry.clipPaths) {
      final err = await PhotoSaveService.saveVideo(p);
      if (err != null) return err;
    }
    final n = entry.clipPaths.length;
    return n == 1 ? 'Saved to Photos.' : 'Saved $n clips to Photos.';
  }

  Future<void> _moveToTrash(
      BuildContext context, ProjectState state, HistoryEntry entry) async {
    final messenger = ScaffoldMessenger.of(context);
    final item = await state.deleteHistoryEntry(entry);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Moved to Recently Deleted'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => state.restoreFromTrash(item),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteForever(
      BuildContext context, ProjectState state, TrashedEntry item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete forever?'),
        content: const Text(
          'This permanently removes the video from your device. '
          'This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await state.deleteFromTrashForever(item);
    }
  }

  Future<void> _confirmEmptyTrash(
      BuildContext context, ProjectState state) async {
    final n = state.trash.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Empty Recently Deleted?'),
        content: Text(
          n == 1
              ? 'This permanently removes 1 video. This can\'t be undone.'
              : 'This permanently removes $n videos. This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Empty'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await state.emptyTrash();
    }
  }

  void _openViewer(BuildContext context, HistoryEntry entry) {
    if (!_filesExist(entry)) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This video file is missing, so it can\'t play.'),
        ),
      );
      return;
    }
    bool saving = false;
    String? note;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (innerContext, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SequentialVideoPlayer(
                    key: ValueKey(entry.id),
                    filePaths: entry.clipPaths,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Builder(
                          builder: (btnContext) => OutlinedButton.icon(
                            icon: const Icon(Icons.ios_share, size: 18),
                            label: const Text('Share'),
                            onPressed: () => _share(btnContext, entry),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.download_outlined, size: 18),
                          label: Text(saving ? 'Saving...' : 'Save'),
                          onPressed: saving
                              ? null
                              : () async {
                                  setSheetState(() {
                                    saving = true;
                                    note = null;
                                  });
                                  final msg = await _saveClips(entry);
                                  if (!sheetContext.mounted) return;
                                  setSheetState(() {
                                    saving = false;
                                    note = msg;
                                  });
                                },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: const Text('Close'),
                        ),
                      ),
                    ],
                  ),
                  if (note != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        note!,
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
