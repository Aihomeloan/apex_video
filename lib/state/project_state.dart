import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dialogue_line.dart';
import '../models/history_entry.dart';
import '../services/api_service.dart';
import '../services/ffmpeg_service.dart';
import '../services/gemini_image_service.dart';
import '../services/gemini_text_service.dart';
import '../services/history_service.dart';
import '../services/install_id.dart';
import '../services/minimax_video_service.dart';
import '../services/purchase_service.dart';

class ProjectState extends ChangeNotifier {
  final MiniMaxVideoService _minimax = MiniMaxVideoService();
  final GeminiImageService _geminiImage = GeminiImageService();
  final GeminiTextService _geminiText = GeminiTextService();
  final PurchaseService purchaseService = PurchaseService();
  final HistoryService historyService = HistoryService();

  /// Display cache only — the server is the source of truth for credits.
  static const _creditsCacheKey = 'apexvideo_credits';
  static const _aiAssistEnabledKey = 'apexvideo_ai_assist_enabled';
  static const maxDialogueLines = 4;

  static const durationOptions = [10, 15];

  static const qualityStandard = 'standard';
  static const qualityHd = 'hd';

  /// Credit costs. Replaced by the live numbers from the server at startup.
  Map<String, Map<int, int>> _costs = {
    qualityStandard: {10: 4, 15: 6},
    qualityHd: {10: 7, 15: 10},
  };

  // Rough natural speaking pace guardrail — ~2.5 words/sec, leaving room
  // for the scene itself to breathe rather than every second being talk.
  static const Map<int, int> _wordBudgetByDuration = {10: 18, 15: 28};

  String scriptPrompt = '';
  File? sceneImage;

  List<DialogueLine> dialogueLines = [];

  int videoDurationSeconds = 10;
  String videoQuality = qualityStandard;

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

  /// Videos in Recently Deleted (restorable for 30 days).
  List<TrashedEntry> trash = [];

  bool isCombining = false;
  String? combineError;
  String? combinedExportPath;

  int costFor(String quality, int seconds) =>
      _costs[quality]?[seconds] ?? _costs[qualityStandard]?[seconds] ?? 6;

  int get creditsNeeded => costFor(videoQuality, videoDurationSeconds);

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

  // ---------------------------------------------------------------------------
  // Credits (server is the source of truth)
  // ---------------------------------------------------------------------------

  Future<void> loadCredits() async {
    final prefs = await SharedPreferences.getInstance();
    credits = prefs.getInt(_creditsCacheKey) ?? 0;
    aiAssistEnabled = prefs.getBool(_aiAssistEnabledKey) ?? true;
    notifyListeners();

    if (kDebugMode) {
      final id = await InstallId.get();
      // ignore: avoid_print
      print('>>> ApexVideo installId: $id');
    }

    purchaseService.listenForPurchases(
      onVerify: _verifyPurchase,
      onError: (message) {
        errorMessage = 'Purchase error: $message';
        notifyListeners();
      },
    );

    await Future.wait([refreshBalance(), _loadConfig()]);
  }

  /// Asks the server for the current balance.
  Future<void> refreshBalance() async {
    try {
      final data = await ApiService.instance.post('/balance', {});
      final balance = (data['balance'] as num?)?.toInt();
      if (balance != null) _setCredits(balance);
    } catch (_) {
      // Offline — keep showing the cached number.
    }
  }

  void _setCredits(int value) {
    credits = value;
    notifyListeners();
    SharedPreferences.getInstance()
        .then((p) => p.setInt(_creditsCacheKey, value));
  }

  Future<void> _loadConfig() async {
    try {
      final data = await ApiService.instance.getConfig();
      final raw = data['costs'];
      if (raw is Map) {
        final parsed = <String, Map<int, int>>{};
        raw.forEach((quality, table) {
          if (table is Map) {
            final m = <int, int>{};
            table.forEach((secs, cost) {
              final s = int.tryParse('$secs');
              final c = cost is num ? cost.toInt() : int.tryParse('$cost');
              if (s != null && c != null) m[s] = c;
            });
            if (m.isNotEmpty) parsed['$quality'] = m;
          }
        });
        if (parsed.isNotEmpty) {
          _costs = parsed;
          notifyListeners();
        }
      }
    } catch (_) {
      // Keep the built-in defaults.
    }
  }

  /// Called for every completed Apple purchase. The server checks it with
  /// Apple and adds the credits; only then is the purchase finished.
  Future<VerifyOutcome> _verifyPurchase(PurchaseDetails purchase) async {
    final txId = purchase.purchaseID;
    if (txId == null || txId.isEmpty) {
      errorMessage =
          'Purchase error: Apple did not send a transaction ID. We will try again next time you open the app.';
      notifyListeners();
      return VerifyOutcome.retryLater;
    }
    try {
      final data =
          await ApiService.instance.post('/redeem', {'transactionId': txId});
      final balance = (data['balance'] as num?)?.toInt();
      if (balance != null) _setCredits(balance);
      if (errorMessage?.startsWith('Purchase error') == true) {
        errorMessage = null;
      }
      notifyListeners();
      return data['alreadyRedeemed'] == true
          ? VerifyOutcome.alreadyDone
          : VerifyOutcome.credited;
    } on ApiException catch (e) {
      const permanent = {'wrong_app', 'unknown_product', 'refunded_by_apple'};
      if (e.statusCode == 409 || permanent.contains(e.code)) {
        errorMessage = e.statusCode == 409
            ? 'Purchase error: This purchase was already added on another device.'
            : 'Purchase error: This purchase could not be used (${e.code}).';
        notifyListeners();
        return VerifyOutcome.rejected;
      }
      errorMessage =
          'Purchase error: Couldn\'t confirm your purchase yet. It will be added automatically the next time you open the app.';
      notifyListeners();
      return VerifyOutcome.retryLater;
    }
  }

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------

  Future<void> setAiAssistEnabled(bool value) async {
    aiAssistEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_aiAssistEnabledKey, value);
    notifyListeners();
  }

  void setVideoQuality(String quality) {
    if (isGenerating) return;
    if (quality != qualityStandard && quality != qualityHd) return;
    videoQuality = quality;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // History + Recently Deleted
  // ---------------------------------------------------------------------------

  /// Loads History and Recently Deleted, clearing out anything that has
  /// been in the trash for 30+ days first.
  Future<void> loadHistory() async {
    await historyService.purgeExpiredTrash();
    history = await historyService.loadHistory();
    trash = await historyService.loadTrash();
    notifyListeners();
  }

  /// Moves a video to Recently Deleted. Returns the trashed item so the
  /// UI can offer Undo.
  Future<TrashedEntry> deleteHistoryEntry(HistoryEntry entry) async {
    final item = await historyService.moveToTrash(entry);
    await loadHistory();
    return item;
  }

  Future<void> restoreFromTrash(TrashedEntry item) async {
    await historyService.restoreFromTrash(item);
    await loadHistory();
  }

  Future<void> deleteFromTrashForever(TrashedEntry item) async {
    await historyService.deleteForever(item);
    await loadHistory();
  }

  Future<void> emptyTrash() async {
    await historyService.emptyTrash();
    await loadHistory();
  }

  // ---------------------------------------------------------------------------
  // Script, scene image, dialogue
  // ---------------------------------------------------------------------------

  Future<void> assistScript() async {
    isAssisting = true;
    errorMessage = null;
    notifyListeners();
    try {
      final improved = await _geminiText.improvePrompt(scriptPrompt);
      scriptPrompt = improved;
      hasUsedAssist = true;
    } catch (e) {
      errorMessage = 'AI Assist: $e';
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
    final lines =
        dialogueLines.where((d) => d.line.trim().isNotEmpty).toList();
    if (lines.isNotEmpty) {
      buffer.write('Dialogue, in order. Speak only the words inside the '
          'quotes; never say the speaker labels: ');
      for (final d in lines) {
        final speaker =
            d.speaker.trim().isEmpty ? 'Speaker' : d.speaker.trim();
        buffer.write('[$speaker] "${d.line.trim()}" ');
      }
    }
    return buffer.toString().trim();
  }

  // ---------------------------------------------------------------------------
  // Generate (the server charges credits and refunds on failure)
  // ---------------------------------------------------------------------------

  Future<void> generate() async {
    errorMessage = null;
    isGenerating = true;
    generatedClipPaths = [];
    currentSegmentIndex = 0;
    totalSegments = 1;
    combinedExportPath = null;
    combineError = null;
    notifyListeners();

    try {
      List<int>? imageBytes;
      if (sceneImage != null) {
        imageBytes = await sceneImage!.readAsBytes();
      }
      final mime = (sceneImage != null &&
              (sceneImage!.path.toLowerCase().endsWith('.jpg') ||
                  sceneImage!.path.toLowerCase().endsWith('.jpeg')))
          ? 'image/jpeg'
          : 'image/png';

      final prompt = _buildCombinedPrompt();

      final start = await _minimax.generate(
        prompt: prompt,
        imageBytes: imageBytes,
        imageMimeType: mime,
        durationSeconds: videoDurationSeconds,
        quality: videoQuality,
      );
      if (start.balance != null) _setCredits(start.balance!);
      currentSegmentIndex = 1;
      notifyListeners();

      final finished = await _minimax.pollUntilComplete(
        start.taskId,
        onUpdate: (_) => notifyListeners(),
      );
      if (finished.balance != null) _setCredits(finished.balance!);

      if (finished.videoUri == null) {
        errorMessage = finished.errorMessage ??
            'Generation failed. Your credits were refunded.';
      } else {
        final dir = await getTemporaryDirectory();
        final localPath =
            '${dir.path}/output_${DateTime.now().millisecondsSinceEpoch}.mp4';
        final file =
            await _minimax.downloadVideo(finished.videoUri!, localPath);
        generatedClipPaths = [file.path];

        final entry = await historyService.saveToHistory(
          tempClipPaths: generatedClipPaths,
          scriptPrompt: prompt,
        );
        generatedClipPaths = entry.clipPaths;
        await loadHistory();
      }
    } on ApiException catch (e) {
      errorMessage = e.message;
      final b = e.body['balance'];
      if (b is num) _setCredits(b.toInt());
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isGenerating = false;
      notifyListeners();
      refreshBalance();
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
