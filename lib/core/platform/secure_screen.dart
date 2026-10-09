import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Activa FLAG_SECURE en Android para bloquear capturas mientras hay QR en pantalla.
class SecureScreen {
  SecureScreen._();
  static const _channel = MethodChannel('com.gympasscontrol.gym/secure_screen');

  static Future<void> enable() => _call('enable');
  static Future<void> disable() => _call('disable');

  static Future<void> _call(String method) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod(method);
    } catch (_) {
      // No crítico: la protección es "best effort".
    }
  }
}
