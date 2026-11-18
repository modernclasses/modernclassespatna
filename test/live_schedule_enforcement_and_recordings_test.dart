import 'package:flutter_test/flutter_test.dart';
import 'package:modern_classes_patna/core/utils/batch_timing_helper.dart';
import 'package:modern_classes_patna/features/live_classes/data/models/lecture_recording_model.dart';
import 'package:modern_classes_patna/features/live_classes/data/models/live_class_model.dart';
import 'package:modern_classes_patna/features/live_classes/data/repositories/live_class_repository.dart';
import 'package:modern_classes_patna/features/live_classes/logic/live_class_provider.dart';

class MockLiveClassRepository implements LiveClassRepository {
  final List<LiveClassModel> liveClasses;
  final List<LectureRecordingModel> recordings;

  MockLiveClassRepository({
    List<LiveClassModel>? liveClasses,
    List<LectureRecordingModel>? recordings,
  })  : liveClasses = liveClasses ?? [],
        recordings = recordings ?? [];

  @override
  Future<List<LiveClassModel>> getLiveClasses() async => liveClasses;

  @override
  Future<LiveClassModel> scheduleLiveClass(LiveClassModel liveClass, {String? teacherId}) async => liveClass;

  @override
  Future<void> updateLiveClassStatus(String id, LiveStatus status) async {}

  @override
  Future<String> uploadLiveClassThumbnail({required String fileName, required dynamic fileBytes}) async =>
      'https://mock.storage/thumb.jpg';

  @override
  Future<SlotValidationResult> validateBatchSchedule(String batchId) async {
    return const SlotValidationResult(
      isValid: true,
      message: 'Validated by mock backend',
    );
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
    final session = LiveClassModel(
      id: 'session_${DateTime.now().millisecondsSinceEpoch}',
      courseId: 'course_1',
      batchId: batchId,
      courseName: 'General Studies',
      batchName: 'Target Batch A',
      title: title,
      subject: subject,
      teacherName: 'Faculty Test',
      teacherAvatar: '',
      scheduledStartTime: DateTime.now(),
      actualStartTime: DateTime.now(),
      status: LiveStatus.live,
      streamUrl: streamUrl,
      thumbnailUrl: thumbnailUrl,
      liveInputUid: liveInputUid,
      recordingStatus: 'processing',
    );
    liveClasses.insert(0, session);
    return session;
  }

  @override
  Future<void> endAuthenticatedLiveSession(String liveClassId, {int? durationSeconds, DateTime? endTime}) async {
    final idx = liveClasses.indexWhere((c) => c.id == liveClassId);
    if (idx != -1) {
      liveClasses[idx] = liveClasses[idx].copyWith(
        status: LiveStatus.ended,
        actualEndTime: DateTime.now(),
        recordingStatus: 'processing',
      );
    }
  }

  @override
  Future<List<LectureRecordingModel>> getLectureRecordings({
    String? courseId,
    String? batchId,
    String? teacherId,
  }) async {
    return recordings.where((r) {
      if (courseId != null && r.courseId != courseId) return false;
      if (batchId != null && r.batchId != batchId) return false;
      if (teacherId != null && r.teacherId != teacherId) return false;
      return true;
    }).toList();
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
    final effectiveVideoUid = liveClassId != null
        ? 'cf_video_$liveClassId'
        : 'cf_video_${DateTime.now().millisecondsSinceEpoch}';

    final existingIdx = recordings.indexWhere(
      (r) =>
          (liveClassId != null && r.liveClassId == liveClassId) ||
          r.videoUid == effectiveVideoUid,
    );

    if (existingIdx != -1) {
      final updated = recordings[existingIdx].copyWith(
        title: title,
        durationSeconds:
            durationSeconds ?? recordings[existingIdx].durationSeconds,
        playbackUrl: playbackUrl ?? recordings[existingIdx].playbackUrl,
      );
      recordings[existingIdx] = updated;
      return updated;
    }

    final rec = LectureRecordingModel(
      id: 'rec_${DateTime.now().millisecondsSinceEpoch}',
      liveClassId: liveClassId,
      courseId: courseId,
      batchId: batchId,
      courseName: 'General Studies',
      batchName: 'Target Batch A',
      teacherId: teacherId,
      teacherName: 'Faculty Test',
      title: title,
      liveInputUid: liveInputUid,
      videoUid: effectiveVideoUid,
      playbackUrl: playbackUrl ??
          'https://videodelivery.net/$effectiveVideoUid/manifest/video.m3u8',
      startTime: startTime ?? DateTime.now(),
      endTime: endTime,
      durationSeconds: durationSeconds ?? 3600,
      status: RecordingStatus.processing,
      isPublished: true,
      createdAt: DateTime.now(),
    );
    recordings.insert(0, rec);
    return rec;
  }

  @override
  Future<LectureRecordingModel?> refreshRecordingStatus(String videoUid) async {
    final idx = recordings.indexWhere((r) => r.videoUid == videoUid);
    if (idx != -1) {
      final promoted = LectureRecordingModel(
        id: recordings[idx].id,
        liveClassId: recordings[idx].liveClassId,
        courseId: recordings[idx].courseId,
        batchId: recordings[idx].batchId,
        courseName: recordings[idx].courseName,
        batchName: recordings[idx].batchName,
        teacherId: recordings[idx].teacherId,
        teacherName: recordings[idx].teacherName,
        title: recordings[idx].title,
        liveInputUid: recordings[idx].liveInputUid,
        videoUid: recordings[idx].videoUid,
        playbackUrl: recordings[idx].playbackUrl,
        startTime: recordings[idx].startTime,
        endTime: recordings[idx].endTime,
        durationSeconds: recordings[idx].durationSeconds,
        status: RecordingStatus.ready,
        isPublished: true,
        createdAt: recordings[idx].createdAt,
      );
      recordings[idx] = promoted;
      return promoted;
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>> checkCloudflareLiveStatus(String liveInputUid) async {
    return {'status': 'connected', 'connected': true};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Batch Live Schedule Enforcement (Asia/Kolkata IST)', () {
    const timingSlot = '07:00 PM - 08:00 PM (Mon-Sun)';

    test('Strictly BLOCKS starting at 8:04 PM when batch slot ends at 8:00 PM', () {
      // Create UTC timestamp corresponding to 8:04 PM IST (20:04 IST = 14:34 UTC)
      final testTimeUtc = DateTime.utc(2026, 10, 25, 14, 34); // 8:04 PM IST
      final result = BatchTimingHelper.validateCurrentTimeSlot(
        timingSlot,
        customNow: testTimeUtc,
        postEndGraceMinutes: 0, // strict 0-minute post-end grace
      );

      expect(result.isValid, isFalse, reason: 'Must block start after 8:00 PM');
      expect(result.isPastEndTime, isTrue);
      expect(result.message, contains('ended at 08:00 PM IST'));
      expect(result.message, contains('4 minutes ago'));
      expect(result.minutesRemainingInSlot, equals(0));
    });

    test('Permits starting at 7:30 PM within the 7:00 PM - 8:00 PM slot', () {
      // 7:30 PM IST = 14:00 UTC
      final testTimeUtc = DateTime.utc(2026, 10, 25, 14, 0);
      final result = BatchTimingHelper.validateCurrentTimeSlot(
        timingSlot,
        customNow: testTimeUtc,
      );

      expect(result.isValid, isTrue);
      expect(result.isPastEndTime, isFalse);
      expect(result.minutesRemainingInSlot, equals(30));
    });

    test('Permits starting 10 minutes early with default 15-minute early setup buffer', () {
      // 6:50 PM IST = 13:20 UTC (10 mins before 7:00 PM)
      final testTimeUtc = DateTime.utc(2026, 10, 25, 13, 20);
      final result = BatchTimingHelper.validateCurrentTimeSlot(
        timingSlot,
        customNow: testTimeUtc,
        earlyBufferMinutes: 15,
      );

      expect(result.isValid, isTrue, reason: 'Early setup within 15 mins should be allowed');
    });

    test('Blocks starting too early (e.g. 6:30 PM for 7:00 PM slot)', () {
      // 6:30 PM IST = 13:00 UTC (30 mins before 7:00 PM)
      final testTimeUtc = DateTime.utc(2026, 10, 25, 13, 0);
      final result = BatchTimingHelper.validateCurrentTimeSlot(
        timingSlot,
        customNow: testTimeUtc,
        earlyBufferMinutes: 15,
      );

      expect(result.isValid, isFalse);
      expect(result.isTooEarly, isTrue);
      expect(result.message, contains('Class slot begins at 07:00 PM IST'));
    });

    test('Correctly handles overnight schedules crossing midnight', () {
      const overnightSlot = '10:00 PM - 01:00 AM (Mon-Sun)';
      // 11:30 PM IST (before midnight)
      final timeBeforeMidnightUtc = DateTime.utc(2026, 10, 25, 18, 0); // 23:30 IST
      final resultBefore = BatchTimingHelper.validateCurrentTimeSlot(
        overnightSlot,
        customNow: timeBeforeMidnightUtc,
      );
      expect(resultBefore.isValid, isTrue);

      // 12:30 AM IST (after midnight)
      final timeAfterMidnightUtc = DateTime.utc(2026, 10, 25, 19, 0); // 00:30 IST
      final resultAfter = BatchTimingHelper.validateCurrentTimeSlot(
        overnightSlot,
        customNow: timeAfterMidnightUtc,
      );
      expect(resultAfter.isValid, isTrue);

      // 01:05 AM IST (after overnight slot end)
      final timePastEndUtc = DateTime.utc(2026, 10, 25, 19, 35); // 01:05 IST
      final resultPast = BatchTimingHelper.validateCurrentTimeSlot(
        overnightSlot,
        customNow: timePastEndUtc,
        postEndGraceMinutes: 0,
      );
      expect(resultPast.isValid, isFalse);
      expect(resultPast.isPastEndTime, isTrue);
    });

    test('Verifies IST conversion from UTC accurately', () {
      final utc = DateTime.utc(2026, 10, 25, 10, 0); // 10:00 UTC
      final ist = BatchTimingHelper.getNowInKolkata(utc);
      expect(ist.hour, equals(15)); // 10 + 5.5 = 15:30
      expect(ist.minute, equals(30));
    });
  });

  group('Lecture Recordings Processing & Authorization', () {
    late MockLiveClassRepository mockRepo;
    late LiveClassProvider liveProvider;

    setUp(() {
      mockRepo = MockLiveClassRepository(
        liveClasses: [
          LiveClassModel(
            id: 'live_ready_1',
            courseId: 'c1',
            batchId: 'b1',
            courseName: 'Course 1',
            batchName: 'Batch 1',
            title: 'Ready Lecture',
            subject: 'History',
            teacherName: 'Teacher A',
            teacherAvatar: '',
            scheduledStartTime: DateTime.now().subtract(const Duration(hours: 3)),
            status: LiveStatus.ended,
            streamUrl: 'https://videodelivery.net/ready1/manifest/video.m3u8',
            recordingStatus: 'ready',
          ),
          LiveClassModel(
            id: 'live_proc_1',
            courseId: 'c1',
            batchId: 'b1',
            courseName: 'Course 1',
            batchName: 'Batch 1',
            title: 'Processing Lecture',
            subject: 'History',
            teacherName: 'Teacher A',
            teacherAvatar: '',
            scheduledStartTime: DateTime.now().subtract(const Duration(minutes: 5)),
            status: LiveStatus.ended,
            streamUrl: '',
            recordingStatus: 'processing',
          ),
          LiveClassModel(
            id: 'live_fail_1',
            courseId: 'c1',
            batchId: 'b1',
            courseName: 'Course 1',
            batchName: 'Batch 1',
            title: 'Failed Lecture',
            subject: 'History',
            teacherName: 'Teacher A',
            teacherAvatar: '',
            scheduledStartTime: DateTime.now().subtract(const Duration(days: 1)),
            status: LiveStatus.ended,
            streamUrl: '',
            recordingStatus: 'failed',
          ),
        ],
        recordings: [
          LectureRecordingModel(
            id: 'rec_1',
            courseId: 'c1',
            batchId: 'b1',
            teacherId: 'teacher_1',
            teacherName: 'Teacher A',
            title: 'Lecture 1',
            videoUid: 'vid_1',
            playbackUrl: 'https://videodelivery.net/vid1/manifest/video.m3u8',
            durationSeconds: 3600,
            status: RecordingStatus.processing,
            isPublished: true,
            createdAt: DateTime.now(),
          ),
          LectureRecordingModel(
            id: 'rec_2',
            courseId: 'c2',
            batchId: 'b2',
            teacherId: 'teacher_2',
            teacherName: 'Teacher B',
            title: 'Lecture 2',
            videoUid: 'vid_2',
            playbackUrl: 'https://videodelivery.net/vid2/manifest/video.m3u8',
            durationSeconds: 2700,
            status: RecordingStatus.ready,
            isPublished: true,
            createdAt: DateTime.now(),
          ),
        ],
      );
      liveProvider = LiveClassProvider(repository: mockRepo);
    });

    test('Student pastRecordings ONLY exposes recordings with status ready', () async {
      await liveProvider.fetchLiveClasses();

      final past = liveProvider.pastRecordings;
      expect(past.length, equals(1), reason: 'Processing and Failed recordings must be hidden from students');
      expect(past.first.id, equals('live_ready_1'));
      expect(past.first.recordingStatus, equals('ready'));
    });

    test('Retains processing recording and promotes to ready upon Cloudflare refresh', () async {
      await liveProvider.fetchLectureRecordings();
      expect(liveProvider.recordings.first.isProcessing, isTrue);

      final promoted = await liveProvider.refreshRecording('vid_1');
      expect(promoted, isNotNull);
      expect(promoted!.isReady, isTrue);
      expect(liveProvider.recordings.first.isReady, isTrue);
    });

    test('Teacher recordings query filters strictly by teacherId authorization', () async {
      await liveProvider.fetchLectureRecordings(teacherId: 'teacher_1');
      expect(liveProvider.recordings.length, equals(1));
      expect(liveProvider.recordings.first.teacherId, equals('teacher_1'));
      expect(liveProvider.recordings.first.title, equals('Lecture 1'));
    });

    test('Live session lifecycle correctly tracks actual start and end timestamps', () async {
      final session = await liveProvider.startAuthenticatedLiveSession(
        batchId: 'batch_test_1',
        title: 'Authoritative Session Test',
        subject: 'Polity',
        streamUrl: 'rtmps://live.cloudflare.com/live/key',
        liveInputUid: 'input_uid_123',
      );

      expect(session.actualStartTime, isNotNull);
      expect(session.status, equals(LiveStatus.live));

      await liveProvider.endAuthenticatedLiveSession(session.id);
      final endedClass = liveProvider.getLiveClassById(session.id);
      expect(endedClass?.status, equals(LiveStatus.ended));
      expect(endedClass?.actualEndTime, isNotNull);
      expect(endedClass?.recordingStatus, equals('processing'));
    });

    test('Safe retry: repeat syncBroadcastRecording calls update existing record and prevent duplicates', () async {
      final initialRec = await liveProvider.syncBroadcastRecording(
        batchId: 'batch_test_1',
        courseId: 'course_test_1',
        title: 'Retry Lecture',
        liveClassId: 'live_retry_101',
        liveInputUid: 'input_retry_101',
        playbackUrl: 'https://customer-test.cloudflarestream.com/input_retry_101/manifest/video.m3u8',
        durationSeconds: 1200,
      );

      expect(initialRec, isNotNull);
      final initialCount = liveProvider.recordings.where((r) => r.liveClassId == 'live_retry_101').length;
      expect(initialCount, equals(1));

      // Re-trigger sync (e.g. repeated tap or network retry)
      final retryRec = await liveProvider.syncBroadcastRecording(
        batchId: 'batch_test_1',
        courseId: 'course_test_1',
        title: 'Retry Lecture (Updated)',
        liveClassId: 'live_retry_101',
        liveInputUid: 'input_retry_101',
        playbackUrl: 'https://customer-test.cloudflarestream.com/input_retry_101/manifest/video.m3u8',
        durationSeconds: 1500,
      );

      expect(retryRec, isNotNull);
      final afterRetryCount = liveProvider.recordings.where((r) => r.liveClassId == 'live_retry_101').length;
      expect(afterRetryCount, equals(1), reason: 'Safe upsert must never duplicate recordings for the same session');
      expect(retryRec!.title, equals('Retry Lecture (Updated)'));
      expect(retryRec.durationSeconds, equals(1500));
    });

    test('Cloudflare delayed recording availability: retains processing state and does not mark failed', () async {
      final rec = await liveProvider.syncBroadcastRecording(
        batchId: 'batch_test_1',
        courseId: 'course_test_1',
        title: 'Delayed Buffer Lecture',
        liveClassId: 'live_delayed_202',
        liveInputUid: 'input_delayed_202',
        durationSeconds: 2400,
      );

      expect(rec, isNotNull);
      expect(rec!.isProcessing, isTrue);
      expect(rec.isFailed, isFalse);
      expect(rec.statusName, equals('processing'));

      // Verify that student past recordings still hides it while in ~60s processing buffer
      final studentPast = liveProvider.pastRecordings;
      expect(studentPast.any((c) => c.id == 'live_delayed_202'), isFalse);
    });

    test('Promoting recording to ready synchronizes status across recordings and live class state', () async {
      // Start and end session
      final session = await liveProvider.startAuthenticatedLiveSession(
        batchId: 'batch_test_1',
        title: 'Status Sync Lecture',
        subject: 'History',
        streamUrl: 'https://customer-test.cloudflarestream.com/history/manifest/video.m3u8',
      );

      await liveProvider.endAuthenticatedLiveSession(session.id);

      final rec = await liveProvider.syncBroadcastRecording(
        batchId: 'batch_test_1',
        courseId: 'course_test_1',
        title: 'Status Sync Lecture',
        liveClassId: session.id,
        durationSeconds: 1800,
      );

      expect(rec, isNotNull);
      expect(rec!.isProcessing, isTrue);

      // Now promote status to ready
      final promoted = await liveProvider.refreshRecording(rec.videoUid);
      expect(promoted, isNotNull);
      expect(promoted!.isReady, isTrue);

      // Verify class in liveProvider._classes reflects ready state
      final updatedClass = liveProvider.getLiveClassById(session.id);
      expect(updatedClass?.recordingStatus, equals('ready'));

      // Verify student archive now includes the promoted recording
      final studentPast = liveProvider.pastRecordings;
      expect(studentPast.any((c) => c.id == session.id), isTrue);
    });
  });
}
