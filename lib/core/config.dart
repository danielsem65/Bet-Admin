class AppConfig {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String adminApiBase = String.fromEnvironment(
    'ADMIN_API_BASE',
    defaultValue: 'https://semdev.site.je',
  );
  static const String _storageBucketRaw = String.fromEnvironment(
    'STORAGE_BUCKET',
    defaultValue: '',
  );
  static const String storageBucket = _storageBucketRaw.isEmpty ? 'uploads' : _storageBucketRaw;
  static const String appName = 'Positive Elijoe Bet';

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
