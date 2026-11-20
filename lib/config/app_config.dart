/// Build-time settings, passed in with
///   --dart-define-from-file=dart_defines.json
/// No API keys live here — those are on the ApexVideo server.
class AppConfig {
  static const workerUrl = String.fromEnvironment(
    'WORKER_URL',
    defaultValue: 'https://apexvideo-receipt-worker.goldenapexapps.workers.dev',
  );

  /// Not a real secret — it only blocks casual abuse of the server.
  /// The actual protection is the server-side credit ledger + Apple checks.
  static const appSecret = String.fromEnvironment('APP_SECRET');

  static bool get isConfigured => appSecret.isNotEmpty;
}
