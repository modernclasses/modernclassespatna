import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:modern_classes_patna/features/live_classes/data/models/cloudflare_live_input.dart';
import 'package:modern_classes_patna/core/services/cloudflare_live_stream_service.dart';
import 'package:modern_classes_patna/core/services/platform_settings_service.dart';
import 'package:modern_classes_patna/core/errors/exceptions.dart';
import 'package:modern_classes_patna/features/live_classes/logic/live_class_provider.dart';
import 'package:modern_classes_patna/features/live_classes/data/models/live_class_model.dart';
import 'package:modern_classes_patna/core/utils/batch_timing_helper.dart';
import 'package:modern_classes_patna/features/live_classes/data/models/lecture_recording_model.dart';
import 'package:modern_classes_patna/features/live_classes/data/repositories/live_class_repository.dart';
import 'package:modern_classes_patna/screens/admin/app_settings_screen.dart';

class MockLiveClassRepository implements LiveClassRepository {
  final List<LiveClassModel> classes = [];

  @override
  Future<List<LiveClassModel>> getLiveClasses() async => List.from(classes);

  @override
  Future<LiveClassModel> scheduleLiveClass(
    LiveClassModel liveClass, {
    String? teacherId,
  }) async {
    final created = LiveClassModel(
      id: liveClass.id.isEmpty
          ? 'live-${DateTime.now().millisecondsSinceEpoch}'
          : liveClass.id,
      courseId: liveClass.courseId,
      batchId: liveClass.batchId,
      courseName: liveClass.courseName,
      batchName: liveClass.batchName,
      title: liveClass.title,
      subject: liveClass.subject,
      teacherName: liveClass.teacherName,
      teacherAvatar: liveClass.teacherAvatar,
      scheduledStartTime: liveClass.scheduledStartTime,
      estimatedDuration: liveClass.estimatedDuration,
      status: liveClass.status,
      streamUrl: liveClass.streamUrl,
    );
    classes.add(created);
    return created;
  }

  @override
  Future<void> updateLiveClassStatus(String classId, LiveStatus status) async {
    final index = classes.indexWhere((c) => c.id == classId);
    if (index != -1) {
      classes[index] = classes[index].copyWith(status: status);
    }
  }

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
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    CloudflareLiveStreamService.resetCacheForTesting();
    PlatformSettingsService.resetCacheForTesting();
  });

  tearDown(() {
    CloudflareLiveStreamService.resetCacheForTesting();
    PlatformSettingsService.resetCacheForTesting();
  });

  group('1. CloudflareLiveInput Entity & Serialization', () {
    test('toMap and fromMap serialize and deserialize all required fields', () {
      final input = CloudflareLiveInput(
        id: 'test-uuid-1234',
        uid: 'cf-uid-9876543210',
        name: 'Studio Broadcaster Alpha',
        rtmpsUrl: 'rtmps://live.cloudflare.com:443/live/',
        streamKey: 'live_secret_key_abc123',
        playbackUrl: 'https://customer-xyz.cloudflarestream.com/cf-uid-9876543210/manifest/video.m3u8',
        accountId: 'acc-cloudflare-org-patna',
        batchId: 'batch-target-01',
        isActive: true,
        isPrimary: true,
      );

      final map = input.toMap();
      expect(map['uid'], 'cf-uid-9876543210');
      expect(map['name'], 'Studio Broadcaster Alpha');
      expect(map['rtmps_url'], 'rtmps://live.cloudflare.com:443/live/');
      expect(map['stream_key'], 'live_secret_key_abc123');
      expect(map['playback_url'], contains('cf-uid-9876543210'));
      expect(map['account_id'], 'acc-cloudflare-org-patna');
      expect(map['is_primary'], isTrue);

      final deserialized = CloudflareLiveInput.fromMap(map);
      expect(deserialized.uid, input.uid);
      expect(deserialized.name, input.name);
      expect(deserialized.rtmpsUrl, input.rtmpsUrl);
      expect(deserialized.streamKey, input.streamKey);
      expect(deserialized.playbackUrl, input.playbackUrl);
      expect(deserialized.accountId, input.accountId);
      expect(deserialized.isPrimary, isTrue);
      expect(deserialized.isConfigured, isTrue);
    });

    test('isConfigured validates protocol and key presence', () {
      const invalidProto = CloudflareLiveInput(
        id: '1',
        uid: 'uid-1',
        name: 'Test',
        rtmpsUrl: 'http://insecure.url/live',
        streamKey: 'key',
        playbackUrl: 'playback',
      );
      expect(invalidProto.isConfigured, isFalse);

      const missingKey = CloudflareLiveInput(
        id: '1',
        uid: 'uid-1',
        name: 'Test',
        rtmpsUrl: 'rtmps://live.cloudflare.com/live',
        streamKey: '',
        playbackUrl: 'playback',
      );
      expect(missingKey.isConfigured, isFalse);

      const valid = CloudflareLiveInput(
        id: '1',
        uid: 'uid-1',
        name: 'Test',
        rtmpsUrl: 'rtmps://live.cloudflare.com:443/live/',
        streamKey: 'valid_key',
        playbackUrl: 'playback',
      );
      expect(valid.isConfigured, isTrue);
    });
  });

  group('2. CloudflareLiveStreamService Input Persistence & Validation', () {
    test('saveLiveInput validates empty UID, Name, and Stream Key', () async {
      // Missing UID
      expect(
        () => CloudflareLiveStreamService.saveLiveInput(
          const CloudflareLiveInput(
            id: '',
            uid: '',
            name: 'Valid Name',
            streamKey: 'valid_key',
            playbackUrl: 'url',
          ),
        ),
        throwsA(isA<ValidationException>()),
      );

      // Missing Name
      expect(
        () => CloudflareLiveStreamService.saveLiveInput(
          const CloudflareLiveInput(
            id: '',
            uid: 'uid-1',
            name: '',
            streamKey: 'valid_key',
            playbackUrl: 'url',
          ),
        ),
        throwsA(isA<ValidationException>()),
      );

      // Missing Key
      expect(
        () => CloudflareLiveStreamService.saveLiveInput(
          const CloudflareLiveInput(
            id: '',
            uid: 'uid-1',
            name: 'Valid Name',
            streamKey: '',
            playbackUrl: 'url',
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('saveLiveInput persists input and retrieves it via getLiveInputs', () async {
      const input = CloudflareLiveInput(
        id: 'live-id-1',
        uid: 'cf-uid-studio-1',
        name: 'Physics Lab Live Camera',
        rtmpsUrl: 'rtmps://live.cloudflare.com:443/live/',
        streamKey: 'secret_key_physics',
        playbackUrl: 'https://customer-xyz.cloudflarestream.com/cf-uid-studio-1/manifest/video.m3u8',
        accountId: 'acc-patna-123',
        isPrimary: true,
      );

      final saved = await CloudflareLiveStreamService.saveLiveInput(input);
      expect(saved.uid, 'cf-uid-studio-1');

      final inputs = await CloudflareLiveStreamService.getLiveInputs();
      expect(inputs.length, 1);
      expect(inputs.first.uid, 'cf-uid-studio-1');
      expect(inputs.first.name, 'Physics Lab Live Camera');
      expect(inputs.first.isPrimary, isTrue);
    });

    test('makePrimary switches the active institute broadcast ingest', () async {
      await CloudflareLiveStreamService.saveLiveInput(
        const CloudflareLiveInput(
          id: '1',
          uid: 'uid-camera-1',
          name: 'Camera 1',
          streamKey: 'key-1',
          playbackUrl: 'play-1',
          isPrimary: true,
        ),
      );

      await CloudflareLiveStreamService.saveLiveInput(
        const CloudflareLiveInput(
          id: '2',
          uid: 'uid-camera-2',
          name: 'Camera 2',
          streamKey: 'key-2',
          playbackUrl: 'play-2',
          isPrimary: false,
        ),
      );

      // Promote Camera 2 to primary
      await CloudflareLiveStreamService.makePrimary('uid-camera-2');

      final inputs = await CloudflareLiveStreamService.getLiveInputs();
      final cam2 = inputs.firstWhere((i) => i.uid == 'uid-camera-2');
      final cam1 = inputs.firstWhere((i) => i.uid == 'uid-camera-1');

      expect(cam2.isPrimary, isTrue);
      expect(cam1.isPrimary, isFalse);

      // Verify PlatformSettingsService was updated with Camera 2's credentials
      final liveConfig = await PlatformSettingsService.getLiveStreamConfig();
      expect(liveConfig.streamKey, 'key-2');
      expect(liveConfig.playbackUrl, 'play-2');
    });
  });

  group('3. Cold Start & App Reinstallation Simulation (Zero Local State)', () {
    test('Inputs persist in local backup and recover after mock app wipe', () async {
      // Step 1: Register an input
      await CloudflareLiveStreamService.saveLiveInput(
        const CloudflareLiveInput(
          id: 'persisted-1',
          uid: 'cf-persistent-uid-456',
          name: 'Main Auditorium Ingest',
          rtmpsUrl: 'rtmps://live.cloudflare.com:443/live/',
          streamKey: 'permanent_key_auditorium',
          playbackUrl: 'https://customer.cloudflare.com/auditorium.m3u8',
          accountId: 'org-account-modern',
          isPrimary: true,
        ),
      );

      // Step 2: Simulate Cold App Restart (memory wiped)
      CloudflareLiveStreamService.resetCacheForTesting();
      PlatformSettingsService.resetCacheForTesting();

      // Step 3: Fetch on fresh restart
      final recovered = await CloudflareLiveStreamService.getLiveInputs();
      expect(recovered.isNotEmpty, isTrue);
      expect(recovered.first.uid, 'cf-persistent-uid-456');
      expect(recovered.first.name, 'Main Auditorium Ingest');
    });
  });

  group('4. Input Reuse Across Multiple Live Lectures', () {
    test('Reusing an existing input preserves its UID and properties without duplication', () async {
      const studioInput = CloudflareLiveInput(
        id: 'studio-reusable',
        uid: 'cf-uid-reusable-777',
        name: 'Shared Studio A',
        rtmpsUrl: 'rtmps://live.cloudflare.com:443/live/',
        streamKey: 'stream_key_shared_777',
        playbackUrl: 'https://customer-xyz.cloudflarestream.com/cf-uid-reusable-777/manifest/video.m3u8',
        isPrimary: true,
      );

      await CloudflareLiveStreamService.saveLiveInput(studioInput);

      final liveRepo = MockLiveClassRepository();
      final liveProvider = LiveClassProvider(repository: liveRepo);

      // Lecture 1: Physics Class using studioInput
      final lecture1 = await liveProvider.scheduleLiveClass(
        courseId: 'course-physics',
        batchId: 'batch-target-1',
        courseName: 'Target JEE Physics',
        batchName: 'Morning Batch',
        title: 'Rotational Dynamics Lecture 01',
        subject: 'Physics',
        teacherName: 'Dr. Anand Kumar',
        teacherAvatar: '',
        scheduledStartTime: DateTime.now(),
        streamUrl: studioInput.playbackUrl,
      );

      // End Lecture 1
      await liveProvider.endLiveClass(lecture1.id);
      expect(liveRepo.classes.first.status, LiveStatus.ended);

      // Verify the live input is still present and unmodified in service
      final inputAfterEnd = await CloudflareLiveStreamService.findLiveInputByUid('cf-uid-reusable-777');
      expect(inputAfterEnd.uid, 'cf-uid-reusable-777');
      expect(inputAfterEnd.streamKey, 'stream_key_shared_777');

      // Lecture 2: Chemistry Class reusing the same studioInput
      final lecture2 = await liveProvider.scheduleLiveClass(
        courseId: 'course-chemistry',
        batchId: 'batch-target-2',
        courseName: 'Target JEE Chemistry',
        batchName: 'Evening Batch',
        title: 'Chemical Equilibrium Lecture 01',
        subject: 'Chemistry',
        teacherName: 'Prof. R. K. Singh',
        teacherAvatar: '',
        scheduledStartTime: DateTime.now().add(const Duration(hours: 4)),
        streamUrl: inputAfterEnd.playbackUrl,
      );

      expect(lecture2.streamUrl, studioInput.playbackUrl);

      // Confirm only 1 live input exists (no duplicate created)
      final allInputs = await CloudflareLiveStreamService.getLiveInputs();
      expect(allInputs.where((i) => i.uid == 'cf-uid-reusable-777').length, 1);
    });
  });

  group('5. Lecture End Workflow Isolation', () {
    test('Ending a live class does NOT delete or alter the Live Input', () async {
      await CloudflareLiveStreamService.saveLiveInput(
        const CloudflareLiveInput(
          id: 'live-permanent',
          uid: 'uid-never-delete',
          name: 'Dedicated Biology Studio',
          streamKey: 'bio_key',
          playbackUrl: 'https://customer.cloudflare.com/bio.m3u8',
          isPrimary: true,
        ),
      );

      final liveRepo = MockLiveClassRepository();
      final liveProvider = LiveClassProvider(repository: liveRepo);

      final liveClass = await liveProvider.scheduleLiveClass(
        courseId: 'c-bio',
        batchId: 'b-bio',
        courseName: 'NEET Biology',
        batchName: 'Alpha Batch',
        title: 'Genetics Live Lecture',
        subject: 'Biology',
        teacherName: 'Faculty',
        teacherAvatar: '',
        scheduledStartTime: DateTime.now(),
        streamUrl: 'https://customer.cloudflare.com/bio.m3u8',
      );

      // Start class
      await liveProvider.startLiveClass(liveClass.id);
      expect(liveRepo.classes.first.status, LiveStatus.live);

      // Stop/End class
      await liveProvider.endLiveClass(liveClass.id);
      expect(liveRepo.classes.first.status, LiveStatus.ended);

      // Assert Live Input is intact
      final inputs = await CloudflareLiveStreamService.getLiveInputs();
      expect(inputs.any((i) => i.uid == 'uid-never-delete'), isTrue);
    });
  });

  group('6. Live Input Deletion Protection (Strict "CONFIRM" Requirement)', () {
    test('deleteLiveInput rejects deletion without exact CONFIRM keyword', () async {
      await CloudflareLiveStreamService.saveLiveInput(
        const CloudflareLiveInput(
          id: 'del-1',
          uid: 'uid-protected-999',
          name: 'Protected Ingest Slot',
          streamKey: 'key-protected',
          playbackUrl: 'play-protected',
        ),
      );

      // Empty string
      expect(
        () => CloudflareLiveStreamService.deleteLiveInput(
          uid: 'uid-protected-999',
          confirmation: '',
        ),
        throwsA(isA<ValidationException>()),
      );

      // Lowercase confirm
      expect(
        () => CloudflareLiveStreamService.deleteLiveInput(
          uid: 'uid-protected-999',
          confirmation: 'confirm',
        ),
        throwsA(isA<ValidationException>()),
      );

      // Verify input still exists
      var inputs = await CloudflareLiveStreamService.getLiveInputs();
      expect(inputs.any((i) => i.uid == 'uid-protected-999'), isTrue);

      // Exact "CONFIRM" succeeds
      await CloudflareLiveStreamService.deleteLiveInput(
        uid: 'uid-protected-999',
        confirmation: 'CONFIRM',
      );

      inputs = await CloudflareLiveStreamService.getLiveInputs();
      expect(inputs.any((i) => i.uid == 'uid-protected-999'), isFalse);
    });
  });

  group('7. Non-existent UID Lookup Prevention (Requirement 9)', () {
    test('findLiveInputByUid throws clear error when input not found and does NOT create duplicate', () async {
      expect(
        () => CloudflareLiveStreamService.findLiveInputByUid('ghost-uid-000000'),
        throwsA(isA<ServerException>().having(
          (e) => e.message,
          'message',
          contains('not found in Supabase. Please verify the UID'),
        )),
      );

      final inputs = await CloudflareLiveStreamService.getLiveInputs();
      expect(inputs.any((i) => i.uid == 'ghost-uid-000000'), isFalse);
    });
  });

  group('8. Admin UI Verification (AppSettingsScreen)', () {
    testWidgets('Admin Settings Screen does not render live streaming ingest card per configuration', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: AppSettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Live Streaming Ingest (Admin)"), findsNothing);
    });
  });
}
