import 'package:flutter/material.dart';
import 'sequential_video_player.dart';

class FullscreenVideoViewer extends StatelessWidget {
  final List<String> filePaths;
  const FullscreenVideoViewer({super.key, required this.filePaths});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SequentialVideoPlayer(
                  key: ValueKey(filePaths.join(',')),
                  filePaths: filePaths,
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.6),
                ),
                icon: const Icon(Icons.close),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
