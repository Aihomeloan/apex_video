import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/history_entry.dart';
import '../state/project_state.dart';
import 'sequential_video_player.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProjectState>();

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: state.history.isEmpty
          ? const Center(
              child: Text('No saved videos yet',
                  style: TextStyle(color: Colors.grey)),
            )
          : ListView.builder(
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
                        IconButton(
                          icon: const Icon(Icons.ios_share, size: 20),
                          tooltip: 'Share',
                          onPressed: () => _share(entry),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          tooltip: 'Delete',
                          onPressed: () => _confirmDelete(context, state, entry),
                        ),
                      ],
                    ),
                    onTap: () => _openViewer(context, entry),
                  ),
                );
              },
            ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.month}/${d.day}/${d.year} ${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _share(HistoryEntry entry) async {
    final files = entry.clipPaths.map((p) => XFile(p)).toList();
    await Share.shareXFiles(files, text: entry.scriptPrompt);
  }

  void _openViewer(BuildContext context, HistoryEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
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
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.ios_share, size: 18),
                      label: const Text('Share'),
                      onPressed: () => _share(entry),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, ProjectState state, HistoryEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this video?'),
        content: const Text(
          'This removes it from your device permanently. This can\'t be undone.',
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
      await state.deleteHistoryEntry(entry);
    }
  }
}
