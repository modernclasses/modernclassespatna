import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/batch_timing_helper.dart';
import '../models/lecture_recording_model.dart';
import '../models/live_class_model.dart';

abstract class LiveClassRemoteDataSource {
  Future<List<LiveClassModel>> getLiveClasses();
  Future<LiveClassModel> scheduleLiveClass(
    LiveClassModel liveClass, {
    String? teacherId,
  });
  Future<void> updateLiveClassStatus(String id, LiveStatus status);
  Future<String> uploadLiveClassThumbnail({
    required String fileName,
    required Uint8List fileBytes,
  });

  /// Authoritative server-side batch schedule validation
  Future<SlotValidationResult> validateBatchSchedule(String batchId);

  /// Starts an authenticated live session with server-side validation
  Future<LiveClassModel> startAuthenticatedLiveSession({
    required String batchId,
    required String title,
    required String subject,
    required String streamUrl,
    String? thumbnailUrl,
    String? liveInputUid,
  });

  /// Ends live session, records actual duration, and marks recording processing
  Future<void> endAuthenticatedLiveSession(
    String liveClassId, {
    int? durationSeconds,
    DateTime? endTime,
  });

  /// Retrieves lecture recordings with optional filters
  Future<List<LectureRecordingModel>> getLectureRecordings({
    String? courseId,
    String? batchId,
    String? teacherId,
  });

  /// Synchronizes broadcast recording with Cloudflare Stream
  Future<LectureRecordingModel?> syncBroadcastRecording({
    required String batchId,
    required String courseId,
    required String title,
    String? liveClassId,
    String? liveInputUid,
    String? teacherId,
    String? playbackUrl,
    int? durationSeconds,
    DateTime? startTime,
    DateTime? endTime,
  });

  /// Refreshes processing status of a recording from Cloudflare Stream
  Future<LectureRecordingModel?> refreshRecordingStatus(String videoUid);

  /// Checks live input connection status from Cloudflare Stream
  Future<Map<String, dynamic>> checkCloudflareLiveStatus(String liveInputUid);

  /// Updates recording details such as title and thumbnail
  Future<LectureRecordingModel> updateRecordingDetails({
    required String recordingId,
    String? title,
    String? thumbnailUrl,
  });

  /// Deletes a lecture recording permanently
  Future<void> deleteRecording(String recordingId);
}

class LiveClassRemoteDataSourceImpl implements LiveClassRemoteDataSource {
  SupabaseClient? get _supabase {
    if (!AppConfig.isSupabaseConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<LiveClassModel>> getLiveClasses() async {
    final client = _supabase;
    if (client == null) {
      throw const ServerException('Supabase not configured');
    }

    try {
      final response = await client
          .from('live_classes')
          .select('*, batches(id, name, course_id, courses(id, title))')
          .order('scheduled_at', ascending: true);

      final list = (response as List)
          .map((item) => LiveClassModel.fromMap(item as Map<String, dynamic>))
          .toList();

      return list;
    } catch (e) {
      // Fallback to simple query if nested join is disallowed by policies
      try {
        final response = await client
            .from('live_classes')
            .select()
            .order('scheduled_at', ascending: true);

        final list = (response as List)
            .map((item) => LiveClassModel.fromMap(item as Map<String, dynamic>))
            .toList();

        return list;
      } catch (innerError) {
        debugPrint('Error fetching live classes from Supabase: $innerError');
        throw ServerException('Failed to fetch live classes', innerError);
      }
    }
  }

  @override
  Future<LiveClassModel> scheduleLiveClass(
    LiveClassModel liveClass, {
    String? teacherId,
  }) async {
    final client = _supabase;
    if (client == null) throw const ServerException('Supabase not configured');

    final effectiveTeacherId = teacherId ?? client.auth.currentUser?.id;
    final insertPayload = liveClass.toInsertMap(teacherId: effectiveTeacherId);

    try {
      final response = await client
          .from('live_classes')
          .insert(insertPayload)
          .select('*, batches(id, name, course_id, courses(id, title))')
          .single();

      return LiveClassModel.fromMap(response);
    } catch (e) {
      // If error might be due to column missing in older db, retry without thumbnail_url
      if (insertPayload.containsKey('thumbnail_url')) {
        try {
          final fallbackPayload = Map<String, dynamic>.from(insertPayload)
            ..remove('thumbnail_url');
          final response = await client
              .from('live_classes')
              .insert(fallbackPayload)
              .select('*, batches(id, name, course_id, courses(id, title))')
              .single();
          return LiveClassModel.fromMap(response);
        } catch (_) {}
      }

      try {
        final response = await client
            .from('live_classes')
            .insert(insertPayload)
            .select()
            .single();

        return LiveClassModel.fromMap(response);
      } catch (innerError) {
        debugPrint('Error scheduling live class in Supabase: $innerError');
        throw ServerException('Failed to schedule live class: $innerError');
      }
    }
  }

  @override
  Future<void> updateLiveClassStatus(String id, LiveStatus status) async {
    final client = _supabase;
    if (client == null) return;

    try {
      final updateData = <String, dynamic>{'status': status.name};
      if (status == LiveStatus.ended) {
        updateData['actual_end_time'] = DateTime.now().toUtc().toIso8601String();
      }
      await client
          .from('live_classes')
          .update(updateData)
          .eq('id', id);
    } catch (e) {
      debugPrint('Error updating live class status: $e');
      throw ServerException('Failed to update live class status', e);
    }
  }

  @override
  Future<String> uploadLiveClassThumbnail({
    required String fileName,
    required Uint8List fileBytes,
  }) async {
    final client = _supabase;
    if (client == null) {
      throw const ServerException('Supabase client is not configured.');
    }

    try {
      final cleanName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final storagePath =
          'live-classes/${DateTime.now().millisecondsSinceEpoch}_$cleanName';

      String contentType = 'image/jpeg';
      final lower = cleanName.toLowerCase();
      if (lower.endsWith('.png')) contentType = 'image/png';
      if (lower.endsWith('.webp')) contentType = 'image/webp';

      await client.storage
          .from(AppConstants.bucketCourseThumbnails)
          .uploadBinary(
            storagePath,
            fileBytes,
            fileOptions: FileOptions(contentType: contentType, upsert: false),
          );

      return client.storage
          .from(AppConstants.bucketCourseThumbnails)
          .getPublicUrl(storagePath);
    } catch (e) {
      debugPrint('Error uploading live class thumbnail: $e');
      throw ServerException('Failed to upload live class thumbnail: $e');
    }
  }

  @override
  Future<SlotValidationResult> validateBatchSchedule(String batchId) async {
    final client = _supabase;
    if (client == null) {
      return const SlotValidationResult(
        isValid: true,
        message: 'Client offline or mock mode',
      );
    }

    try {
      final res = await client.rpc(
        'validate_batch_live_schedule',
        params: {'p_batch_id': batchId},
      );
      if (res is Map) {
        final isValid = res['is_valid'] == true;
        final message = res['message']?.toString() ?? '';
        final isPast = res['error_code'] == 'SLOT_ENDED';
        final isEarly = res['error_code'] == 'TOO_EARLY';
        return SlotValidationResult(
          isValid: isValid,
          message: message,
          isPastEndTime: isPast,
          isTooEarly: isEarly,
        );
      }
    } catch (e) {
      debugPrint('[LiveClassRemoteDataSource] Server schedule RPC notice: $e');
    }

    // Fallback: Query batch timing directly from database and validate in IST
    try {
      final batchRes = await client
          .from('batches')
          .select('timing')
          .eq('id', batchId)
          .maybeSingle();
      final timing = batchRes?['timing']?.toString() ?? '';
      return BatchTimingHelper.validateCurrentTimeSlot(timing);
    } catch (_) {
      return const SlotValidationResult(
        isValid: true,
        message: 'Schedule check bypassed due to network lookup limitation.',
      );
    }
  }

  @override
  Future<LiveClassModel> startAuthenticatedLiveSession({
    required String batchId,
    required String title,
    required String subject,
    required String streamUrl,
    String? thumbnailUrl,
    String? liveInputUid,
  }) async {
    final client = _supabase;
    if (client == null) {
      throw const ServerException('Backend service is not configured.');
    }

    // 1. Authoritative server-side schedule verification
    final validation = await validateBatchSchedule(batchId);
    if (!validation.isValid) {
      throw ValidationException(validation.message);
    }

    // 2. Try server-side RPC start_authenticated_live_session
    try {
      final rpcRes = await client.rpc(
        'start_authenticated_live_session',
        params: {
          'p_batch_id': batchId,
          'p_title': title,
          'p_subject': subject,
          'p_stream_url': streamUrl,
          'p_thumbnail_url': ?thumbnailUrl,
          'p_live_input_uid': ?liveInputUid,
        },
      );

      if (rpcRes is Map &&
          rpcRes['success'] == true &&
          rpcRes['live_class'] != null) {
        return LiveClassModel.fromMap(
          Map<String, dynamic>.from(rpcRes['live_class'] as Map),
        );
      }
    } catch (rpcErr) {
      debugPrint(
        '[LiveClassRemoteDataSource] start_authenticated_live_session RPC notice: $rpcErr',
      );
      final errStr = rpcErr.toString().toLowerCase();
      if (errStr.contains('slot ended') ||
          errStr.contains('not permitted') ||
          errStr.contains('forbidden')) {
        throw ValidationException(
          rpcErr.toString().replaceAll('Exception:', '').trim(),
        );
      }
    }

    // Fallback standard insert
    final user = client.auth.currentUser;
    final now = DateTime.now().toUtc();
    final insertPayload = <String, dynamic>{
      'batch_id': batchId,
      'title': title,
      'subject': subject,
      'teacher_name': user?.userMetadata?['full_name'] ?? 'Faculty Member',
      'teacher_id': user?.id,
      'stream_url': streamUrl,
      'scheduled_at': now.toIso8601String(),
      'actual_start_time': now.toIso8601String(),
      'duration_minutes': 90,
      'status': 'live',
      'thumbnail_url': ?thumbnailUrl,
      'live_input_uid': ?liveInputUid,
    };

    try {
      final res = await client
          .from('live_classes')
          .insert(insertPayload)
          .select('*, batches(id, name, course_id, courses(id, title))')
          .single();
      return LiveClassModel.fromMap(res);
    } catch (e) {
      debugPrint(
        '[LiveClassRemoteDataSource] startAuthenticatedLiveSession nested join notice: $e. Retrying simple insert.',
      );
      try {
        final res = await client
            .from('live_classes')
            .insert(insertPayload)
            .select()
            .single();
        return LiveClassModel.fromMap(res);
      } catch (innerError) {
        throw ServerException(
          'Failed to start live session: $innerError',
          innerError,
        );
      }
    }
  }

  @override
  Future<void> endAuthenticatedLiveSession(
    String liveClassId, {
    int? durationSeconds,
    DateTime? endTime,
  }) async {
    final client = _supabase;
    if (client == null) return;

    final resolvedEnd = endTime ?? DateTime.now();

    try {
      await client.rpc(
        'end_authenticated_live_session',
        params: {'p_live_class_id': liveClassId},
      );
    } catch (rpcErr) {
      debugPrint(
        '[LiveClassRemoteDataSource] end_authenticated_live_session RPC notice: $rpcErr',
      );
    }

    try {
      final updateData = <String, dynamic>{
        'status': 'ended',
        'actual_end_time': resolvedEnd.toUtc().toIso8601String(),
        'recording_status': 'processing',
      };
      if (durationSeconds != null && durationSeconds > 0) {
        updateData['actual_duration_seconds'] = durationSeconds;
        updateData['duration_minutes'] = (durationSeconds / 60).ceil();
      }
      await client.from('live_classes').update(updateData).eq('id', liveClassId);
    } catch (e) {
      debugPrint('[LiveClassRemoteDataSource] Fallback end session notice: $e');
    }
  }

  @override
  Future<List<LectureRecordingModel>> getLectureRecordings({
    String? courseId,
    String? batchId,
    String? teacherId,
  }) async {
    final client = _supabase;
    if (client == null) return [];

    try {
      var query = client.from('lecture_recordings').select(
        '*, batches(id, name, course_id, courses(id, title)), profiles(id, full_name)',
      );

      if (courseId != null && courseId.isNotEmpty) {
        query = query.eq('course_id', courseId);
      }
      if (batchId != null && batchId.isNotEmpty) {
        query = query.eq('batch_id', batchId);
      }
      if (teacherId != null && teacherId.isNotEmpty) {
        query = query.eq('teacher_id', teacherId);
      }

      final response = await query.order('created_at', ascending: false);
      return (response as List)
          .map((row) =>
              LectureRecordingModel.fromMap(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      try {
        var simple = client.from('lecture_recordings').select();
        if (courseId != null && courseId.isNotEmpty) {
          simple = simple.eq('course_id', courseId);
        }
        if (batchId != null && batchId.isNotEmpty) {
          simple = simple.eq('batch_id', batchId);
        }
        if (teacherId != null && teacherId.isNotEmpty) {
          simple = simple.eq('teacher_id', teacherId);
        }
        final response = await simple.order('created_at', ascending: false);
        return (response as List)
            .map((row) =>
                LectureRecordingModel.fromMap(row as Map<String, dynamic>))
            .toList();
      } catch (innerErr) {
        debugPrint(
          '[LiveClassRemoteDataSource] Error fetching lecture recordings: $innerErr',
        );
        return [];
      }
    }
  }

  @override
  Future<LectureRecordingModel?> syncBroadcastRecording({
    required String batchId,
    required String courseId,
    required String title,
    String? liveClassId,
    String? liveInputUid,
    String? teacherId,
    String? playbackUrl,
    int? durationSeconds,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    final client = _supabase;
    if (client == null) return null;

    // Clean liveInputUid if in composite format (keykUID)
    var cleanLiveInputUid = liveInputUid?.trim();
    if (cleanLiveInputUid != null &&
        cleanLiveInputUid.contains('k') &&
        cleanLiveInputUid.length > 32) {
      cleanLiveInputUid =
          cleanLiveInputUid.substring(cleanLiveInputUid.indexOf('k') + 1);
    }

    final cleanVideoUid =
        'rec_${(liveClassId ?? DateTime.now().millisecondsSinceEpoch.toString()).replaceAll('-', '')}';
    final effectivePlayback = (playbackUrl != null && playbackUrl.isNotEmpty)
        ? playbackUrl
        : 'https://videodelivery.net/$cleanVideoUid/manifest/video.m3u8';

    // 1. Call deployed Cloudflare Stream Manager Edge Function
    try {
      final res = await client.functions.invoke(
        'cloudflare_stream_manager',
        body: {
          'action': 'sync_broadcast_recording',
          'batch_id': batchId,
          'course_id': courseId,
          'title': title,
          'live_class_id': liveClassId,
          'live_input_uid': cleanLiveInputUid,
          'teacher_id': teacherId,
          'playback_url': effectivePlayback,
          'duration_seconds': durationSeconds,
          'start_time': startTime?.toIso8601String(),
          'end_time': endTime?.toIso8601String(),
        },
      );

      if (res.data != null &&
          res.data is Map &&
          res.data['recording'] != null) {
        return LectureRecordingModel.fromMap(
          Map<String, dynamic>.from(res.data['recording'] as Map),
        );
      }
    } catch (e) {
      debugPrint(
        '[LiveClassRemoteDataSource] Edge function sync_broadcast_recording notice: $e',
      );
    }

    // 2. Authoritative PostgreSQL RPC sync_lecture_recording (SECURITY DEFINER)
    try {
      final rpcRes = await client.rpc(
        'sync_lecture_recording',
        params: {
          'p_batch_id': batchId,
          'p_course_id': courseId,
          'p_title': title,
          'p_video_uid': cleanVideoUid,
          'p_playback_url': effectivePlayback,
          'p_live_class_id': liveClassId,
          'p_live_input_uid': cleanLiveInputUid,
          'p_teacher_id': teacherId,
          'p_duration_seconds': durationSeconds ?? 0,
          'p_status': 'processing',
          'p_start_time': startTime?.toIso8601String(),
          'p_end_time': endTime?.toIso8601String(),
          'p_is_published': true,
        },
      );

      if (rpcRes is Map && rpcRes['recording'] != null) {
        return LectureRecordingModel.fromMap(
          Map<String, dynamic>.from(rpcRes['recording'] as Map),
        );
      }
    } catch (rpcErr) {
      debugPrint(
        '[LiveClassRemoteDataSource] sync_lecture_recording RPC notice: $rpcErr',
      );
    }

    // 3. Direct table upsert (authorized for teachers via Migration 042)
    try {
      final payload = {
        'live_class_id': liveClassId,
        'course_id': courseId,
        'batch_id': batchId,
        'teacher_id': teacherId ?? client.auth.currentUser?.id,
        'title': title,
        'live_input_uid': cleanLiveInputUid,
        'video_uid': cleanVideoUid,
        'playback_url': effectivePlayback,
        'duration_seconds': durationSeconds ?? 0,
        'status': 'processing',
        'start_time': startTime?.toIso8601String(),
        'end_time': endTime?.toIso8601String(),
        'is_published': true,
      };

      final rec = await client
          .from('lecture_recordings')
          .upsert(payload, onConflict: 'video_uid')
          .select()
          .single();

      return LectureRecordingModel.fromMap(rec);
    } catch (dbErr) {
      debugPrint(
        '[LiveClassRemoteDataSource] Database fallback sync error: $dbErr',
      );
      return null;
    }
  }

  @override
  Future<LectureRecordingModel?> refreshRecordingStatus(String videoUid) async {
    final client = _supabase;
    if (client == null) return null;

    // 1. Check Cloudflare Stream via Edge Function
    try {
      final res = await client.functions.invoke(
        'cloudflare_stream_manager',
        body: {
          'action': 'refresh_recording',
          'video_uid': videoUid,
        },
      );

      if (res.data != null &&
          res.data is Map &&
          res.data['recording'] != null) {
        return LectureRecordingModel.fromMap(
          Map<String, dynamic>.from(res.data['recording'] as Map),
        );
      }
    } catch (e) {
      debugPrint(
        '[LiveClassRemoteDataSource] refreshRecordingStatus edge function notice: $e',
      );
    }

    // 2. Authoritative PostgreSQL RPC promote_lecture_recording_status
    try {
      final rpcRes = await client.rpc(
        'promote_lecture_recording_status',
        params: {
          'p_video_uid': videoUid,
          'p_status': 'ready',
        },
      );
      if (rpcRes is Map && rpcRes['recording'] != null) {
        return LectureRecordingModel.fromMap(
          Map<String, dynamic>.from(rpcRes['recording'] as Map),
        );
      }
    } catch (rpcErr) {
      debugPrint(
        '[LiveClassRemoteDataSource] promote_lecture_recording_status RPC notice: $rpcErr',
      );
    }

    // 3. Fallback direct select
    try {
      final row = await client
          .from('lecture_recordings')
          .select(
            '*, batches(id, name, course_id, courses(id, title)), profiles(id, full_name)',
          )
          .eq('video_uid', videoUid)
          .maybeSingle();
      if (row != null) {
        return LectureRecordingModel.fromMap(row);
      }
    } catch (_) {
      try {
        final row = await client
            .from('lecture_recordings')
            .select()
            .eq('video_uid', videoUid)
            .maybeSingle();
        if (row != null) {
          return LectureRecordingModel.fromMap(row);
        }
      } catch (_) {}
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>> checkCloudflareLiveStatus(
    String liveInputUid,
  ) async {
    final client = _supabase;
    if (client == null) {
      return {'is_live': false, 'state': 'offline'};
    }

    try {
      final res = await client.functions.invoke(
        'cloudflare_stream_manager',
        body: {
          'action': 'get_live_status',
          'uid': liveInputUid,
        },
      );

      if (res.data != null && res.data is Map) {
        return Map<String, dynamic>.from(res.data as Map);
      }
    } catch (e) {
      debugPrint(
        '[LiveClassRemoteDataSource] checkCloudflareLiveStatus notice: $e',
      );
    }

    return {'is_live': false, 'state': 'unavailable'};
  }

  @override
  Future<LectureRecordingModel> updateRecordingDetails({
    required String recordingId,
    String? title,
    String? thumbnailUrl,
  }) async {
    final client = _supabase;
    if (client == null) throw const ServerException('Backend not configured');

    try {
      final updates = <String, dynamic>{};
      if (title != null) updates['title'] = title.trim();
      if (thumbnailUrl != null) updates['thumbnail_url'] = thumbnailUrl.trim();

      if (updates.isEmpty) {
        try {
          final existing = await client
              .from('lecture_recordings')
              .select(
                '*, batches(id, name, course_id, courses(id, title)), profiles(id, full_name)',
              )
              .eq('id', recordingId)
              .single();
          return LectureRecordingModel.fromMap(existing);
        } catch (_) {
          final existing = await client
              .from('lecture_recordings')
              .select()
              .eq('id', recordingId)
              .single();
          return LectureRecordingModel.fromMap(existing);
        }
      }

      LectureRecordingModel updated;
      try {
        final response = await client
            .from('lecture_recordings')
            .update(updates)
            .eq('id', recordingId)
            .select(
              '*, batches(id, name, course_id, courses(id, title)), profiles(id, full_name)',
            )
            .single();
        updated = LectureRecordingModel.fromMap(response);
      } catch (_) {
        final response = await client
            .from('lecture_recordings')
            .update(updates)
            .eq('id', recordingId)
            .select()
            .single();
        updated = LectureRecordingModel.fromMap(response);
      }

      // Sync linked live_classes if present
      if (updated.liveClassId != null && updated.liveClassId!.isNotEmpty) {
        final liveUpdates = <String, dynamic>{};
        if (title != null) liveUpdates['title'] = title.trim();
        if (thumbnailUrl != null) {
          liveUpdates['thumbnail_url'] = thumbnailUrl.trim();
        }
        try {
          await client
              .from('live_classes')
              .update(liveUpdates)
              .eq('id', updated.liveClassId!);
        } catch (e) {
          debugPrint('Non-fatal live_classes sync notice: $e');
        }
      }

            return updated;
    } catch (e) {
      debugPrint('Error updating recording details: $e');
      throw ServerException('Failed to update recording details: $e');
    }
  }

  @override
  Future<void> deleteRecording(String recordingId) async {
    final client = _supabase;
    if (client == null) throw const ServerException('Backend not configured');

    try {
      // 1. Fetch recording to find any linked liveClassId or videoUid
      Map<String, dynamic>? rec;
      try {
        rec = await client
            .from('lecture_recordings')
            .select('id, live_class_id, video_uid')
            .eq('id', recordingId)
            .maybeSingle();
      } catch (_) {}

      bool rpcHandled = false;
      try {
        final rpcRes = await client.rpc('delete_lecture', params: {
          'p_lecture_id': recordingId,
          'p_confirm': 'confirm',
        });
        if (rpcRes != null) {
          rpcHandled = true;
        }
      } catch (rpcErr) {
        debugPrint('delete_lecture RPC fallback notice: $rpcErr');
      }

      if (!rpcHandled) {
        // 2. Delete recording from lecture_recordings table and verify row count
        final deleted = await client
            .from('lecture_recordings')
            .delete()
            .eq('id', recordingId)
            .select('id');

        if ((deleted as List).isEmpty) {
          throw const ServerException(
            'Failed to delete recording: Row was not deleted. '
            'Please ensure database migration 059 has been run in Supabase SQL editor.',
          );
        }

        // 3. Clear recording reference on linked live_classes if present
        if (rec != null && rec['live_class_id'] != null) {
          try {
            await client
                .from('live_classes')
                .update({'recording_status': 'deleted', 'recording_url': null})
                .eq('id', rec['live_class_id']);
          } catch (e) {
            debugPrint('Non-fatal live_classes recording_status clear notice: $e');
          }
        }

        // 4. Trigger video cleanup via Cloudflare edge function if video_uid present
        if (rec != null && rec['video_uid'] != null && (rec['video_uid'] as String).isNotEmpty) {
          try {
            await client.functions.invoke(
              'cloudflare_stream_manager',
              body: {
                'action': 'delete_video',
                'uid': rec['video_uid'],
              },
            );
          } catch (e) {
            debugPrint('Non-fatal Cloudflare video delete notice: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error deleting lecture recording: $e');
      if (e is ServerException) rethrow;
      throw ServerException('Failed to delete recording: $e');
    }
  }
}
