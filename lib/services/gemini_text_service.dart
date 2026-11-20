import 'api_service.dart';

/// AI Assist — runs on the ApexVideo server (Gemini). No key in the app.
class GeminiTextService {
  Future<String> improvePrompt(String roughIdea) async {
    final data = await ApiService.instance.post(
      '/assist',
      {'text': roughIdea},
      timeout: const Duration(seconds: 60),
    );
    final text = (data['text'] as String?)?.trim() ?? '';
    if (text.isEmpty) {
      throw ApiException(0, 'assist_empty', 'No response from AI Assist.');
    }
    return text;
  }
}
