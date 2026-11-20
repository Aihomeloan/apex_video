import 'dart:convert';
import 'api_service.dart';

/// Scene image — made on the ApexVideo server (Gemini). No key in the app.
class GeminiImageService {
  Future<List<int>> generatePreviewImage(String prompt) async {
    final data = await ApiService.instance.post(
      '/image',
      {'prompt': prompt},
      timeout: const Duration(seconds: 120),
    );
    final b64 = data['imageBase64'] as String?;
    if (b64 == null || b64.isEmpty) {
      throw ApiException(
          0, 'no_image', 'No image came back. Try rewording the scene.');
    }
    return base64Decode(b64);
  }
}
