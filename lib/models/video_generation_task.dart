enum GenerationStatus { running, succeeded, failed }

class VideoGenerationTask {
  final String operationName;
  final bool done;
  final String? videoUri;
  final String? errorMessage;

  const VideoGenerationTask({
    required this.operationName,
    required this.done,
    this.videoUri,
    this.errorMessage,
  });

  GenerationStatus get status {
    if (!done) return GenerationStatus.running;
    return videoUri != null ? GenerationStatus.succeeded : GenerationStatus.failed;
  }
}
