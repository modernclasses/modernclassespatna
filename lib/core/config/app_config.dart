import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Application Configuration & Environment Management for Modern Classes Patna.
///
/// Supports runtime `.env` files and compile-time `--dart-define` flags.
/// Ensures zero secrets are hardcoded in the codebase.
class AppConfig {
  AppConfig._();

  static const String appName = "Modern Classes Patna";
  static const String appVersion = "1.0.0";
  static const String appBuildNumber = "1";

  /// Initialize environment configuration.
  static Future<void> initialize() async {
    try {
      await dotenv.load(fileName: ".env");
    } catch (_) {
      // .env file is optional if compile-time flags are used
    }
  }

  /// Safe lookup for dotenv without throwing NotInitializedError in tests
  static String? _getEnv(String key) {
    if (dotenv.isInitialized) {
      return dotenv.maybeGet(key);
    }
    return null;
  }

  // Environment: 'development', 'staging', 'production'
  static String get environment =>
      _getEnv('APP_ENV') ??
      const String.fromEnvironment(
        'APP_ENV',
        defaultValue: 'development',
      );

  // Supabase Configuration
  static String get supabaseUrl =>
      _getEnv('SUPABASE_URL') ??
      const String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: 'https://ajwbifguifbzqmpaxvug.supabase.co',
      );

  static String get supabaseAnonKey =>
      _getEnv('SUPABASE_ANON_KEY') ??
      const String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue: '',
      );

  // Support Contacts
  static String get supportEmail =>
      _getEnv('INSTITUTE_SUPPORT_EMAIL') ??
      const String.fromEnvironment(
        'INSTITUTE_SUPPORT_EMAIL',
        defaultValue: 'support@modernclassespatna.com',
      );

  static String get supportPhone =>
      _getEnv('INSTITUTE_SUPPORT_PHONE') ??
      const String.fromEnvironment(
        'INSTITUTE_SUPPORT_PHONE',
        defaultValue: '+91 9876543210',
      );

  static bool get isProduction => environment == 'production';
  static bool get isDevelopment => environment == 'development';

  /// Validates whether production Supabase credentials are configured.
  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseAnonKey.startsWith('placeholder');
}

