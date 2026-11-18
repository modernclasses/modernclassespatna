import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service to enforce Android OS hardware-level Anti-Piracy (FLAG_SECURE).
/// Prevents screenshots, screen recorders, external capture, and blanking in recent apps.
class SecurityProtectionService {
  SecurityProtectionService._();

  static const MethodChannel _channel = MethodChannel(
    'com.modernclasses.patna/security',
  );

  /// Enable FLAG_SECURE on the native Android Window.
  static Future<bool> enableScreenProtection() async {
    try {
      final res = await _channel.invokeMethod<bool>('enableSecure');
      debugPrint(
        '🛡️ Anti-Piracy Screen Recording & Screenshot Protection: ENABLED',
      );
      return res ?? true;
    } catch (e) {
      debugPrint(
        'Notice: SecurityProtectionService.enableScreenProtection error: $e',
      );
      return false;
    }
  }

  /// Disable FLAG_SECURE (e.g. for debug screenshots if required).
  static Future<bool> disableScreenProtection() async {
    try {
      final res = await _channel.invokeMethod<bool>('disableSecure');
      debugPrint('🛡️ Anti-Piracy Screen Recording Protection: DISABLED');
      return res ?? true;
    } catch (e) {
      debugPrint(
        'Notice: SecurityProtectionService.disableScreenProtection error: $e',
      );
      return false;
    }
  }

  /// Query active status of FLAG_SECURE on current Window.
  static Future<bool> isSecureActive() async {
    try {
      final res = await _channel.invokeMethod<bool>('isSecureEnabled');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }
}
