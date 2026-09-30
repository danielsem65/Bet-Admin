import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';

/// Outcome of an admin role check.
///
/// [offline] exists so a network failure is never mistaken for "not an admin".
/// Collapsing the two into a single `false` is what used to sign the admin out
/// whenever the app was opened without a connection.
enum AdminStatus { admin, notAdmin, offline }

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

  /// Resolves the account's admin role, separating "cannot reach the server"
  /// from "server says this is not an admin".
  static Future<AdminStatus> adminStatus() async {
    final id = user?.id;
    if (id == null || id.isEmpty) return AdminStatus.notAdmin;
    try {
      final res = await client
          .from('profiles')
          .select('role,banned_at')
          .eq('id', id)
          .maybeSingle();
      final allowed = res?['role'] == 'admin' && res?['banned_at'] == null;
      return allowed ? AdminStatus.admin : AdminStatus.notAdmin;
    } catch (e) {
      return _isNetworkFailure(e) ? AdminStatus.offline : AdminStatus.notAdmin;
    }
  }

  /// Supabase wraps transport errors, so match on the rendered text as well as
  /// the concrete exception types.
  static bool _isNetworkFailure(Object error) {
    if (error is SocketException) return true;
    if (error is TimeoutException) return true;
    final text = error.toString().toLowerCase();
    const markers = [
      'socketexception',
      'failed host lookup',
      'no address associated',
      'network is unreachable',
      'connection closed',
      'connection refused',
      'connection reset',
      'connection terminated',
      'handshake',
      'timed out',
      'timeout',
    ];
    return markers.any(text.contains);
  }

  static Future<void> signOut() => client.auth.signOut();
}
