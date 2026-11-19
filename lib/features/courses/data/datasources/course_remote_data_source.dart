import 'dart:io' show File, RandomAccessFile;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/course_model.dart';
import '../models/batch_model.dart';
import '../../../../models/payment_model.dart';

String _sanitizeForLog(dynamic err) {
  if (err == null) return '';
  String s = err.toString();
  s = s.replaceAllMapped(
    RegExp(r'(https?|rtmps?)://([^:@\s]+):([^@\s]+)@', caseSensitive: false),
    (m) => '${m[1]}://***:***@',
  );
  s = s.replaceAllMapped(
    RegExp(r'([?&](?:token|key|secret|apiKey|api_key|auth)=)[^&\s]+', caseSensitive: false),
    (m) => '${m[1]}***masked***',
  );
  return s;
}

abstract class CourseRemoteDataSource {
  Future<List<CourseModel>> getCourses();
  Future<List<BatchModel>> getBatches();
  Future<List<BatchModel>> adminGetAllBatches();
  Future<List<VideoLessonModel>> getVideoLessons(String batchId);
  Future<void> enrollInBatch({
    String? purchaseToken,
    String? batchId,
    String? couponCode,
    double? amountPaid,
  });
  Future<Map<String, List<String>>> getMyEnrollments();
  Future<void> assignTeacherToBatch(String teacherId, String batchId);
  Future<void> setPrimaryBatchTeacher(String teacherId, String batchId);
  Future<void> removeTeacherFromBatch(String teacherId, String batchId);
  Future<List<Map<String, dynamic>>> getTeacherAssignments(String teacherId);
  Future<void> createCourse(
    CourseModel course, {
    List<BatchModel>? initialBatches,
    Map<int, List<String>>? batchTeacherIds,
  });
  Future<void> updateCourse(CourseModel course);
  Future<void> createBatch(BatchModel batch, {List<String>? teacherIds});
  Future<void> updateBatch(BatchModel batch, {List<String>? teacherIds});
  Future<void> deleteBatch(String batchId);
  Future<List<String>> getBatchTeacherIds(String batchId);
  Future<void> updateBatchTeachers(String batchId, List<String> teacherIds);

  Future<String> uploadLectureVideo({
    required String batchId,
    required String fileName,
    Uint8List? fileBytes,
    String? filePath,
    void Function(int uploadedBytes, int totalBytes)? onProgress,
    bool Function()? isCancelled,
  });

  Future<List<VideoLessonModel>> getLessonsForBatches(List<String> batchIds);

  Future<String> uploadCourseCoverImage({
    required String fileName,
    required Uint8List fileBytes,
  });

  Future<String> uploadLessonThumbnail({
    required String batchId,
    required String fileName,
    required Uint8List fileBytes,
  });

  Future<VideoLessonModel> updateLessonThumbnail({
    required String lessonId,
    required String thumbnailUrl,
  });

  Future<VideoLessonModel> updateLesson({
    required String lessonId,
    String? title,
    String? chapter,
    String? thumbnailUrl,
    String? notesPdfUrl,
  });

  Future<VideoLessonModel> createLesson({
    required String courseId,
    required String batchId,
    required String title,
    required String chapter,
    required String videoUrl,
    String? thumbnailUrl,
    int durationSeconds = 0,
    int? orderIndex,
  });

  Future<String> getLessonVideoSignedUrl(String videoUrlOrPath);

  Future<List<PaymentTransactionModel>> getStudentTransactions(
    String studentId,
  );
  Future<List<PaymentTransactionModel>> getAdminLedger(int offset, int limit);
  Future<double?> getAdminManualCollectionsTotal();
  Future<void> deleteCourse(String courseId);
  Future<void> deleteLesson(
    String lessonId, {
    String? videoPath,
    String? thumbnailPath,
  });
  Future<List<CouponModel>> getCoupons();
  Future<CouponModel> createCoupon(CouponModel coupon);
  Future<void> updateCoupon(CouponModel coupon);
  Future<void> deleteCoupon(String couponId);
}

class CourseRemoteDataSourceImpl implements CourseRemoteDataSource {
  SupabaseClient? get _supabase {
    if (!AppConfig.isSupabaseConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<CourseModel>> getCourses() async {
    final client = _supabase;
    if (client == null) {
      throw ServerException('Supabase client is not configured.');
    }

    try {
      final response = await client
          .from('vw_courses_with_stats')
          .select()
          .order('created_at', ascending: false);

      final list = (response as List)
          .map((item) => CourseModel.fromMap(item as Map<String, dynamic>))
          .toList();

      return list;
    } catch (e) {
      debugPrint('Error fetching courses from Supabase: ');
      throw ServerException(e.toString());
    }
  }

  Future<String?> _getCurrentUserRole(SupabaseClient client) async {
    final user = client.auth.currentUser;
    if (user == null) return null;
    try {
      final res = await client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      return res?['role']?.toString().toLowerCase();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, Map<String, dynamic>>> _fetchBatchStreamCredentials(
    SupabaseClient client,
  ) async {
    // Defense-in-depth: only query credentials if the caller is verified staff (admin or teacher).
    // Students never require stream_key or rtmps_url and should never receive them.
    final userRole = await _getCurrentUserRole(client);
    if (userRole != 'admin' && userRole != 'teacher') {
      return {};
    }

    try {
      final res = await client
          .from('vw_batches_with_stats')
          .select('id, stream_key, playback_url, rtmps_url');
      final map = <String, Map<String, dynamic>>{};
      for (final row in (res as List)) {
        final id = row['id']?.toString();
        if (id != null && id.isNotEmpty) {
          map[id] = Map<String, dynamic>.from(row as Map);
        }
      }
      return map;
    } catch (e) {
      debugPrint(
        '[CourseRemoteDataSource] Failed to fetch stream credentials from view: ${_sanitizeForLog(e)}',
      );
      if (userRole == 'admin') {
        try {
          final res = await client
              .from('batches')
              .select('id, stream_key, playback_url, rtmps_url');
          final map = <String, Map<String, dynamic>>{};
          for (final row in (res as List)) {
            final id = row['id']?.toString();
            if (id != null && id.isNotEmpty) {
              map[id] = Map<String, dynamic>.from(row as Map);
            }
          }
          return map;
        } catch (_) {
          return {};
        }
      }
      return {};
    }
  }

  List<BatchModel> _enrichBatchRows(
    List<dynamic> rows,
    Map<String, Map<String, dynamic>> credentialsMap,
  ) {
    return rows.map((item) {
      final map = Map<String, dynamic>.from(item as Map<String, dynamic>);
      final id = map['id']?.toString();
      if (id != null && credentialsMap.containsKey(id)) {
        final creds = credentialsMap[id]!;
        if ((map['stream_key'] == null ||
                map['stream_key'].toString().isEmpty) &&
            creds['stream_key'] != null) {
          map['stream_key'] = creds['stream_key'];
        }
        if ((map['playback_url'] == null ||
                map['playback_url'].toString().isEmpty) &&
            creds['playback_url'] != null) {
          map['playback_url'] = creds['playback_url'];
        }
        if ((map['rtmps_url'] == null ||
                map['rtmps_url'].toString().isEmpty) &&
            creds['rtmps_url'] != null) {
          map['rtmps_url'] = creds['rtmps_url'];
        }
      }
      return BatchModel.fromMap(map);
    }).toList();
  }

  @override
  Future<List<BatchModel>> adminGetAllBatches() async {
    final client = _supabase;
    if (client == null) {
      throw ServerException('Supabase client is not configured.');
    }
    try {
      final credsMap = await _fetchBatchStreamCredentials(client);
      try {
        final response = await client
            .from('vw_batches_with_stats')
            .select()
            .order('start_date', ascending: true);
        return _enrichBatchRows(response as List, credsMap);
      } catch (viewError) {
        debugPrint(
          '[CourseRemoteDataSource] adminGetAllBatches view failed, falling back to batches table: ${_sanitizeForLog(viewError)}',
        );
        final fallback = await client
            .from('batches')
            .select(
              'id, course_id, name, timing, start_date, end_date, max_students, batch_price, medium, is_active, created_at, updated_at, play_product_id, playback_url',
            )
            .order('start_date', ascending: true);
        return _enrichBatchRows(fallback as List, credsMap);
      }
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<BatchModel>> getBatches() async {
    final client = _supabase;
    if (client == null) {
      throw ServerException('Supabase client is not configured.');
    }

    try {
      final credsMap = await _fetchBatchStreamCredentials(client);
      try {
        final response = await client
            .from('vw_batches_with_stats')
            .select()
            .order('start_date', ascending: true);

        return _enrichBatchRows(response as List, credsMap);
      } catch (viewError) {
        debugPrint(
          '[CourseRemoteDataSource] getBatches view failed, falling back to batches table: ${_sanitizeForLog(viewError)}',
        );
        final fallback = await client
            .from('batches')
            .select(
              'id, course_id, name, timing, start_date, end_date, max_students, batch_price, medium, is_active, created_at, updated_at, play_product_id, playback_url',
            )
            .order('start_date', ascending: true);

        return _enrichBatchRows(fallback as List, credsMap);
      }
    } catch (e) {
      debugPrint('Error fetching batches from Supabase: ${_sanitizeForLog(e)}');
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<VideoLessonModel>> getVideoLessons(String batchId) async {
    final client = _supabase;
    if (client == null) {
      throw ServerException('Supabase client is not configured.');
    }

    try {
      final response = await client
          .from('lessons')
          .select()
          .eq('batch_id', batchId)
          .order('order_index', ascending: true);

      final lessons = (response as List)
          .map((item) => VideoLessonModel.fromMap(item as Map<String, dynamic>))
          .toList();

      // Also merge ready live lecture recordings so students find all lectures in one place
      try {
        final recResponse = await client
            .from('lecture_recordings')
            .select()
            .eq('batch_id', batchId)
            .inFilter('status', ['ready', 'processing'])
            .order('duration_seconds', ascending: false)
            .order('start_time', ascending: false);

        for (final item in (recResponse as List)) {
          final row = item as Map<String, dynamic>;
          final playbackUrl = (row['playback_url'] as String?) ?? '';
          if (playbackUrl.isEmpty) continue;

          final recId = row['id']?.toString() ?? '';
          final title = (row['title'] as String?)?.trim() ?? 'Recorded Live Lecture';
          final durationSec = (row['duration_seconds'] as num?)?.toInt() ?? 0;
          final liveInputUid = row['live_input_uid']?.toString();
          final videoUid = row['video_uid']?.toString();

          // Skip if this is a live-input placeholder that never produced duration
          if (durationSec <= 0 && liveInputUid != null && videoUid == liveInputUid) {
            continue;
          }

          // If a ready recording with the same title and positive duration already exists, skip 0-duration copy
          if (durationSec <= 0 &&
              lessons.any((l) =>
                  l.title.trim().toLowerCase() == title.toLowerCase() &&
                  l.duration > Duration.zero)) {
            continue;
          }

          // Check if an existing lesson in lessons table represents the same lecture
          final existingIdx = lessons.indexWhere((l) =>
              l.id == recId ||
              (l.videoUrl.isNotEmpty && l.videoUrl == playbackUrl) ||
              (l.title.trim().toLowerCase() == title.toLowerCase()));

          if (existingIdx != -1) {
            // If existing lesson has 0 duration and this recording has positive duration, upgrade it
            if (lessons[existingIdx].duration == Duration.zero && durationSec > 0) {
              lessons[existingIdx] = lessons[existingIdx].copyWith(
                duration: Duration(seconds: durationSec),
                videoUrl: playbackUrl,
                thumbnailUrl: row['thumbnail_url']?.toString() ?? lessons[existingIdx].thumbnailUrl,
              );
            }
            continue;
          }

          final startTimeStr = row['start_time'] ?? row['created_at'];
          final uploadedAt = startTimeStr != null
              ? DateTime.tryParse(startTimeStr.toString()) ?? DateTime.now()
              : DateTime.now();

          lessons.add(
            VideoLessonModel(
              id: recId,
              courseId: row['course_id']?.toString() ?? '',
              batchId: row['batch_id']?.toString() ?? batchId,
              title: title,
              chapter: 'Live Lecture Recording',
              duration: Duration(seconds: durationSec),
              videoUrl: playbackUrl,
              thumbnailUrl: row['thumbnail_url']?.toString(),
              uploadedAt: uploadedAt,
            ),
          );
        }
      } catch (recError) {
        debugPrint('Note: Could not query lecture_recordings in getVideoLessons: $recError');
      }

      // Also merge completed live classes for this batch
      try {
        final liveClassesResponse = await client
            .from('live_classes')
            .select()
            .eq('batch_id', batchId)
            .eq('status', 'ended')
            .order('actual_duration_seconds', ascending: false)
            .order('created_at', ascending: false);

        for (final item in (liveClassesResponse as List)) {
          final row = item as Map<String, dynamic>;
          final liveId = row['id']?.toString() ?? '';
          final title = (row['title'] as String?)?.trim() ?? 'Recorded Live Lecture';
          final durationSec = (row['actual_duration_seconds'] as num?)?.toInt() ?? 0;
          final recordingUrl = (row['recording_url'] as String?) ?? (row['stream_url'] as String?) ?? '';

          if (lessons.any((l) => l.id == liveId || (recordingUrl.isNotEmpty && l.videoUrl == recordingUrl))) {
            continue;
          }

          if (durationSec <= 0 && (recordingUrl.isEmpty || recordingUrl.contains('rec_'))) {
            continue;
          }

          final startTimeStr = row['actual_start_time'] ?? row['scheduled_at'] ?? row['created_at'];
          final uploadedAt = startTimeStr != null
              ? DateTime.tryParse(startTimeStr.toString()) ?? DateTime.now()
              : DateTime.now();

          lessons.add(
            VideoLessonModel(
              id: liveId,
              courseId: row['course_id']?.toString() ?? '',
              batchId: row['batch_id']?.toString() ?? batchId,
              title: title,
              chapter: (row['subject'] as String?)?.trim().isNotEmpty == true
                  ? (row['subject'] as String).trim()
                  : 'Live Lecture Recording',
              duration: Duration(seconds: durationSec),
              videoUrl: recordingUrl,
              thumbnailUrl: row['thumbnail_url']?.toString(),
              uploadedAt: uploadedAt,
            ),
          );
        }
      } catch (liveErr) {
        debugPrint('Note: Could not query live_classes in getVideoLessons: $liveErr');
      }

      // Deduplicate lessons list to guarantee no duplicate entries or 0-duration redundant entries
      final deduplicated = <VideoLessonModel>[];
      final seenIds = <String>{};
      final seenUrls = <String>{};
      final seenTitles = <String>{};

      // Sort with positive duration items first
      final sortedLessons = List<VideoLessonModel>.from(lessons)
        ..sort((a, b) => b.duration.compareTo(a.duration));

      for (final l in sortedLessons) {
        if (seenIds.contains(l.id)) continue;
        if (l.videoUrl.isNotEmpty && seenUrls.contains(l.videoUrl)) continue;

        final normTitle = l.title.trim().toLowerCase();
        if (seenTitles.contains(normTitle) && l.duration == Duration.zero) continue;
        if (seenTitles.contains(normTitle) && seenUrls.any((u) => u.isNotEmpty)) continue;

        seenIds.add(l.id);
        if (l.videoUrl.isNotEmpty) seenUrls.add(l.videoUrl);
        seenTitles.add(normTitle);
        deduplicated.add(l);
      }

      return deduplicated;
    } catch (e) {
      debugPrint('Error fetching lessons from Supabase: ');
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> enrollInBatch({
    String? purchaseToken,
    String? batchId,
    String? couponCode,
    double? amountPaid,
  }) async {
    final client = _supabase;
    if (client == null) {
      throw const ServerException('Supabase client is not configured.');
    }

    final user = client.auth.currentUser;
    if (user == null) {
      throw const ServerException('User must be logged in to enroll.');
    }

    // 1. FREE ENROLLMENT (Scenario 1 / 100% Coupon Bypass)
    if (amountPaid != null && amountPaid <= 0 && batchId != null) {
      try {
        final rpcParams = <String, dynamic>{
          'p_batch_id': batchId,
        };
        if (couponCode != null && couponCode.trim().isNotEmpty) {
          rpcParams['p_coupon_code'] = couponCode.trim();
        }

        await client.rpc('enroll_student_free_or_coupon', params: rpcParams);
        return;
      } catch (e) {
        debugPrint('enroll_student_free_or_coupon RPC error: $e');
        final message = e
            .toString()
            .replaceAll('PostgrestException(message: ', '')
            .replaceAll(')', '');
        throw ServerException(
          'Failed to process free/coupon enrollment: $message',
        );
      }
    }

    // 2. PAID ENROLLMENT VIA GOOGLE PLAY (Scenario 2 Tier Downgrade)
    final token = purchaseToken ??
        'mockpurchase:mock_batch_product_001:${DateTime.now().millisecondsSinceEpoch}';

    try {
      final payload = <String, dynamic>{'purchaseToken': token};
      if (batchId != null) payload['batchId'] = batchId;
      if (couponCode != null) payload['couponCode'] = couponCode;
      if (amountPaid != null) payload['amountPaid'] = amountPaid;

      final response = await client.functions.invoke(
        'verify_purchase',
        body: payload,
      );

      if (response.status == 200) {
        return;
      }
      throw ServerException(
        'Edge function responded with status: ${response.status}',
      );
    } catch (e) {
      debugPrint('Purchase verification error: $e');
      if (e is ServerException) rethrow;
      final message = e
          .toString()
          .replaceAll('PostgrestException(message: ', '')
          .replaceAll('FunctionException(message: ', '')
          .replaceAll(')', '');
      throw ServerException(
        'Payment verification failed. Google Play purchase could not be verified: $message',
      );
    }
  }

  @override
  Future<void> assignTeacherToBatch(String teacherId, String batchId) async {
    final client = _supabase;
    if (client == null) throw const ServerException('Backend not configured');
    try {
      await client.from('batch_teachers').insert({
        'teacher_id': teacherId,
        'batch_id': batchId,
      });
    } catch (e) {
      throw ServerException('Failed to assign teacher', e);
    }
  }

  @override
  Future<void> setPrimaryBatchTeacher(String teacherId, String batchId) async {
    final client = _supabase;
    if (client == null) throw const ServerException('Backend not configured');
    try {
      await client.rpc(
        'admin_set_primary_batch_teacher',
        params: {'p_batch_id': batchId, 'p_teacher_id': teacherId},
      );
    } catch (e) {
      throw ServerException('Failed to set primary teacher', e);
    }
  }

  @override
  Future<void> removeTeacherFromBatch(String teacherId, String batchId) async {
    final client = _supabase;
    if (client == null) throw const ServerException('Backend not configured');
    try {
      await client.from('batch_teachers').delete().match({
        'teacher_id': teacherId,
        'batch_id': batchId,
      });
    } catch (e) {
      throw ServerException('Failed to remove teacher', e);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getTeacherAssignments(
    String teacherId,
  ) async {
    final client = _supabase;
    if (client == null) throw const ServerException('Backend not configured');
    try {
      final res = await client
          .from('batch_teachers')
          .select('batch_id, is_primary, batches(name)')
          .eq('teacher_id', teacherId);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      throw ServerException('Failed to fetch assignments', e);
    }
  }

  @override
  Future<Map<String, List<String>>> getMyEnrollments() async {
    final client = _supabase;
    if (client == null) {
      throw ServerException('Supabase client is not configured.');
    }

    final user = client.auth.currentUser;
    if (user == null) {
      return {'courseIds': [], 'batchIds': []};
    }

    try {
      final response = await client
          .from('enrollments')
          .select('batch_id, batches!inner(course_id)')
          .eq('student_id', user.id)
          .eq('status', 'active');

      final courseIds = <String>{};
      final batchIds = <String>{};

      for (var row in (response as List)) {
        final batchId = row['batch_id'] as String?;
        if (batchId != null && batchId.isNotEmpty) {
          batchIds.add(batchId);
        }

        final batchData = row['batches'];
        if (batchData != null && batchData['course_id'] != null) {
          courseIds.add(batchData['course_id'].toString());
        }
      }

      return {'courseIds': courseIds.toList(), 'batchIds': batchIds.toList()};
    } catch (e) {
      debugPrint(
        '[CourseRemoteDataSource] Nested join getMyEnrollments notice: $e. Falling back to direct enrollments query.',
      );
      try {
        // Direct query on enrollments with NO joins to guarantee student never loses access
        final response = await client
            .from('enrollments')
            .select('batch_id')
            .eq('student_id', user.id)
            .eq('status', 'active');

        final batchIds = <String>{};
        for (var row in (response as List)) {
          final batchId = row['batch_id'] as String?;
          if (batchId != null && batchId.isNotEmpty) {
            batchIds.add(batchId);
          }
        }

        return {'courseIds': <String>[], 'batchIds': batchIds.toList()};
      } catch (fallbackError) {
        debugPrint('Error fetching enrollments in fallback: $fallbackError');
        throw ServerException(fallbackError.toString());
      }
    }
  }

  @override
  Future<void> createCourse(
    CourseModel course, {
    List<BatchModel>? initialBatches,
    Map<int, List<String>>? batchTeacherIds,
  }) async {
    final client = _supabase;
    if (client == null) throw const ServerException('Backend not configured');
    String? newCourseId;
    try {
      final data = course.toMap();
      data.remove('id'); // let db generate uuid
      data.remove('teacher_name'); // not in table
      if (data['teacher_id'] != null &&
          !RegExp(
            r'^[0-9a-fA-F-]{36}$',
          ).hasMatch(data['teacher_id'].toString())) {
        data['teacher_id'] =
            null; // prevent uuid parsing error for non-uuid strings
      }

      final res = await client.from('courses').insert(data).select().single();
      newCourseId = res['id']?.toString();
      if (newCourseId != null && newCourseId.isNotEmpty) {
        if (initialBatches != null && initialBatches.isNotEmpty) {
          for (int i = 0; i < initialBatches.length; i++) {
            final slot = initialBatches[i];
            final teachers = batchTeacherIds?[i] ??
                (slot.teacherId.isNotEmpty ? [slot.teacherId] : <String>[]);
            await createBatch(
              slot.copyWith(courseId: newCourseId),
              teacherIds: teachers,
            );
          }
        } else {
          try {
            await createBatch(
              BatchModel(
                id: "",
                courseId: newCourseId,
                name: '${course.title} - Batch 1',
                timing: '08:00 AM - 10:00 AM (Mon-Sat)',
                startDate: DateTime.now(),
                endDate: DateTime.now().add(const Duration(days: 90)),
                teacherName: course.teacherName.isNotEmpty
                    ? course.teacherName
                    : 'Faculty Member',
                teacherId: course.teacherId,
                totalStudents: 0,
                maxStudents: 500,
                batchPrice: course.price,
                medium: 'Bilingual (Hindi + English)',
                isActive: true,
              ),
              teacherIds:
                  course.teacherId.isNotEmpty ? [course.teacherId] : null,
            );
          } catch (_) {
            // Non-blocking fallback
          }
        }
      }
    } catch (e) {
      if (newCourseId != null) {
        try {
          await client.from('courses').delete().eq('id', newCourseId);
        } catch (_) {}
      }
      throw ServerException('Failed to create course', e);
    }
  }

  @override
  Future<void> updateCourse(CourseModel course) async {
    final client = _supabase;
    if (client == null) throw const ServerException('Backend not configured');
    try {
      final data = course.toMap();
      data.remove('id');
      data.remove('teacher_name');
      if (data['teacher_id'] != null &&
          !RegExp(
            r'^[0-9a-fA-F-]{36}$',
          ).hasMatch(data['teacher_id'].toString())) {
        data['teacher_id'] = null;
      }
      data['updated_at'] = DateTime.now().toIso8601String();

      await client.from('courses').update(data).eq('id', course.id);
    } catch (e) {
      throw ServerException('Failed to update course', e);
    }
  }

  @override
  Future<List<String>> getBatchTeacherIds(String batchId) async {
    final client = _supabase;
    if (client == null) return [];
    try {
      final res = await client
          .from('batch_teachers')
          .select('teacher_id')
          .eq('batch_id', batchId);
      final list = (res as List)
          .map((r) => r['teacher_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      return list;
    } catch (e) {
      debugPrint('Error fetching batch teachers: $e');
      return [];
    }
  }

  @override
  Future<void> updateBatchTeachers(
    String batchId,
    List<String> newTeacherIds,
  ) async {
    final client = _supabase;
    if (client == null) throw const ServerException('Backend not configured');
    try {
      final currentList = await getBatchTeacherIds(batchId);
      final currentSet = currentList.toSet();
      final newSet = newTeacherIds
          .where((id) => id.isNotEmpty && id != 'tch_001')
          .toSet();

      final toRemove = currentSet.difference(newSet);
      final toAdd = newSet.difference(currentSet);

      for (final teacherId in toRemove) {
        await client.from('batch_teachers').delete().match({
          'batch_id': batchId,
          'teacher_id': teacherId,
        });
      }

      for (final teacherId in toAdd) {
        final isPrimary = currentSet.isEmpty && teacherId == newSet.first;
        await client.from('batch_teachers').upsert({
          'batch_id': batchId,
          'teacher_id': teacherId,
          'is_primary': isPrimary,
        }, onConflict: 'batch_id,teacher_id');
      }

      if (newSet.isNotEmpty) {
        final primaryCheck = await client
            .from('batch_teachers')
            .select('teacher_id')
            .eq('batch_id', batchId)
            .eq('is_primary', true)
            .maybeSingle();

        if (primaryCheck == null) {
          await client
              .from('batch_teachers')
              .update({'is_primary': true})
              .match({
                'batch_id': batchId,
                'teacher_id': newSet.first,
              });
        }
      }
    } catch (e) {
      throw ServerException('Failed to update batch teachers', e);
    }
  }

  @override
  Future<void> createBatch(BatchModel batch, {List<String>? teacherIds}) async {
    final client = _supabase;
    if (client == null) throw const ServerException('Backend not configured');
    try {
      final data = batch.toMap();
      data.remove('id');
      data.remove('teacher_name');
      data.remove('teacher_id');
      data.remove('total_students');
      data.remove('play_product_id');

      Map<String, dynamic> insertData = Map<String, dynamic>.from(data);
      Map<String, dynamic>? response;
      try {
        response = await client
            .from('batches')
            .insert(insertData)
            .select('id')
            .single();
      } catch (insertErr) {
        final errStr = insertErr.toString().toLowerCase();
        final isUndefinedCol = errStr.contains('42703') ||
            errStr.contains('does not exist') ||
            errStr.contains('undefined column');
        bool handled = false;
        if (isUndefinedCol) {
          if (errStr.contains('rtmps_url')) {
            insertData.remove('rtmps_url');
            handled = true;
          }
          if (errStr.contains('stream_key')) {
            insertData.remove('stream_key');
            handled = true;
          }
          if (errStr.contains('playback_url')) {
            insertData.remove('playback_url');
            handled = true;
          }
        }

        if (handled) {
          try {
            response = await client
                .from('batches')
                .insert(insertData)
                .select('id')
                .single();
          } catch (retryErr) {
            final retryStr = retryErr.toString().toLowerCase();
            final isRetryUndefined = retryStr.contains('42703') ||
                retryStr.contains('does not exist') ||
                retryStr.contains('undefined column');
            if (isRetryUndefined) {
              if (retryStr.contains('rtmps_url')) insertData.remove('rtmps_url');
              if (retryStr.contains('stream_key')) insertData.remove('stream_key');
              if (retryStr.contains('playback_url')) insertData.remove('playback_url');
              response = await client
                  .from('batches')
                  .insert(insertData)
                  .select('id')
                  .single();
            } else {
              rethrow;
            }
          }
        } else {
          rethrow;
        }
      }

      final newBatchId = response['id']?.toString() ?? '';
      if (newBatchId.isNotEmpty) {
        final teachersToAssign = teacherIds ??
            (batch.teacherId.isNotEmpty && batch.teacherId != 'tch_001'
                ? [batch.teacherId]
                : <String>[]);
        for (int i = 0; i < teachersToAssign.length; i++) {
          final tId = teachersToAssign[i];
          if (tId.isNotEmpty && tId != 'tch_001') {
            try {
              await client.from('batch_teachers').insert({
                'batch_id': newBatchId,
                'teacher_id': tId,
                'is_primary': (i == 0),
              });
            } catch (tErr) {
              debugPrint('[CourseRemoteDataSource] Non-fatal batch_teachers insert error: ${_sanitizeForLog(tErr)}');
            }
          }
        }
      }
    } catch (e) {
      final sanitized = _sanitizeForLog(e);
      debugPrint('[CourseRemoteDataSource] Failed to create batch: $sanitized');
      throw ServerException('Failed to create batch: $sanitized', e);
    }
  }

  @override
  Future<void> updateBatch(BatchModel batch, {List<String>? teacherIds}) async {
    final client = _supabase;
    if (client == null) throw const ServerException('Backend not configured');
    try {
      final data = batch.toMap(includeNullsForUpdates: true);
      data.remove('id');
      data.remove('course_id');
      data.remove('teacher_name');
      data.remove('teacher_id');
      data.remove('total_students');
      data.remove('play_product_id');
      data['updated_at'] = DateTime.now().toIso8601String();

      Map<String, dynamic> updateData = Map<String, dynamic>.from(data);
      try {
        await client.from('batches').update(updateData).eq('id', batch.id);
      } catch (updateErr) {
        final errStr = updateErr.toString().toLowerCase();
        final isUndefinedCol = errStr.contains('42703') ||
            errStr.contains('does not exist') ||
            errStr.contains('undefined column');
        bool handled = false;
        if (isUndefinedCol) {
          if (errStr.contains('rtmps_url')) {
            updateData.remove('rtmps_url');
            handled = true;
          }
          if (errStr.contains('stream_key')) {
            updateData.remove('stream_key');
            handled = true;
          }
          if (errStr.contains('playback_url')) {
            updateData.remove('playback_url');
            handled = true;
          }
        }

        if (handled) {
          try {
            await client.from('batches').update(updateData).eq('id', batch.id);
          } catch (retryErr) {
            final retryStr = retryErr.toString().toLowerCase();
            final isRetryUndefined = retryStr.contains('42703') ||
                retryStr.contains('does not exist') ||
                retryStr.contains('undefined column');
            if (isRetryUndefined) {
              if (retryStr.contains('rtmps_url')) updateData.remove('rtmps_url');
              if (retryStr.contains('stream_key')) updateData.remove('stream_key');
              if (retryStr.contains('playback_url')) updateData.remove('playback_url');
              await client.from('batches').update(updateData).eq('id', batch.id);
            } else {
              rethrow;
            }
          }
        } else {
          rethrow;
        }
      }

      if (teacherIds != null) {
        try {
          await updateBatchTeachers(batch.id, teacherIds);
        } catch (tErr) {
          debugPrint('[CourseRemoteDataSource] Non-fatal batch_teachers update error: ${_sanitizeForLog(tErr)}');
        }
      } else if (batch.teacherId.isNotEmpty && batch.teacherId != 'tch_001') {
        try {
          await client.from('batch_teachers').upsert({
            'batch_id': batch.id,
            'teacher_id': batch.teacherId,
            'is_primary': true,
          }, onConflict: 'batch_id,teacher_id');
        } catch (tErr) {
          debugPrint('[CourseRemoteDataSource] Non-fatal batch_teachers upsert error: ${_sanitizeForLog(tErr)}');
        }
      }
    } catch (e) {
      final sanitized = _sanitizeForLog(e);
      debugPrint('[CourseRemoteDataSource] Failed to update batch: $sanitized');
      throw ServerException('Failed to update batch: $sanitized', e);
    }
  }

  @override
  Future<void> deleteBatch(String batchId) async {
    final client = _supabase;
    if (client == null) throw const ServerException('Backend not configured');
    try {
      // 1. Guard against deleting batch with active enrollments
      final enrollments = await client
          .from('enrollments')
          .select('id')
          .eq('batch_id', batchId)
          .eq('status', 'active');
      if ((enrollments as List).isNotEmpty) {
        throw const ServerException(
          'Cannot delete time slot with active student enrollments. Students must be transferred or unenrolled first.',
        );
      }

      // 2. Remove batch_teachers assignments
      try {
        await client.from('batch_teachers').delete().eq('batch_id', batchId);
      } catch (_) {}

      // 3. Delete batch
      await client.from('batches').delete().eq('id', batchId);
    } catch (e) {
      if (e is ServerException) rethrow;
      final err = e.toString().toLowerCase();
      if (err.contains('violates foreign key constraint') ||
          err.contains('23503')) {
        throw const ServerException(
          'Cannot delete time slot with existing records (enrollments, lessons, or attendance).',
        );
      }
      throw ServerException('Failed to delete batch: $e', e);
    }
  }

  @override
  Future<List<PaymentTransactionModel>> getStudentTransactions(
    String studentId,
  ) async {
    final client = _supabase;
    if (client == null) throw const ServerException('Backend not configured');
    try {
      final response = await client
          .from('transactions')
          .select('*')
          .eq('student_id', studentId)
          .order('created_at', ascending: false);
      return (response as List)
          .map(
            (json) =>
                PaymentTransactionModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      throw ServerException('Failed to fetch student transactions', e);
    }
  }

  @override
  Future<List<PaymentTransactionModel>> getAdminLedger(
    int offset,
    int limit,
  ) async {
    final client = _supabase;
    if (client == null) throw const ServerException('Backend not configured');
    try {
      final response = await client
          .from('transactions')
          .select('*')
          .order('created_at', ascending: false)
          .order('id', ascending: true)
          .range(offset, offset + limit - 1);

      final list = (response as List)
          .map(
            (json) =>
                PaymentTransactionModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();

      if (list.isNotEmpty) return list;

      // Fallback: If transactions table is empty, generate ledger items from active enrollments
      if (offset == 0) {
        try {
          final enrollments = await client
              .from('enrollments')
              .select(
                'id, student_id, batch_id, enrolled_at, batches(name, batch_price, course_id, courses(title)), profiles(full_name)',
              )
              .eq('status', 'active')
              .limit(limit);

          if (enrollments.isNotEmpty) {
            // Fetch 100% coupon redemptions to accurately tag free enrollments
            final Set<String> freeRedemptions = {};
            try {
              final redemptions = await client
                  .from('coupon_redemptions')
                  .select('student_id, batch_id');
              for (final r in (redemptions as List)) {
                final sId = r['student_id']?.toString() ?? '';
                final bId = r['batch_id']?.toString() ?? '';
                if (sId.isNotEmpty && bId.isNotEmpty) {
                  freeRedemptions.add('${sId}_$bId');
                }
              }
            } catch (_) {}

            return enrollments.map((row) {
              final studentId = row['student_id']?.toString() ?? '';
              final batchId = row['batch_id']?.toString() ?? '';
              final isFree = freeRedemptions.contains('${studentId}_$batchId');

              final batchData = row['batches'] as Map<String, dynamic>? ?? {};
              final courseData =
                  batchData['courses'] as Map<String, dynamic>? ?? {};
              final profileData =
                  row['profiles'] as Map<String, dynamic>? ?? {};
              final rawAmount =
                  (batchData['batch_price'] as num?)?.toDouble() ?? 0.0;
              final amount = isFree ? 0.0 : rawAmount;
              final studentName =
                  profileData['full_name'] as String? ?? 'Enrolled Student';
              final courseTitle = courseData['title'] as String? ??
                  batchData['name'] as String? ??
                  'Course';

              final idStr = row['id']?.toString() ?? '000000';
              final invSnippet = idStr.length >= 6
                  ? idStr.substring(0, 6).toUpperCase()
                  : idStr.toUpperCase();
              final refSnippet = idStr.length >= 8
                  ? idStr.substring(0, 8)
                  : idStr;

              return PaymentTransactionModel(
                id: idStr,
                invoiceNumber: isFree ? 'INV-FREE-$invSnippet' : 'INV-$invSnippet',
                transactionReference: isFree ? 'COUPON-$refSnippet' : 'ENR-$refSnippet',
                studentId: studentId,
                studentName: studentName,
                courseId: batchData['course_id']?.toString() ?? '',
                courseTitle: courseTitle,
                batchId: batchId,
                batchName: batchData['name']?.toString() ?? 'Batch',
                originalAmount: rawAmount,
                discountAmount: isFree ? rawAmount : 0.0,
                amountPaid: amount,
                paymentMethod: isFree ? 'Free Coupon (Scholarship)' : 'Google Play Billing',
                status: PaymentStatus.success,
                timestamp: row['enrolled_at'] != null
                    ? DateTime.tryParse(row['enrolled_at'].toString()) ??
                        DateTime.now()
                    : DateTime.now(),
              );
            }).toList();
          }
        } catch (fbErr) {
          debugPrint(
            '[CourseRemoteDataSource] Fallback admin ledger notice: $fbErr',
          );
        }
      }

      return [];
    } catch (e) {
      throw ServerException('Failed to fetch admin ledger', e);
    }
  }

  static double? parseCollectionsTotal(dynamic response) {
    if (response == null) {
      return null;
    }
    if (response is num) {
      return response.toDouble();
    }
    if (response is String) {
      final parsed = double.tryParse(response);
      if (parsed != null) {
        return parsed;
      }
    }
    throw ServerException(
      'Malformed RPC response for collections total: $response',
    );
  }

  @override
  Future<double?> getAdminManualCollectionsTotal() async {
    final client = _supabase;
    if (client == null) throw const ServerException('Backend not configured');
    try {
      double? rpcTotal;
      try {
        final response = await client.rpc('get_admin_manual_collections_total');
        rpcTotal = parseCollectionsTotal(response);
      } catch (rpcErr) {
        debugPrint(
          '[CourseRemoteDataSource] RPC get_admin_manual_collections_total notice: $rpcErr',
        );
      }

      // If the RPC returned a non-zero positive number, return it.
      if (rpcTotal != null && rpcTotal > 0) {
        return rpcTotal;
      }

      // Multi-tier Fallback: If RPC returned 0 or failed, aggregate directly
      double fallbackTotal = 0.0;

      // Tier 1: Aggregate transactions table
      try {
        final txList = await client
            .from('transactions')
            .select('amount_paid')
            .eq('status', 'success');

        if (txList.isNotEmpty) {
          for (final row in txList) {
            final amt = (row['amount_paid'] as num?)?.toDouble() ?? 0.0;
            fallbackTotal += amt;
          }
        }
      } catch (txErr) {
        debugPrint(
          '[CourseRemoteDataSource] Fallback transactions total notice: $txErr',
        );
      }

      // Tier 2: If transactions table has 0 collections, aggregate active enrollments x batch prices (excluding free coupon redemptions)
      if (fallbackTotal <= 0) {
        try {
          final enrollmentsList = await client
              .from('enrollments')
              .select('student_id, batch_id, batches!inner(batch_price)')
              .eq('status', 'active');

          if (enrollmentsList.isNotEmpty) {
            // Fetch free coupon redemptions to exclude them from cash revenue
            final Set<String> freeRedemptions = {};
            try {
              final redemptions = await client
                  .from('coupon_redemptions')
                  .select('student_id, batch_id');
              for (final r in (redemptions as List)) {
                final sId = r['student_id']?.toString() ?? '';
                final bId = r['batch_id']?.toString() ?? '';
                if (sId.isNotEmpty && bId.isNotEmpty) {
                  freeRedemptions.add('${sId}_$bId');
                }
              }
            } catch (_) {}

            for (final row in enrollmentsList) {
              final sId = row['student_id']?.toString() ?? '';
              final bId = row['batch_id']?.toString() ?? '';
              if (freeRedemptions.contains('${sId}_$bId')) {
                continue; // Exclude free coupon enrollments
              }

              final batchData = row['batches'];
              if (batchData is Map && batchData['batch_price'] != null) {
                final price =
                    (batchData['batch_price'] as num?)?.toDouble() ?? 0.0;
                fallbackTotal += price;
              }
            }
          }
        } catch (enrErr) {
          debugPrint(
            '[CourseRemoteDataSource] Fallback enrollments join notice: $enrErr',
          );
          // If inner join fails due to schema divergence, try separate batches lookup
          try {
            final rawEnrollments = await client
                .from('enrollments')
                .select('student_id, batch_id')
                .eq('status', 'active');

            if (rawEnrollments.isNotEmpty) {
              final Set<String> freeRedemptions = {};
              try {
                final redemptions = await client
                    .from('coupon_redemptions')
                    .select('student_id, batch_id');
                for (final r in (redemptions as List)) {
                  final sId = r['student_id']?.toString() ?? '';
                  final bId = r['batch_id']?.toString() ?? '';
                  if (sId.isNotEmpty && bId.isNotEmpty) {
                    freeRedemptions.add('${sId}_$bId');
                  }
                }
              } catch (_) {}

              final batchIds = rawEnrollments
                  .map((e) => e['batch_id']?.toString())
                  .where((id) => id != null && id.isNotEmpty)
                  .toSet()
                  .toList();

              if (batchIds.isNotEmpty) {
                final batchesList = await client
                    .from('batches')
                    .select('id, batch_price')
                    .inFilter('id', batchIds);

                final priceMap = <String, double>{};
                for (final b in (batchesList as List)) {
                  priceMap[b['id'].toString()] =
                      (b['batch_price'] as num?)?.toDouble() ?? 0.0;
                }

                for (final e in rawEnrollments) {
                  final sId = e['student_id']?.toString() ?? '';
                  final bId = e['batch_id']?.toString() ?? '';
                  if (freeRedemptions.contains('${sId}_$bId')) {
                    continue; // Exclude free coupon enrollments
                  }
                  if (bId.isNotEmpty && priceMap.containsKey(bId)) {
                    fallbackTotal += priceMap[bId]!;
                  }
                }
              }
            }
          } catch (flatErr) {
            debugPrint(
              '[CourseRemoteDataSource] Fallback flat enrollments notice: $flatErr',
            );
          }
        }
      }

      if (fallbackTotal > 0) {
        return fallbackTotal;
      }

      return rpcTotal ?? 0.0;
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(
        'Failed to fetch admin manual collections total',
        e,
      );
    }
  }

  Future<String> _uploadLectureVideoTus({
    required SupabaseClient client,
    required String fileName,
    required int fileLength,
    Uint8List? fileBytes,
    String? filePath,
    void Function(int uploadedBytes, int totalBytes)? onProgress,
    bool Function()? isCancelled,
  }) async {
    // Ensure active session token is refreshed before initiating TUS upload
    if (client.auth.currentSession?.isExpired ?? false) {
      try {
        await client.auth.refreshSession();
      } catch (_) {}
    }

    final freshToken = client.auth.currentSession?.accessToken;
    final headers = <String, String>{};
    if (freshToken != null) {
      headers['Authorization'] = 'Bearer $freshToken';
    }

    final response = await client.functions.invoke(
      'cloudflare_stream_manager',
      headers: headers,
      body: {
        'action': 'create_tus_upload',
        'upload_length': fileLength,
        'title': fileName,
        'max_duration_seconds': 14400,
      },
    );

    if (response.status != 200 ||
        response.data is! Map ||
        response.data['upload_url'] == null) {
      throw ServerException('Cloudflare TUS upload setup failed: ${response.data}');
    }

    final uploadUrl = response.data['upload_url'].toString();
    final playbackUrl = response.data['playback_url']?.toString();
    final chunkSize = _optimalTusChunkSize(fileLength);
    var offset = 0;
    RandomAccessFile? input;

    try {
      if (filePath != null && !kIsWeb && File(filePath).existsSync()) {
        input = await File(filePath).open();
      }

      while (offset < fileLength) {
        if (isCancelled?.call() == true) {
          throw const ServerException('Upload cancelled by user.');
        }
        final currentChunkSize =
            (fileLength - offset) > chunkSize ? chunkSize : fileLength - offset;
        Uint8List chunk;
        if (input != null) {
          await input.setPosition(offset);
          chunk = await input.read(currentChunkSize);
        } else {
          chunk = fileBytes!.sublist(offset, offset + currentChunkSize);
        }

        if (isCancelled?.call() == true) {
          throw const ServerException('Upload cancelled by user.');
        }

        offset = await _uploadTusChunk(
          uploadUrl: uploadUrl,
          offset: offset,
          chunk: chunk,
          isCancelled: isCancelled,
        );
        if (isCancelled?.call() == true) {
          throw const ServerException('Upload cancelled by user.');
        }
        onProgress?.call(offset, fileLength);
        debugPrint('Cloudflare TUS upload progress: $offset/$fileLength bytes');
      }
    } finally {
      await input?.close();
    }

    if (playbackUrl == null || playbackUrl.isEmpty) {
      throw const ServerException('Cloudflare did not return a playback URL.');
    }
    return playbackUrl;
  }

  int _optimalTusChunkSize(int fileLength) {
    // 5 MB chunk size (AWS S3 & Cloudflare standard minimum chunk).
    // Bounded chunk size guarantees that low-end devices (2GB-4GB RAM)
    // and spotty cellular networks (Jio/Airtel 4G/5G) never suffer carrier
    // NAT timeouts (Broken pipe / Connection reset by peer) or JVM heap exhaustion.
    return 5 * 1024 * 1024;
  }
/// Streams a video into Supabase Storage without loading it into memory.
  ///
  /// The bundled `storage_client` (2.8.x) reads the entire file into RAM via
  /// `file.readAsBytesSync()` before uploading, which throws "Out of Memory"
  /// for multi-hundred-MB / GB-sized lecture recordings. This fallback sends a
  /// multipart request whose file part streams straight from disk (via
  /// `MultipartFile.fromPath`), so peak memory stays bounded.
  Future<void> _uploadVideoToStorageFallback(
    SupabaseClient client, {
    required String storagePath,
    required String contentType,
    Uint8List? fileBytes,
    String? filePath,
    void Function(int uploadedBytes, int totalBytes)? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (isCancelled?.call() == true) {
      throw const ServerException('Upload cancelled by user.');
    }

    final session = client.auth.currentSession;
    if (session == null) {
      throw const ServerException(
        'Your session expired. Please sign out, log back in, and retry the upload.',
      );
    }

    final endpoint = Uri.parse(
      '${AppConfig.supabaseUrl}/storage/v1/object/'
      '${AppConstants.bucketLectureVideos}/$storagePath',
    );

    final request = http.MultipartRequest('POST', endpoint)
      ..headers['apikey'] = AppConfig.supabaseAnonKey
      ..headers['Authorization'] = 'Bearer ${session.accessToken}'
      ..headers['x-upsert'] = 'false'
      ..headers['cacheControl'] = '3600'
      ..fields['cacheControl'] = '3600';

    final mediaType = MediaType.parse(contentType);
    final fileName = storagePath.split('/').last;
    if (filePath != null && !kIsWeb && File(filePath).existsSync()) {
      request.files.add(
        await http.MultipartFile.fromPath(
          '',
          filePath,
          filename: fileName,
          contentType: mediaType,
        ),
      );
    } else if (fileBytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          '',
          fileBytes,
          filename: fileName,
          contentType: mediaType,
        ),
      );
    } else {
      throw const ServerException('No video data available to upload.');
    }

    if (isCancelled?.call() == true) {
      throw const ServerException('Upload cancelled by user.');
    }

    final response = await request.send();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await response.stream.bytesToString();
      throw ServerException(
        'Video upload rejected by storage (${response.statusCode}): $body',
      );
    }

    if (isCancelled?.call() == true) {
      throw const ServerException('Upload cancelled by user.');
    }

    final totalLen = filePath != null && !kIsWeb && File(filePath).existsSync()
        ? await File(filePath).length()
        : (fileBytes?.length ?? 0);
    onProgress?.call(totalLen, totalLen);
  }

  Future<int> _uploadTusChunk({
    required String uploadUrl,
    required int offset,
    required Uint8List chunk,
    bool Function()? isCancelled,
  }) async {
    Object? lastError;
    // Retry up to 5 times for mobile network resilience (survives 4G antenna handoffs / temporary drops)
    for (var attempt = 0; attempt < 5; attempt++) {
      if (isCancelled?.call() == true) {
        throw const ServerException('Upload cancelled by user.');
      }
      try {
        final response = await http.patch(
          Uri.parse(uploadUrl),
          headers: {
            'Tus-Resumable': '1.0.0',
            'Upload-Offset': offset.toString(),
            'Content-Type': 'application/offset+octet-stream',
            'Content-Length': chunk.length.toString(),
          },
          body: chunk,
        ).timeout(const Duration(seconds: 45));

        if (response.statusCode == 204) {
          return int.tryParse(response.headers['upload-offset'] ?? '') ??
              offset + chunk.length;
        }

        if (response.statusCode == 409 ||
            response.statusCode == 408 ||
            response.statusCode == 429 ||
            response.statusCode >= 500) {
          final acknowledgedOffset = await _getTusOffset(uploadUrl);
          if (acknowledgedOffset != null && acknowledgedOffset > offset) {
            return acknowledgedOffset;
          }
          lastError =
              'Cloudflare returned ${response.statusCode}: ${response.body}';
        } else {
          throw ServerException(
            'Cloudflare TUS chunk upload failed (${response.statusCode}): ${response.body}',
          );
        }
      } catch (error) {
        if (error is ServerException) rethrow;
        lastError = error;
        debugPrint('TUS chunk attempt $attempt failed ($error). Verifying acknowledged offset...');
        try {
          final ackOffset = await _getTusOffset(uploadUrl);
          if (ackOffset != null && ackOffset > offset) {
            return ackOffset;
          }
        } catch (_) {}
      }

      await Future<void>.delayed(Duration(milliseconds: 750 * (1 << attempt)));
    }

    throw ServerException(
      'Network upload interrupted after multiple retries ($lastError). Please verify your internet connection.',
    );
  }

  Future<int?> _getTusOffset(String uploadUrl) async {
    try {
      final response = await http.head(
        Uri.parse(uploadUrl),
        headers: {'Tus-Resumable': '1.0.0'},
      );
      return int.tryParse(response.headers['upload-offset'] ?? '');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String> uploadLectureVideo({
    required String batchId,
    required String fileName,
    Uint8List? fileBytes,
    String? filePath,
    void Function(int uploadedBytes, int totalBytes)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final client = _supabase;
    if (client == null) {
      throw const ServerException('Supabase client is not configured.');
    }

    if (filePath == null && fileBytes == null) {
      throw const ServerException('No video data or file path provided.');
    }

    String? cloudflareUploadFailure;

    // 1. Attempt Cloudflare Stream Direct Creator Upload first (0 bandwidth egress, adaptive HLS)
    try {
      final fileLength = filePath != null && !kIsWeb && File(filePath).existsSync()
          ? await File(filePath).length()
          : fileBytes!.length;
      if (fileLength > 0) {
        return await _uploadLectureVideoTus(
          client: client,
          fileName: fileName,
          fileLength: fileLength,
          fileBytes: fileBytes,
          filePath: filePath,
          onProgress: onProgress,
          isCancelled: isCancelled,
        );
      }

      final cfRes = await client.functions.invoke(
        'cloudflare_stream_manager',
        body: {
          'action': 'create_direct_upload',
          'batch_id': batchId,
          'title': fileName,
        },
      );

      if (cfRes.status == 200 && cfRes.data is Map && cfRes.data['upload_url'] != null) {
        final uploadUrl = cfRes.data['upload_url'].toString();
        final playbackUrl = cfRes.data['playback_url']?.toString();

        final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
        if (filePath != null && !kIsWeb && File(filePath).existsSync()) {
          request.files.add(
            await http.MultipartFile.fromPath(
              'file',
              filePath,
              filename: fileName,
            ),
          );
        } else if (fileBytes != null) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'file',
              fileBytes,
              filename: fileName,
            ),
          );
        }

        final streamedResponse = await request.send();
        if (streamedResponse.statusCode >= 200 && streamedResponse.statusCode < 300) {
          debugPrint('Prerecorded lecture uploaded directly to Cloudflare Stream: ${playbackUrl ?? uploadUrl}');
          return playbackUrl ?? uploadUrl;
        } else {
          final responseBody = await streamedResponse.stream.bytesToString();
          cloudflareUploadFailure =
              'Cloudflare upload returned ${streamedResponse.statusCode}${responseBody.isEmpty ? '' : ': $responseBody'}';
          debugPrint('Cloudflare direct upload returned status: ${streamedResponse.statusCode}. Falling back to storage.');
        }
      } else {
        cloudflareUploadFailure = 'Cloudflare direct-upload setup failed: ${cfRes.data}';
        debugPrint('Cloudflare create_direct_upload returned: ${cfRes.data}');
      }
    } catch (cfErr) {
      if (cfErr.toString().contains('Upload cancelled by user')) {
        rethrow;
      }
      cloudflareUploadFailure = 'Cloudflare direct-upload request failed: $cfErr';
      debugPrint('Cloudflare Stream direct upload notice: $cfErr. Falling back to Supabase storage.');
    }

    if (isCancelled?.call() == true) {
      throw const ServerException('Upload cancelled by user.');
    }

    // 2. Fallback to Supabase Storage if Cloudflare Stream is offline or unconfigured
    try {
      final cleanName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final storagePath =
          '$batchId/${DateTime.now().millisecondsSinceEpoch}_$cleanName';

      String contentType = 'video/mp4';
      final lower = cleanName.toLowerCase();
      if (lower.endsWith('.mkv')) contentType = 'video/x-matroska';
      if (lower.endsWith('.webm')) contentType = 'video/webm';
      if (lower.endsWith('.mov')) contentType = 'video/quicktime';

      await _uploadVideoToStorageFallback(
        client,
        storagePath: storagePath,
        contentType: contentType,
        fileBytes: fileBytes,
        filePath: filePath,
        onProgress: onProgress,
        isCancelled: isCancelled,
      );

      return storagePath;
    } catch (e) {
      if (e.toString().contains('Upload cancelled by user')) {
        rethrow;
      }
      debugPrint('Error uploading lecture video: $e');
      final errStr = e.toString();
      final cfFail = cloudflareUploadFailure;
      if (cfFail.contains('Storage capacity exceeded') ||
          cfFail.contains('allocated storage quota') ||
          cfFail.contains('10011')) {
        throw const ServerException(
          'Cloudflare Stream storage quota exceeded: Your account has reached its 1,000-minute limit (currently at 1,200+ mins). Please delete older or test recordings in your Cloudflare dashboard (Stream > Videos) or increase your allocated minutes to continue uploading lectures.',
        );
      }
      if (errStr.contains('exceeded the maximum') ||
          errStr.contains('exceeds') ||
          errStr.contains('413') ||
          errStr.contains('Payload Too Large')) {
        throw ServerException(
          'Video upload was rejected because the Cloudflare upload failed and the Supabase fallback exceeded its file-size limit. Configure Cloudflare Stream with a token that has Stream: Edit permission, then apply migration 057 or raise the lecture-videos bucket limit in Supabase. $cloudflareUploadFailure',
        );
      }
      if (errStr.contains('Broken pipe') ||
          errStr.contains('Connection reset') ||
          errStr.contains('SocketException')) {
        throw const ServerException(
          'Video upload connection closed: Network transfer timed out or exceeded connection threshold. Please ensure your internet connection is stable or run migration 057 to ensure unlimited storage bucket configuration.',
        );
      }
      throw ServerException('Failed to upload video: $e');
    }
  }

  @override
  Future<List<VideoLessonModel>> getLessonsForBatches(List<String> batchIds) async {
    final client = _supabase;
    if (client == null) throw const ServerException('Backend not configured');
    if (batchIds.isEmpty) return [];
    try {
      final response = await client
          .from('lessons')
          .select()
          .inFilter('batch_id', batchIds)
          .order('created_at', ascending: false);
      return (response as List)
          .map((item) => VideoLessonModel.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching lessons for batches: $e');
      return [];
    }
  }

  @override
  Future<String> uploadCourseCoverImage({
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
          'courses/${DateTime.now().millisecondsSinceEpoch}_$cleanName';

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
      debugPrint('Error uploading course cover image: $e');
      throw ServerException('Failed to upload course cover image: $e');
    }
  }

  @override
  Future<String> uploadLessonThumbnail({
    required String batchId,
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
          'lessons/$batchId/${DateTime.now().millisecondsSinceEpoch}_$cleanName';

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
      debugPrint('Error uploading thumbnail: $e');
      throw ServerException('Failed to upload thumbnail: $e');
    }
  }

  @override
  Future<VideoLessonModel> updateLessonThumbnail({
    required String lessonId,
    required String thumbnailUrl,
  }) async {
    final client = _supabase;
    if (client == null) {
      throw const ServerException('Supabase client is not configured.');
    }

    try {
      final response = await client
          .from('lessons')
          .update({'thumbnail_url': thumbnailUrl})
          .eq('id', lessonId)
          .select()
          .single();

      return VideoLessonModel.fromMap(response);
    } catch (e) {
      debugPrint('Error updating lesson thumbnail: $e');
      throw ServerException('Failed to update lesson thumbnail: $e');
    }
  }

  @override
  Future<VideoLessonModel> updateLesson({
    required String lessonId,
    String? title,
    String? chapter,
    String? thumbnailUrl,
    String? notesPdfUrl,
  }) async {
    final client = _supabase;
    if (client == null) {
      throw const ServerException('Supabase client is not configured.');
    }

    try {
      final updates = <String, dynamic>{};
      if (title != null) updates['title'] = title.trim();
      if (chapter != null) updates['chapter'] = chapter.trim();
      if (thumbnailUrl != null) updates['thumbnail_url'] = thumbnailUrl.trim();
      if (notesPdfUrl != null) updates['notes_pdf_url'] = notesPdfUrl.trim();

      if (updates.isEmpty) {
        final existing = await client
            .from('lessons')
            .select()
            .eq('id', lessonId)
            .single();
        return VideoLessonModel.fromMap(existing);
      }

      final response = await client
          .from('lessons')
          .update(updates)
          .eq('id', lessonId)
          .select()
          .single();

      return VideoLessonModel.fromMap(response);
    } catch (e) {
      debugPrint('Error updating lesson: $e');
      throw ServerException('Failed to update lesson: $e');
    }
  }

  @override
  Future<VideoLessonModel> createLesson({
    required String courseId,
    required String batchId,
    required String title,
    required String chapter,
    required String videoUrl,
    String? thumbnailUrl,
    int durationSeconds = 0,
    int? orderIndex,
  }) async {
    final client = _supabase;
    if (client == null) {
      throw const ServerException('Supabase client is not configured.');
    }

    try {
      // Prevent duplicate lesson titles in the same batch
      final existing = await client
          .from('lessons')
          .select('id')
          .eq('batch_id', batchId)
          .eq('title', title)
          .maybeSingle();

      if (existing != null) {
        throw const ServerException(
          'A lesson with this title already exists in this batch.',
        );
      }

      int calculatedOrderIndex = orderIndex ?? 1;
      if (orderIndex == null) {
        final lastLesson = await client
            .from('lessons')
            .select('order_index')
            .eq('batch_id', batchId)
            .order('order_index', ascending: false)
            .limit(1)
            .maybeSingle();

        if (lastLesson != null && lastLesson['order_index'] != null) {
          calculatedOrderIndex = (lastLesson['order_index'] as num).toInt() + 1;
        }
      }

      final payload = <String, dynamic>{
        'course_id': courseId,
        'batch_id': batchId,
        'title': title,
        'chapter': chapter,
        'video_url': videoUrl,
        'duration_seconds': durationSeconds,
        'order_index': calculatedOrderIndex,
      };
      if (thumbnailUrl != null) {
        payload['thumbnail_url'] = thumbnailUrl;
      }

      final response = await client
          .from('lessons')
          .insert(payload)
          .select()
          .single();

      // Dynamically auto-track and recalculate course lesson stats
      try {
        final lessonsCountRes = await client
            .from('lessons')
            .select('duration_seconds')
            .eq('course_id', courseId);
        final count = (lessonsCountRes as List).length;
        int totalSec = 0;
        for (final row in lessonsCountRes) {
          totalSec += (row['duration_seconds'] as num?)?.toInt() ?? 0;
        }
        final totalHours = (totalSec / 3600).round();
        await client.from('courses').update({
          'total_lessons': count,
          'total_hours': totalHours,
        }).eq('id', courseId);
      } catch (statsErr) {
        debugPrint('Non-critical: Failed to auto-update course stats: $statsErr');
      }

      return VideoLessonModel.fromMap(response);
    } catch (e) {
      debugPrint('Error inserting lesson: $e');
      if (e is ServerException) rethrow;
      throw ServerException('Failed to create lesson: $e');
    }
  }

  @override
  Future<String> getLessonVideoSignedUrl(String videoUrlOrPath) async {
    final trimmed = videoUrlOrPath.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    final client = _supabase;
    if (client == null) {
      throw const ServerException('Supabase client is not configured.');
    }

    try {
      final cleanPath = trimmed
          .replaceFirst(RegExp(r'^/+'), '')
          .replaceFirst(RegExp(r'^' + RegExp.escape(AppConstants.bucketLectureVideos) + r'/+'), '');

      // 1. Try generating a signed URL first (valid for 2 hours = 7200s for uninterrupted study)
      try {
        final signedUrl = await client.storage
            .from(AppConstants.bucketLectureVideos)
            .createSignedUrl(cleanPath, 7200);
        if (signedUrl.isNotEmpty &&
            (signedUrl.startsWith('http://') || signedUrl.startsWith('https://'))) {
          return signedUrl;
        }
      } catch (signErr) {
        debugPrint('[CourseRemoteDataSource] createSignedUrl notice: $signErr. Trying public URL fallback...');
      }

      // 2. Fallback to public URL in case the bucket is public
      final publicUrl = client.storage
          .from(AppConstants.bucketLectureVideos)
          .getPublicUrl(cleanPath);
      if (publicUrl.isNotEmpty &&
          (publicUrl.startsWith('http://') || publicUrl.startsWith('https://'))) {
        return publicUrl;
      }

      throw ServerException('Failed to generate video access URL for path: $cleanPath');
    } catch (e) {
      debugPrint('Error generating video URL: $e');
      throw ServerException('Failed to generate video access URL: $e');
    }
  }

  @override
  Future<void> deleteCourse(String courseId) async {
    final client = _supabase;
    if (client == null) {
      throw const ServerException('Supabase client is not configured.');
    }

    try {
      // 1. Fetch child batch IDs to clean up dependent records safely
      final batches = await client.from('batches').select('id').eq('course_id', courseId);
      for (final b in (batches as List)) {
        final bId = b['id']?.toString() ?? '';
        if (bId.isNotEmpty) {
          try { await client.from('enrollments').delete().eq('batch_id', bId); } catch (_) {}
          try { await client.from('lessons').delete().eq('batch_id', bId); } catch (_) {}
          try { await client.from('batch_teachers').delete().eq('batch_id', bId); } catch (_) {}
          try { await client.from('batch_schedules').delete().eq('batch_id', bId); } catch (_) {}
          try { await client.from('attendance').delete().eq('batch_id', bId); } catch (_) {}
        }
      }
      // 2. Delete child batches
      await client.from('batches').delete().eq('course_id', courseId);
      // 3. Delete lessons & study materials attached directly to course
      try { await client.from('lessons').delete().eq('course_id', courseId); } catch (_) {}
      try { await client.from('study_materials').delete().eq('course_id', courseId); } catch (_) {}
      // 4. Finally delete the course
      await client.from('courses').delete().eq('id', courseId);
    } catch (e) {
      debugPrint('Error deleting course $courseId: $e');
      throw ServerException('Failed to delete course: $e');
    }
  }

  @override
  Future<void> deleteLesson(
    String lessonId, {
    String? videoPath,
    String? thumbnailPath,
  }) async {
    final client = _supabase;
    if (client == null) {
      throw const ServerException('Supabase client is not configured.');
    }

    if (videoPath != null && videoPath.isNotEmpty) {
      try {
        final cleanPath =
            videoPath.contains('/') ? videoPath.split('/').last : videoPath;
        await client.storage
            .from(AppConstants.bucketLectureVideos)
            .remove([cleanPath]);
      } catch (e) {
        debugPrint('Warning: Failed to delete lecture video file: $e');
      }
    }

    if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
      try {
        final cleanThumb = thumbnailPath.contains('/')
            ? thumbnailPath.split('/').last
            : thumbnailPath;
        await client.storage
            .from(AppConstants.bucketCourseThumbnails)
            .remove([cleanThumb]);
      } catch (e) {
        debugPrint('Warning: Failed to delete lecture thumbnail file: $e');
      }
    }

    try {
      bool rpcHandled = false;
      try {
        final rpcRes = await client.rpc('delete_lecture', params: {
          'p_lecture_id': lessonId,
          'p_confirm': 'confirm',
        });
        if (rpcRes != null) {
          rpcHandled = true;
        }
      } catch (rpcErr) {
        debugPrint('delete_lecture RPC fallback notice: $rpcErr');
      }

      if (!rpcHandled) {
        String? courseId;
        try {
          final lRow = await client
              .from('lessons')
              .select('course_id')
              .eq('id', lessonId)
              .maybeSingle();
          courseId = lRow?['course_id']?.toString();
        } catch (_) {}

        final deleted = await client
            .from('lessons')
            .delete()
            .eq('id', lessonId)
            .select('id');

        if ((deleted as List).isEmpty) {
          throw const ServerException(
            'Failed to delete lecture: Row was not deleted. '
            'Please ensure database migration 059 has been run in Supabase SQL editor.',
          );
        }

        if (courseId != null && courseId.isNotEmpty) {
          try {
            final lessonsCountRes = await client
                .from('lessons')
                .select('duration_seconds')
                .eq('course_id', courseId);
            final count = (lessonsCountRes as List).length;
            int totalSec = 0;
            for (final row in lessonsCountRes) {
              totalSec += (row['duration_seconds'] as num?)?.toInt() ?? 0;
            }
            final totalHours = (totalSec / 3600).round();
            await client.from('courses').update({
              'total_lessons': count,
              'total_hours': totalHours,
            }).eq('id', courseId);
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Error deleting lesson $lessonId: $e');
      if (e is ServerException) rethrow;
      throw ServerException('Failed to delete lesson: $e');
    }
  }

  @override
  Future<List<CouponModel>> getCoupons() async {
    final client = _supabase;
    if (client == null) throw const ServerException('Backend not configured');
    try {
      final res = await client
          .from('coupons')
          .select()
          .order('created_at', ascending: false);
      return (res as List)
          .map((c) => CouponModel.fromJson(c as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('getCoupons error: $e');
      return [];
    }
  }

  @override
  Future<CouponModel> createCoupon(CouponModel coupon) async {
    final client = _supabase;
    if (client == null) throw const ServerException('Backend not configured');
    try {
      final payload = <String, dynamic>{
        'code': coupon.code.trim().toUpperCase(),
        'discount_amount': coupon.discountAmount,
        'discount_type': coupon.discountType,
        'min_order_value': coupon.minOrderValue,
        if (coupon.description.isNotEmpty) 'description': coupon.description,
        'is_active': coupon.isActive,
        'applicable_course_ids': coupon.applicableCourseIds.isNotEmpty ? coupon.applicableCourseIds : null,
      };
      try {
        final res = await client.from('coupons').insert(payload).select().single();
        return CouponModel.fromJson(res);
      } catch (inner) {
        if (inner.toString().contains('description')) {
          payload.remove('description');
          final res = await client.from('coupons').insert(payload).select().single();
          return CouponModel.fromJson(res);
        }
        rethrow;
      }
    } catch (e) {
      debugPrint('createCoupon error: $e');
      throw ServerException('Failed to create coupon: $e');
    }
  }

  @override
  Future<void> updateCoupon(CouponModel coupon) async {
    final client = _supabase;
    if (client == null) throw const ServerException('Backend not configured');
    try {
      final payload = <String, dynamic>{
        'code': coupon.code.trim().toUpperCase(),
        'discount_amount': coupon.discountAmount,
        'discount_type': coupon.discountType,
        'min_order_value': coupon.minOrderValue,
        if (coupon.description.isNotEmpty) 'description': coupon.description,
        'is_active': coupon.isActive,
        'applicable_course_ids': coupon.applicableCourseIds.isNotEmpty ? coupon.applicableCourseIds : null,
      };
      Future<void> executeUpdate(Map<String, dynamic> data) async {
        if (coupon.id != null && coupon.id!.isNotEmpty) {
          await client.from('coupons').update(data).eq('id', coupon.id!);
        } else {
          await client.from('coupons').update(data).eq('code', coupon.code.trim().toUpperCase());
        }
      }
      try {
        await executeUpdate(payload);
      } catch (inner) {
        if (inner.toString().contains('description')) {
          payload.remove('description');
          await executeUpdate(payload);
        } else {
          rethrow;
        }
      }
    } catch (e) {
      debugPrint('updateCoupon error: $e');
      throw ServerException('Failed to update coupon: $e');
    }
  }

  @override
  Future<void> deleteCoupon(String couponId) async {
    final client = _supabase;
    if (client == null) throw const ServerException('Backend not configured');
    try {
      await client.from('coupons').delete().eq('id', couponId);
    } catch (e) {
      debugPrint('deleteCoupon error: $e');
      throw ServerException('Failed to delete coupon: $e');
    }
  }
}
