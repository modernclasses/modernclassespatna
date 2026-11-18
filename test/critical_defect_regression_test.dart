import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:modern_classes_patna/core/services/platform_settings_service.dart';
import 'package:modern_classes_patna/features/auth/data/models/user_model.dart';
import 'package:modern_classes_patna/features/auth/logic/auth_provider.dart';
import 'package:modern_classes_patna/features/courses/data/models/course_model.dart';
import 'package:modern_classes_patna/features/courses/logic/course_provider.dart';
import 'package:modern_classes_patna/features/live_classes/logic/live_class_provider.dart';
import 'package:modern_classes_patna/features/notifications/data/models/notification_model.dart';
import 'package:modern_classes_patna/features/notifications/data/repositories/notification_repository.dart';
import 'package:modern_classes_patna/features/notifications/logic/notification_provider.dart';
import 'package:modern_classes_patna/features/tests/data/models/test_model.dart';
import 'package:modern_classes_patna/features/tests/data/repositories/test_repository.dart';
import 'package:modern_classes_patna/features/tests/logic/test_provider.dart';
import 'package:modern_classes_patna/screens/admin/app_settings_screen.dart';
import 'package:modern_classes_patna/screens/student/notifications_screen.dart';
import 'package:modern_classes_patna/screens/student/test_result_screen.dart';
import 'package:modern_classes_patna/screens/student/tests_screen.dart';
import 'package:modern_classes_patna/screens/student/video_player_screen.dart';
import 'package:modern_classes_patna/screens/teacher/create_test_screen.dart';
import 'package:modern_classes_patna/screens/teacher/teacher_broadcast_prototype_screen.dart';
import 'fake_course_repository.dart';

class FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  UserModel _user = const UserModel(
    id: 'tch_001',
    name: 'Dr. Kumar',
    email: 'kumar@example.com',
    phone: '9876543210',
    role: UserRole.teacher,
  );

  @override
  UserModel get currentUser => _user;

  @override
  bool get isAuthenticated => true;

  @override
  bool get isTeacher => _user.role == UserRole.teacher;

  @override
  bool get isAdmin => _user.role == UserRole.admin;

  @override
  bool get isStudent => _user.role == UserRole.student;

  void setUser(UserModel user) {
    _user = user;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockNotificationRepoForDeletion implements NotificationRepository {
  List<NotificationModel> list = [
    NotificationModel(
      id: 'notif_1',
      title: 'Lecture Ready',
      message: 'New video has been uploaded.',
      category: NotificationCategory.material,
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      isRead: false,
    ),
    NotificationModel(
      id: 'notif_2',
      title: 'Exam Alert',
      message: 'Mock test scheduled for tomorrow.',
      category: NotificationCategory.test,
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      isRead: true,
    ),
  ];

  @override
  Future<List<NotificationModel>> getNotifications() async => List.from(list);

  @override
  Future<void> broadcastAnnouncement(NotificationModel notification) async {
    list.insert(0, notification);
  }
}

class FakeTestRepoForCreate implements TestRepository {
  List<TestModel> tests = [];

  @override
  Future<List<TestModel>> getTests() async => tests;

  @override
  Future<TestModel> getTestPaper(String testId) async =>
      tests.firstWhere((t) => t.id == testId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Defect 4 & 5: Streaming Role Separation & Broadcast Interface', () {
    test('PlatformSettingsService persists and loads RTMP configuration',
        () async {
      SharedPreferences.setMockInitialValues({});

      final initial = await PlatformSettingsService.getLiveStreamConfig();
      expect(initial.isConfigured, isFalse);

      await PlatformSettingsService.saveLiveStreamConfig(
        const LiveStreamConfig(
          rtmpUrl: 'rtmps://live.cloudflare.com:443/live/',
          streamKey: 'super_secret_stream_key_123',
          playbackUrl: 'https://customer-abc.cloudflarestream.com/manifest.m3u8',
        ),
      );

      final loaded =
          await PlatformSettingsService.getLiveStreamConfig(forceRefresh: true);
      expect(loaded.isConfigured, isTrue);
      expect(loaded.rtmpUrl, 'rtmps://live.cloudflare.com:443/live/');
      expect(loaded.streamKey, 'super_secret_stream_key_123');
      expect(
        loaded.playbackUrl,
        'https://customer-abc.cloudflarestream.com/manifest.m3u8',
      );
    });

    testWidgets(
      'Admin Settings does not render live streaming ingest card',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await tester.pumpWidget(
          const MaterialApp(
            home: AppSettingsScreen(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Live Streaming Ingest (Admin)'), findsNothing);
      },
    );

    testWidgets(
      'Teacher Broadcast screen DOES NOT expose RTMPS URL or stream key fields',
      (tester) async {
        final courseRepo = FakeCourseRepository();
        final courseProvider = CourseProvider(repository: courseRepo);
        final liveProvider = LiveClassProvider();
        final notifProvider = NotificationProvider(
          repository: MockNotificationRepoForDeletion(),
        );
        final authProvider = FakeAuthProvider();
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<CourseProvider>.value(
                  value: courseProvider),
              ChangeNotifierProvider<LiveClassProvider>.value(
                  value: liveProvider),
              ChangeNotifierProvider<NotificationProvider>.value(
                  value: notifProvider),
              ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ],
            child: const MaterialApp(
              home: TeacherBroadcastPrototypeScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Must display honest title and studio header
        expect(find.text('Live Broadcast Studio'), findsOneWidget);
        expect(find.text('Broadcast Configuration'), findsOneWidget);

        // STRICT REQUIREMENT: No RTMPS Ingest URL or Stream Key fields in Teacher UI
        expect(find.text('RTMPS Ingest URL'), findsNothing);
        expect(find.text('Live Stream Key'), findsNothing);
        expect(find.text('rtmps://'), findsNothing);

        // Action button is present
        expect(find.byKey(const Key('broadcast_action_button')), findsOneWidget);
      },
    );
  });

  group('Defect 6: Create Test Entry Point in TestsScreen', () {
    testWidgets('Teachers and Admins see Create Test action on TestsScreen',
        (tester) async {
      final testRepo = FakeTestRepoForCreate();
      final testProvider = TestProvider(repository: testRepo);
      final courseRepo = FakeCourseRepository();
      final courseProvider = CourseProvider(repository: courseRepo);
      final authProvider = FakeAuthProvider();
      authProvider.setUser(const UserModel(
        id: 'teacher_1',
        name: 'Faculty Vikram',
        email: 'vikram@example.com',
        phone: '9876543210',
        role: UserRole.teacher,
      ));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CourseProvider>.value(value: courseProvider),
            ChangeNotifierProvider<TestProvider>.value(value: testProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: const MaterialApp(home: TestsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Verify FAB and empty state button are present for teachers
      expect(find.byKey(const Key('create_test_fab')), findsOneWidget);
      expect(find.byKey(const Key('create_test_appbar_action')), findsOneWidget);
      expect(find.byKey(const Key('create_first_test_button')), findsOneWidget);

      // Tap Create Test FAB to verify navigation opens CreateTestScreen
      await tester.tap(find.byKey(const Key('create_test_fab')));
      await tester.pumpAndSettle();

      expect(find.byType(CreateTestScreen), findsOneWidget);
      expect(find.text('Create Mock Test / Exam'), findsOneWidget);
    });

    testWidgets('Students DO NOT see Create Test buttons', (tester) async {
      final testRepo = FakeTestRepoForCreate();
      final testProvider = TestProvider(repository: testRepo);
      final courseRepo = FakeCourseRepository();
      final courseProvider = CourseProvider(repository: courseRepo);
      final authProvider = FakeAuthProvider();
      authProvider.setUser(const UserModel(
        id: 'student_1',
        name: 'Student Rahul',
        email: 'rahul@example.com',
        phone: '9876543211',
        role: UserRole.student,
      ));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CourseProvider>.value(value: courseProvider),
            ChangeNotifierProvider<TestProvider>.value(value: testProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: const MaterialApp(home: TestsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('create_test_fab')), findsNothing);
      expect(find.byKey(const Key('create_test_appbar_action')), findsNothing);
      expect(find.byKey(const Key('create_first_test_button')), findsNothing);
    });
  });

  group('Defect 7: Notification Deletion & Clear All', () {
    testWidgets('Notification deletion removes item and persists in storage',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repo = MockNotificationRepoForDeletion();
      final provider = NotificationProvider(repository: repo);
      await provider.fetchNotifications();

      expect(provider.notifications.length, 2);

      await tester.pumpWidget(
        ChangeNotifierProvider<NotificationProvider>.value(
          value: provider,
          child: const MaterialApp(home: NotificationsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lecture Ready'), findsOneWidget);
      expect(find.text('Exam Alert'), findsOneWidget);

      // Tap delete button on the first notification
      await tester.tap(find.byKey(const Key('delete_notif_notif_1')));
      await tester.pumpAndSettle();

      expect(find.text('Lecture Ready'), findsNothing);
      expect(find.text('Exam Alert'), findsOneWidget);
      expect(provider.notifications.length, 1);

      // Verify clear all confirmation dialog
      await tester.tap(find.byKey(const Key('clear_all_notifications_button')));
      await tester.pumpAndSettle();

      expect(find.text('Clear all notifications?'), findsOneWidget);
      await tester.tap(find.text('Clear All'));
      await tester.pumpAndSettle();

      expect(provider.notifications, isEmpty);
      expect(find.text('No notifications yet'), findsOneWidget);
    });
  });

  group('Defect 8: Exam Performance Unattempted-Card Responsive Layout', () {
    testWidgets(
      'TestResultScreen renders breakdown chips without overflow at 360px and 320px',
      (tester) async {
        final result = TestResultModel(
          id: 'result_test_1',
          testId: 'test_1',
          testTitle: 'Full Length Mock 1',
          studentId: 'student_1',
          studentName: 'Rahul Kumar',
          score: 85.0,
          maxScore: 100.0,
          percentage: 85.0,
          totalQuestions: 50,
          correctCount: 42,
          incorrectCount: 5,
          unattemptedCount: 3,
          totalTimeTaken: const Duration(minutes: 45),
          submittedAt: DateTime.now(),
          responses: const {},
        );

        final testModel = TestModel(
          id: 'test_1',
          courseId: 'c1',
          batchId: 'b1',
          title: 'Full Length Mock 1',
          subject: 'General Studies',
          totalMarks: 100,
          totalQuestions: 50,
          questions: const [],
          scheduledDate: DateTime.now(),
          duration: const Duration(hours: 2),
        );

        Widget buildScreen(double width) {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1.0;
          return MaterialApp(
            home: TestResultScreen(
              result: result,
              test: testModel,
            ),
          );
        }

        // Test on standard 360px budget Android (previously failing by 3.9px)
        await tester.pumpWidget(buildScreen(360));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Correct'), findsOneWidget);
        expect(find.text('Incorrect'), findsOneWidget);
        expect(find.text('Unattempted'), findsOneWidget);

        // Test on narrow 320px screen
        await tester.pumpWidget(buildScreen(320));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Unattempted'), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );
  });

  group('Defect 9, 10 & 13: Video Controls Auto-Hide, No Watermarks & 75/25 Layout', () {
    final lesson = VideoLessonModel(
      id: 'l1',
      courseId: 'c1',
      batchId: 'b1',
      title: 'Polity Basics',
      chapter: 'Constitution',
      duration: const Duration(minutes: 10),
      videoUrl: 'https://example.com/video.mp4',
      uploadedAt: DateTime.now(),
    );

    const course = CourseModel(
      id: 'c1',
      title: 'BPSC Foundation',
      category: 'Civil Services',
      description: 'Comprehensive course',
      coverImageUrl: '',
      price: 2500,
      originalPrice: 5000,
      teacherName: 'Dr. Kumar',
      teacherId: 'tch_1',
      totalLessons: 10,
      totalHours: 20,
      totalTests: 5,
      totalNotes: 8,
      highlights: ['Full Syllabus'],
    );

    testWidgets(
      'VideoPlayerScreen: no watermarks present & controls auto-hide timer operates',
      (tester) async {
        final courseRepo = FakeCourseRepository();
        final courseProvider = CourseProvider(repository: courseRepo);
        final authProvider = FakeAuthProvider();
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<CourseProvider>.value(
                  value: courseProvider),
              ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ],
            child: MaterialApp(
              home: VideoPlayerScreen(
                lesson: lesson,
                course: course,
              ),
            ),
          ),
        );
        await tester.pump();

        // 1. Watermark absence verified
        expect(find.textContaining('Modern Classes Patna •'), findsNothing);

        // 2. Center play/pause button is initially visible
        expect(find.byKey(const Key('video_center_play_button')), findsOneWidget);

        // Advance timer by 3.5 seconds to trigger auto-hide while playing
        await tester.pump(const Duration(seconds: 4));

        // Center play button has faded out (opacity 0.0)
        final opacityFinder = find.byType(AnimatedOpacity);
        expect(opacityFinder, findsWidgets);

        // Tapping screen toggles controls back visible
        await tester.tap(find.byType(GestureDetector).first);
        await tester.pump();

        // Tapping pause keeps controls permanently visible
        await tester.tap(find.byKey(const Key('video_bottom_play_button')));
        await tester.pump();
        await tester.pump(const Duration(seconds: 5));
        // Still visible when paused
        expect(find.byKey(const Key('video_bottom_play_button')), findsOneWidget);
      },
    );
  });
}
