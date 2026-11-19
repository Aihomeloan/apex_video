import 'dart:io';

/// macOS-only: shells out to a system `ffmpeg`/`ffprobe` on PATH
/// (`brew install ffmpeg`). Don't call this from iOS/Android builds —
/// Apple's sandbox doesn't allow subprocesses at all on iOS.
class FfmpegService {
  static Future<void> _run(List<String> args) async {
    final result = await Process.run('ffmpeg', args);
    if (result.exitCode != 0) {
      throw Exception('ffmpeg failed:\n${result.stderr}');
    }
  }

  static Future<double> _probeDuration(String path) async {
    final result = await Process.run('ffprobe', [
      '-v', 'error',
      '-show_entries', 'format=duration',
      '-of', 'csv=p=0',
      path,
    ]);
    if (result.exitCode != 0) {
      throw Exception('ffprobe failed for $path:\n${result.stderr}');
    }
    return double.parse((result.stdout as String).trim());
  }

  /// Turns a still image into a short silent-audio-padded clip, so it can
  /// slot into concatClips() alongside real video/audio clips without
  /// the crossfade filter erroring on a missing audio stream.
  static Future<String> imageToVideoClip({
    required String imagePath,
    required String outputPath,
    double durationSeconds = 1.5,
    int width = 1080,
    int height = 1920,
  }) async {
    await _run([
      '-y',
      '-loop', '1',
      '-i', imagePath,
      '-f', 'lavfi',
      '-i', 'anullsrc=channel_layout=stereo:sample_rate=44100',
      '-t', durationSeconds.toString(),
      '-vf',
      'scale=$width:$height:force_original_aspect_ratio=decrease,'
          'pad=$width:$height:(ow-iw)/2:(oh-ih)/2,setsar=1',
      '-r', '30',
      '-pix_fmt', 'yuv420p',
      '-c:v', 'libx264', '-preset', 'fast', '-crf', '18',
      '-c:a', 'aac',
      '-shortest',
      outputPath,
    ]);
    return outputPath;
  }

  /// Concatenates clips in order, normalizing resolution/fps/pixel format
  /// first so every clip matches (required for the crossfade filter),
  /// then blends consecutive clips with a short crossfade instead of a
  /// hard cut.
  static Future<String> concatClips({
    required List<String> clipPaths,
    required String outputPath,
    int width = 1080,
    int height = 1920,
    double crossfadeSeconds = 0.4,
  }) async {
    final normalized = <String>[];
    for (var i = 0; i < clipPaths.length; i++) {
      final out = '${outputPath}_part$i.mp4';
      await _run([
        '-y',
        '-i', clipPaths[i],
        '-vf',
        'scale=$width:$height:force_original_aspect_ratio=decrease,'
            'pad=$width:$height:(ow-iw)/2:(oh-ih)/2,setsar=1',
        '-r', '30',
        '-pix_fmt', 'yuv420p',
        '-c:v', 'libx264', '-preset', 'fast', '-crf', '18',
        '-c:a', 'aac', '-ar', '44100', '-ac', '2',
        out,
      ]);
      normalized.add(out);
    }

    if (normalized.length == 1) {
      await File(normalized.first).copy(outputPath);
      await File(normalized.first).delete();
      return outputPath;
    }

    final durations = <double>[];
    for (final path in normalized) {
      durations.add(await _probeDuration(path));
    }

    final args = <String>['-y'];
    for (final path in normalized) {
      args.addAll(['-i', path]);
    }

    final filters = <String>[];
    var runningDuration = durations[0];
    var lastVideoLabel = '0:v';
    var lastAudioLabel = '0:a';

    for (var i = 1; i < normalized.length; i++) {
      final safeFade = [
        crossfadeSeconds,
        durations[i - 1] / 2,
        durations[i] / 2,
      ].reduce((a, b) => a < b ? a : b);

      final offset = (runningDuration - safeFade).clamp(0.0, double.infinity);
      final vOut = 'v$i';
      final aOut = 'a$i';

      filters.add(
        '[$lastVideoLabel][$i:v]xfade=transition=fade:'
        'duration=${safeFade.toStringAsFixed(2)}:'
        'offset=${offset.toStringAsFixed(2)}[$vOut]',
      );
      filters.add(
        '[$lastAudioLabel][$i:a]acrossfade=d=${safeFade.toStringAsFixed(2)}[$aOut]',
      );

      lastVideoLabel = vOut;
      lastAudioLabel = aOut;
      runningDuration = offset + durations[i];
    }

    args.addAll([
      '-filter_complex', filters.join(';'),
      '-map', '[$lastVideoLabel]',
      '-map', '[$lastAudioLabel]',
      '-c:v', 'libx264', '-preset', 'fast', '-crf', '18',
      '-c:a', 'aac',
      outputPath,
    ]);

    await _run(args);

    for (final p in normalized) {
      try {
        await File(p).delete();
      } catch (_) {}
    }

    return outputPath;
  }

  static Future<String> burnCaptions({
    required String videoPath,
    required String assSubtitlePath,
    required String outputPath,
  }) async {
    await _run([
      '-y',
      '-i', videoPath,
      '-vf', 'ass=$assSubtitlePath',
      '-c:a', 'copy',
      outputPath,
    ]);
    return outputPath;
  }
}
