import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env.dart';
import 'gemini_video_service.dart' show GeminiApiException;

class GeminiTextService {
  static const _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';
  // gemini-2.5-flash-lite was retired for new API keys — Google's own
  // error pointed at this replacement.
  static const _model = 'gemini-3.5-flash-lite';

  static const _systemInstruction =
      'You write prompts for an AI video generator. Take the user\'s rough '
      'idea and rewrite it as one vivid, detailed paragraph (2-4 sentences) '
      'describing: the subject/who is in it, the setting, camera framing '
      '(e.g. medium shot, close-up), lighting/mood, and any action or '
      'dialogue. Be specific and concrete. Return ONLY the rewritten '
      'prompt — no preamble, no quotation marks, no labels.';

  Future<String> improvePrompt(String roughIdea) async {
    final input = roughIdea.trim().isEmpty
        ? 'A promo video for a mobile app'
        : roughIdea.trim();

    final res = await http.post(
      Uri.parse('$_baseUrl/models/$_model:generateContent'),
      headers: {
        'x-goog-api-key': Env.geminiApiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'systemInstruction': {
          'parts': [
            {'text': _systemInstruction}
          ]
        },
        'contents': [
          {
            'parts': [
              {'text': input}
            ]
          }
        ],
      }),
    );

    if (res.statusCode != 200) {
      throw GeminiApiException(res.statusCode, res.body);
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('No response from AI Assist.');
    }
    final parts = candidates[0]['content']['parts'] as List;
    final text = parts.map((p) => p['text'] ?? '').join();
    return text.trim();
  }
}
