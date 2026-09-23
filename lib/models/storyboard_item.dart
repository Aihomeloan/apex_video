import 'dart:io';

enum StoryboardItemType { image, video }

class StoryboardItem {
  final String id;
  final StoryboardItemType type;
  final File file;
  // Only meaningful for image items — must be 4, 6, or 8 (Veo's only
  // valid discrete durations). Longer dialogue needs more seconds so
  // Veo doesn't have to rush or truncate it.
  int durationSeconds;

  StoryboardItem({
    required this.id,
    required this.type,
    required this.file,
    this.durationSeconds = 8,
  });
}
