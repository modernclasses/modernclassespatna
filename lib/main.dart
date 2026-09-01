import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/config/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize environment configuration
  await AppConfig.initialize();

  // 2. Initialize Supabase if configured
  if (AppConfig.isSupabaseConfigured) {
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
      );
      debugPrint("✅ Connected to Supabase backend: ${AppConfig.supabaseUrl}");
    } catch (e) {
      debugPrint("⚠️ Supabase initialization note: $e");
    }
  } else {
    debugPrint("ℹ️ Running in local development mode (Mock Data active)");
  }

  runApp(const ModernClassesPatnaApp());
}

