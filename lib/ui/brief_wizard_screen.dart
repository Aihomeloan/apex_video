import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/project_state.dart';
import 'home_screen.dart';

class BriefWizardScreen extends StatefulWidget {
  const BriefWizardScreen({super.key});

  @override
  State<BriefWizardScreen> createState() => _BriefWizardScreenState();
}

class _BriefWizardScreenState extends State<BriefWizardScreen> {
  int _step = 0;
  static const _totalSteps = 7;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProjectState>();
    final brief = state.brief;
    final hasContentToDelete = state.generatedClipPaths.isNotEmpty ||
        state.scriptPrompt.isNotEmpty ||
        state.previewImagePath != null ||
        brief.subject.isNotEmpty ||
        brief.setting.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text('Build your video (${_step + 1}/$_totalSteps)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete video & script',
            onPressed:
                hasContentToDelete ? () => _confirmDelete(context, state) : null,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(value: (_step + 1) / _totalSteps),
            const SizedBox(height: 24),
            Expanded(child: _buildStep(state, brief)),
            const SizedBox(height: 8),
            const Text(
              'Continue typing to add more detail — it\'s fine to keep '
              'going. Tap Next when you\'re ready.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _step == 0 ? null : () => setState(() => _step--),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back'),
                ),
                FilledButton(
                  onPressed: () {
                    if (_step < _totalSteps - 1) {
                      setState(() => _step++);
                    } else {
                      state.generatePreview();
                      _showPreviewSheet(context);
                    }
                  },
                  child: Text(_step < _totalSteps - 1 ? 'Next' : 'Preview'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, ProjectState state) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete video & script?'),
        content: const Text(
          'This deletes every generated clip and the preview image from '
          'your device and clears everything you\'ve entered in this '
          'wizard. This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await state.deleteVideoAndScript();
      if (mounted) {
        setState(() => _step = 0);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video and script deleted.')),
        );
      }
    }
  }

  Widget _buildStep(ProjectState state, brief) {
    switch (_step) {
      case 0:
        return _textStep(
          label: 'Who or what is the subject?',
          hint: 'e.g. a couple in their kitchen',
          initial: brief.subject,
          onChanged: (v) => brief.subject = v,
        );
      case 1:
        return _textStep(
          label: 'Where is it set?',
          hint: 'e.g. modern kitchen, morning light',
          initial: brief.setting,
          onChanged: (v) => brief.setting = v,
        );
      case 2:
        return _textStep(
          label: 'Any key visual element to place deliberately? (optional)',
          hint: 'e.g. trees, a plant, a window',
          initial: brief.keyElementLabel,
          onChanged: (v) => brief.keyElementLabel = v,
        );
      case 3:
        return _choiceStep(
          label: 'Which side should it be on?',
          options: const ['Left', 'Right', 'Center', "Doesn't matter"],
          selected: brief.keyElementSide,
          onSelected: (v) => setState(() => brief.keyElementSide = v),
        );
      case 4:
        return _choiceStep(
          label: 'Camera framing',
          options: const [
            'Close-up shot',
            'Medium shot',
            'Wide shot',
            'Over-the-shoulder shot',
          ],
          selected: brief.cameraShot,
          onSelected: (v) => setState(() => brief.cameraShot = v),
        );
      case 5:
        return _choiceStep(
          label: 'Mood / lighting',
          options: const ['Warm & cozy', 'Energetic', 'Cinematic', 'Minimal & clean'],
          selected: brief.mood,
          onSelected: (v) => setState(() => brief.mood = v),
        );
      case 6:
      default:
        return _textStep(
          label: 'Dialogue or key action? (optional)',
          hint: 'e.g. she says "wait, look at this!"',
          initial: brief.dialogueOrCaption,
          onChanged: (v) => brief.dialogueOrCaption = v,
          maxLines: 3,
        );
    }
  }

  Widget _textStep({
    required String label,
    required String hint,
    required String initial,
    required ValueChanged<String> onChanged,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: initial,
          maxLines: maxLines,
          decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder()),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _choiceStep({
    required String label,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            return ChoiceChip(
              label: Text(opt),
              selected: selected == opt,
              onSelected: (_) => onSelected(opt),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _showPreviewSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Consumer<ProjectState>(
          builder: (context, state, _) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        tooltip: 'Back to editing',
                        onPressed: () => Navigator.of(sheetContext).pop(),
                      ),
                      Text('Preview', style: Theme.of(context).textTheme.titleLarge),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (state.isGeneratingPreview)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    )
                  else if (state.previewError != null)
                    Text(state.previewError!,
                        style: const TextStyle(color: Colors.redAccent))
                  else if (state.previewImagePath != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(File(state.previewImagePath!), height: 400),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: state.isGeneratingPreview
                              ? null
                              : () => state.generatePreview(),
                          child: const Text('Regenerate'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: state.previewImagePath == null
                              ? null
                              : () {
                                  state.approvePreview();
                                  Navigator.of(sheetContext).pop();
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) => const HomeScreen()),
                                  );
                                },
                          child: const Text('Looks good →'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
