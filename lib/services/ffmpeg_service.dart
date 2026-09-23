import 'dart:io';

/// macOS-only: shells out to a system `ffmpeg` binary on PATH
/// (`brew install ffmpeg`). Don't call this from iOS/Android builds.
class FfmpegService {
  static Future<void> _run(List<String> args) async {
    final result = await Process.run('ffmpeg', args);
    if (result.exitCode != 0) {
      throw Exception('ffmpeg failed:\n${result.stderr}');
    }
  }

  static Future<String> concatClips({
    required List<String> clipPaths,
    required String outputPath,
    int width = 1080,
    int height = 1920,
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
        '-c:v', 'libx264', '-preset', 'fast', '-crf', '18',
        '-c:a', 'aac',
        out,
      ]);
      normalized.add(out);
    }

    final listFile = File('${outputPath}_concat_list.txt');
    await listFile.writeAsString(
      normalized.map((p) => "file '$p'").join('\n'),
    );

    await _run([
      '-y',
      '-f', 'concat', '-safe', '0',
      '-i', listFile.path,
      '-c', 'copy',
      outputPath,
    ]);

    for (final p in normalized) {
      await File(p).delete();
    }
    await listFile.delete();

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
