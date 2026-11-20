import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A random ID for this device, kept in the iPhone Keychain.
///
/// The Keychain survives deleting the app, so after a reinstall the app
/// gets the same ID back — and the server still has that device's credits.
/// It's random, not tied to the person, and never leaves our own server.
class InstallId {
  static const _key = 'apexvideo_install_id';
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  static String? _cached;

  static Future<String> get() async {
    if (_cached != null) return _cached!;
    String? id;
    try {
      id = await _storage.read(key: _key);
    } catch (_) {}
    if (id == null || !_isValid(id)) {
      id = _newUuid();
      try {
        await _storage.write(key: _key, value: id);
      } catch (_) {}
    }
    _cached = id;
    return id;
  }

  static bool _isValid(String s) => RegExp(r'^[0-9a-f-]{36}$').hasMatch(s);

  static String _newUuid() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40; // version 4
    b[8] = (b[8] & 0x3f) | 0x80; // variant
    final hex = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
