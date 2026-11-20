import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'install_id.dart';

class ApiException implements Exception {
  final int statusCode; // 0 = network / no response
  final String code;
  final String message;
  final Map<String, dynamic> body;

  ApiException(this.statusCode, this.code, this.message,
      [this.body = const {}]);

  /// Worth retrying later (connection trouble or a server hiccup).
  bool get isTransient =>
      statusCode == 0 || statusCode == 429 || statusCode >= 500;

  @override
  String toString() => message;
}

/// The only thing in the app that talks to the ApexVideo server.
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    if (!AppConfig.isConfigured) {
      throw ApiException(
        0,
        'not_configured',
        'This build is missing APP_SECRET. Run it with '
            '--dart-define-from-file=dart_defines.json',
      );
    }

    final installId = await InstallId.get();
    http.Response res;
    try {
      res = await http
          .post(
            Uri.parse('${AppConfig.workerUrl}$path'),
            headers: {
              'Content-Type': 'application/json',
              'X-App-Secret': AppConfig.appSecret,
            },
            body: jsonEncode({...body, 'installId': installId}),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw ApiException(0, 'timeout',
          'The server took too long to answer. Check your connection and try again.');
    } catch (_) {
      throw ApiException(0, 'network',
          'Could not reach the server. Check your connection and try again.');
    }

    Map<String, dynamic> data = {};
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) data = decoded;
    } catch (_) {}

    if (res.statusCode >= 200 && res.statusCode < 300) return data;

    throw ApiException(
      res.statusCode,
      (data['error'] ?? 'http_${res.statusCode}').toString(),
      (data['message'] ?? 'Server error (${res.statusCode}).').toString(),
      data,
    );
  }

  /// Public settings (credit costs). No secret needed.
  Future<Map<String, dynamic>> getConfig() async {
    final res = await http
        .get(Uri.parse('${AppConfig.workerUrl}/config'))
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw ApiException(res.statusCode, 'config', 'Could not load settings.');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
