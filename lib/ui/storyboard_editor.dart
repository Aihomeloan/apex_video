import 'package:flutter/material.dart';
import '../models/storyboard_item.dart';

class StoryboardEditor extends StatelessWidget {
  final List<StoryboardItem> items;
  final ValueChanged<int> onRemove;
  final void Function(int index, int seconds) onDurationChanged;
  final bool enabled;

  const StoryboardEditor({
    super.key,
    required this.items,
    required this.onRemove,
    required this.onDurationChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text(
        'No items yet — tap + to add up to 4 photos or clips.',
        style: TextStyle(fontSize: 11, color: Colors.grey),
      );
    }

    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          final isImage = item.type == StoryboardItemType.image;
          return GestureDetector(
            onTap: enabled
                ? () => _openDetailSheet(context, index, item)
                : null,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: isImage
                          ? Opacity(
                              opacity: enabled ? 1.0 : 0.5,
                              child: Image.file(item.file, fit: BoxFit.cover),
                            )
                          : Container(
                              color: Colors.amber.withOpacity(0.12),
                              child: Icon(Icons.videocam,
                                  color: Colors.amber
                                      .withOpacity(enabled ? 1 : 0.5)),
                            ),
                    ),
                  ),
                  Positioned(
                    left: 2,
                    top: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${index + 1}',
                        style:
                            const TextStyle(fontSize: 9, color: Colors.white),
                      ),
                    ),
                  ),
                  if (isImage)
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 3, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${item.durationSeconds}s',
                          style: const TextStyle(
                              fontSize: 9, color: Colors.amber),
                        ),
                      ),
                    ),
                  if (!enabled)
                    const Positioned(
                      right: 2,
                      top: 2,
                      child: Icon(Icons.lock, size: 12, color: Colors.grey),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openDetailSheet(
      BuildContext context, int index, StoryboardItem item) {
    final isImage = item.type == StoryboardItemType.image;
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: isImage
                          ? Image.file(item.file, fit: BoxFit.cover)
                          : Container(
                              color: Colors.amber.withOpacity(0.12),
                              child: const Icon(Icons.videocam,
                                  color: Colors.amber),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Item ${index + 1} — ${isImage ? "Generate from photo (1 credit)" : "Existing footage (free)"}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              if (isImage) ...[
                const SizedBox(height: 16),
                const Text('Length',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final seconds in [4, 6, 8])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('${seconds}s'),
                          selected: item.durationSeconds == seconds,
                          onSelected: (_) {
                            onDurationChanged(index, seconds);
                            Navigator.of(sheetContext).pop();
                          },
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Match this to how much dialogue applies to this shot — '
                  'a longer line needs more seconds so Veo has room to '
                  'finish speaking.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 16),
              ] else
                const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Remove this item'),
                  onPressed: () {
                    onRemove(index);
                    Navigator.of(sheetContext).pop();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
