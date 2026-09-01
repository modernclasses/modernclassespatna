/// Application Configuration & Environment Management for Modern Classes Patna.
///
/// Supports compile-time environment variables (`--dart-define`) and runtime fallback.
/// Ensures zero secrets are hardcoded in the codebase.
class AppConfig {
  AppConfig._();

  static const String appName = "Modern Classes Patna";
  static const String appVersion = "1.0.0";
  static const String appBuildNumber = "1";

  // Environment: 'development', 'staging', 'production'
  static const String environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  // Supabase Configuration
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://placeholder.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'placeholder-anon-key',
  );

  // Support Contacts
  static const String supportEmail = String.fromEnvironment(
    'INSTITUTE_SUPPORT_EMAIL',
    defaultValue: 'support@modernclassespatna.com',
  );

  static const String supportPhone = String.fromEnvironment(
    'INSTITUTE_SUPPORT_PHONE',
    defaultValue: '+91 9876543210',
  );

  static bool get isProduction => environment == 'production';
  static bool get isDevelopment => environment == 'development';

  /// Validates whether production credentials are configured properly.
  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseUrl != 'https://placeholder.supabase.co' &&
      supabaseAnonKey.isNotEmpty &&
      supabaseAnonKey != 'placeholder-anon-key';
}
