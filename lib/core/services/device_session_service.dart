import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

/// Single Device Student Session Lock Service.
/// Enforces that a student account can only be active on one physical device at a time.
/// If credentials are shared and another device logs in, the previous device session is locked.
class DeviceSessionService {
  DeviceSessionService._();

  static String? _cachedDeviceId;

  static SupabaseClient? get _supabase {
    if (!AppConfig.isSupabaseConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Get or generate a persistent unique device installation identifier.
  static Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;

    try {
      final dir = Directory.systemTemp;
      final file = File('${dir.path}/mcp_device_session_id.lock');
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          _cachedDeviceId = content.trim();
          return _cachedDeviceId!;
        }
      }

      final random = Random.secure();
      final values = List<int>.generate(16, (i) => random.nextInt(256));
      final generated = values
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();

      await file.writeAsString(generated);
      _cachedDeviceId = generated;
      return generated;
    } catch (_) {
      _cachedDeviceId ??=
          'dev_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';
      return _cachedDeviceId!;
    }
  }

  /// Register current device for student upon successful login.
  static Future<void> registerDeviceSession(String userId) async {
    final deviceId = await getDeviceId();
    final client = _supabase;
    if (client == null || userId.isEmpty) return;

    try {
      await client
          .from('profiles')
          .update({'current_device_id': deviceId})
          .eq('id', userId);
      debugPrint(
        '🔒 Single-Device Session Registered: $deviceId for user $userId',
      );
    } catch (e) {
      debugPrint('Notice: Device session registration (graceful fallback): $e');
    }
  }

  /// Validate that the current device is still the authorized active device for this user.
  /// Returns false if another device has logged in with these credentials.
  static Future<bool> validateDeviceSession(String userId) async {
    final client = _supabase;
    if (client == null || userId.isEmpty) return true;

    try {
      final currentDeviceId = await getDeviceId();
      final res = await client
          .from('profiles')
          .select('current_device_id')
          .eq('id', userId)
          .maybeSingle();

      if (res != null && res['current_device_id'] != null) {
        final registeredDeviceId = res['current_device_id'].toString();
        if (registeredDeviceId.isNotEmpty &&
            registeredDeviceId != currentDeviceId) {
          debugPrint(
            '⚠️ Device session mismatch: Registered ($registeredDeviceId) != Current ($currentDeviceId)',
          );
          return false;
        }
      }
      return true;
    } catch (e) {
      debugPrint('Notice: Device session validation check: $e');
      return true;
    }
  }
}
