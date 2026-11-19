import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dialogue_line.dart';
import '../models/history_entry.dart';
import '../services/ffmpeg_service.dart';
import '../services/gemini_image_service.dart';
import '../services/gemini_text_service.dart';
import '../services/history_service.dart';
import '../services/minimax_video_service.dart';
import '../services/purchase_service.dart';

class ProjectState extends ChangeNotifier {
  final MiniMaxVideoService _minimax = MiniMaxVideoService();
  final GeminiImageService _geminiImage = GeminiImageService();
  final GeminiTextService _geminiText = GeminiTextService();
  final PurchaseService purchaseService = PurchaseService();
  final HistoryService historyService = HistoryService();

  static const _creditsKey = 'apexvideo_credits';
  static const _aiAssistEnabledKey = 'apexvideo_ai_assist_enabled';
  static const maxDialogueLines = 4;

  static const durationOptions = [10, 15];
  static const Map<int, int> _creditsByDuration = {10: 4, 15: 6};

  // Rough natural speaking pace guardrail — ~2.5 words/sec, leaving room
  // for the scene itself to breathe rather than every second being talk.
  static const Map<int, int> _wordBudgetByDuration = {10: 18, 15: 28};

  String scriptPrompt = '';
  File? sceneImage;

  List<DialogueLine> dialogueLines = [];

  int videoDurationSeconds = 10;

  int credits = 0;
  bool isAssisting = false;
  bool hasUsedAssist = false;
  bool aiAssistEnabled = true;

  bool isGeneratingPreview = false;
  String? previewError;

  bool isGenerating = false;
  String? errorMessage;
  List<String> generatedClipPaths = [];
  int currentSegmentIndex = 0;
  int totalSegments = 0;

  List<HistoryEntry> history = [];

  bool isCombining = false;
  String? combineError;
  String? combinedExportPath;

  int get creditsNeeded =>
      _creditsByDuration[videoDurationSeconds] ?? _creditsByDuration[10]!;

  bool get canCombineWithPrevious =>
      Platform.isMacOS &&
      generatedClipPaths.isNotEmpty &&
      history.length >= 2;

  /// Word count across every dialogue line — the part MiniMax actually
  /// has to speak. The scene description itself isn't spoken, so it's
  /// not counted toward the pacing budget.
  int get spokenWordCount {
    var count = 0;
    for (final d in dialogueLines) {
      final trimmed = d.line.trim();
      if (trimmed.isEmpty) continue;
      count += trimmed.split(RegExp(r'\s+')).length;
    }
    return count;
  }

  int get wordBudget =>
      _wordBudgetByDuration[videoDurationSeconds] ??
      _wordBudgetByDuration[10]!;

  bool get isOverWordBudget => spokenWordCount > wordBudget;

  /// Loads saved credits. No free welcome credits — new installs start
  /// at 0 and buy a credit pack to generate.
  Future<void> loadCredits() async {
    final prefs = await SharedPreferences.getInstance();
    credits = prefs.getInt(_creditsKey) ?? 0;
    aiAssistEnabled = prefs.getBool(_aiAssistEnabledKey) ?? true;

    notifyListeners();

    purchaseService.listenForPurchases(
      onCreditsGranted: (amount) async {
        credits += amount;
        await _saveCredits();
        notifyListeners();
      },
      onError: (message) {
        errorMessage = 'Purchase error: $message';
        notifyListeners();
      },
    );
  }

  Future<void> setAiAssistEnabled(bool value) async {
    aiAssistEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_aiAssistEnabledKey, value);
    notifyListeners();
  }

  Future<void> loadHistory() async {
    history = await historyService.loadHistory();
    notifyListeners();
  }

  Future<void> deleteHistoryEntry(HistoryEntry entry) async {
    await historyService.deleteEntry(entry);
    await loadHistory();
  }

  Future<void> _saveCredits() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_creditsKey, credits);
  }

  Future<bool> _spendCredits(int amount) async {
    if (credits < amount) return false;
    credits -= amount;
    await _saveCredits();
    notifyListeners();
    return true;
  }

  Future<void> _refundCredits(int amount) async {
    credits += amount;
    await _saveCredits();
    notifyListeners();
  }

  Future<void> assistScript() async {
    isAssisting = true;
    errorMessage = null;
    notifyListeners();
    try {
      final improved = await _geminiText.improvePrompt(scriptPrompt);
      scriptPrompt = improved;
      hasUsedAssist = true;
    } catch (e) {
      errorMessage = 'AI Assist failed: $e';
    } finally {
      isAssisting = false;
      notifyListeners();
    }
  }

  void setScript(String value) {
    scriptPrompt = value;
    notifyListeners();
  }

  void setVideoDuration(int seconds) {
    if (isGenerating) return;
    if (!durationOptions.contains(seconds)) return;
    videoDurationSeconds = seconds;
    notifyListeners();
  }

  void setSceneImage(File file) {
    if (isGenerating) return;
    sceneImage = file;
    notifyListeners();
  }

  void clearSceneImage() {
    if (isGenerating) return;
    sceneImage = null;
    notifyListeners();
  }

  Future<void> generateSceneImage() async {
    if (scriptPrompt.trim().isEmpty) {
      previewError = 'Add a scene description first.';
      notifyListeners();
      return;
    }
    previewError = null;
    isGeneratingPreview = true;
    notifyListeners();
    try {
      final bytes = await _geminiImage.generatePreviewImage(scriptPrompt);
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/scene_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(path).writeAsBytes(bytes);
      sceneImage = File(path);
    } catch (e) {
      previewError = e.toString();
    } finally {
      isGeneratingPreview = false;
      notifyListeners();
    }
  }

  void addDialogueLine() {
    if (isGenerating) return;
    if (dialogueLines.length >= maxDialogueLines) return;
    dialogueLines.add(DialogueLine(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
    ));
    notifyListeners();
  }

  void removeDialogueLine(int index) {
    if (isGenerating) return;
    dialogueLines.removeAt(index);
    notifyListeners();
  }

  void updateDialogueSpeaker(int index, String speaker) {
    if (index < dialogueLines.length) dialogueLines[index].speaker = speaker;
  }

  /// This one DOES notify — the word-budget warning depends on live
  /// dialogue text, so the UI needs to rebuild as the user types.
  void updateDialogueLineText(int index, String line) {
    if (index < dialogueLines.length) {
      dialogueLines[index].line = line;
      notifyListeners();
    }
  }

  String _buildCombinedPrompt() {
    final buffer = StringBuffer();
    if (scriptPrompt.trim().isNotEmpty) {
      buffer.write(scriptPrompt.trim());
      buffer.write(' ');
    }
    for (final d in dialogueLines) {
      if (d.line.trim().isEmpty) continue;
      final speaker = d.speaker.trim().isEmpty ? 'A character' : d.speaker.trim();
      buffer.write('$speaker says: "${d.line.trim()}". ');
    }
    return buffer.toString().trim();
  }

  Future<void> generate() async {
    errorMessage = null;
    isGenerating = true;
    generatedClipPaths = [];
    currentSegmentIndex = 0;
    totalSegments = 1;
    combinedExportPath = null;
    combineError = null;
    notifyListeners();

    final cost = creditsNeeded;
    var creditsSpent = 0;

    try {
      final spent = await _spendCredits(cost);
      if (!spent) {
        errorMessage =
            'Out of credits — this needs $cost, you have $credits.';
        isGenerating = false;
        notifyListeners();
        return;
      }
      creditsSpent = cost;
      currentSegmentIndex = 1;
      notifyListeners();

      List<int>? imageBytes;
      if (sceneImage != null) {
        imageBytes = await sceneImage!.readAsBytes();
      }

      final prompt = _buildCombinedPrompt();

      // ignore: avoid_print
      print('>>> ApexVideo: generating via MiniMax — '
          '${videoDurationSeconds}s ($cost credits), '
          'spokenWords=$spokenWordCount/$wordBudget, '
          'hasImage=${imageBytes != null}');

      final taskId = await _minimax.generate(
        prompt: prompt,
        imageBytes: imageBytes,
        durationSeconds: videoDurationSeconds,
      );
      final finished = await _minimax.pollUntilComplete(
        taskId,
        onUpdate: (_) => notifyListeners(),
      );

      if (finished.videoUri == null) {
        errorMessage = finished.errorMessage ?? 'Generation failed.';
        await _refundCredits(creditsSpent);
        creditsSpent = 0;
      } else {
        final dir = await getTemporaryDirectory();
        final localPath =
            '${dir.path}/output_${DateTime.now().millisecondsSinceEpoch}.mp4';
        final file = await _minimax.downloadVideo(finished.videoUri!, localPath);
        generatedClipPaths = [file.path];

        final entry = await historyService.saveToHistory(
          tempClipPaths: generatedClipPaths,
          scriptPrompt: prompt,
        );
        generatedClipPaths = entry.clipPaths;
        await loadHistory();
      }
    } catch (e) {
      errorMessage = e.toString();
      if (creditsSpent > 0) {
        await _refundCredits(creditsSpent);
      }
    } finally {
      isGenerating = false;
      notifyListeners();
    }
  }

  Future<void> combineWithPrevious({required bool useSplashBridge}) async {
    if (!canCombineWithPrevious) return;

    combineError = null;
    isCombining = true;
    combinedExportPath = null;
    notifyListeners();

    try {
      final latest = history[0];
      final previous = history[1];

      final clips = <String>[...previous.clipPaths, ...latest.clipPaths];

      if (useSplashBridge) {
        final byteData =
            await rootBundle.load('assets/branding/apexvideo_splash.png');
        final tempDir = await getTemporaryDirectory();
        final splashImagePath =
            '${tempDir.path}/splash_source_${DateTime.now().millisecondsSinceEpoch}.png';
        await File(splashImagePath)
            .writeAsBytes(byteData.buffer.asUint8List());

        final splashClipPath =
            '${tempDir.path}/splash_clip_${DateTime.now().millisecondsSinceEpoch}.mp4';
        await FfmpegService.imageToVideoClip(
          imagePath: splashImagePath,
          outputPath: splashClipPath,
          durationSeconds: 1.5,
        );

        clips.insertAll(previous.clipPaths.length, [splashClipPath]);
      }

      final dir = Directory.systemTemp;
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${dir.path}/combined_$stamp.mp4';

      await FfmpegService.concatClips(
        clipPaths: clips,
        outputPath: outputPath,
      );

      combinedExportPath = outputPath;
    } catch (e) {
      combineError = e.toString();
    } finally {
      isCombining = false;
      notifyListeners();
    }
  }

  Future<void> deleteVideoAndScript() async {
    scriptPrompt = '';
    sceneImage = null;
    dialogueLines = [];
    previewError = null;
    generatedClipPaths = [];
    currentSegmentIndex = 0;
    totalSegments = 0;
    errorMessage = null;
    hasUsedAssist = false;
    combinedExportPath = null;
    combineError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    purchaseService.dispose();
    super.dispose();
  }
}
