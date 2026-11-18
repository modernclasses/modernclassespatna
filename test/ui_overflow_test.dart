import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:modern_classes_patna/core/theme/app_theme.dart';
import 'package:modern_classes_patna/features/auth/data/models/user_model.dart';
import 'package:modern_classes_patna/features/auth/logic/auth_provider.dart';
import 'package:modern_classes_patna/features/attendance/data/models/attendance_model.dart';
import 'package:modern_classes_patna/features/attendance/data/repositories/attendance_repository.dart';
import 'package:modern_classes_patna/features/attendance/logic/attendance_provider.dart';
import 'package:modern_classes_patna/features/courses/data/models/batch_model.dart';
import 'package:modern_classes_patna/features/courses/data/models/course_model.dart';
import 'package:modern_classes_patna/features/courses/logic/course_provider.dart';
import 'package:modern_classes_patna/features/notifications/data/models/notification_model.dart';
import 'package:modern_classes_patna/features/notifications/data/repositories/notification_repository.dart';
import 'package:modern_classes_patna/features/notifications/logic/notification_provider.dart';
import 'package:modern_classes_patna/features/study_materials/data/models/study_material_model.dart';
import 'package:modern_classes_patna/features/study_materials/data/repositories/study_material_repository.dart';
import 'package:modern_classes_patna/features/study_materials/logic/study_material_provider.dart';
import 'package:modern_classes_patna/features/tests/data/models/test_model.dart';
import 'package:modern_classes_patna/features/tests/data/repositories/test_repository.dart';
import 'package:modern_classes_patna/features/tests/logic/test_provider.dart';
import 'package:modern_classes_patna/providers/theme_provider.dart';
import 'package:modern_classes_patna/screens/admin/admin_dashboard_screen.dart';
import 'package:modern_classes_patna/screens/teacher/create_test_screen.dart';
import 'package:modern_classes_patna/screens/teacher/mark_attendance_screen.dart';
import 'package:modern_classes_patna/screens/teacher/upload_lecture_screen.dart';
import 'package:modern_classes_patna/screens/teacher/upload_material_screen.dart';
import 'fake_course_repository.dart';
import 'schema_and_auth_test.dart';

class MockOverflowCourseRepository extends FakeCourseRepository {
  final List<CourseModel> mockCourses;
  final List<BatchModel> mockBatches;
  final double mockCollectionsTotal;

  MockOverflowCourseRepository({
    required this.mockCourses,
    required this.mockBatches,
    this.mockCollectionsTotal = 12456780.75,
  });

  @override
  Future<List<CourseModel>> getCourses() async => mockCourses;

  @override
  Future<List<BatchModel>> getBatches() async => mockBatches;

  @override
  Future<List<BatchModel>> adminGetAllBatches() async => mockBatches;

  @override
  Future<double?> getAdminManualCollectionsTotal() async =>
      mockCollectionsTotal;

  @override
  Future<List<Map<String, dynamic>>> getTeacherAssignments(
    String teacherId,
  ) async {
    return mockBatches
        .map((b) => {'batch_id': b.id, 'is_primary': true})
        .toList();
  }
}

class MockOverflowAuthRepository extends FakeAuthRepository {
  final List<UserModel> mockBatchStudents;

  MockOverflowAuthRepository({this.mockBatchStudents = const []});

  @override
  Future<List<UserModel>> getBatchStudents(String batchId) async =>
      mockBatchStudents;

  @override
  Future<List<UserModel>> getAllStudents() async => mockBatchStudents;
}

class MockOverflowAttendanceRepository implements AttendanceRepository {
  @override
  Future<List<AttendanceRecordModel>> getAttendanceRecords() async => [];

  @override
  Future<void> saveAttendanceRecords(
    List<AttendanceRecordModel> records,
  ) async {}
}

class MockOverflowTestRepository implements TestRepository {
  @override
  Future<List<TestModel>> getTests() async => [];

  @override
  Future<TestModel> getTestPaper(String testId) async => TestModel(
    id: testId,
    courseId: 'course-long-1',
    batchId: 'batch-long-1',
    title: 'Mock Test Paper',
    subject: 'General Studies',
    duration: const Duration(minutes: 30),
    totalMarks: 50.0,
    passingMarks: 20.0,
    totalQuestions: 1,
    questions: const [],
    scheduledDate: DateTime.now(),
  );

  @override
  Future<void> submitTestResult(TestResultModel result) async {}

  @override
  Future<void> createTest(TestModel test) async {}

  @override
  Future<void> deleteTest(String testId) async {}

  @override
  Future<List<TestResultModel>> getTestSubmissionsForTest(String testId) async => [];
}

class MockOverflowNotificationRepository implements NotificationRepository {
  @override
  Future<List<NotificationModel>> getNotifications() async => [];

  @override
  Future<void> broadcastAnnouncement(NotificationModel notification) async {}
}

class MockOverflowStudyMaterialRepository implements StudyMaterialRepository {
  @override
  Future<void> deleteMaterial(String materialId, {String? fileUrl}) async {}

  @override
  Future<List<StudyMaterialModel>> getMaterials() async => [];

  @override
  Future<StudyMaterialModel> uploadMaterial(
    StudyMaterialModel material,
  ) async => material;

  @override
  Future<String> uploadMaterialFile({
    required String courseId,
    required String fileName,
    required dynamic fileBytes,
  }) async => 'https://example.com/files/$fileName';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  final List<CourseModel> longCourses = [
    const CourseModel(
      id: 'course-long-1',
      title:
          'General Studies Paper I & Paper II Integrated Mains Comprehensive Program 2026-2027',
      description:
          'Complete syllabus coverage for BPSC 71st Combined Competitive Exam',
      price: 15999,
      originalPrice: 19999,
      category: 'General Studies',
      teacherId: 'tch_1',
      teacherName: 'Dr. Madhurendra Kumar',
      totalLessons: 120,
      totalHours: 240,
      totalTests: 45,
      totalNotes: 60,
      rating: 4.9,
      reviewsCount: 320,
      coverImageUrl: 'https://example.com/cover.png',
      highlights: ['Daily Answer Writing', 'Sectional Tests'],
    ),
  ];

  final List<BatchModel> longBatches = [
    BatchModel(
      id: 'batch-long-1',
      courseId: 'course-long-1',
      name:
          'BPSC 71st PT Intensive Foundation Batch - Evening Batch 2026-2027 Musallahpur Hat Campus',
      timing: '05:00 PM - 08:00 PM',
      batchPrice: 15999,
      teacherId: 'tch_1',
      teacherName: 'Dr. Madhurendra Kumar',
      totalStudents: 480,
      medium: 'Hindi & English',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 12, 31),
    ),
  ];

  final List<UserModel> mockStudents = [
    const UserModel(
      id: 'student-long-1',
      name: 'Dr. Harshavardhan Kumar Suryavanshi Sharma Patna',
      email: 'harshavardhan.suryavanshi.patna.academic@modernclassespatna.org',
      phone: '+91 9876543210',
      role: UserRole.student,
    ),
    const UserModel(
      id: 'student-long-2',
      name: 'Kumari Priyadarshini Madhurendra Vikramaditya',
      email: 'priyadarshini.vikramaditya.patna@modernclassespatna.org',
      phone: '+91 9123456780',
      role: UserRole.student,
    ),
  ];

  const testViewports = [
    {'name': '300px (Ultra-narrow)', 'width': 300.0, 'height': 750.0},
    {'name': '320px (Narrow Android phone)', 'width': 320.0, 'height': 800.0},
    {
      'name': '360px (Standard budget Android)',
      'width': 360.0,
      'height': 800.0,
    },
    {'name': '390px (Mid-tier mobile)', 'width': 390.0, 'height': 844.0},
    {'name': '412px (Large Android flagship)', 'width': 412.0, 'height': 915.0},
    {'name': '600px (Tablet portrait)', 'width': 600.0, 'height': 1024.0},
    {
      'name': '800px (Wider layout / tablet landscape)',
      'width': 800.0,
      'height': 1200.0,
    },
  ];

  group('Area 1 & 3: Select Target Batch dropdown in UploadLectureScreen', () {
    for (final vp in testViewports) {
      testWidgets('Renders without overflow on ${vp['name']}', (tester) async {
        tester.view.physicalSize = Size(
          vp['width'] as double,
          vp['height'] as double,
        );
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final courseRepo = MockOverflowCourseRepository(
          mockCourses: longCourses,
          mockBatches: longBatches,
        );
        final courseProvider = CourseProvider(repository: courseRepo);
        await courseProvider.fetchCatalog();

        final authRepo = MockOverflowAuthRepository();
        final authProvider = AuthProvider(repository: authRepo);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<CourseProvider>.value(
                value: courseProvider,
              ),
              ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
              ChangeNotifierProvider<ThemeProvider>(
                create: (_) => ThemeProvider(autoLoad: false),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.academicTheme,
              darkTheme: AppTheme.darkTheme,
              home: const UploadLectureScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.textContaining('Select Target Batch'), findsOneWidget);
      });
    }
  });

  group(
    'Area 2 & 3: Course field and Target Batch field in CreateTestScreen',
    () {
      for (final vp in testViewports) {
        testWidgets('Renders without overflow on ${vp['name']}', (
          tester,
        ) async {
          tester.view.physicalSize = Size(
            vp['width'] as double,
            vp['height'] as double,
          );
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final courseRepo = MockOverflowCourseRepository(
            mockCourses: longCourses,
            mockBatches: longBatches,
          );
          final courseProvider = CourseProvider(repository: courseRepo);
          await courseProvider.fetchCatalog();

          final authRepo = MockOverflowAuthRepository();
          final authProvider = AuthProvider(repository: authRepo);
          final testRepo = MockOverflowTestRepository();
          final testProvider = TestProvider(repository: testRepo);
          final notifRepo = MockOverflowNotificationRepository();
          final notifProvider = NotificationProvider(repository: notifRepo);

          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<CourseProvider>.value(
                  value: courseProvider,
                ),
                ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
                ChangeNotifierProvider<TestProvider>.value(value: testProvider),
                ChangeNotifierProvider<NotificationProvider>.value(
                  value: notifProvider,
                ),
                ChangeNotifierProvider<ThemeProvider>(
                  create: (_) => ThemeProvider(autoLoad: false),
                ),
              ],
              child: MaterialApp(
                theme: AppTheme.academicTheme,
                darkTheme: AppTheme.darkTheme,
                home: const CreateTestScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('Course'), findsOneWidget);
          expect(find.text('Target Batch'), findsOneWidget);
        });
      }
    },
  );

  group(
    'Area 2 & 3: Course field and Target Batch field in UploadMaterialScreen',
    () {
      for (final vp in testViewports) {
        testWidgets('Renders without overflow on ${vp['name']}', (
          tester,
        ) async {
          tester.view.physicalSize = Size(
            vp['width'] as double,
            vp['height'] as double,
          );
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final courseRepo = MockOverflowCourseRepository(
            mockCourses: longCourses,
            mockBatches: longBatches,
          );
          final courseProvider = CourseProvider(repository: courseRepo);
          await courseProvider.fetchCatalog();

          final materialRepo = MockOverflowStudyMaterialRepository();
          final materialProvider = StudyMaterialProvider(
            repository: materialRepo,
          );

          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<CourseProvider>.value(
                  value: courseProvider,
                ),
                ChangeNotifierProvider<StudyMaterialProvider>.value(
                  value: materialProvider,
                ),
                ChangeNotifierProvider<ThemeProvider>(
                  create: (_) => ThemeProvider(autoLoad: false),
                ),
              ],
              child: MaterialApp(
                theme: AppTheme.academicTheme,
                darkTheme: AppTheme.darkTheme,
                home: const UploadMaterialScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('Course'), findsOneWidget);
          expect(find.textContaining('Target Batch'), findsOneWidget);
        });
      }
    },
  );

  group(
    'Area 4 & 5: Manual Collections card and Enrolled Students card in AdminDashboardScreen',
    () {
      for (final vp in testViewports) {
        testWidgets(
          'Renders large numbers/currency without overflow on ${vp['name']}',
          (tester) async {
            tester.view.physicalSize = Size(
              vp['width'] as double,
              vp['height'] as double,
            );
            tester.view.devicePixelRatio = 1.0;
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });

            final courseRepo = MockOverflowCourseRepository(
              mockCourses: longCourses,
              mockBatches: longBatches,
              mockCollectionsTotal: 98765432.50,
            );
            final courseProvider = CourseProvider(repository: courseRepo);
            await courseProvider.fetchCatalog();
            await courseProvider.fetchAdminManualCollectionsTotal();

            final testRepo = MockOverflowTestRepository();
            final testProvider = TestProvider(repository: testRepo);
            final authRepo = MockOverflowAuthRepository();
            final authProvider = AuthProvider(repository: authRepo);

            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider<CourseProvider>.value(
                    value: courseProvider,
                  ),
                  ChangeNotifierProvider<TestProvider>.value(
                    value: testProvider,
                  ),
                  ChangeNotifierProvider<AuthProvider>.value(
                    value: authProvider,
                  ),
                  ChangeNotifierProvider<ThemeProvider>(
                    create: (_) => ThemeProvider(autoLoad: false),
                  ),
                ],
                child: MaterialApp(
                  theme: AppTheme.academicTheme,
                  darkTheme: AppTheme.darkTheme,
                  home: const AdminDashboardScreen(),
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
            expect(find.text('MANUAL COLLECTIONS'), findsOneWidget);
            expect(find.text('ENROLLED STUDENTS'), findsOneWidget);
          },
        );
      }
    },
  );

  group('Area 6: Students Roster card in MarkAttendanceScreen', () {
    for (final vp in testViewports) {
      testWidgets(
        'Renders student roster card without overflow on ${vp['name']}',
        (tester) async {
          FlutterError.onError = (FlutterErrorDetails details) {
            debugPrint('=== ATTENDANCE OVERFLOW DETAILS ===');
            debugPrint(details.toString());
          };
          tester.view.physicalSize = Size(
            vp['width'] as double,
            vp['height'] as double,
          );
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final courseRepo = MockOverflowCourseRepository(
            mockCourses: longCourses,
            mockBatches: longBatches,
          );
          final courseProvider = CourseProvider(repository: courseRepo);
          await courseProvider.fetchCatalog();
          await courseProvider.fetchMyTeacherAssignments('tch_1');

          final authRepo = MockOverflowAuthRepository(
            mockBatchStudents: mockStudents,
          );
          final authProvider = AuthProvider(repository: authRepo);

          final attendanceRepo = MockOverflowAttendanceRepository();
          final attendanceProvider = AttendanceProvider(
            repository: attendanceRepo,
          );

          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<CourseProvider>.value(
                  value: courseProvider,
                ),
                ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
                ChangeNotifierProvider<AttendanceProvider>.value(
                  value: attendanceProvider,
                ),
                ChangeNotifierProvider<ThemeProvider>(
                  create: (_) => ThemeProvider(autoLoad: false),
                ),
              ],
              child: MaterialApp(
                theme: AppTheme.academicTheme,
                darkTheme: AppTheme.darkTheme,
                home: const MarkAttendanceScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('Select Assigned Batch'), findsOneWidget);
        },
      );
    }
  });
}
