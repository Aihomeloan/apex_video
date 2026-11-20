import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/caption_cue.dart';
import '../services/ffmpeg_service.dart';
import '../services/photo_save_service.dart';
import '../state/project_state.dart';
import 'credits_screen.dart';
import 'fullscreen_video_viewer.dart';
import 'gold_shimmer_border.dart';
import 'history_screen.dart';
import 'sequential_video_player.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scriptController = TextEditingController();
  bool _controllerInitialized = false;

  /// True while the full-screen player is open. The small preview is
  /// removed during that time so only ONE player is ever playing —
  /// otherwise both play at once and you hear the voice twice.
  bool _fullscreenOpen = false;

  bool _savingToPhotos = false;

  @override
  void dispose() {
    _scriptController.dispose();
    super.dispose();
  }

  Future<void> _handleAssist(ProjectState state) async {
    state.setScript(_scriptController.text);
    await state.assistScript();
    if (mounted) {
      _scriptController.text = state.scriptPrompt;
      _scriptController.selection = TextSelection.collapsed(
        offset: _scriptController.text.length,
      );
    }
  }

  Future<void> _openFullscreen(
      BuildContext context, ProjectState state, List<String> paths) async {
    if (_fullscreenOpen) return;
    setState(() => _fullscreenOpen = true);
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FullscreenVideoViewer(
          filePaths: paths,
          shareText: state.scriptPrompt,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _fullscreenOpen = false);
    if (result == kFullscreenResultNew) {
      await _startNewVideo(state, confirm: false);
    }
  }

  void _handleVerticalDragEnd(BuildContext context, ProjectState state,
      DragEndDetails details, List<String> paths) {
    final double velocity = details.primaryVelocity ?? 0.0;
    final bool isSwipeUp = velocity < -200.0;
    if (isSwipeUp) {
      _openFullscreen(context, state, paths);
    }
  }

  /// [buttonContext] is the Share button's own context, so iPad knows
  /// where to anchor the share popover (without it, iPad can crash).
  Future<void> _shareCurrent(
      BuildContext buttonContext, ProjectState state) async {
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin = (box != null && box.hasSize)
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    final files = state.generatedClipPaths.map((p) => XFile(p)).toList();
    await Share.shareXFiles(
      files,
      text: state.scriptPrompt,
      sharePositionOrigin: origin,
    );
  }

  Future<void> _saveCurrentToPhotos(ProjectState state) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _savingToPhotos = true);
    String? err;
    for (final p in state.generatedClipPaths) {
      err = await PhotoSaveService.saveVideo(p);
      if (err != null) break;
    }
    if (!mounted) return;
    setState(() => _savingToPhotos = false);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(err ?? 'Saved to Photos.')));
  }

  /// Clears the scene, image, dialogue and current video so the user can
  /// start the next one. The finished video is already in History.
  Future<void> _startNewVideo(ProjectState state, {bool confirm = true}) async {
    if (state.isGenerating) return;
    if (confirm) {
      final hasVideo = state.generatedClipPaths.isNotEmpty;
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Start a new video?'),
          content: Text(
            hasVideo
                ? 'Your current video is already saved in History. This '
                    'clears the scene, image, and dialogue so you can start fresh.'
                : 'This clears the scene, image, and dialogue so you can '
                    'start fresh.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Start new'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await state.deleteVideoAndScript();
    if (mounted) {
      setState(() => _scriptController.clear());
    }
  }

  void _onMenuSelected(String value, ProjectState state) {
    switch (value) {
      case 'new':
        _startNewVideo(state);
        break;
      case 'history':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const HistoryScreen()),
        );
        break;
      case 'credits':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreditsScreen()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProjectState>();

    if (!_controllerInitialized) {
      _scriptController.text = state.scriptPrompt;
      _controllerInitialized = true;
    }

    final hasContentToClear = state.generatedClipPaths.isNotEmpty ||
        state.scriptPrompt.isNotEmpty ||
        state.sceneImage != null ||
        state.dialogueLines.isNotEmpty;
    final creditsNeeded = state.creditsNeeded;
    final locked = state.isGenerating;
    final assistDisabled = state.isAssisting || state.isGenerating;
    final hasVideo = state.generatedClipPaths.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ApexVideo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'History',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
          ),
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CreditsScreen()),
            ),
            icon: const Icon(Icons.bolt, size: 18, color: Colors.amber),
            label: Text('${state.credits}',
                style: const TextStyle(color: Colors.amber)),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz),
            tooltip: 'More',
            onSelected: (v) => _onMenuSelected(v, state),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'new',
                enabled: hasContentToClear && !locked,
                child: const ListTile(
                  leading: Icon(Icons.add_circle_outline),
                  title: Text('New video'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'history',
                child: ListTile(
                  leading: Icon(Icons.history),
                  title: Text('History'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'credits',
                child: ListTile(
                  leading: Icon(Icons.bolt),
                  title: Text('Buy credits'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: SizedBox(
                      height: 240,
                      width: double.infinity,
                      child: !hasVideo
                          ? _emptyPreview()
                          : (_fullscreenOpen
                              ? _playingFullscreenPlaceholder()
                              : Stack(
                                  children: [
                                    Positioned.fill(
                                      child: GestureDetector(
                                        onTap: () => _openFullscreen(context,
                                            state, state.generatedClipPaths),
                                        onVerticalDragEnd: (details) =>
                                            _handleVerticalDragEnd(
                                                context,
                                                state,
                                                details,
                                                state.generatedClipPaths),
                                        child: Center(
                                          child: SequentialVideoPlayer(
                                            key: ValueKey(state
                                                .generatedClipPaths
                                                .join(',')),
                                            filePaths: state.generatedClipPaths,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const Positioned(
                                      bottom: 6,
                                      left: 0,
                                      right: 0,
                                      child: Center(
                                        child: Text(
                                          'Tap or swipe up for full screen',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Builder(
                                        builder: (btnContext) =>
                                            IconButton.filled(
                                          style: IconButton.styleFrom(
                                            backgroundColor: Colors.amber,
                                            foregroundColor: Colors.black,
                                            side: const BorderSide(
                                                color: Colors.white,
                                                width: 1.5),
                                            padding: const EdgeInsets.all(10),
                                          ),
                                          icon: const Icon(Icons.ios_share,
                                              size: 24),
                                          tooltip: 'Share',
                                          onPressed: () =>
                                              _shareCurrent(btnContext, state),
                                        ),
                                      ),
                                    ),
                                  ],
                                )),
                    ),
                  ),

                  // After a video is made: save it, or move on to the next.
                  if (hasVideo)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: _savingToPhotos
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Icon(Icons.download, size: 18),
                                  label: const Text('Save to Photos'),
                                  onPressed: _savingToPhotos
                                      ? null
                                      : () => _saveCurrentToPhotos(state),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('New video'),
                                  onPressed: locked
                                      ? null
                                      : () => _startNewVideo(state),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'This video is saved in History automatically.',
                            style:
                                TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),

                  _bottomPanel(context, state, creditsNeeded, locked,
                      assistDisabled),
                ],
              ),
            ),
            const Positioned.fill(child: GoldShimmerBorder()),
          ],
        ),
      ),
    );
  }

  Widget _playingFullscreenPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.black,
      ),
      alignment: Alignment.center,
      child: const Text('Playing full screen…',
          style: TextStyle(color: Colors.grey)),
    );
  }

  Widget _emptyPreview() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.2)),
        color: const Color(0xFF111111),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.movie_creation_outlined,
              size: 48, color: Colors.amber.withOpacity(0.4)),
          const SizedBox(height: 8),
          const Text('Your video will appear here',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _bottomPanel(BuildContext context, ProjectState state,
      int creditsNeeded, bool locked, bool assistDisabled) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        border: Border(top: BorderSide(color: Colors.amber.withOpacity(0.2))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('1. Starting image — describe the scene'),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome,
                            size: 14, color: Colors.amber),
                        const SizedBox(width: 6),
                        const Text('AI Assisted Prompt',
                            style: TextStyle(fontSize: 11)),
                        const Spacer(),
                        Transform.scale(
                          scale: 0.75,
                          child: Switch(
                            value: state.aiAssistEnabled,
                            activeColor: Colors.amber,
                            onChanged: (v) => state.setAiAssistEnabled(v),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.keyboard_hide,
                              size: 18, color: Colors.grey),
                          tooltip: 'Hide keyboard',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => FocusScope.of(context).unfocus(),
                        ),
                      ],
                    ),
                    TextField(
                      controller: _scriptController,
                      minLines: 2,
                      maxLines: 2,
                      maxLength: 1000,
                      textInputAction: TextInputAction.done,
                      onEditingComplete: () =>
                          FocusScope.of(context).unfocus(),
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'e.g. girl in a bikini and guy on a '
                            'surfboard at the beach',
                        counterStyle:
                            const TextStyle(fontSize: 10, color: Colors.grey),
                        suffixIcon: !state.aiAssistEnabled
                            ? null
                            : (state.isAssisting
                                ? const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.auto_awesome,
                                        color: Colors.amber, size: 18),
                                    tooltip: 'Improve with AI — free',
                                    onPressed: assistDisabled
                                        ? null
                                        : () => _handleAssist(state),
                                  )),
                      ),
                      onChanged: state.setScript,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (state.sceneImage != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(state.sceneImage!,
                                width: 40, height: 40, fit: BoxFit.cover),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed:
                                locked ? null : () => state.clearSceneImage(),
                          ),
                          const Spacer(),
                        ] else
                          const Spacer(),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.upload, size: 16),
                          label: const Text('Upload',
                              style: TextStyle(fontSize: 12)),
                          onPressed: locked
                              ? null
                              : () async {
                                  final file = await FilePicker.pickFile(
                                      type: FileType.image);
                                  if (file?.path != null) {
                                    state.setSceneImage(File(file!.path!));
                                  }
                                },
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                          ),
                          icon: state.isGeneratingPreview
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.black),
                                )
                              : const Icon(Icons.auto_awesome, size: 16),
                          label: const Text('Generate w/ Gemini',
                              style: TextStyle(fontSize: 12)),
                          onPressed: (locked || state.isGeneratingPreview)
                              ? null
                              : () => state.generateSceneImage(),
                        ),
                      ],
                    ),
                    if (state.previewError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(state.previewError!,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.redAccent)),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              _sectionLabel(
                  '2. Dialogue (${state.dialogueLines.length}/${ProjectState.maxDialogueLines})'),
              const SizedBox(height: 4),
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                  children: [
                    TextSpan(
                      text: '${state.spokenWordCount}/${state.wordBudget} words',
                      style: const TextStyle(color: Colors.amber),
                    ),
                    TextSpan(
                      text: state.isOverWordBudget
                          ? " — trim it down so MiniMax doesn't rush the delivery"
                          : ' — good pace for ${state.videoDurationSeconds}s',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              for (int i = 0; i < state.dialogueLines.length; i++)
                _DialogueRow(
                  key: ValueKey(state.dialogueLines[i].id),
                  index: i,
                  line: state.dialogueLines[i],
                  locked: locked,
                  onRemove: () => state.removeDialogueLine(i),
                  onSpeakerChanged: (v) => state.updateDialogueSpeaker(i, v),
                  onLineChanged: (v) => state.updateDialogueLineText(i, v),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add dialogue line',
                      style: TextStyle(fontSize: 12)),
                  onPressed: (locked ||
                          state.dialogueLines.length >=
                              ProjectState.maxDialogueLines)
                      ? null
                      : () => state.addDialogueLine(),
                ),
              ),

              const SizedBox(height: 8),
              _sectionLabel('3. Length & quality'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ProjectState.durationOptions.map((seconds) {
                  return ChoiceChip(
                    label: Text('${seconds}s'),
                    selected: state.videoDurationSeconds == seconds,
                    onSelected:
                        locked ? null : (_) => state.setVideoDuration(seconds),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(
                        'Standard · ${state.costFor(ProjectState.qualityStandard, state.videoDurationSeconds)} credits'),
                    selected:
                        state.videoQuality == ProjectState.qualityStandard,
                    onSelected: locked
                        ? null
                        : (_) =>
                            state.setVideoQuality(ProjectState.qualityStandard),
                  ),
                  ChoiceChip(
                    label: Text(
                        'HD 2K · ${state.costFor(ProjectState.qualityHd, state.videoDurationSeconds)} credits'),
                    selected: state.videoQuality == ProjectState.qualityHd,
                    onSelected: locked
                        ? null
                        : (_) => state.setVideoQuality(ProjectState.qualityHd),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              Text(
                '$creditsNeeded credits needed (you have ${state.credits}).',
                style: TextStyle(
                  fontSize: 12,
                  color: state.credits >= creditsNeeded
                      ? Colors.grey
                      : Colors.redAccent,
                ),
              ),

              if (state.errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(state.errorMessage!,
                    style: const TextStyle(
                        color: Colors.redAccent, fontSize: 12)),
              ],

              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: locked
                      ? null
                      : () => _handleGeneratePressed(
                          context, state, creditsNeeded),
                  icon: locked
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.movie_creation),
                  label: locked
                      ? const _GeneratingLabel()
                      : const Text('Generate with MiniMax'),
                ),
              ),
              if (locked)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'MiniMax dialogue clips can take up to ~5 minutes — '
                    'this is normal, not stuck.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),

              if (state.canCombineWithPrevious) ...[
                const SizedBox(height: 10),
                _CombineSection(),
              ],

              if (state.generatedClipPaths.isNotEmpty) ...[
                const SizedBox(height: 10),
                _ExportSection(scriptText: state.scriptPrompt),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      );

  Future<void> _handleGeneratePressed(
      BuildContext context, ProjectState state, int creditsNeeded) async {
    FocusScope.of(context).unfocus();

    if (state.scriptPrompt.trim().isEmpty &&
        state.dialogueLines.every((d) => d.line.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Add a scene description or dialogue first.')),
      );
      return;
    }

    if (state.credits < creditsNeeded) {
      final wantsToBuy = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Not enough credits'),
          content: Text(
            'This needs $creditsNeeded credits, but you have ${state.credits}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Buy credits'),
            ),
          ],
        ),
      );
      if (wantsToBuy == true && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreditsScreen()),
        );
      }
      return;
    }
    state.generate();
  }
}

class _GeneratingLabel extends StatefulWidget {
  const _GeneratingLabel();

  @override
  State<_GeneratingLabel> createState() => _GeneratingLabelState();
}

class _GeneratingLabelState extends State<_GeneratingLabel> {
  late final Timer _timer;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = (_seconds ~/ 60).toString().padLeft(1, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return Text('Generating… $m:$s');
  }
}

class _DialogueRow extends StatefulWidget {
  final int index;
  final dynamic line; // DialogueLine
  final bool locked;
  final VoidCallback onRemove;
  final ValueChanged<String> onSpeakerChanged;
  final ValueChanged<String> onLineChanged;

  const _DialogueRow({
    super.key,
    required this.index,
    required this.line,
    required this.locked,
    required this.onRemove,
    required this.onSpeakerChanged,
    required this.onLineChanged,
  });

  @override
  State<_DialogueRow> createState() => _DialogueRowState();
}

class _DialogueRowState extends State<_DialogueRow> {
  late final TextEditingController _speakerController;
  late final TextEditingController _lineController;

  @override
  void initState() {
    super.initState();
    _speakerController = TextEditingController(text: widget.line.speaker);
    _lineController = TextEditingController(text: widget.line.line);
  }

  @override
  void dispose() {
    _speakerController.dispose();
    _lineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: TextField(
              controller: _speakerController,
              enabled: !widget.locked,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Name',
                hintStyle: TextStyle(fontSize: 11),
                border: OutlineInputBorder(),
              ),
              onChanged: widget.onSpeakerChanged,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _lineController,
              enabled: !widget.locked,
              maxLines: 1,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'e.g. Let\'s hit the waves, Daisy!',
                hintStyle: const TextStyle(fontSize: 11),
                border: const OutlineInputBorder(),
              ),
              onChanged: widget.onLineChanged,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: widget.locked ? null : widget.onRemove,
          ),
        ],
      ),
    );
  }
}

class _CombineSection extends StatelessWidget {
  const _CombineSection();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProjectState>();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Combine with your last video into one ~30s video?',
            style: TextStyle(fontSize: 13, color: Colors.amber),
          ),
          const SizedBox(height: 4),
          const Text(
            'Crossfade blends straight into the next clip. Splash screen '
            'inserts a short branded card between them first.',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: state.isCombining
                      ? null
                      : () =>
                          state.combineWithPrevious(useSplashBridge: false),
                  child: const Text('Crossfade',
                      style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: state.isCombining
                      ? null
                      : () =>
                          state.combineWithPrevious(useSplashBridge: true),
                  child: state.isCombining
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('With splash screen',
                          style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
          if (state.combineError != null) ...[
            const SizedBox(height: 8),
            Text(state.combineError!,
                style: const TextStyle(fontSize: 11, color: Colors.redAccent)),
          ],
          if (state.combinedExportPath != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle,
                    size: 14, color: Colors.greenAccent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Combined: ${state.combinedExportPath}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ExportSection extends StatefulWidget {
  final String scriptText;
  const _ExportSection({required this.scriptText});

  @override
  State<_ExportSection> createState() => _ExportSectionState();
}

class _ExportSectionState extends State<_ExportSection> {
  String? _exportedPath;
  bool _exporting = false;

  Future<void> _export(ProjectState state) async {
    if (state.generatedClipPaths.isEmpty) return;
    setState(() => _exporting = true);
    try {
      final dir = Directory.systemTemp;
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final mergedPath = '${dir.path}/merged_$stamp.mp4';

      await FfmpegService.concatClips(
        clipPaths: state.generatedClipPaths,
        outputPath: mergedPath,
      );

      final cues = [
        CaptionCue(
          start: Duration.zero,
          end: const Duration(seconds: 4),
          text: widget.scriptText.isEmpty
              ? 'Your caption here'
              : widget.scriptText,
        ),
      ];
      final assPath = '${dir.path}/captions_$stamp.ass';
      await File(assPath).writeAsString(buildAssSubtitles(cues));

      final finalPath = '${dir.path}/final_$stamp.mp4';
      await FfmpegService.burnCaptions(
        videoPath: mergedPath,
        assSubtitlePath: assPath,
        outputPath: finalPath,
      );

      setState(() => _exportedPath = finalPath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProjectState>();

    // iPhone: Save to Photos / Share are right under the video, so no
    // extra note is needed here. The caption export is Mac-only.
    if (!Platform.isMacOS) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _exporting ? null : () => _export(state),
            icon: _exporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_download),
            label: Text(_exporting
                ? 'Exporting…'
                : (_exportedPath != null ? 'Exported ✓' : 'Export final MP4')),
          ),
        ),
      ],
    );
  }
}
