class VideoBrief {
  String subject = '';
  String setting = '';
  String keyElementLabel = '';
  String keyElementSide = 'Right';
  String cameraShot = 'Medium shot';
  String mood = 'Warm & cozy';
  String dialogueOrCaption = '';
  int durationSeconds = 8;

  String buildPrompt() {
    final buffer = StringBuffer();
    buffer.write(
        'Photorealistic, shot on a DSLR camera, natural lighting, ultra '
        'realistic skin and textures, documentary-style — not illustrated, '
        'not cartoon, not 3D render. $cameraShot of $subject, set in $setting. ');
    if (keyElementLabel.trim().isNotEmpty) {
      final label = keyElementLabel.trim();
      buffer.write(
          '${label[0].toUpperCase()}${label.substring(1)} positioned on the '
          '$keyElementSide side of the frame. ');
    }
    buffer.write('Mood: $mood lighting and color grade.');
    if (dialogueOrCaption.trim().isNotEmpty) {
      buffer.write(' Dialogue/action: ${dialogueOrCaption.trim()}.');
    }
    return buffer.toString().trim();
  }
}
