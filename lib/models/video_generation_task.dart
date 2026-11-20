enum GenerationStatus { running, succeeded, failed }

class VideoGenerationTask {
  final String operationName;
  final bool done;
  final String? videoUri;
  final String? errorMessage;

  /// Credit balance the server reported with this update, if any.
  final int? balance;

  /// True when the server gave the credits back for a failed video.
  final bool refunded;

  const VideoGenerationTask({
    required this.operationName,
    required this.done,
    this.videoUri,
    this.errorMessage,
    this.balance,
    this.refunded = false,
  });

  GenerationStatus get status {
    if (!done) return GenerationStatus.running;
    return videoUri != null ? GenerationStatus.succeeded : GenerationStatus.failed;
  }
}
