import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Thin wrapper over connectivity_plus.
///
/// The plugin only reports which interfaces are up, not whether traffic can
/// actually reach the internet (a hotel Wi-Fi with a captive portal still
/// looks connected), so this is treated as a hint. The real guard is the
/// network-failure branch in [SupabaseService.adminStatus].
class ConnectivityService {
  ConnectivityService._();

  static final Connectivity _plugin = Connectivity();

  /// Emits whenever the set of available interfaces changes.
  static Stream<List<ConnectivityResult>> get onChange =>
      _plugin.onConnectivityChanged;

  static bool _hasLink(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  /// Best-effort check used before touching the network at startup.
  ///
  /// Returns `true` when the check itself fails, so an inconclusive probe
  /// never blocks the app from starting.
  static Future<bool> isOnline() async {
    try {
      final results = await _plugin.checkConnectivity();
      return _hasLink(results);
    } catch (_) {
      return true;
    }
  }
}
