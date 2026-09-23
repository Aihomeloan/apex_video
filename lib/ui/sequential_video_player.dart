import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class SequentialVideoPlayer extends StatefulWidget {
  final List<String> filePaths;
  const SequentialVideoPlayer({super.key, required this.filePaths});

  @override
  State<SequentialVideoPlayer> createState() => _SequentialVideoPlayerState();
}

class _SequentialVideoPlayerState extends State<SequentialVideoPlayer> {
  late VideoPlayerController _controller;
  int _index = 0;
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadClip(0);
  }

  @override
  void didUpdateWidget(covariant SequentialVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePaths != widget.filePaths) {
      _controller.removeListener(_onTick);
      _controller.dispose();
      _index = 0;
      _initialized = false;
      _error = null;
      _loadClip(0);
    }
  }

  void _loadClip(int index) {
    if (index >= widget.filePaths.length) return;
    _controller = VideoPlayerController.file(File(widget.filePaths[index]));
    _controller.addListener(_onTick);
    _controller.initialize().then((_) {
      if (mounted) {
        setState(() => _initialized = true);
        _controller.play();
      }
    }).catchError((e) {
      if (mounted) setState(() => _error = e.toString());
    });
  }

  void _onTick() {
    if (_controller.value.isInitialized &&
        !_controller.value.isPlaying &&
        _controller.value.duration > Duration.zero &&
        _controller.value.position >= _controller.value.duration) {
      _advance();
    }
  }

  void _advance() {
    if (_index < widget.filePaths.length - 1) {
      _controller.removeListener(_onTick);
      _controller.dispose();
      setState(() {
        _index++;
        _initialized = false;
      });
      _loadClip(_index);
    }
  }

  void _goTo(int newIndex) {
    _controller.removeListener(_onTick);
    _controller.dispose();
    setState(() {
      _index = newIndex;
      _initialized = false;
    });
    _loadClip(_index);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Text('Couldn\'t load video: $_error',
          style: const TextStyle(color: Colors.redAccent));
    }
    if (!_initialized) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          ),
        ),
        const SizedBox(height: 8),
        Text('Clip ${_index + 1} of ${widget.filePaths.length}'),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous),
              onPressed: _index == 0 ? null : () => _goTo(_index - 1),
            ),
            IconButton(
              iconSize: 40,
              icon: Icon(_controller.value.isPlaying
                  ? Icons.pause_circle
                  : Icons.play_circle),
              onPressed: () {
                setState(() {
                  _controller.value.isPlaying
                      ? _controller.pause()
                      : _controller.play();
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.skip_next),
              onPressed: _index >= widget.filePaths.length - 1
                  ? null
                  : () => _goTo(_index + 1),
            ),
          ],
        ),
      ],
    );
  }
}
