class CaptionCue {
  final Duration start;
  final Duration end;
  final String text;

  const CaptionCue({
    required this.start,
    required this.end,
    required this.text,
  });
}

String _assTimestamp(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  final cs = (d.inMilliseconds.remainder(1000) / 10).floor();
  String two(int n) => n.toString().padLeft(2, '0');
  return '$h:${two(m)}:${two(s)}.${two(cs)}';
}

/// Minimal ASS subtitle file — bold white text, dark pill background,
/// bottom-third placement.
String buildAssSubtitles(List<CaptionCue> cues) {
  const header = '''
[Script Info]
ScriptType: v4.00+
PlayResX: 1080
PlayResY: 1920

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, OutlineColour, BackColour, Bold, BorderStyle, Outline, Shadow, Alignment, MarginV
Style: Caption,Arial Black,64,&H00FFFFFF,&H00000000,&HAA000000,-1,3,2,0,2,120

[Events]
Format: Layer, Start, End, Style, Text
''';
  final lines = cues.map((c) =>
      'Dialogue: 0,${_assTimestamp(c.start)},${_assTimestamp(c.end)},Caption,${c.text}');
  return header + lines.join('\n');
}
