class AppConfig {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String adminApiBase = String.fromEnvironment(
    'ADMIN_API_BASE',
    defaultValue: 'https://semdev.site.je',
  );
  static const String appName = 'Positive Elijoe Bet Admin';

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
