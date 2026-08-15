import 'package:flutter/services.dart';

/// Native window controls for the frameless desktop window.
/// Backed by the `admin_window` MethodChannel implemented in the
/// Windows runner (ci/windows/flutter_window.cpp).
class AdminWindow {
  static const _channel = MethodChannel('admin_window');

  static Future<void> minimize() => _channel.invokeMethod('minimize');

  static Future<void> toggleFullScreen() =>
      _channel.invokeMethod('toggleFullScreen');

  static Future<void> close() => _channel.invokeMethod('close');
}
