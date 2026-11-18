import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:modern_classes_patna/core/services/platform_settings_service.dart';
import 'package:modern_classes_patna/features/courses/data/models/batch_model.dart';
import 'package:modern_classes_patna/features/courses/data/models/course_model.dart';
import 'package:modern_classes_patna/features/courses/data/repositories/course_repository.dart';
import 'package:modern_classes_patna/features/live_classes/data/models/live_class_model.dart';
import 'package:modern_classes_patna/features/live_classes/data/repositories/live_class_repository.dart';
import 'package:modern_classes_patna/features/live_classes/logic/live_class_provider.dart';
import 'package:modern_classes_patna/features/notifications/data/models/notification_model.dart';
import 'package:modern_classes_patna/features/notifications/data/repositories/notification_repository.dart';
import 'package:modern_classes_patna/models/user_model.dart';
import 'package:modern_classes_patna/providers/auth_provider.dart';
import 'package:modern_classes_patna/providers/course_provider.dart';
import 'package:modern_classes_patna/core/utils/batch_timing_helper.dart';
import 'package:modern_classes_patna/features/live_classes/data/models/lecture_recording_model.dart';
import 'package:modern_classes_patna/providers/notification_provider.dart';
import 'package:modern_classes_patna/screens/teacher/teacher_broadcast_prototype_screen.dart';

class MockLiveClassRepository implements LiveClassRepository {
  final List<LiveClassModel> classes = [];

  @override
  Future<List<LiveClassModel>> getLiveClasses() async => List.from(classes);

  @override
  Future<LiveClassModel> scheduleLiveClass(
    LiveClassModel liveClass, {
    String? teacherId,
  }) async {
    classes.insert(0, liveClass);
    return liveClass;
  }

  @override
  Future<void> updateLiveClassStatus(String id, LiveStatus status) async {}

  @override
  Future<String> uploadLiveClassThumbnail({
    required String fileName,
    required dynamic fileBytes,
  }) async => 'https://mock.example.com/$fileName';

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

class FakeCourseRepoWithBatches implements CourseRepository {
  final List<BatchModel> batches;

  FakeCourseRepoWithBatches({required this.batches});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<CourseModel>> getCourses() async => [
        const CourseModel(
          id: 'course-1',
          title: 'General Studies Foundation',
          category: 'GS',
          description: 'GS Foundation Course',
          coverImageUrl: '',
          price: 2999,
          originalPrice: 4999,
          teacherName: 'Faculty',
          teacherId: 'teacher-1',
          totalLessons: 10,
          totalHours: 30,
          totalTests: 5,
          totalNotes: 5,
          highlights: ['Live Classes'],
        ),
      ];

  @override
  Future<List<BatchModel>> getBatches() async => batches;
}

class FakeNotificationRepo implements NotificationRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> broadcastAnnouncement(NotificationModel notification) async {}

  @override
  Future<List<NotificationModel>> getNotifications() async => [];
}

class FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  UserModel get currentUser => const UserModel(
        id: 'teacher-1',
        name: 'Prof. Sharma',
        email: 'sharma@modernclasses.com',
        phone: '9876543210',
        role: UserRole.teacher,
      );

  @override
  bool get isAuthenticated => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Batch-Specific Live Streaming Credentials Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      PlatformSettingsService.resetCacheForTesting();

      const MethodChannel permChannel =
          MethodChannel('flutter.baseflow.com/permissions/methods');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(permChannel, (MethodCall methodCall) async {
        if (methodCall.method == 'checkPermissionStatus') {
          return 1; // PermissionStatus.granted
        } else if (methodCall.method == 'requestPermissions') {
          final List<dynamic> args = methodCall.arguments as List<dynamic>;
          final Map<int, int> result = {};
          for (final dynamic item in args) {
            result[item as int] = 1;
          }
          return result;
        }
        return null;
      });
    });

    tearDown(() {
      const MethodChannel permChannel =
          MethodChannel('flutter.baseflow.com/permissions/methods');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(permChannel, null);
    });

    testWidgets(
        'TeacherBroadcastPrototypeScreen recognizes batch streamKey without admin settings',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final configuredBatch = BatchModel(
        id: 'batch-configured-1',
        courseId: 'course-1',
        name: 'Target Batch 2026',
        timing: '08:00 AM - 10:00 AM',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 60)),
        teacherName: 'Prof. Sharma',
        teacherId: 'teacher-1',
        totalStudents: 30,
        maxStudents: 100,
        batchPrice: 2999,
        streamKey: 'live_stream_key_cloudflare_secret_123',
        playbackUrl: 'https://customer-xyz.cloudflarestream.com/manifest/video.m3u8',
        rtmpsUrl: 'rtmps://live.cloudflare.com:443/live/',
      );

      final courseRepo = FakeCourseRepoWithBatches(batches: [configuredBatch]);
      final courseProvider = CourseProvider(repository: courseRepo);
      await courseProvider.fetchCatalog();

      final liveRepo = MockLiveClassRepository();
      final liveProvider = LiveClassProvider(repository: liveRepo);
      final notifRepo = FakeNotificationRepo();
      final notifProvider = NotificationProvider(repository: notifRepo);
      final authProvider = FakeAuthProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CourseProvider>.value(value: courseProvider),
            ChangeNotifierProvider<LiveClassProvider>.value(value: liveProvider),
            ChangeNotifierProvider<NotificationProvider>.value(value: notifProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: const MaterialApp(
            home: TeacherBroadcastPrototypeScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify that it displays Batch Configured
      expect(find.text('Batch Configured'), findsOneWidget);

      // Verify that the warning message about Admin Settings is NOT displayed
      expect(
        find.textContaining('Contact the Administrator to add RTMP settings in Admin Settings'),
        findsNothing,
      );

      // Verify the button text is "Start Live Broadcast"
      expect(find.text('Start Live Broadcast'), findsOneWidget);
    });

    testWidgets(
        'TeacherBroadcastPrototypeScreen displays batch settings error when streamKey is missing',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final unconfiguredBatch = BatchModel(
        id: 'batch-unconfigured-1',
        courseId: 'course-1',
        name: 'Unconfigured Batch B',
        timing: '10:00 AM - 12:00 PM',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 60)),
        teacherName: 'Prof. Sharma',
        teacherId: 'teacher-1',
        totalStudents: 10,
        maxStudents: 100,
        batchPrice: 1999,
        streamKey: null, // No stream key configured
        playbackUrl: null,
      );

      final courseRepo = FakeCourseRepoWithBatches(batches: [unconfiguredBatch]);
      final courseProvider = CourseProvider(repository: courseRepo);
      await courseProvider.fetchCatalog();

      final liveRepo = MockLiveClassRepository();
      final liveProvider = LiveClassProvider(repository: liveRepo);
      final notifRepo = FakeNotificationRepo();
      final notifProvider = NotificationProvider(repository: notifRepo);
      final authProvider = FakeAuthProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CourseProvider>.value(value: courseProvider),
            ChangeNotifierProvider<LiveClassProvider>.value(value: liveProvider),
            ChangeNotifierProvider<NotificationProvider>.value(value: notifProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: const MaterialApp(
            home: TeacherBroadcastPrototypeScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify badge says Not Configured
      expect(find.text('Not Configured'), findsOneWidget);

      // Verify error points to Batch Settings, NOT Admin Settings
      expect(
        find.textContaining("Please configure the Stream Key in Batch Settings"),
        findsOneWidget,
      );
    });

    testWidgets(
        'Dynamic batch selection updates configuration status between batches',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final batchA = BatchModel(
        id: 'batch-a',
        courseId: 'course-1',
        name: 'Batch A Configured',
        timing: '08:00 AM',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 30)),
        teacherName: 'Prof. Sharma',
        teacherId: 'teacher-1',
        totalStudents: 10,
        maxStudents: 50,
        batchPrice: 1000,
        streamKey: 'key_batch_a_secret',
      );

      final batchB = BatchModel(
        id: 'batch-b',
        courseId: 'course-1',
        name: 'Batch B Empty',
        timing: '10:00 AM',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 30)),
        teacherName: 'Prof. Sharma',
        teacherId: 'teacher-1',
        totalStudents: 10,
        maxStudents: 50,
        batchPrice: 1000,
        streamKey: '',
      );

      final courseRepo = FakeCourseRepoWithBatches(batches: [batchA, batchB]);
      final courseProvider = CourseProvider(repository: courseRepo);
      await courseProvider.fetchCatalog();

      final liveRepo = MockLiveClassRepository();
      final liveProvider = LiveClassProvider(repository: liveRepo);
      final notifRepo = FakeNotificationRepo();
      final notifProvider = NotificationProvider(repository: notifRepo);
      final authProvider = FakeAuthProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CourseProvider>.value(value: courseProvider),
            ChangeNotifierProvider<LiveClassProvider>.value(value: liveProvider),
            ChangeNotifierProvider<NotificationProvider>.value(value: notifProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: const MaterialApp(
            home: TeacherBroadcastPrototypeScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Initially batch A is selected and configured
      expect(find.text('Batch Configured'), findsOneWidget);

      // Open dropdown and switch to batch B
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Batch B Empty').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Now it should show Not Configured for Batch B
      expect(find.text('Not Configured'), findsOneWidget);
      expect(
        find.textContaining("credentials have not been configured for 'Batch B Empty'"),
        findsOneWidget,
      );
    });
  });

  group('Landscape Studio Orientation & Responsive UI Tests', () {
    late List<MethodCall> platformCalls;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      PlatformSettingsService.resetCacheForTesting();
      platformCalls = [];

      const MethodChannel permChannel =
          MethodChannel('flutter.baseflow.com/permissions/methods');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(permChannel, (MethodCall methodCall) async {
        if (methodCall.method == 'checkPermissionStatus') {
          return 1;
        } else if (methodCall.method == 'requestPermissions') {
          final List<dynamic> args = methodCall.arguments as List<dynamic>;
          final Map<int, int> result = {};
          for (final dynamic item in args) {
            result[item as int] = 1;
          }
          return result;
        }
        return null;
      });

      const MethodChannel broadcastChannel =
          MethodChannel('modern_classes_patna/broadcast_0');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(broadcastChannel, (MethodCall methodCall) async {
        platformCalls.add(methodCall);
        if (methodCall.method == 'initializePreview' ||
            methodCall.method == 'setOrientation' ||
            methodCall.method == 'startStream') {
          return true;
        }
        return null;
      });
    });

    tearDown(() {
      const MethodChannel permChannel =
          MethodChannel('flutter.baseflow.com/permissions/methods');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(permChannel, null);

      const MethodChannel broadcastChannel =
          MethodChannel('modern_classes_patna/broadcast_0');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(broadcastChannel, null);
    });

    testWidgets(
        'TeacherBroadcastPrototypeScreen renders modern landscape layout with floating viewfinder pill and dark studio dock',
        (tester) async {
      // Standard landscape viewport (800x480)
      tester.view.physicalSize = const Size(1600, 960);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final batch = BatchModel(
        id: 'batch-landscape-1',
        courseId: 'course-1',
        name: 'Civil Services 2026',
        timing: '09:00 AM - 11:00 AM',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 90)),
        teacherName: 'Prof. Sharma',
        teacherId: 'teacher-1',
        totalStudents: 45,
        maxStudents: 100,
        batchPrice: 3500,
        streamKey: 'live_stream_key_landscape_test',
        playbackUrl: 'https://customer-xyz.cloudflarestream.com/manifest/video.m3u8',
        rtmpsUrl: 'rtmps://live.cloudflare.com:443/live/',
      );

      final courseRepo = FakeCourseRepoWithBatches(batches: [batch]);
      final courseProvider = CourseProvider(repository: courseRepo);
      await courseProvider.fetchCatalog();

      final liveRepo = MockLiveClassRepository();
      final liveProvider = LiveClassProvider(repository: liveRepo);
      final notifRepo = FakeNotificationRepo();
      final notifProvider = NotificationProvider(repository: notifRepo);
      final authProvider = FakeAuthProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CourseProvider>.value(value: courseProvider),
            ChangeNotifierProvider<LiveClassProvider>.value(value: liveProvider),
            ChangeNotifierProvider<NotificationProvider>.value(value: notifProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: const MaterialApp(
            home: TeacherBroadcastPrototypeScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 1. Verify Landscape floating overlays on camera viewfinder
      expect(find.text('Live Studio'), findsOneWidget);
      expect(find.text('16:9'), findsOneWidget);

      // 2. Verify Studio Dock controls
      expect(find.text('Broadcast Configuration'), findsOneWidget);
      expect(find.text('Batch Configured'), findsOneWidget);
      expect(find.text('Lecture Title'), findsOneWidget);
      expect(find.text('Target Batch'), findsOneWidget);
      expect(find.text('Start Live Broadcast'), findsOneWidget);

      // 3. Verify floating quick action buttons (Camera switch, mic toggle)
      expect(find.byIcon(Icons.flip_camera_android), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsOneWidget);
    });

    testWidgets(
        'Landscape mode on narrow 640x360 phone viewport renders cleanly without overflow',
        (tester) async {
      // Compact Android landscape phone (640x360 logical)
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final batch = BatchModel(
        id: 'batch-narrow-landscape',
        courseId: 'course-1',
        name: 'GS Batch Alpha',
        timing: '07:00 AM',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 30)),
        teacherName: 'Prof. Sharma',
        teacherId: 'teacher-1',
        totalStudents: 20,
        maxStudents: 50,
        batchPrice: 2000,
        streamKey: 'narrow_key_secret',
      );

      final courseRepo = FakeCourseRepoWithBatches(batches: [batch]);
      final courseProvider = CourseProvider(repository: courseRepo);
      await courseProvider.fetchCatalog();

      final liveRepo = MockLiveClassRepository();
      final liveProvider = LiveClassProvider(repository: liveRepo);
      final notifRepo = FakeNotificationRepo();
      final notifProvider = NotificationProvider(repository: notifRepo);
      final authProvider = FakeAuthProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CourseProvider>.value(value: courseProvider),
            ChangeNotifierProvider<LiveClassProvider>.value(value: liveProvider),
            ChangeNotifierProvider<NotificationProvider>.value(value: notifProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: const MaterialApp(
            home: TeacherBroadcastPrototypeScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Live Studio'), findsOneWidget);
      expect(find.text('16:9'), findsOneWidget);
      expect(find.text('Batch Configured'), findsOneWidget);
      expect(find.text('Start Live Broadcast'), findsOneWidget);
    });
  });
}
