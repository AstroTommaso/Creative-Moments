/// Supplied at build time: flutter run --dart-define-from-file=.env
abstract final class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static const authRedirect = 'creativemoments://login-callback';
  static const resetRedirect = 'creativemoments://reset-callback';
}
