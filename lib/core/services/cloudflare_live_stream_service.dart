import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../errors/exceptions.dart';
import '../../features/live_classes/data/models/cloudflare_live_input.dart';
import 'platform_settings_service.dart';

/// Service managing persistent Cloudflare Stream Live Inputs.
///
/// Ensures all Live Input UIDs, keys, and URLs are stored reliably in Supabase
/// and recovered automatically upon cold app starts or complete reinstallations.
class CloudflareLiveStreamService {
  CloudflareLiveStreamService._();

  static const String _kLocalCachedInputsKey = 'cached_cloudflare_live_inputs_v1';
  static List<CloudflareLiveInput> _cachedInputs = [];
  static bool _hasLoadedOnce = false;

  /// Supabase client getter.
  static SupabaseClient? get _supabase {
    if (!AppConfig.isSupabaseConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Override cache for unit tests or cold start simulation.
  @visibleForTesting
  static void resetCacheForTesting() {
    _cachedInputs = [];
    _hasLoadedOnce = false;
  }

  /// Retrieves all registered Cloudflare Live Inputs from Supabase.
  ///
  /// On app reinstallation (where SharedPreferences is completely empty),
  /// this method fetches directly from Supabase to restore all inputs.
  static Future<List<CloudflareLiveInput>> getLiveInputs({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _hasLoadedOnce && _cachedInputs.isNotEmpty) {
      return List.unmodifiable(_cachedInputs);
    }

    // Try loading from Supabase first (primary persistent vault)
    final client = _supabase;
    if (client != null) {
      try {
        final response = await client
            .from('cloudflare_live_inputs')
            .select()
            .order('is_primary', ascending: false)
            .order('created_at', ascending: false);

        final rows = response as List<dynamic>;
        final inputs = rows
            .map((r) => CloudflareLiveInput.fromMap(Map<String, dynamic>.from(r)))
            .toList();

        _cachedInputs = inputs;
        _hasLoadedOnce = true;

        // Sync primary input with PlatformSettingsService if present
        final primary = inputs.where((i) => i.isPrimary && i.isActive).firstOrNull;
        if (primary != null) {
          PlatformSettingsService.updateMemoryCache(
            LiveStreamConfig(
              rtmpUrl: primary.rtmpsUrl,
              streamKey: primary.streamKey,
              playbackUrl: primary.playbackUrl,
            ),
          );
        }

        // Cache locally for offline resilience
        _persistToLocalCache(inputs);

        return List.unmodifiable(_cachedInputs);
      } catch (e) {
        debugPrint('[CloudflareLiveStreamService] Supabase fetch notice: $e');
      }
    }

    // Fallback: Read local cache (e.g. offline device)
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_kLocalCachedInputsKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final decoded = jsonDecode(cachedJson) as List<dynamic>;
        _cachedInputs = decoded
            .map((item) => CloudflareLiveInput.fromMap(Map<String, dynamic>.from(item)))
            .toList();
        _hasLoadedOnce = true;
        return List.unmodifiable(_cachedInputs);
      }
    } catch (_) {}

    return List.unmodifiable(_cachedInputs);
  }

  /// Persists a live input to Supabase.
  ///
  /// Throws [ValidationException] if validation fails.
  /// Throws [ServerException] if Supabase persistence fails (never swallowed).
  static Future<CloudflareLiveInput> saveLiveInput(CloudflareLiveInput input) async {
    final uid = input.uid.trim();
    final name = input.name.trim();
    final rtmpsUrl = input.rtmpsUrl.trim();
    final streamKey = input.streamKey.trim();
    final playbackUrl = input.playbackUrl.trim();

    if (uid.isEmpty) {
      throw const ValidationException('Cloudflare Live Input UID is required.');
    }
    if (name.isEmpty) {
      throw const ValidationException('Live Input Name is required.');
    }
    if (streamKey.isEmpty) {
      throw const ValidationException('Cloudflare Stream Key is required.');
    }
    if (rtmpsUrl.isNotEmpty &&
        !rtmpsUrl.startsWith('rtmp://') &&
        !rtmpsUrl.startsWith('rtmps://')) {
      throw const ValidationException('RTMPS URL must start with rtmp:// or rtmps://');
    }

    final client = _supabase;
    if (client == null) {
      // In-memory / offline mock fallback
      final sanitized = input.copyWith(
        id: input.id.isEmpty ? 'local-${DateTime.now().millisecondsSinceEpoch}' : input.id,
        uid: uid,
        name: name,
        rtmpsUrl: rtmpsUrl,
        streamKey: streamKey,
        playbackUrl: playbackUrl,
      );
      await _updateMemoryAndLocal(sanitized);
      return sanitized;
    }

    try {
      final payload = {
        'uid': uid,
        'name': name,
        'rtmps_url': rtmpsUrl,
        'stream_key': streamKey,
        'playback_url': playbackUrl,
        'account_id': input.accountId?.trim(),
        'batch_id': input.batchId,
        'is_active': input.isActive,
        'is_primary': input.isPrimary,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      final response = await client
          .from('cloudflare_live_inputs')
          .upsert(payload, onConflict: 'uid')
          .select()
          .single();

      final saved = CloudflareLiveInput.fromMap(Map<String, dynamic>.from(response));

      // If marked as primary, ensure other inputs are updated
      if (saved.isPrimary) {
        await makePrimary(saved.uid);
      } else {
        await _updateMemoryAndLocal(saved);
      }

      return saved;
    } catch (e) {
      debugPrint('[CloudflareLiveStreamService] Save error in Supabase: $e');
      throw ServerException('Failed to persist Cloudflare Live Input to Supabase: $e', e);
    }
  }

  /// Locates a live input by its UID.
  ///
  /// Conforms to Requirement 9: If an existing input cannot be found,
  /// displays a useful error and DOES NOT silently create a duplicate input.
  static Future<CloudflareLiveInput> findLiveInputByUid(String uid) async {
    final cleanUid = uid.trim();
    if (cleanUid.isEmpty) {
      throw const ValidationException('UID cannot be empty.');
    }

    // Check memory first
    final memoryMatch = _cachedInputs.where((i) => i.uid == cleanUid).firstOrNull;
    if (memoryMatch != null) return memoryMatch;

    final client = _supabase;
    if (client != null) {
      try {
        final res = await client
            .from('cloudflare_live_inputs')
            .select()
            .eq('uid', cleanUid)
            .maybeSingle();

        if (res != null) {
          final found = CloudflareLiveInput.fromMap(Map<String, dynamic>.from(res));
          await _updateMemoryAndLocal(found);
          return found;
        }
      } catch (e) {
        debugPrint('[CloudflareLiveStreamService] Error looking up UID: $e');
      }
    }

    // If not found, explicitly throw error to prevent silent recreation
    throw ServerException(
      'Live input with UID "$cleanUid" was not found in Supabase. '
      'Please verify the UID or register it in Admin Settings. Duplicate input will not be created.',
    );
  }

  /// Sets an input as the primary broadcast ingest for the institute.
  static Future<void> makePrimary(String uid) async {
    final client = _supabase;
    if (client != null) {
      try {
        // Demote all other inputs
        await client
            .from('cloudflare_live_inputs')
            .update({'is_primary': false})
            .eq('is_primary', true);

        // Promote specified input
        await client
            .from('cloudflare_live_inputs')
            .update({'is_primary': true, 'is_active': true})
            .eq('uid', uid);
      } catch (e) {
        debugPrint('[CloudflareLiveStreamService] Notice setting primary in Supabase: $e');
      }
    }

    // Update in memory
    for (int i = 0; i < _cachedInputs.length; i++) {
      if (_cachedInputs[i].uid == uid) {
        _cachedInputs[i] = _cachedInputs[i].copyWith(isPrimary: true, isActive: true);
        // Also update PlatformSettingsService
        await PlatformSettingsService.saveLiveStreamConfig(
          LiveStreamConfig(
            rtmpUrl: _cachedInputs[i].rtmpsUrl,
            streamKey: _cachedInputs[i].streamKey,
            playbackUrl: _cachedInputs[i].playbackUrl,
          ),
        );
      } else {
        _cachedInputs[i] = _cachedInputs[i].copyWith(isPrimary: false);
      }
    }

    _hasLoadedOnce = true;
    await _persistToLocalCache(_cachedInputs);
  }

  /// Deletes a live input.
  ///
  /// Conforms to Requirement 8: Explicitly requires [confirmation] to be 'CONFIRM'.
  /// Ending a lecture, restarting, or reinstalling must NEVER delete an input.
  static Future<void> deleteLiveInput({
    required String uid,
    required String confirmation,
  }) async {
    if (confirmation.trim() != 'CONFIRM') {
      throw const ValidationException(
        'Deletion aborted. You must type "CONFIRM" in capital letters to delete a Live Input.',
      );
    }

    final client = _supabase;
    if (client != null) {
      try {
        await client.from('cloudflare_live_inputs').delete().eq('uid', uid);
      } catch (e) {
        throw ServerException('Failed to delete live input from Supabase: $e', e);
      }
    }

    _cachedInputs.removeWhere((i) => i.uid == uid);
    _hasLoadedOnce = true;
    await _persistToLocalCache(_cachedInputs);
  }

  static Future<void> _updateMemoryAndLocal(CloudflareLiveInput input) async {
    final index = _cachedInputs.indexWhere((i) => i.uid == input.uid);
    if (index >= 0) {
      _cachedInputs[index] = input;
    } else {
      _cachedInputs.insert(0, input);
    }
    _hasLoadedOnce = true;
    await _persistToLocalCache(_cachedInputs);
  }

  static Future<void> _persistToLocalCache(List<CloudflareLiveInput> inputs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serialized = jsonEncode(inputs.map((i) => i.toMap()).toList());
      await prefs.setString(_kLocalCachedInputsKey, serialized);
    } catch (_) {}
  }
}
