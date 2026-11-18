import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:modern_classes_patna/features/auth/data/models/user_model.dart';
import 'package:modern_classes_patna/features/auth/data/repositories/auth_repository.dart';
import 'package:modern_classes_patna/features/courses/logic/course_provider.dart';
import 'package:modern_classes_patna/features/live_classes/data/models/live_class_model.dart';
import 'package:modern_classes_patna/features/live_classes/data/repositories/live_class_repository.dart';
import 'package:modern_classes_patna/features/live_classes/logic/live_class_provider.dart';
import 'package:modern_classes_patna/providers/auth_provider.dart';
import 'package:modern_classes_patna/screens/student/live_classes_screen.dart';
import 'package:modern_classes_patna/screens/student/live_classroom_screen.dart';
import 'fake_course_repository.dart';

class MockTestLiveClassRepo implements LiveClassRepository {
  final List<LiveClassModel> liveClasses;

  MockTestLiveClassRepo({required this.liveClasses});

  @override
  Future<List<LiveClassModel>> getLiveClasses() async => liveClasses;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
  testWidgets('LiveClassroomScreen for Recorded Lecture removes chat, doubts stream, and raise hand',
      (tester) async {
    final recordedClass = LiveClassModel(
      id: 'rec_101',
      courseId: 'c_1',
      batchId: 'b_1',
      courseName: 'BPSC Prelims',
      batchName: 'Target 70th Batch',
      title: 'Historical Background of Indian Constitution',
      subject: 'Polity',
      teacherName: 'Dr. Kumar',
      teacherAvatar: '',
      scheduledStartTime: DateTime.now().subtract(const Duration(hours: 2)),
      status: LiveStatus.ended,
      recordingStatus: 'ready',
      streamUrl: 'https://customer-mock.cloudflarestream.com/mock_uid/manifest/video.m3u8',
      recordingUrl: 'https://customer-mock.cloudflarestream.com/mock_uid/manifest/video.m3u8',
      actualDurationSeconds: 3600,
    );

    final student = UserModel(
      id: 'student_1',
      email: 'student@example.com',
      phone: '9876543210',
      name: 'Anshu Kumar',
      role: UserRole.student,
    );

    final authProvider = AuthProvider(repository: FakeTestAuthRepo(student));
    final liveProvider = LiveClassProvider(
      repository: MockTestLiveClassRepo(liveClasses: [recordedClass]),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<LiveClassProvider>.value(value: liveProvider),
        ],
        child: MaterialApp(
          home: LiveClassroomScreen(liveClass: recordedClass),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Should display "Recorded Lecture" badge
    expect(find.text("Recorded Lecture"), findsWidgets);

    // 2. Should display "Lecture Information" and NOT display removed guidance card
    expect(find.text("Lecture Information"), findsOneWidget);
    expect(find.text("Revision & Study Guidance"), findsNothing);

    await tester.scrollUntilVisible(find.text("Ask Doubt to Faculty"), 200);
    expect(find.text("Ask Doubt to Faculty"), findsOneWidget);

    // 3. Should NOT display live classroom chat, doubts list, or raise hand
    expect(find.text("Live Classroom Chat & Doubts"), findsNothing);
    expect(find.text("Raise Hand"), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.send_rounded), findsNothing);
  });

  testWidgets('LiveClassroomScreen for Active Live Class displays chat, viewers, and raise hand',
      (tester) async {
    final liveClass = LiveClassModel(
      id: 'live_202',
      courseId: 'c_1',
      batchId: 'b_1',
      courseName: 'BPSC Prelims',
      batchName: 'Target 70th Batch',
      title: 'Live Current Affairs Discussion',
      subject: 'Current Affairs',
      teacherName: 'Dr. Kumar',
      teacherAvatar: '',
      scheduledStartTime: DateTime.now(),
      status: LiveStatus.live,
      streamUrl: 'https://customer-mock.cloudflarestream.com/live_uid/manifest/video.m3u8',
      activeViewersCount: 42,
    );

    final student = UserModel(
      id: 'student_1',
      email: 'student@example.com',
      phone: '9876543210',
      name: 'Anshu Kumar',
      role: UserRole.student,
    );

    final authProvider = AuthProvider(repository: FakeTestAuthRepo(student));
    final liveProvider = LiveClassProvider(
      repository: MockTestLiveClassRepo(liveClasses: [liveClass]),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<LiveClassProvider>.value(value: liveProvider),
        ],
        child: MaterialApp(
          home: LiveClassroomScreen(liveClass: liveClass),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Should display live viewers badge
    expect(find.text("42 Watching"), findsOneWidget);

    // 2. Should display live chat and raise hand button
    expect(find.text("Live Classroom Chat & Doubts"), findsOneWidget);
    expect(find.text("Raise Hand"), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);

    // 3. Should NOT display recorded archive banner or study guidance
    expect(find.text("Recorded Archive"), findsNothing);
    expect(find.text("Lecture Information"), findsNothing);
    expect(find.text("Revision & Study Guidance"), findsNothing);
  });

  testWidgets('LiveClassroomScreen fullscreen button enters and exits immersive fullscreen',
      (tester) async {
    final recordedClass = LiveClassModel(
      id: 'rec_303',
      courseId: 'c_1',
      batchId: 'b_1',
      courseName: 'BPSC Prelims',
      batchName: 'Target 70th Batch',
      title: 'Full Screen Mechanics Test',
      subject: 'Polity',
      teacherName: 'Dr. Kumar',
      teacherAvatar: '',
      scheduledStartTime: DateTime.now().subtract(const Duration(hours: 1)),
      status: LiveStatus.ended,
      recordingStatus: 'ready',
      streamUrl: 'https://customer-mock.cloudflarestream.com/mock_uid/manifest/video.m3u8',
      recordingUrl: 'https://customer-mock.cloudflarestream.com/mock_uid/manifest/video.m3u8',
      actualDurationSeconds: 120,
    );

    final student = UserModel(
      id: 'student_1',
      email: 'student@example.com',
      phone: '9876543210',
      name: 'Anshu Kumar',
      role: UserRole.student,
    );

    final authProvider = AuthProvider(repository: FakeTestAuthRepo(student));
    final liveProvider = LiveClassProvider(
      repository: MockTestLiveClassRepo(liveClasses: [recordedClass]),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<LiveClassProvider>.value(value: liveProvider),
        ],
        child: MaterialApp(
          home: LiveClassroomScreen(liveClass: recordedClass),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Find and tap the enter fullscreen button
    final enterFullscreenBtn = find.byTooltip("Enter Fullscreen");
    expect(enterFullscreenBtn, findsOneWidget);

    await tester.tap(enterFullscreenBtn);
    await tester.pumpAndSettle();

    // Now in fullscreen: exit fullscreen button and back button must be present
    expect(find.byTooltip("Exit Fullscreen"), findsWidgets);

    // Tap exit fullscreen
    await tester.tap(find.byTooltip("Exit Fullscreen").first);
    await tester.pumpAndSettle();

    // Back in portrait: Enter Fullscreen button must be present again
    expect(find.byTooltip("Enter Fullscreen"), findsOneWidget);
  });

  testWidgets('LiveClassesScreen replaces Recorded Archive with Lectures and shows unified lectures',
      (tester) async {
    final recordedClass = LiveClassModel(
      id: 'rec_404',
      courseId: 'c_1',
      batchId: 'b_1',
      courseName: 'Rangdari batch',
      batchName: 'Rangdari batch - Batch 2',
      title: 'Live Concept Lecture',
      subject: 'Polity',
      teacherName: 'Dr. Kumar',
      teacherAvatar: '',
      scheduledStartTime: DateTime.now().subtract(const Duration(days: 1)),
      status: LiveStatus.ended,
      recordingStatus: 'ready',
      streamUrl: 'https://customer-mock.cloudflarestream.com/mock_uid/manifest/video.m3u8',
      recordingUrl: 'https://customer-mock.cloudflarestream.com/mock_uid/manifest/video.m3u8',
      actualDurationSeconds: 14,
    );

    final student = UserModel(
      id: 'student_1',
      email: 'student@example.com',
      phone: '9876543210',
      name: 'Anshu Kumar',
      role: UserRole.student,
    );

    final authProvider = AuthProvider(repository: FakeTestAuthRepo(student));
    final liveProvider = LiveClassProvider(
      repository: MockTestLiveClassRepo(liveClasses: [recordedClass]),
    );
    final courseProvider = CourseProvider(repository: FakeCourseRepository());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<LiveClassProvider>.value(value: liveProvider),
          ChangeNotifierProvider<CourseProvider>.value(value: courseProvider),
        ],
        child: const MaterialApp(
          home: LiveClassesScreen(initialTabIndex: 1),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify "Lectures" tab exists, and "Recorded Archive" is removed
    expect(find.text("Lectures"), findsOneWidget);
    expect(find.text("Recorded Archive"), findsNothing);

    // 2. Verify the recorded live broadcast appears in the Lectures page
    expect(find.text("Live Concept Lecture"), findsOneWidget);
    expect(find.text("Live Recording"), findsOneWidget);
  });
}
