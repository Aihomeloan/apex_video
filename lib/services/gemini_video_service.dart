import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/env.dart';
import '../models/video_generation_task.dart';

class GeminiApiException implements Exception {
  final int statusCode;
  final String message;
  GeminiApiException(this.statusCode, this.message);
  @override
  String toString() => 'GeminiApiException($statusCode): $message';
}

class GeminiVideoService {
  static const _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';
  static const _model = 'veo-3.1-lite-generate-preview';

  // Only applied when there's no source image — an image-to-video call
  // inherits its realism from the already-realistic still it was given.
  static const _realismPrefix =
      'Photorealistic footage, shot on a professional cinema camera, '
      'natural lighting, real human skin texture, candid documentary style. '
      'This is NOT animation, NOT a cartoon, NOT 3D render, NOT CGI — it is '
      'real filmed footage. ';

  Map<String, String> get _headers => {
        'x-goog-api-key': Env.geminiApiKey,
        'Content-Type': 'application/json',
      };

  Future<String> generate({
    required String prompt,
    List<int>? imageBytes,
    String imageMimeType = 'image/png',
    String aspectRatio = '9:16',
    int durationSeconds = 8,
    bool generateAudio = false,
  }) async {
    final effectivePrompt =
        imageBytes == null ? '$_realismPrefix$prompt' : prompt;

    final instance = <String, dynamic>{'prompt': effectivePrompt};
    if (imageBytes != null) {
      instance['image'] = {
        'bytesBase64Encoded': base64Encode(imageBytes),
        'mimeType': imageMimeType,
      };
    }

    final res = await http.post(
      Uri.parse('$_baseUrl/models/$_model:predictLongRunning'),
      headers: _headers,
      body: jsonEncode({
        'instances': [instance],
        'parameters': {
          'aspectRatio': aspectRatio,
          'durationSeconds': durationSeconds,
          if (generateAudio) 'generateAudio': generateAudio,
        },
      }),
    );

    if (res.statusCode != 200) {
      throw GeminiApiException(res.statusCode, res.body);
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return decoded['name'] as String;
  }

  Future<VideoGenerationTask> getOperation(String operationName) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/$operationName'),
      headers: _headers,
    );
    if (res.statusCode != 200) {
      throw GeminiApiException(res.statusCode, res.body);
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final done = decoded['done'] as bool? ?? false;

    if (!done) {
      return VideoGenerationTask(operationName: operationName, done: false);
    }

    if (decoded['error'] != null) {
      return VideoGenerationTask(
        operationName: operationName,
        done: true,
        errorMessage: decoded['error'].toString(),
      );
    }

    // ignore: avoid_print
    print('Gemini operation response: ${res.body}');

    final response = decoded['response'] as Map<String, dynamic>?;
    final generatedVideos =
        (response?['generateVideoResponse']?['generatedSamples'] as List?) ??
            (response?['generatedVideos'] as List?);

    final firstVideo = (generatedVideos != null && generatedVideos.isNotEmpty)
        ? generatedVideos.first as Map<String, dynamic>
        : null;
    final videoUri = firstVideo?['video']?['uri'] as String?;

    return VideoGenerationTask(
      operationName: operationName,
      done: true,
      videoUri: videoUri,
      errorMessage:
          videoUri == null ? 'No video in response — check logged JSON.' : null,
    );
  }

  Future<VideoGenerationTask> pollUntilComplete(
    String operationName, {
    void Function(VideoGenerationTask task)? onUpdate,
    Duration initialDelay = const Duration(seconds: 8),
    Duration maxDelay = const Duration(seconds: 20),
  }) async {
    var delay = initialDelay;
    while (true) {
      await Future.delayed(delay);
      final task = await getOperation(operationName);
      onUpdate?.call(task);
      if (task.done) return task;
      delay = Duration(
        milliseconds: (delay.inMilliseconds * 1.3)
            .clamp(0, maxDelay.inMilliseconds)
            .toInt(),
      );
    }
  }

  Future<File> downloadVideo(String videoUri, String destPath) async {
    final sep = videoUri.contains('?') ? '&' : '?';
    final res = await http.get(
      Uri.parse('$videoUri${sep}key=${Env.geminiApiKey}'),
      headers: {'x-goog-api-key': Env.geminiApiKey},
    );
    if (res.statusCode != 200) {
      throw GeminiApiException(
          res.statusCode, 'Failed to download video: ${res.body}');
    }
    final file = File(destPath);
    await file.writeAsBytes(res.bodyBytes);
    return file;
  }
}
