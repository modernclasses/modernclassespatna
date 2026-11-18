import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../errors/exceptions.dart';

/// Configuration entity for Cloudflare / RTMP live broadcasts.
class LiveStreamConfig {
  final String rtmpUrl;
  final String streamKey;
  final String playbackUrl;

  const LiveStreamConfig({
    this.rtmpUrl = '',
    this.streamKey = '',
    this.playbackUrl = '',
  });

  bool get isConfigured =>
      rtmpUrl.isNotEmpty &&
      (rtmpUrl.startsWith('rtmp://') || rtmpUrl.startsWith('rtmps://')) &&
      streamKey.isNotEmpty;

  LiveStreamConfig copyWith({
    String? rtmpUrl,
    String? streamKey,
    String? playbackUrl,
  }) {
    return LiveStreamConfig(
      rtmpUrl: rtmpUrl ?? this.rtmpUrl,
      streamKey: streamKey ?? this.streamKey,
      playbackUrl: playbackUrl ?? this.playbackUrl,
    );
  }
}

/// Service to read and persist institute-wide platform settings in Supabase and SharedPreferences.
class PlatformSettingsService {
  PlatformSettingsService._();

  static const String _kRtmpUrlKey = 'platform_live_rtmps_url';
  static const String _kStreamKeyKey = 'platform_live_stream_key';
  static const String _kPlaybackUrlKey = 'platform_live_playback_url';

  static LiveStreamConfig _cachedConfig = const LiveStreamConfig();

  static SupabaseClient? get _supabase {
    if (!AppConfig.isSupabaseConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Directly updates the in-memory configuration cache.
  static void updateMemoryCache(LiveStreamConfig config) {
    _cachedConfig = config;
  }

  /// Resets configuration cache for isolated testing.
  @visibleForTesting
  static void resetCacheForTesting() {
    _cachedConfig = const LiveStreamConfig();
  }

  /// Fetches live stream settings from Supabase (`cloudflare_live_inputs` primary or `platform_settings`)
  /// with SharedPreferences fallback.
  static Future<LiveStreamConfig> getLiveStreamConfig({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cachedConfig.isConfigured) {
      return _cachedConfig;
    }

    final client = _supabase;
    if (client != null) {
      // 1. Check for primary live input in cloudflare_live_inputs table
      try {
        final primaryRes = await client
            .from('cloudflare_live_inputs')
            .select()
            .eq('is_primary', true)
            .eq('is_active', true)
            .maybeSingle();

        if (primaryRes != null) {
          final rtmp = primaryRes['rtmps_url']?.toString() ?? '';
          final key = primaryRes['stream_key']?.toString() ?? '';
          final playback = primaryRes['playback_url']?.toString() ?? '';

          if (rtmp.isNotEmpty && key.isNotEmpty) {
            _cachedConfig = LiveStreamConfig(
              rtmpUrl: rtmp,
              streamKey: key,
              playbackUrl: playback,
            );
            _cacheLocally(_cachedConfig);
            return _cachedConfig;
          }
        }
      } catch (e) {
        debugPrint('[PlatformSettingsService] Primary live input lookup notice: $e');
      }

      // 2. Check platform_settings table
      try {
        final response = await client
            .from('platform_settings')
            .select('key, value')
            .inFilter('key', [
              'live_rtmps_url',
              'live_stream_key',
              'live_playback_url',
            ]);

        final rows = response as List<dynamic>;
        String rtmp = _cachedConfig.rtmpUrl;
        String key = _cachedConfig.streamKey;
        String playback = _cachedConfig.playbackUrl;

        for (final row in rows) {
          final k = row['key']?.toString();
          dynamic rawVal = row['value'];
          String v = '';
          if (rawVal is String) {
            v = rawVal;
          } else if (rawVal != null) {
            v = jsonEncode(rawVal).replaceAll('"', '');
          }

          if (k == 'live_rtmps_url') rtmp = v;
          if (k == 'live_stream_key') key = v;
          if (k == 'live_playback_url') playback = v;
        }

        _cachedConfig = LiveStreamConfig(
          rtmpUrl: rtmp,
          streamKey: key,
          playbackUrl: playback,
        );

        _cacheLocally(_cachedConfig);
        return _cachedConfig;
      } catch (e) {
        debugPrint('Notice: platform_settings lookup (using fallback): $e');
      }
    }

    // 3. Fallback: Load from SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final localRtmp = prefs.getString(_kRtmpUrlKey);
      final localKey = prefs.getString(_kStreamKeyKey);
      final localPlayback = prefs.getString(_kPlaybackUrlKey);

      if (localRtmp != null || localKey != null || localPlayback != null) {
        _cachedConfig = LiveStreamConfig(
          rtmpUrl: localRtmp ?? '',
          streamKey: localKey ?? '',
          playbackUrl: localPlayback ?? '',
        );
      }
    } catch (_) {}

    return _cachedConfig;
  }

  /// Saves or updates the institute live stream configuration in `public.platform_settings` and SharedPreferences.
  ///
  /// Throws [ServerException] if Supabase save fails, ensuring UI displays the failure.
  static Future<void> saveLiveStreamConfig(LiveStreamConfig config) async {
    _cachedConfig = config;
    await _cacheLocally(config);

    final client = _supabase;
    if (client == null) {
      return;
    }

    try {
      final records = [
        {
          'key': 'live_rtmps_url',
          'value': jsonEncode(config.rtmpUrl.trim()),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        {
          'key': 'live_stream_key',
          'value': jsonEncode(config.streamKey.trim()),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        {
          'key': 'live_playback_url',
          'value': jsonEncode(config.playbackUrl.trim()),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
      ];

      await client.from('platform_settings').upsert(records, onConflict: 'key');
    } catch (e) {
      debugPrint('Error saving to platform_settings in Supabase: $e');
      throw ServerException('Failed to persist streaming settings to Supabase: $e', e);
    }
  }

  static Future<void> _cacheLocally(LiveStreamConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kRtmpUrlKey, config.rtmpUrl.trim());
      await prefs.setString(_kStreamKeyKey, config.streamKey.trim());
      await prefs.setString(_kPlaybackUrlKey, config.playbackUrl.trim());
    } catch (_) {}
  }
}
