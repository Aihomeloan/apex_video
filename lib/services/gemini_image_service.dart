import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env.dart';
import 'gemini_video_service.dart' show GeminiApiException;

class GeminiImageService {
  static const _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';
  static const _model = 'gemini-2.5-flash-image';

  // Always on. No user-facing toggle — every image this app generates is
  // instructed to look like a real photo, full stop.
  static const _realismPrefix =
      'A real photograph, captured on a professional DSLR camera with a '
      '50mm lens, natural window lighting, realistic human skin texture and '
      'pores, true-to-life fabric and material textures, candid documentary '
      'photography style. This is NOT an illustration, NOT a cartoon, NOT '
      'anime, NOT a 3D render, NOT digital art, NOT CGI — it is an actual '
      'unedited photo. Subject: ';

  Future<List<int>> generatePreviewImage(String prompt) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/models/$_model:generateContent'),
      headers: {
        'x-goog-api-key': Env.geminiApiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': '$_realismPrefix$prompt'}
            ]
          }
        ],
      }),
    );

    if (res.statusCode != 200) {
      throw GeminiApiException(res.statusCode, res.body);
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final parts = (decoded['candidates'] as List)[0]['content']['parts'] as List;
    for (final part in parts) {
      final inline = (part as Map<String, dynamic>)['inlineData'];
      if (inline != null) {
        return base64Decode(inline['data'] as String);
      }
    }
    throw Exception('No image returned — check the raw response.');
  }
}
