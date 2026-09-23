enum VideoLengthOption { s10, s20, s30, s40, s50 }

extension VideoLengthOptionData on VideoLengthOption {
  int get targetSeconds {
    switch (this) {
      case VideoLengthOption.s10:
        return 10;
      case VideoLengthOption.s20:
        return 20;
      case VideoLengthOption.s30:
        return 30;
      case VideoLengthOption.s40:
        return 40;
      case VideoLengthOption.s50:
        return 50;
    }
  }

  String get label => '${targetSeconds}s';

  /// Veo only accepts 4, 6, or 8 second segments per call. These are the
  /// exact combinations that sum to the target with no rounding, generated
  /// as separate clips and concatenated — NOT a single continuous Extend
  /// chain (Lite doesn't support Extend).
  List<int> get segmentPlan {
    switch (this) {
      case VideoLengthOption.s10:
        return [6, 4];
      case VideoLengthOption.s20:
        return [8, 8, 4];
      case VideoLengthOption.s30:
        return [8, 8, 8, 6];
      case VideoLengthOption.s40:
        return [8, 8, 8, 8, 8];
      case VideoLengthOption.s50:
        return [8, 8, 8, 8, 8, 6, 4];
    }
  }

  /// Estimate at Veo 3.1 Lite's 720p rate. Update the multiplier here if
  /// GeminiVideoService's _model ever changes to Fast (~$0.10-0.15/sec) or
  /// full Veo 3.1 ($0.40/sec).
  double get estimatedCostLite => targetSeconds * 0.05;
}
