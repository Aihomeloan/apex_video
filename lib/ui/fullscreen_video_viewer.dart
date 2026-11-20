import 'package:flutter/material.dart';
import 'sequential_video_player.dart';

/// Full-screen playback. Close with the gold button (top left) or by
/// swiping down.
class FullscreenVideoViewer extends StatelessWidget {
  final List<String> filePaths;
  const FullscreenVideoViewer({super.key, required this.filePaths});

  @override
  Widget build(BuildContext context) {
    void close() => Navigator.of(context).maybePop();

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > 300) close();
        },
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 64, 16, 28),
                  child: SequentialVideoPlayer(
                    key: ValueKey(filePaths.join(',')),
                    filePaths: filePaths,
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 12,
                child: Material(
                  color: Colors.amber,
                  shape: const CircleBorder(
                    side: BorderSide(color: Colors.white, width: 1.5),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.black, size: 26),
                    tooltip: 'Close',
                    onPressed: close,
                  ),
                ),
              ),
              const Positioned(
                bottom: 6,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    'Swipe down to close',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
