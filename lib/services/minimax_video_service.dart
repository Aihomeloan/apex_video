import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/video_generation_task.dart';
import 'api_service.dart';

class VideoStartResult {
  final String taskId;
  final int? balance;
  const VideoStartResult(this.taskId, this.balance);
}

/// Video generation — runs on the ApexVideo server (MiniMax). The server
/// charges credits, starts the job, and refunds automatically on failure.
class MiniMaxVideoService {
  Future<VideoStartResult> generate({
    required String prompt,
    List<int>? imageBytes,
    String imageMimeType = 'image/png',
    required int durationSeconds,
    required String quality,
  }) async {
    final data = await ApiService.instance.post(
      '/video',
      {
        'prompt': prompt,
        'duration': durationSeconds,
        'quality': quality,
        if (imageBytes != null) 'imageBase64': base64Encode(imageBytes),
        if (imageBytes != null) 'imageMimeType': imageMimeType,
      },
      timeout: const Duration(seconds: 90),
    );
    final taskId = data['taskId'] as String?;
    if (taskId == null || taskId.isEmpty) {
      throw ApiException(
          0, 'no_task', 'The video service did not start the job.');
    }
    return VideoStartResult(taskId, (data['balance'] as num?)?.toInt());
  }

  Future<VideoGenerationTask> getStatus(String taskId) async {
    final data =
        await ApiService.instance.post('/video/status', {'taskId': taskId});
    final done = data['done'] == true;
    final balance = (data['balance'] as num?)?.toInt();
    if (!done) {
      return VideoGenerationTask(
          operationName: taskId, done: false, balance: balance);
    }
    return VideoGenerationTask(
      operationName: taskId,
      done: true,
      videoUri: data['videoUrl'] as String?,
      errorMessage: data['error'] as String?,
      balance: balance,
      refunded: data['refunded'] == true,
    );
  }

  Future<VideoGenerationTask> pollUntilComplete(
    String taskId, {
    void Function(VideoGenerationTask task)? onUpdate,
    Duration initialDelay = const Duration(seconds: 8),
    Duration maxDelay = const Duration(seconds: 20),
    // A bit longer than the server's 30-minute limit, so the server's
    // automatic refund always happens first.
    Duration maxWait = const Duration(minutes: 35),
  }) async {
    final deadline = DateTime.now().add(maxWait);
    var delay = initialDelay;
    var transientErrors = 0;
    while (true) {
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException(
          'This video is taking unusually long. If it fails, your credits '
          'are refunded automatically.',
        );
      }
      await Future.delayed(delay);
      try {
        final task = await getStatus(taskId);
        transientErrors = 0;
        onUpdate?.call(task);
        if (task.done) return task;
      } on ApiException catch (e) {
        if (!e.isTransient) rethrow;
        transientErrors++;
        if (transientErrors > 10) rethrow;
      }
      delay = Duration(
        milliseconds: (delay.inMilliseconds * 1.3)
            .clamp(0, maxDelay.inMilliseconds)
            .toInt(),
      );
    }
  }

  /// The finished video's link is public — no key needed to download it.
  Future<File> downloadVideo(String videoUri, String destPath) async {
    final res = await http.get(Uri.parse(videoUri));
    if (res.statusCode != 200) {
      throw ApiException(res.statusCode, 'download_failed',
          'Could not download the finished video.');
    }
    final file = File(destPath);
    await file.writeAsBytes(res.bodyBytes);
    return file;
  }
}
