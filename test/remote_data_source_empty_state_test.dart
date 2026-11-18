import 'package:flutter_test/flutter_test.dart';
import 'package:modern_classes_patna/core/utils/batch_timing_helper.dart';
import 'package:modern_classes_patna/features/live_classes/data/models/lecture_recording_model.dart';
import 'package:modern_classes_patna/features/live_classes/data/models/live_class_model.dart';
import 'package:modern_classes_patna/features/live_classes/data/repositories/live_class_repository.dart';
import 'package:modern_classes_patna/features/live_classes/logic/live_class_provider.dart';

class FakeLiveClassRepository implements LiveClassRepository {
  bool throwError = false;
  List<LiveClassModel> response = [];

  @override
  Future<List<LiveClassModel>> getLiveClasses() async {
    if (throwError) throw Exception('Simulated fetch error');
    return response;
  }

  @override
  Future<LiveClassModel> scheduleLiveClass(
    LiveClassModel liveClass, {
    String? teacherId,
  }) async {
    return liveClass;
  }

  @override
  Future<void> updateLiveClassStatus(String id, LiveStatus status) async {}

  @override
  Future<String> uploadLiveClassThumbnail({
    required String fileName,
    required dynamic fileBytes,
  }) async => 'https://mock.supabase.co/storage/v1/object/public/course-thumbnails/$fileName';

  @override
  Future<SlotValidationResult> validateBatchSchedule(String batchId) async =>
      const SlotValidationResult(isValid: true, message: 'Valid');

  @override
  Future<LiveClassModel> startAuthenticatedLiveSession({
    required String batchId,
    required String title,
    required String subject,
    required String streamUrl,
    String? thumbnailUrl,
    String? liveInputUid,
  }) async =>
      scheduleLiveClass(LiveClassModel(
        id: 'mock_live_id',
        courseId: 'mock_course',
        batchId: batchId,
        courseName: 'Mock Course',
        batchName: 'Mock Batch',
        title: title,
        subject: subject,
        teacherName: 'Teacher',
        teacherAvatar: '',
        scheduledStartTime: DateTime.now(),
        status: LiveStatus.live,
        streamUrl: streamUrl,
        thumbnailUrl: thumbnailUrl,
      ));

  @override
  Future<void> endAuthenticatedLiveSession(String liveClassId, {int? durationSeconds, DateTime? endTime}) async {}

  @override
  Future<List<LectureRecordingModel>> getLectureRecordings({
    String? courseId,
    String? batchId,
    String? teacherId,
  }) async => [];

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
  }) async => null;

  @override
  Future<LectureRecordingModel?> refreshRecordingStatus(String videoUid) async => null;

  @override
  Future<Map<String, dynamic>> checkCloudflareLiveStatus(String liveInputUid) async =>
      {'status': 'connected', 'connected': true};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('LiveClassProvider Empty and Error States', () {
    late FakeLiveClassRepository repo;
    late LiveClassProvider provider;

    setUp(() {
      repo = FakeLiveClassRepository();
      provider = LiveClassProvider(repository: repo);
    });

    test(
      'Successful empty response clears state and produces empty list',
      () async {
        repo.response = [];
        await provider.fetchLiveClasses();
        expect(provider.classes, isEmpty);
        expect(provider.isLoading, false);
        expect(provider.errorMessage, isNull);
      },
    );

    test('Populated response displays actual data', () async {
      repo.response = [
        LiveClassModel(
          id: '1',
          courseId: 'c1',
          batchId: 'b1',
          courseName: 'C',
          batchName: 'B',
          title: 'T',
          subject: 'S',
          teacherName: 'TN',
          teacherAvatar: '',
          scheduledStartTime: DateTime.now(),
          estimatedDuration: const Duration(hours: 1),
          status: LiveStatus.upcoming,
          streamUrl: '',
        ),
      ];
      await provider.fetchLiveClasses();
      expect(provider.classes.length, 1);
      expect(provider.classes.first.id, '1');
      expect(provider.isLoading, false);
      expect(provider.errorMessage, isNull);
    });

    test('Repository failure produces error state, not mock records', () async {
      repo.throwError = true;
      await provider.fetchLiveClasses();
      expect(provider.errorMessage, contains('Simulated fetch error'));
      expect(provider.classes, isEmpty); // Ensure no mock data fallback
      expect(provider.isLoading, false);
    });
  });
}
