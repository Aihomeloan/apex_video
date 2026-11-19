import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/env.dart';
import '../models/video_generation_task.dart';

class MiniMaxApiException implements Exception {
  final int statusCode;
  final String message;
  MiniMaxApiException(this.statusCode, this.message);
  @override
  String toString() => 'MiniMaxApiException($statusCode): $message';
}

class MiniMaxVideoService {
  static const _baseUrl = 'https://api.minimax.io/v2';
  static const _model = 'MiniMax-H3';

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${Env.minimaxApiKey}',
        'Content-Type': 'application/json',
      };

  Future<String> generate({
    required String prompt,
    List<int>? imageBytes,
    String imageMimeType = 'image/png',
    int durationSeconds = 6,
  }) async {
    final clampedDuration = durationSeconds < 5 ? 5 : durationSeconds;

    final content = <Map<String, dynamic>>[
      {'type': 'text', 'text': prompt},
    ];
    if (imageBytes != null) {
      content.add({
        'type': 'image_url',
        'image_url': {
          'url': 'data:$imageMimeType;base64,${base64Encode(imageBytes)}',
        },
      });
    }

    final body = {
      'model': _model,
      'content': content,
      'resolution': '2K',
      'duration': clampedDuration,
      'ratio': '9:16',
    };

    // ignore: avoid_print
    print('>>> MiniMax: submitting task — duration=$clampedDuration, '
        'requestedRatio=9:16, hasImage=${imageBytes != null}, '
        'promptChars=${prompt.length}');
    // ignore: avoid_print
    print('>>> MiniMax: FULL PROMPT SENT: "$prompt"');

    final res = await http.post(
      Uri.parse('$_baseUrl/video_generation'),
      headers: _headers,
      body: jsonEncode(body),
    );

    // ignore: avoid_print
    print('>>> MiniMax: submit response (${res.statusCode}): ${res.body}');

    if (res.statusCode != 200) {
      throw MiniMaxApiException(res.statusCode, res.body);
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final taskId = decoded['task_id'] as String?;
    if (taskId == null || taskId.isEmpty) {
      throw MiniMaxApiException(
          res.statusCode, 'No task_id in response: ${res.body}');
    }
    return taskId;
  }

  Future<VideoGenerationTask> getOperation(String taskId) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/query/video_generation?task_id=$taskId'),
      headers: _headers,
    );
    if (res.statusCode != 200) {
      // ignore: avoid_print
      print('>>> MiniMax: poll HTTP error (${res.statusCode}): ${res.body}');
      throw MiniMaxApiException(res.statusCode, res.body);
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;

    final items = decoded['items'] as List<dynamic>?;
    Map<String, dynamic>? match;
    if (items != null) {
      for (final raw in items) {
        final item = raw as Map<String, dynamic>;
        if (item['id'] == taskId) {
          match = item;
          break;
        }
      }
    }

    if (match == null) {
      // ignore: avoid_print
      print('>>> MiniMax: task $taskId not found in items list yet — '
          'full response: ${res.body}');
      return VideoGenerationTask(operationName: taskId, done: false);
    }

    final status = (match['status'] as String?)?.toLowerCase() ?? '';
    final actualRatio = match['ratio']?.toString() ?? 'unknown';

    // ignore: avoid_print
    print('>>> MiniMax: poll status = "$status", actualRatio="$actualRatio" '
        '(we requested 9:16) — task $taskId');

    if (status == 'succeeded' || status == 'success') {
      final content = match['content'] as Map<String, dynamic>?;
      final url = content?['url'] as String?;
      if (url == null) {
        // ignore: avoid_print
        print('>>> MiniMax: succeeded but no content.url — item: $match');
        return VideoGenerationTask(
          operationName: taskId,
          done: true,
          errorMessage:
              'Status succeeded but no content.url — check logged JSON.',
        );
      }
      // ignore: avoid_print
      print('>>> MiniMax: FINAL ITEM DETAILS: $match');
      return VideoGenerationTask(
          operationName: taskId, done: true, videoUri: url);
    }
    if (status == 'failed' || status == 'fail') {
      // ignore: avoid_print
      print('>>> MiniMax: task FAILED — item: $match');
      final error = match['error'] as Map<String, dynamic>?;
      final errMsg = error?['message']?.toString();
      return VideoGenerationTask(
        operationName: taskId,
        done: true,
        errorMessage:
            errMsg ?? 'MiniMax generation failed — check logged JSON.',
      );
    }
    return VideoGenerationTask(operationName: taskId, done: false);
  }

  Future<VideoGenerationTask> pollUntilComplete(
    String taskId, {
    void Function(VideoGenerationTask task)? onUpdate,
    Duration initialDelay = const Duration(seconds: 8),
    Duration maxDelay = const Duration(seconds: 20),
    Duration maxWait = const Duration(minutes: 8),
  }) async {
    final deadline = DateTime.now().add(maxWait);
    var delay = initialDelay;
    while (true) {
      if (DateTime.now().isAfter(deadline)) {
        // ignore: avoid_print
        print('>>> MiniMax: TIMED OUT after ${maxWait.inMinutes} minutes '
            'for task $taskId.');
        throw TimeoutException(
          'MiniMax generation took longer than ${maxWait.inMinutes} '
          'minutes — giving up.',
        );
      }
      await Future.delayed(delay);
      final task = await getOperation(taskId);
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
    final res = await http.get(Uri.parse(videoUri));
    if (res.statusCode != 200) {
      throw MiniMaxApiException(res.statusCode, 'Failed to download video');
    }
    final file = File(destPath);
    await file.writeAsBytes(res.bodyBytes);
    return file;
  }
}
