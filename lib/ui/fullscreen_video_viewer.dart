import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/photo_save_service.dart';
import 'sequential_video_player.dart';

/// Returned to the home screen when the user taps "Make a new video".
const String kFullscreenResultNew = 'new';

/// Full-screen playback with Share, Save to Photos, Exit, and
/// "Make a new video". Finished videos are already saved to History, so
/// nothing is lost by exiting.
class FullscreenVideoViewer extends StatefulWidget {
  final List<String> filePaths;
  final String shareText;

  const FullscreenVideoViewer({
    super.key,
    required this.filePaths,
    this.shareText = '',
  });

  @override
  State<FullscreenVideoViewer> createState() => _FullscreenVideoViewerState();
}

class _FullscreenVideoViewerState extends State<FullscreenVideoViewer> {
  bool _saving = false;

  void _close() => Navigator.of(context).maybePop();

  /// [buttonContext] is the Share button's own context, so iPad knows
  /// where to anchor the share popover (without it, iPad can crash).
  Future<void> _share(BuildContext buttonContext) async {
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin = (box != null && box.hasSize)
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    final files = widget.filePaths.map((p) => XFile(p)).toList();
    await Share.shareXFiles(
      files,
      text: widget.shareText.isEmpty ? null : widget.shareText,
      sharePositionOrigin: origin,
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    String? err;
    for (final p in widget.filePaths) {
      err = await PhotoSaveService.saveVideo(p);
      if (err != null) break;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(err ?? 'Saved to Photos.')),
    );
  }

  Widget _goldCircle({
    required Widget icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return Material(
      color: Colors.amber,
      shape: const CircleBorder(
        side: BorderSide(color: Colors.white, width: 1.5),
      ),
      child: IconButton(
        icon: icon,
        tooltip: tooltip,
        color: Colors.black,
        onPressed: onPressed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > 300) _close();
        },
        child: SafeArea(
          child: Column(
            children: [
              // Top toolbar: Exit on the left, Share + Save on the right.
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    _goldCircle(
                      icon: const Icon(Icons.close, size: 26),
                      tooltip: 'Exit full screen',
                      onPressed: _close,
                    ),
                    const Spacer(),
                    Builder(
                      builder: (btnContext) => _goldCircle(
                        icon: const Icon(Icons.ios_share, size: 22),
                        tooltip: 'Share',
                        onPressed: () => _share(btnContext),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _goldCircle(
                      icon: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.black),
                            )
                          : const Icon(Icons.download, size: 24),
                      tooltip: 'Save to Photos',
                      onPressed: _saving ? null : _save,
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SequentialVideoPlayer(
                      key: ValueKey(widget.filePaths.join(',')),
                      filePaths: widget.filePaths,
                    ),
                  ),
                ),
              ),

              // Bottom: reassurance + move on to the next video.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle,
                            size: 14, color: Colors.greenAccent),
                        SizedBox(width: 6),
                        Text(
                          'Saved to History automatically',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Make a new video'),
                        onPressed: () => Navigator.of(context)
                            .pop(kFullscreenResultNew),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Swipe down to close',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
