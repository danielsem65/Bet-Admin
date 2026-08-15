import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';

class SupabaseService {
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    if (!AppConfig.isConfigured) return;
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
    _initialized = true;
  }

  static SupabaseClient get client => Supabase.instance.client;
  static User? get user => client.auth.currentUser;
  static String get accessToken => client.auth.currentSession?.accessToken ?? '';

  static Future<bool> isAdmin() async {
    final id = user?.id;
    if (id == null || id.isEmpty) return false;
    try {
      final res = await client.from('profiles').select('role,banned_at').eq('id', id).maybeSingle();
      return res?['role'] == 'admin' && res?['banned_at'] == null;
    } catch (_) {
      return false;
    }
  }

  static Future<void> signOut() => client.auth.signOut();
}
