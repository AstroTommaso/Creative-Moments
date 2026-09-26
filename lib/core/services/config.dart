/// Supplied at build time: flutter run --dart-define-from-file=.env
abstract final class AppConfig {
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static bool get isConfigured => apiBaseUrl.isNotEmpty;
}
