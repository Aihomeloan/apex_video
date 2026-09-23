import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dialogue_line.dart';
import '../models/history_entry.dart';
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
  static const _welcomeGrantedKey = 'apexvideo_welcome_credits_granted';
  static const _aiAssistEnabledKey = 'apexvideo_ai_assist_enabled';
  static const _welcomeCreditsAmount = 10;
  static const maxDialogueLines = 4;
  static const durationOptions = [5, 8, 10, 12, 15];

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

  int get creditsNeeded => 1;

  Future<void> loadCredits() async {
    final prefs = await SharedPreferences.getInstance();
    credits = prefs.getInt(_creditsKey) ?? 0;
    aiAssistEnabled = prefs.getBool(_aiAssistEnabledKey) ?? true;

    final alreadyGranted = prefs.getBool(_welcomeGrantedKey) ?? false;
    if (!alreadyGranted) {
      credits += _welcomeCreditsAmount;
      await prefs.setBool(_welcomeGrantedKey, true);
      await _saveCredits();
    }

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

  Future<bool> _spendCredit() async {
    if (credits <= 0) return false;
    credits -= 1;
    await _saveCredits();
    notifyListeners();
    return true;
  }

  /// Credits only represent OUR app's promise to you, not MiniMax's — so
  /// if a generation fails or times out with nothing to show for it,
  /// give the credit back. Whether MiniMax itself still bills for a
  /// failed/incomplete task on their end is a separate question — check
  /// your Balance page on platform.minimax.io to confirm that.
  Future<void> _refundCredit() async {
    credits += 1;
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

  void updateDialogueLineText(int index, String line) {
    if (index < dialogueLines.length) dialogueLines[index].line = line;
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
    notifyListeners();

    var creditSpent = false;

    try {
      final spent = await _spendCredit();
      if (!spent) {
        errorMessage = 'Out of credits — buy more to keep generating.';
        isGenerating = false;
        notifyListeners();
        return;
      }
      creditSpent = true;
      currentSegmentIndex = 1;
      notifyListeners();

      List<int>? imageBytes;
      if (sceneImage != null) {
        imageBytes = await sceneImage!.readAsBytes();
      }

      final prompt = _buildCombinedPrompt();

      // ignore: avoid_print
      print('>>> ApexVideo: generating via MiniMax — '
          '${videoDurationSeconds}s, hasImage=${imageBytes != null}');

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
        await _refundCredit();
        creditSpent = false;
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
      // A timeout or any thrown exception also means nothing was
      // delivered — refund here too, not just on the "failed" path above.
      if (creditSpent) {
        await _refundCredit();
      }
    } finally {
      isGenerating = false;
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
    notifyListeners();
  }

  @override
  void dispose() {
    purchaseService.dispose();
    super.dispose();
  }
}
