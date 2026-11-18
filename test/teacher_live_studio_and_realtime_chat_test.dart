import 'package:modern_classes_patna/features/courses/data/models/course_model.dart';
import 'package:modern_classes_patna/features/courses/data/models/batch_model.dart';
import 'package:modern_classes_patna/screens/student/course_detail_screen.dart';
import 'package:modern_classes_patna/screens/student/my_batches_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:modern_classes_patna/features/auth/data/models/user_model.dart';
import 'package:modern_classes_patna/features/auth/logic/auth_provider.dart';
import 'package:modern_classes_patna/features/auth/data/repositories/auth_repository.dart';
import 'package:modern_classes_patna/features/courses/logic/course_provider.dart';
import 'package:modern_classes_patna/features/live_classes/data/models/live_class_model.dart';
import 'package:modern_classes_patna/features/live_classes/data/repositories/live_class_repository.dart';
import 'package:modern_classes_patna/features/live_classes/logic/live_class_provider.dart';
import 'package:modern_classes_patna/screens/student/live_classes_screen.dart';
import 'package:modern_classes_patna/screens/student/live_classroom_screen.dart';
import 'fake_course_repository.dart';

class MockLiveClassRepository implements LiveClassRepository {
  List<LiveClassModel> classes = [];
  int fetchCallCount = 0;

  @override
  Future<List<LiveClassModel>> getLiveClasses() async {
    fetchCallCount++;
    return List.from(classes);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class StatsTestCourseRepo extends FakeCourseRepository {
  List<CourseModel> testCourses = [];
  List<BatchModel> testBatches = [];
  List<VideoLessonModel> testLessons = [];
  List<String> testEnrolledBatchIds = [];
  List<String> testEnrolledCourseIds = [];

  @override
  Future<List<CourseModel>> getCourses() async => List.from(testCourses);

  @override
  Future<List<BatchModel>> getBatches() async => List.from(testBatches);

  @override
  Future<Map<String, List<String>>> getMyEnrollments() async => {
        'courseIds': List.from(testEnrolledCourseIds),
        'batchIds': List.from(testEnrolledBatchIds),
      };

  @override
  Future<List<VideoLessonModel>> getVideoLessons(String batchId) async =>
      testLessons.where((l) => l.batchId == batchId).toList();
}

class FakeTestAuthRepo implements AuthRepository {
  final UserModel user;
  FakeTestAuthRepo(this.user);

  @override
  bool get isConnected => true;

  @override
  Future<UserModel?> getInitialSession() async => user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Teacher Studio & Realtime Live Chat Tests', () {
    late MockLiveClassRepository mockRepository;
    late LiveClassProvider liveProvider;

    setUp(() {
      mockRepository = MockLiveClassRepository();
      liveProvider = LiveClassProvider(repository: mockRepository);
    });

    test('LiveClassProvider adds and deduplicates chat messages by id', () async {
      final initialClass = LiveClassModel(
        id: 'class_101',
        courseId: 'c1',
        batchId: 'b1',
        courseName: 'Physics JEE',
        batchName: 'Morning Alpha',
        title: 'Optics & Wave Motion',
        subject: 'Physics',
        teacherName: 'Er. Alok Verma',
        teacherAvatar: 'https://example.com/avatar.jpg',
        scheduledStartTime: DateTime.now(),
        estimatedDuration: const Duration(minutes: 60),
        status: LiveStatus.live,
        streamUrl: 'https://example.com/hls.m3u8',
      );

      mockRepository.classes = [initialClass];
      await liveProvider.fetchLiveClasses();

      expect(liveProvider.classes.first.chatMessages.length, 0);

      final msg1 = LiveChatMessage(
        id: 'msg_uuid_1',
        senderName: 'Rahul Kumar',
        senderRole: 'Student',
        text: 'Sir, is Brewster law applicable here?',
        timestamp: DateTime.now(),
      );

      // Add first message
      liveProvider.addLiveChatMessage('class_101', msg1);
      expect(liveProvider.classes.first.chatMessages.length, 1);
      expect(liveProvider.classes.first.chatMessages.first.text, 'Sir, is Brewster law applicable here?');

      // Attempt to add duplicate message with same ID (e.g. echo from broadcast or local sync)
      liveProvider.addLiveChatMessage('class_101', msg1);
      expect(liveProvider.classes.first.chatMessages.length, 1, reason: 'Duplicate message ID must not be appended');

      // Add teacher reply with different ID
      final msg2 = LiveChatMessage(
        id: 'msg_uuid_2',
        senderName: 'Er. Alok Verma',
        senderRole: 'Teacher',
        text: 'Yes Rahul, precisely for polarization by reflection.',
        timestamp: DateTime.now(),
      );
      liveProvider.addLiveChatMessage('class_101', msg2);
      expect(liveProvider.classes.first.chatMessages.length, 2);
      expect(liveProvider.classes.first.chatMessages.last.senderRole, 'Teacher');
    });

    test('Aspect ratio calculations for 16:9 widescreen and 9:16 portrait', () {
      const double landscapeRatio = 16 / 9;
      const double portraitRatio = 9 / 16;

      // 1280x720 video standard
      expect(1280 / 720, closeTo(landscapeRatio, 0.01));
      // 720x1280 vertical video standard
      expect(720 / 1280, closeTo(portraitRatio, 0.01));

      // Verifying strict ratio values
      expect(landscapeRatio > 1.7, isTrue);
      expect(portraitRatio < 0.6, isTrue);
    });

    testWidgets('LiveClassesScreen automatically fetches live classes on init and renders RefreshIndicator', (tester) async {
      final initialClass = LiveClassModel(
        id: 'live_test_1',
        courseId: 'c1',
        batchId: 'b1',
        courseName: 'Physics JEE',
        batchName: 'Morning Alpha',
        title: 'Wave Optics Live',
        subject: 'Physics',
        teacherName: 'Er. Alok Verma',
        teacherAvatar: 'https://example.com/avatar.jpg',
        scheduledStartTime: DateTime.now(),
        estimatedDuration: const Duration(minutes: 60),
        status: LiveStatus.live,
        streamUrl: 'https://customer.cloudflarestream.com/sample/manifest/video.m3u8',
      );

      mockRepository.classes = [initialClass];

      final student = UserModel(
        id: 'student_123',
        email: 'rahul@example.com',
        phone: '9876543210',
        name: 'Rahul Kumar',
        role: UserRole.student,
      );

      final authProvider = AuthProvider(repository: FakeTestAuthRepo(student));
      final courseProvider = CourseProvider(repository: FakeCourseRepository());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<LiveClassProvider>.value(value: liveProvider),
            ChangeNotifierProvider<CourseProvider>.value(value: courseProvider),
          ],
          child: const MaterialApp(
            home: LiveClassesScreen(),
          ),
        ),
      );

      // Verify that fetchLiveClasses was called automatically in initState
      expect(mockRepository.fetchCallCount, greaterThanOrEqualTo(1));
      await tester.pumpAndSettle();

      // Verify the active lecture card is present
      expect(find.text('Wave Optics Live'), findsOneWidget);

      // Verify RefreshIndicator exists for pull-to-refresh
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('LiveClassroomScreen chat and header render on Balmuda viewport without RenderFlex overflow', (tester) async {
      // Simulate Balmuda Phone compact screen (360x640 dp)
      tester.view.physicalSize = const Size(360.0, 640.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final activeClass = LiveClassModel(
        id: 'balmuda_live_1',
        courseId: 'c1',
        batchId: 'b1',
        courseName: 'Physics JEE Super 30',
        batchName: 'Morning Alpha Batch 2026',
        title: 'Electromagnetic Waves Full Chapter Live',
        subject: 'Physics',
        teacherName: 'Er. Alok Verma Senior Faculty',
        teacherAvatar: 'https://example.com/avatar.jpg',
        scheduledStartTime: DateTime.now(),
        estimatedDuration: const Duration(minutes: 90),
        status: LiveStatus.live,
        streamUrl: '',
        chatMessages: [
          LiveChatMessage(
            id: 'm1',
            senderName: 'Abhishek Kumar Chaudhary Senior',
            senderRole: 'Student',
            text: 'Sir please explain displacement current equation again in detail.',
            timestamp: DateTime.now(),
          ),
          LiveChatMessage(
            id: 'm2',
            senderName: 'Er. Alok Verma Senior Faculty',
            senderRole: 'Teacher',
            text: 'Sure Abhishek, Maxwell added epsilon_0 dPhi_E/dt to Ampere circuital law.',
            timestamp: DateTime.now(),
          ),
        ],
      );

      final student = UserModel(
        id: 'student_123',
        email: 'rahul@example.com',
        phone: '9876543210',
        name: 'Rahul Kumar',
        role: UserRole.student,
      );

      final authProvider = AuthProvider(repository: FakeTestAuthRepo(student));
      final courseProvider = CourseProvider(repository: FakeCourseRepository());
      liveProvider = LiveClassProvider(repository: mockRepository);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<LiveClassProvider>.value(value: liveProvider),
            ChangeNotifierProvider<CourseProvider>.value(value: courseProvider),
          ],
          child: MaterialApp(
            home: LiveClassroomScreen(liveClass: activeClass),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify chat header text rendered cleanly without overflow
      expect(find.text('Live Classroom Chat & Doubts'), findsOneWidget);
      expect(find.text('2 msgs'), findsOneWidget);

      // Verify messages are rendered without RenderFlex overflow
      expect(find.text('Abhishek Kumar Chaudhary Senior'), findsOneWidget);

      // Drag list slightly to ensure all messages are in view
      if (find.byType(ListView).evaluate().isNotEmpty) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -100));
        await tester.pump();
      }
      expect(find.text('TEACHER'), findsOneWidget);

      // No exception caught implies zero RenderFlex overflow
      expect(tester.takeException(), isNull);
    });

    test('LiveClassProvider preserves chat messages across fetchLiveClasses calls', () async {
      final initialClass = LiveClassModel(
        id: 'class_preserve_1',
        courseId: 'c1',
        batchId: 'b1',
        courseName: 'Physics JEE',
        batchName: 'Morning Alpha',
        title: 'Wave Optics Live',
        subject: 'Physics',
        teacherName: 'Er. Alok Verma',
        teacherAvatar: 'https://example.com/avatar.jpg',
        scheduledStartTime: DateTime.now(),
        estimatedDuration: const Duration(minutes: 60),
        status: LiveStatus.live,
        streamUrl: 'https://customer.cloudflarestream.com/sample/manifest/video.m3u8',
      );

      mockRepository.classes = [initialClass];
      await liveProvider.fetchLiveClasses();

      final msg = LiveChatMessage(
        id: 'msg_preserve_1',
        senderName: 'Student Rahul',
        senderRole: 'Student',
        text: 'Preserve this message across catalog refreshes',
        timestamp: DateTime.now(),
      );

      liveProvider.addLiveChatMessage('class_preserve_1', msg);
      expect(liveProvider.getChatMessagesForClass('class_preserve_1').length, 1);

      // Now simulate a background catalog refresh from polling or realtime
      await liveProvider.fetchLiveClasses();

      // Chat history MUST be preserved and not wiped out to empty list
      final msgsAfterRefresh = liveProvider.getChatMessagesForClass('class_preserve_1');
      expect(msgsAfterRefresh.length, 1);
      expect(msgsAfterRefresh.first.text, 'Preserve this message across catalog refreshes');
    });

    testWidgets('LiveClassroomScreen handles keyboard opening on Balmuda without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(360.0, 640.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewInsets();
      });

      final activeClass = LiveClassModel(
        id: 'balmuda_kb_1',
        courseId: 'c1',
        batchId: 'b1',
        courseName: 'Physics JEE Super 30',
        batchName: 'Morning Alpha Batch 2026',
        title: 'Electromagnetic Waves Full Chapter Live',
        subject: 'Physics',
        teacherName: 'Er. Alok Verma',
        teacherAvatar: 'https://example.com/avatar.jpg',
        scheduledStartTime: DateTime.now(),
        estimatedDuration: const Duration(minutes: 90),
        status: LiveStatus.live,
        streamUrl: '',
        chatMessages: [
          LiveChatMessage(
            id: 'm1',
            senderName: 'Abhishek',
            senderRole: 'Student',
            text: 'Question about displacement current',
            timestamp: DateTime.now(),
          ),
        ],
      );

      final student = UserModel(
        id: 'student_123',
        email: 'rahul@example.com',
        phone: '9876543210',
        name: 'Rahul Kumar',
        role: UserRole.student,
      );

      final authProvider = AuthProvider(repository: FakeTestAuthRepo(student));
      final courseProvider = CourseProvider(repository: FakeCourseRepository());
      liveProvider = LiveClassProvider(repository: mockRepository);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<LiveClassProvider>.value(value: liveProvider),
            ChangeNotifierProvider<CourseProvider>.value(value: courseProvider),
          ],
          child: MaterialApp(
            home: LiveClassroomScreen(liveClass: activeClass),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Simulate soft keyboard opening (e.g. 280dp height)
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Ensure no RenderFlex overflow happened
      expect(tester.takeException(), isNull);

      // Verify chat input field is still displayed and accessible
      expect(find.byType(TextField), findsOneWidget);
    });
    test('LiveChatMessage.fromMap properly parses Supabase Realtime broadcast payload with nested payload map and snake_case keys', () {
      // Simulate raw broadcast event delivered by Supabase Realtime client
      final rawBroadcast = {
        'event': 'chat_message',
        'type': 'broadcast',
        'payload': {
          'id': 'msg_1730000000_12345',
          'sender_name': 'Rohan Student',
          'sender_role': 'STUDENT',
          'message': 'Sir what is electromagnetic induction?',
          'created_at': '2026-11-02T15:30:00.000Z',
          'is_pinned': false,
        },
      };

      final msg = LiveChatMessage.fromMap(rawBroadcast);
      expect(msg.id, 'msg_1730000000_12345');
      expect(msg.senderName, 'Rohan Student');
      expect(msg.senderRole, 'STUDENT');
      expect(msg.text, 'Sir what is electromagnetic induction?');
      expect(msg.isPinned, isFalse);

      // Verify camelCase fallback as well
      final camelCasePayload = {
        'id': 'msg_camel_1',
        'senderName': 'Teacher Alok',
        'senderRole': 'TEACHER',
        'text': 'Pay attention to Lenz law',
      };
      final msg2 = LiveChatMessage.fromMap(camelCasePayload);
      expect(msg2.id, 'msg_camel_1');
      expect(msg2.senderName, 'Teacher Alok');
      expect(msg2.senderRole, 'TEACHER');
      expect(msg2.text, 'Pay attention to Lenz law');
    });

    testWidgets('LiveClassroomScreen displays YouTube-style live scrubber, LIVE edge badge, and jump to start button', (WidgetTester tester) async {
      final activeClass = LiveClassModel(
        id: 'class_yt_bar_test',
        courseId: 'c1',
        courseName: 'Physics Class 12',
        batchId: 'b1',
        batchName: 'Lakshya 2026',
        title: 'Wave Optics Live Scrubber Test',
        subject: 'Physics',
        teacherName: 'Er. Alok Verma',
        teacherAvatar: 'https://example.com/avatar.jpg',
        scheduledStartTime: DateTime.now().subtract(const Duration(minutes: 25)),
        actualStartTime: DateTime.now().subtract(const Duration(minutes: 25)),
        estimatedDuration: const Duration(minutes: 90),
        status: LiveStatus.live,
        streamUrl: '',
        chatMessages: [],
      );

      final student = UserModel(
        id: 'student_123',
        email: 'rahul@example.com',
        phone: '9876543210',
        name: 'Rahul Kumar',
        role: UserRole.student,
      );

      final authProvider = AuthProvider(repository: FakeTestAuthRepo(student));
      final courseProvider = CourseProvider(repository: FakeCourseRepository());
      liveProvider = LiveClassProvider(repository: mockRepository);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<LiveClassProvider>.value(value: liveProvider),
            ChangeNotifierProvider<CourseProvider>.value(value: courseProvider),
          ],
          child: MaterialApp(
            home: LiveClassroomScreen(liveClass: activeClass),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify YouTube-style Live Bar controls exist
      // 1. Jump to Start button (Icons.skip_previous_rounded)
      expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
      // 2. LIVE badge
      expect(find.text('LIVE'), findsWidgets);
      // 3. Slider scrubber
      expect(find.byType(Slider), findsOneWidget);
      // 4. Chat toggle button in Action Row
      expect(find.byKey(const Key('live_chat_toggle_button')), findsOneWidget);
    });

    testWidgets('LiveClassroomScreen renders side-by-side layout in landscape mode without overflows', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 2.0; // 640x360 logical landscape viewport
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final activeClass = LiveClassModel(
        id: 'class_landscape_test',
        courseId: 'c1',
        courseName: 'Physics Class 12',
        batchId: 'b1',
        batchName: 'Lakshya 2026',
        title: 'Landscape Live Classroom & Chat Test',
        subject: 'Physics',
        teacherName: 'Er. Alok Verma',
        teacherAvatar: 'https://example.com/avatar.jpg',
        scheduledStartTime: DateTime.now().subtract(const Duration(minutes: 10)),
        actualStartTime: DateTime.now().subtract(const Duration(minutes: 10)),
        estimatedDuration: const Duration(minutes: 90),
        status: LiveStatus.live,
        streamUrl: '',
        chatMessages: [
          LiveChatMessage(
            id: 'lm1',
            senderName: 'Student 1',
            senderRole: 'Student',
            text: 'I can see the chat clearly in landscape!',
            timestamp: DateTime.now(),
          ),
        ],
      );

      final student = UserModel(
        id: 'student_123',
        email: 'rahul@example.com',
        phone: '9876543210',
        name: 'Rahul Kumar',
        role: UserRole.student,
      );

      final authProvider = AuthProvider(repository: FakeTestAuthRepo(student));
      final courseProvider = CourseProvider(repository: FakeCourseRepository());
      liveProvider = LiveClassProvider(repository: mockRepository);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<LiveClassProvider>.value(value: liveProvider),
            ChangeNotifierProvider<CourseProvider>.value(value: courseProvider),
          ],
          child: MaterialApp(
            home: LiveClassroomScreen(liveClass: activeClass),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Ensure no RenderFlex overflows in landscape mode
      expect(tester.takeException(), isNull);

      // Verify chat stream and input are present in landscape
      expect(find.text('I can see the chat clearly in landscape!'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    test('LiveClassProvider.isClassActiveLive accurately identifies active classes vs stale ones', () {
      final activeClass = LiveClassModel(
        id: 'live_active_1',
        courseId: 'c1',
        courseName: 'Physics Class 12',
        batchId: 'b1',
        batchName: 'Lakshya 2026',
        title: 'Wave Optics Live Right Now',
        subject: 'Physics',
        teacherName: 'Er. Alok Verma',
        teacherAvatar: 'https://example.com/avatar.jpg',
        scheduledStartTime: DateTime.now().subtract(const Duration(minutes: 15)),
        actualStartTime: DateTime.now().subtract(const Duration(minutes: 15)),
        estimatedDuration: const Duration(minutes: 90),
        status: LiveStatus.live,
        streamUrl: '',
      );

      expect(LiveClassProvider.isClassActiveLive(activeClass), isTrue);

      final staleClass = LiveClassModel(
        id: 'live_stale_1',
        courseId: 'c1',
        courseName: 'Physics Class 12',
        batchId: 'b1',
        batchName: 'Lakshya 2026',
        title: 'Abandoned Live Stream From Yesterday',
        subject: 'Physics',
        teacherName: 'Er. Alok Verma',
        teacherAvatar: 'https://example.com/avatar.jpg',
        scheduledStartTime: DateTime.now().subtract(const Duration(hours: 5)),
        actualStartTime: DateTime.now().subtract(const Duration(hours: 5)),
        estimatedDuration: const Duration(minutes: 90),
        status: LiveStatus.live,
        streamUrl: '',
      );

      expect(LiveClassProvider.isClassActiveLive(staleClass), isFalse);

      final endedClass = activeClass.copyWith(status: LiveStatus.ended);
      expect(LiveClassProvider.isClassActiveLive(endedClass), isFalse);
    });

    test('LiveClassProvider.updateViewerCount dynamically updates activeViewersCount and notifies listeners', () async {
      final classModel = LiveClassModel(
        id: 'viewer_count_test_class',
        courseId: 'c1',
        courseName: 'Physics Class 12',
        batchId: 'b1',
        batchName: 'Lakshya 2026',
        title: 'Viewer Count Test',
        subject: 'Physics',
        teacherName: 'Er. Alok Verma',
        teacherAvatar: 'https://example.com/avatar.jpg',
        scheduledStartTime: DateTime.now(),
        actualStartTime: DateTime.now(),
        status: LiveStatus.live,
        streamUrl: '',
        activeViewersCount: 0,
      );

      mockRepository.classes = [classModel];
      liveProvider = LiveClassProvider(repository: mockRepository);
      await liveProvider.fetchLiveClasses();

      expect(liveProvider.classes.first.activeViewersCount, equals(0));

      int listenerNotificationCount = 0;
      liveProvider.addListener(() {
        listenerNotificationCount++;
      });

      // Simulate student joining
      liveProvider.updateViewerCount('viewer_count_test_class', 1);
      expect(liveProvider.classes.first.activeViewersCount, equals(1));
      expect(listenerNotificationCount, equals(1));

      // Simulate second student joining
      liveProvider.updateViewerCount('viewer_count_test_class', 5);
      expect(liveProvider.classes.first.activeViewersCount, equals(5));
      expect(listenerNotificationCount, equals(2));

      // Redundant update with same count should not fire listener
      liveProvider.updateViewerCount('viewer_count_test_class', 5);
      expect(listenerNotificationCount, equals(2));
    });

    test('Chat Deduplication: Optimistic message followed by Postgres change event is reconciled without duplicate', () async {
      final activeClass = LiveClassModel(
        id: 'class_chat_dedup_test',
        courseId: 'c1',
        courseName: 'Physics 12',
        batchId: 'b1',
        batchName: 'Lakshya Batch',
        title: 'Wave Optics Live',
        subject: 'Physics',
        teacherName: 'Er. Alok Verma',
        teacherAvatar: 'https://example.com/avatar.jpg',
        scheduledStartTime: DateTime.now(),
        actualStartTime: DateTime.now(),
        status: LiveStatus.live,
        streamUrl: '',
      );

      mockRepository.classes = [activeClass];
      liveProvider = LiveClassProvider(repository: mockRepository);
      await liveProvider.fetchLiveClasses();

      final now = DateTime.now();

      // 1. Student sends message locally (optimistic add)
      final localMsg = LiveChatMessage(
        id: 'msg_temp_123456789',
        senderName: 'Anjali Sharma',
        senderRole: 'STUDENT',
        text: 'hello sir please repeat the formula',
        timestamp: now,
      );
      liveProvider.addLiveChatMessage('class_chat_dedup_test', localMsg);

      var msgs = liveProvider.getChatMessagesForClass('class_chat_dedup_test');
      expect(msgs.length, equals(1));
      expect(msgs.first.id, equals('msg_temp_123456789'));

      // 2. Database confirms message with Postgres UUID 600ms later
      final dbMsg = LiveChatMessage(
        id: 'e134bb4e-76e2-411a-bc07-449e7b282c0b',
        senderName: 'Anjali Sharma',
        senderRole: 'STUDENT',
        text: 'hello sir please repeat the formula',
        timestamp: now.add(const Duration(milliseconds: 600)),
      );
      liveProvider.addLiveChatMessage('class_chat_dedup_test', dbMsg);

      // Must be reconciled to a SINGLE message with the canonical UUID
      msgs = liveProvider.getChatMessagesForClass('class_chat_dedup_test');
      expect(msgs.length, equals(1), reason: 'Echo from database must NOT create duplicate message');
      expect(msgs.first.id, equals('e134bb4e-76e2-411a-bc07-449e7b282c0b'));

      // 3. Different message arrives from another student
      final otherMsg = LiveChatMessage(
        id: 'f555cc5e-88e2-411a-bc07-449e7b282c0c',
        senderName: 'Rohan Verma',
        senderRole: 'STUDENT',
        text: 'Understood thanks!',
        timestamp: now.add(const Duration(seconds: 2)),
      );
      liveProvider.addLiveChatMessage('class_chat_dedup_test', otherMsg);

      msgs = liveProvider.getChatMessagesForClass('class_chat_dedup_test');
      expect(msgs.length, equals(2));
    });

    testWidgets('YouTube-Style DVR Timeline: Rewind behind live edge, time-shifted badge, and LIVE return button', (WidgetTester tester) async {
      final activeClass = LiveClassModel(
        id: 'dvr_timeline_test_class',
        courseId: 'c1',
        courseName: 'Physics JEE Advanced',
        batchId: 'b1',
        batchName: 'Morning Alpha Batch',
        title: 'Electromagnetic Induction & Lenz Law',
        subject: 'Physics',
        teacherName: 'Er. Alok Verma',
        teacherAvatar: 'https://example.com/avatar.jpg',
        scheduledStartTime: DateTime.now().subtract(const Duration(minutes: 20)),
        actualStartTime: DateTime.now().subtract(const Duration(minutes: 20)),
        estimatedDuration: const Duration(minutes: 90),
        status: LiveStatus.live,
        streamUrl: '',
        chatMessages: [],
      );

      final student = UserModel(
        id: 'student_dvr_1',
        email: 'student@example.org',
        phone: '9876543210',
        name: 'Rahul Kumar',
        role: UserRole.student,
      );

      final authProvider = AuthProvider(repository: FakeTestAuthRepo(student));
      final courseProvider = CourseProvider(repository: FakeCourseRepository());
      liveProvider = LiveClassProvider(repository: mockRepository);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<LiveClassProvider>.value(value: liveProvider),
            ChangeNotifierProvider<CourseProvider>.value(value: courseProvider),
          ],
          child: MaterialApp(
            home: LiveClassroomScreen(liveClass: activeClass),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Initial State: Player controls rendered with YouTube DVR bar
      expect(find.byKey(const Key('youtube_live_badge_button')), findsOneWidget);
      expect(find.byIcon(Icons.replay_10_rounded), findsOneWidget);
      expect(find.byIcon(Icons.forward_10_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);

      // Verify LIVE badge is visible
      expect(find.text('LIVE'), findsWidgets);

      // 2. Student taps Rewind 10s button to move behind live edge
      await tester.tap(find.byIcon(Icons.replay_10_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 3. Jump to Start button (00:00)
      await tester.tap(find.byIcon(Icons.skip_previous_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('00:00'), findsOneWidget);

      // 4. Student taps YouTube LIVE button to jump back directly to the live edge
      final liveButton = find.byKey(const Key('youtube_live_badge_button'));
      expect(liveButton, findsOneWidget);
      await tester.tap(liveButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Returns to LIVE state
      expect(find.text('LIVE'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    test('LiveClassProvider allows repeated student messages with distinct IDs and does not drop second message', () {
      final classId = 'test_chat_repeat_1';
      final msg1 = LiveChatMessage(
        id: 'msg_uuid_101',
        senderName: 'Student',
        senderRole: 'Student',
        text: 'hello',
        timestamp: DateTime.now(),
      );
      final msg2 = LiveChatMessage(
        id: 'msg_uuid_102',
        senderName: 'Student',
        senderRole: 'Student',
        text: 'hello',
        timestamp: DateTime.now().add(const Duration(seconds: 1)),
      );

      liveProvider.addLiveChatMessage(classId, msg1);
      expect(liveProvider.getChatMessagesForClass(classId).length, 1);

      // Second legitimate 'hello' message from same or another student with distinct ID MUST appear
      liveProvider.addLiveChatMessage(classId, msg2);
      expect(liveProvider.getChatMessagesForClass(classId).length, 2);
      expect(liveProvider.getChatMessagesForClass(classId).first.id, 'msg_uuid_101');
      expect(liveProvider.getChatMessagesForClass(classId).last.id, 'msg_uuid_102');
    });

    test('LiveClassModel effectiveDuration accurately reflects real recorded duration for ended classes instead of 1h 30m fallback', () {
      final endedClassWithSec = LiveClassModel(
        id: 'ended_1',
        courseId: 'c1',
        batchId: 'b1',
        courseName: 'Physics',
        batchName: 'Batch A',
        title: 'Recorded Lecture 1',
        subject: 'Physics',
        teacherName: 'Faculty',
        teacherAvatar: '',
        scheduledStartTime: DateTime.now().subtract(const Duration(minutes: 60)),
        status: LiveStatus.ended,
        streamUrl: 'https://example.com/rec.m3u8',
        actualDurationSeconds: 1200, // 20 minutes
      );

      // Must be 20 minutes (1200s), NOT 90 minutes (5400s)
      expect(endedClassWithSec.effectiveDuration.inSeconds, 1200);
      expect(endedClassWithSec.effectiveDuration.inMinutes, 20);

      // When deserialized from Supabase map with actual_duration_seconds: 600
      final deserialized = LiveClassModel.fromMap({
        'id': 'ended_from_map',
        'status': 'ended',
        'actual_duration_seconds': 600, // 10 minutes
        'duration_minutes': 90, // Legacy fallback column
      });

      expect(deserialized.effectiveDuration.inMinutes, 10);
      expect(deserialized.effectiveDuration.inSeconds, 600);

      // When deserialized with actual_start_time and actual_end_time
      final start = DateTime.now().subtract(const Duration(minutes: 45));
      final end = DateTime.now();
      final fromTimes = LiveClassModel.fromMap({
        'id': 'ended_from_times',
        'status': 'ended',
        'actual_start_time': start.toIso8601String(),
        'actual_end_time': end.toIso8601String(),
      });
      expect(fromTimes.effectiveDuration.inMinutes, closeTo(45, 1));
    });

    testWidgets('CourseDetailScreen displays accurate lesson count and hours when course has 3 recorded live lectures instead of 0', (tester) async {
      final courseWithZero = CourseModel(
        id: 'course_live_stats_1',
        title: 'IIT-JEE Physics Super 30',
        category: 'Engineering',
        description: 'Comprehensive physics curriculum with live classes.',
        price: 9.0,
        originalPrice: 99.0,
        teacherName: 'Er. Alok Verma',
        teacherId: 't1',
        totalLessons: 0, // In db view, lessons table has 0
        totalHours: 0,
        totalTests: 2,
        totalNotes: 5,
        rating: 4.8,
        reviewsCount: 15,
        coverImageUrl: 'https://example.com/cover.jpg',
        highlights: const [],
      );

      final batch = BatchModel(
        id: 'batch_stat_1',
        courseId: 'course_live_stats_1',
        name: 'Morning Alpha Batch',
        timing: '10:00 AM - 11:30 AM',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 90)),
        teacherName: 'Er. Alok Verma',
        teacherId: 't1',
        totalStudents: 25,
        batchPrice: 9.0,
      );

      // 3 recorded live lectures for this batch/course
      final rec1 = LiveClassModel(
        id: 'rec_101',
        courseId: 'course_live_stats_1',
        batchId: 'batch_stat_1',
        courseName: 'IIT-JEE Physics Super 30',
        batchName: 'Morning Alpha Batch',
        title: 'Electrostatics Lecture 1',
        subject: 'Physics',
        teacherName: 'Er. Alok Verma',
        teacherAvatar: '',
        scheduledStartTime: DateTime.now().subtract(const Duration(days: 3)),
        status: LiveStatus.ended,
        recordingStatus: 'ready',
        streamUrl: 'https://example.com/rec1.m3u8',
        actualDurationSeconds: 1800, // 30 mins
      );

      final rec2 = LiveClassModel(
        id: 'rec_102',
        courseId: 'course_live_stats_1',
        batchId: 'batch_stat_1',
        courseName: 'IIT-JEE Physics Super 30',
        batchName: 'Morning Alpha Batch',
        title: 'Electrostatics Lecture 2',
        subject: 'Physics',
        teacherName: 'Er. Alok Verma',
        teacherAvatar: '',
        scheduledStartTime: DateTime.now().subtract(const Duration(days: 2)),
        status: LiveStatus.ended,
        recordingStatus: 'ready',
        streamUrl: 'https://example.com/rec2.m3u8',
        actualDurationSeconds: 2400, // 40 mins
      );

      final rec3 = LiveClassModel(
        id: 'rec_103',
        courseId: 'course_live_stats_1',
        batchId: 'batch_stat_1',
        courseName: 'IIT-JEE Physics Super 30',
        batchName: 'Morning Alpha Batch',
        title: 'Gauss Law Applications',
        subject: 'Physics',
        teacherName: 'Er. Alok Verma',
        teacherAvatar: '',
        scheduledStartTime: DateTime.now().subtract(const Duration(days: 1)),
        status: LiveStatus.ended,
        recordingStatus: 'ready',
        streamUrl: 'https://example.com/rec3.m3u8',
        actualDurationSeconds: 3000, // 50 mins
      );

      mockRepository.classes = [rec1, rec2, rec3];
      final liveProv = LiveClassProvider(repository: mockRepository);
      await liveProv.fetchLiveClasses();

      final student = UserModel(
        id: 'student_stat_1',
        email: 'student@example.com',
        phone: '9988776655',
        name: 'Aman Kumar',
        role: UserRole.student,
        enrolledBatchIds: ['batch_stat_1'],
        enrolledCourseIds: ['course_live_stats_1'],
      );

      final authProvider = AuthProvider(repository: FakeTestAuthRepo(student));
      final fakeCourseRepo = StatsTestCourseRepo();
      fakeCourseRepo.testBatches = [batch];
      fakeCourseRepo.testCourses = [courseWithZero];
      final courseProv = CourseProvider(repository: fakeCourseRepo);
      await courseProv.fetchCatalog();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<LiveClassProvider>.value(value: liveProv),
            ChangeNotifierProvider<CourseProvider>.value(value: courseProv),
          ],
          child: MaterialApp(
            home: CourseDetailScreen(course: courseWithZero),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify that instead of displaying "0 Lessons" and "0+ Hours",
      // it calculates and displays "3 Lessons" and "2+ Hours" (30+40+50 = 120 mins = 2h)
      expect(find.text('3 Lessons'), findsOneWidget);
      expect(find.text('2+ Hours'), findsOneWidget);

      // Verify Curriculum displays the Recorded Live Lectures section and titles
      expect(find.text('Recorded Live Lectures (3)'), findsOneWidget);
      expect(find.text('Electrostatics Lecture 1'), findsOneWidget);
      expect(find.text('Electrostatics Lecture 2'), findsOneWidget);
      expect(find.text('Gauss Law Applications'), findsOneWidget);
    });

    test('LiveClassModel & Provider eliminate 3h 46m ghost duration for abandoned sessions and retain processing live broadcasts', () async {
      // 1. Ghost test session: scheduled at 16:39, ended at 20:25 (diff = 13560s = 3h 46m), actual_duration_seconds: 0
      final ghostMap = {
        'id': 'ghost_session_1',
        'course_id': 'c1',
        'batch_id': 'b1',
        'title': 'Abandoned Test Live',
        'subject': 'General Studies',
        'status': 'ended',
        'actual_start_time': DateTime(2026, 11, 3, 16, 39).toIso8601String(),
        'actual_end_time': DateTime(2026, 11, 3, 20, 25).toIso8601String(),
        'actual_duration_seconds': 0,
        'recording_status': 'ready',
        'recording_url': 'https://videodelivery.net/rec_fakeghost/manifest/video.m3u8',
      };

      final ghostModel = LiveClassModel.fromMap(ghostMap);
      // Duration MUST NOT be 3h 46m (13560s), it must evaluate to Duration.zero
      expect(ghostModel.actualDurationSeconds, equals(0));
      expect(ghostModel.effectiveDuration, equals(Duration.zero));

      // 2. Real live session recorded today: duration 15 mins (900s), recording_status: 'processing'
      final realLiveMap = {
        'id': 'real_live_today',
        'course_id': 'c1',
        'batch_id': 'b1',
        'title': 'Today Live Lecture on Constitution',
        'subject': 'Polity',
        'status': 'ended',
        'actual_start_time': DateTime.now().subtract(const Duration(minutes: 20)).toIso8601String(),
        'actual_end_time': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
        'actual_duration_seconds': 900,
        'recording_status': 'processing',
        'stream_url': 'https://customer-test.cloudflarestream.com/live_today/manifest/video.m3u8',
      };

      final realLiveModel = LiveClassModel.fromMap(realLiveMap);
      expect(realLiveModel.actualDurationSeconds, equals(900));
      expect(realLiveModel.effectiveDuration, equals(const Duration(minutes: 15)));

      // 3. Test LiveClassProvider pastRecordings filtering
      final mockRepo = MockLiveClassRepository();
      mockRepo.classes = [ghostModel, realLiveModel];

      final provider = LiveClassProvider(repository: mockRepo);
      await provider.fetchLiveClasses();

      // Ghost session must be excluded because it has 0 duration and synthetic rec_ URL
      expect(provider.pastRecordings.any((c) => c.id == 'ghost_session_1'), isFalse);

      // Real live session with 'processing' status must be INCLUDED so student sees it
      expect(provider.pastRecordings.any((c) => c.id == 'real_live_today'), isTrue);
    });

    test('LiveClassModel & Provider eliminate 4h 34m ghost recording and auto-promote stale processing session', () async {
      // 1. Ghost test session with bloated duration 4h 34m (16440s) but no real video
      final ghost4hMap = {
        'id': 'ghost_4h_session',
        'course_id': 'c1',
        'batch_id': 'b1',
        'title': '4h 34m Ghost Broadcast Test',
        'subject': 'General Studies',
        'status': 'ended',
        'actual_duration_seconds': 16440,
        'recording_status': 'ready',
        'recording_url': 'https://videodelivery.net/rec_fake4h34m/manifest/video.m3u8',
      };

      final ghost4hModel = LiveClassModel.fromMap(ghost4hMap);
      // Duration MUST NOT be accepted as 16440s; without real video, it must evaluate to 0
      expect(ghost4hModel.actualDurationSeconds, equals(0));
      expect(ghost4hModel.effectiveDuration, equals(Duration.zero));

      // 2. Real broadcast ended 2 hours ago with 'processing' status - must auto-promote to 'ready'
      final staleProcessingMap = {
        'id': 'stale_processing_session',
        'course_id': 'c1',
        'batch_id': 'b1',
        'title': 'Optics Live Lecture 4',
        'subject': 'Physics',
        'status': 'ended',
        'actual_start_time': DateTime.now().subtract(const Duration(hours: 2, minutes: 45)).toIso8601String(),
        'actual_end_time': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        'actual_duration_seconds': 2700,
        'recording_status': 'processing',
        'cloudflare_video_uid': 'cf_real_uid_12345',
        'stream_url': 'https://customer-test.cloudflarestream.com/cf_real_uid_12345/manifest/video.m3u8',
      };

      final staleProcessingModel = LiveClassModel.fromMap(staleProcessingMap);
      // Because it ended > 90 seconds ago, it must auto-promote to 'ready'
      expect(staleProcessingModel.recordingStatus, equals('ready'));

      // 3. Provider pastRecordings filtering
      final mockRepo = MockLiveClassRepository();
      mockRepo.classes = [ghost4hModel, staleProcessingModel];

      final provider = LiveClassProvider(repository: mockRepo);
      await provider.fetchLiveClasses();

      // Ghost 4h session MUST NOT be present in pastRecordings
      expect(provider.pastRecordings.any((c) => c.id == 'ghost_4h_session'), isFalse);

      // Promoted real live lecture MUST be present and ready
      expect(provider.pastRecordings.any((c) => c.id == 'stale_processing_session'), isTrue);
      final promoted = provider.pastRecordings.firstWhere((c) => c.id == 'stale_processing_session');
      expect(promoted.recordingStatus, equals('ready'));
    });

    testWidgets('Batch curriculum progress updates dynamically with fractional watch progress and includes live recordings', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final student = UserModel(
        id: 'student_progress_1',
        email: 'rahul@example.com',
        phone: '9876543210',
        name: 'Rahul Sharma',
        role: UserRole.student,
        enrolledBatchIds: ['batch_prog_1'],
        enrolledCourseIds: ['course_test_prog'],
      );

      final batch = BatchModel(
        id: 'batch_prog_1',
        courseId: 'course_test_prog',
        name: 'Morning Batch Alpha',
        timing: '08:00 AM - 10:00 AM',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 12, 31),
        teacherName: 'History Faculty',
        teacherId: 't_hist_1',
        totalStudents: 15,
        batchPrice: 499.0,
      );

      final testCourse = CourseModel(
        id: 'course_test_prog',
        title: 'Target BPSC Foundation 2026',
        description: 'Comprehensive preparation',
        category: 'Civil Services',
        coverImageUrl: 'https://images.unsplash.com/photo-1532094349884-543bc11b234d',
        price: 499.0,
        originalPrice: 999.0,
        teacherId: 't_hist_1',
        teacherName: 'History Faculty',
        totalLessons: 1,
        totalHours: 10,
        totalTests: 2,
        totalNotes: 5,
        rating: 4.8,
        reviewsCount: 20,
        highlights: const ['Daily Live', 'Recorded Access'],
              );

      final lesson1 = VideoLessonModel(
        id: 'lesson_prog_1',
        courseId: 'course_test_prog',
        batchId: 'batch_prog_1',
        title: 'Introduction to Modern History',
        chapter: 'History',
        videoUrl: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
        duration: const Duration(minutes: 30),
        uploadedAt: DateTime.now(),
        progressPercent: 0.0,
        isCompleted: false,
      );

      final authProvider = AuthProvider(repository: FakeTestAuthRepo(student));
      final fakeCourseRepo = StatsTestCourseRepo();
      fakeCourseRepo.testCourses = [testCourse];
      fakeCourseRepo.testBatches = [batch];
      fakeCourseRepo.testLessons = [lesson1];
      fakeCourseRepo.testEnrolledCourseIds = [testCourse.id];
      fakeCourseRepo.testEnrolledBatchIds = [batch.id];

      final courseProvider = CourseProvider(repository: fakeCourseRepo);
      await courseProvider.fetchCatalog();
      await courseProvider.fetchMyEnrollments();

      final mockRepo = MockLiveClassRepository();
      final liveProvider = LiveClassProvider(repository: mockRepo);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<LiveClassProvider>.value(value: liveProvider),
            ChangeNotifierProvider<CourseProvider>.value(value: courseProvider),
          ],
          child: const MaterialApp(
            home: MyBatchesScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially, 0% watched: displays "0 of 1 Lessons" and "0%"
      expect(find.text('Curriculum: 0 of 1 Lessons'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);

      // Now student watches 50% of the lesson
      await courseProvider.recordLecturePlayback(
        lectureId: lesson1.id,
        courseId: testCourse.id,
        batchId: 'batch_prog_1',
        courseName: testCourse.title,
        batchName: 'Morning Batch Alpha',
        title: lesson1.title,
        subject: lesson1.chapter,
        teacherName: 'History Faculty',
        videoUrl: lesson1.videoUrl,
        duration: lesson1.duration,
        progressPercent: 0.50,
        positionSeconds: 900,
        userId: student.id,
      );

      await tester.pumpAndSettle();

      // Progress bar dynamically advances to 50%
      expect(find.text('50%'), findsOneWidget);

      // Now student finishes 85% (crosses 75% completion threshold)
      await courseProvider.recordLecturePlayback(
        lectureId: lesson1.id,
        courseId: testCourse.id,
        batchId: 'batch_prog_1',
        courseName: testCourse.title,
        batchName: 'Morning Batch Alpha',
        title: lesson1.title,
        subject: lesson1.chapter,
        teacherName: 'History Faculty',
        videoUrl: lesson1.videoUrl,
        duration: lesson1.duration,
        progressPercent: 0.85,
        positionSeconds: 1530,
        userId: student.id,
      );

      await tester.pumpAndSettle();

      // Lesson completed! Displays "1 of 1 Lessons" and "100%"
      expect(find.text('Curriculum: 1 of 1 Lessons'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
    });
  });
}
