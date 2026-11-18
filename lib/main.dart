import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/config/app_config.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/security_protection_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Enable OS-level anti-piracy screen protection (FLAG_SECURE)
  await SecurityProtectionService.enableScreenProtection();

  // 2. Initialize environment configuration
  await AppConfig.initialize();

  // 3. Initialize Firebase & Push Notification Service
  await PushNotificationService.initialize();

  // 4. Initialize Supabase if configured
  if (AppConfig.isSupabaseConfigured) {
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: AppConfig.supabaseAnonKey,
      );
      debugPrint("✅ Connected to Supabase backend: ${AppConfig.supabaseUrl}");
    } catch (e) {
      debugPrint("⚠️ Supabase initialization note: $e");
    }
  } else {
    debugPrint(
      "ℹ️ Supabase credentials not detected. Running in offline mode.",
    );
  }

  runApp(const ModernClassesPatnaApp());
}
