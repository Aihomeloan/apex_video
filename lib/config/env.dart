import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static Future<void> load() async {
    await dotenv.load(fileName: '.env');
  }

  static String get geminiApiKey => _require('GEMINI_API_KEY');
  static String get minimaxApiKey => _require('MINIMAX_API_KEY');

  static String _require(String key) {
    final value = dotenv.env[key];
    if (value == null || value.isEmpty) {
      throw StateError('$key is missing. Add it to .env.');
    }
    return value;
  }
}
