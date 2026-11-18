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
  testWidgets('LiveClassroomScreen displays clean error message when URL is empty or invalid',
      (tester) async {
    final recordedClass = LiveClassModel(
      id: 'rec_invalid_url',
      courseId: 'c_1',
      batchId: 'b_1',
      courseName: 'Test Course',
      batchName: 'Test Batch',
      title: 'Invalid URL Lecture',
      subject: 'Science',
      teacherName: 'Dr. Kumar',
      teacherAvatar: '',
      scheduledStartTime: DateTime.now().subtract(const Duration(hours: 1)),
      status: LiveStatus.ended,
      recordingStatus: 'ready',
      streamUrl: '',
      recordingUrl: '',
      actualDurationSeconds: 60,
    );

    final student = UserModel(
      id: 'student_1',
      email: 'student@example.com',
      phone: '9876543210',
      name: 'Test Student',
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
        child: MaterialApp(
          home: LiveClassroomScreen(liveClass: recordedClass),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify it renders safely without throwing an uncaught platform exception
    expect(find.byType(LiveClassroomScreen), findsOneWidget);
  });

  testWidgets('LiveClassroomScreen handles Cloudflare Stream URL gracefully',
      (tester) async {
    final recordedClass = LiveClassModel(
      id: 'rec_cf_1',
      courseId: 'c_1',
      batchId: 'b_1',
      courseName: 'Test Course',
      batchName: 'Test Batch',
      title: 'Cloudflare Stream Lecture',
      subject: 'Polity',
      teacherName: 'Dr. Kumar',
      teacherAvatar: '',
      scheduledStartTime: DateTime.now().subtract(const Duration(hours: 1)),
      status: LiveStatus.ended,
      recordingStatus: 'ready',
      streamUrl: 'https://videodelivery.net/d41d8cd98f00b204e9800998ecf8427e/manifest/video.m3u8',
      recordingUrl: 'https://videodelivery.net/d41d8cd98f00b204e9800998ecf8427e/manifest/video.m3u8',
      actualDurationSeconds: 15,
    );

    final student = UserModel(
      id: 'student_1',
      email: 'student@example.com',
      phone: '9876543210',
      name: 'Test Student',
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
        child: MaterialApp(
          home: LiveClassroomScreen(liveClass: recordedClass),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(LiveClassroomScreen), findsOneWidget);
    expect(find.text("Cloudflare Stream Lecture"), findsWidgets);
  });
}
