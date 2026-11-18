import 'package:modern_classes_patna/features/doubts/logic/doubt_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:modern_classes_patna/features/auth/data/models/user_model.dart';
import 'package:modern_classes_patna/features/auth/data/repositories/auth_repository.dart';
import 'package:modern_classes_patna/features/auth/logic/auth_provider.dart';
import 'package:modern_classes_patna/features/courses/data/models/batch_model.dart';
import 'package:modern_classes_patna/features/courses/data/models/course_model.dart';
import 'package:modern_classes_patna/features/courses/logic/course_provider.dart';
import 'package:modern_classes_patna/features/study_materials/data/models/study_material_model.dart';
import 'package:modern_classes_patna/features/study_materials/data/repositories/study_material_repository.dart';
import 'package:modern_classes_patna/features/study_materials/logic/study_material_provider.dart';
import 'package:modern_classes_patna/features/tests/data/models/test_model.dart';
import 'package:modern_classes_patna/features/tests/data/repositories/test_repository.dart';
import 'package:modern_classes_patna/features/tests/logic/test_provider.dart';
import 'package:modern_classes_patna/providers/organization_provider.dart';
import 'package:modern_classes_patna/providers/theme_provider.dart';
import 'package:modern_classes_patna/screens/admin/manage_courses_screen.dart';
import 'package:modern_classes_patna/screens/student/study_materials_screen.dart';
import 'package:modern_classes_patna/screens/student/tests_screen.dart';
import 'package:modern_classes_patna/screens/teacher/teacher_broadcast_prototype_screen.dart';
import 'package:modern_classes_patna/screens/teacher/teacher_dashboard_screen.dart';
import 'package:modern_classes_patna/screens/teacher/teacher_test_results_screen.dart';
import 'fake_course_repository.dart';

class MockFollowUpTestRepo implements TestRepository {
  List<TestModel> mockTests;
  List<TestResultModel> mockSubmissions;
  String? lastDeletedId;

  MockFollowUpTestRepo({
    required this.mockTests,
    this.mockSubmissions = const [],
  });

  @override
  Future<List<TestModel>> getTests() async => mockTests;

  @override
  Future<TestModel> getTestPaper(String testId) async =>
      mockTests.firstWhere((t) => t.id == testId);

  @override
  Future<void> submitTestResult(TestResultModel result) async {}

  @override
  Future<void> createTest(TestModel test) async {
    mockTests.insert(0, test);
  }

  @override
  Future<void> deleteTest(String testId) async {
    lastDeletedId = testId;
    mockTests.removeWhere((t) => t.id == testId);
  }

  @override
  Future<List<TestResultModel>> getTestSubmissionsForTest(String testId) async {
    return mockSubmissions.where((s) => s.testId == testId).toList();
  }
}

class MockFollowUpCourseRepo extends FakeCourseRepository {
  List<CourseModel> courses;
  List<BatchModel> batches;
  String? deletedCourseId;

  MockFollowUpCourseRepo({required this.courses, required this.batches});

  @override
  Future<List<CourseModel>> getCourses() async => courses;

  @override
  Future<List<BatchModel>> getBatches() async => batches;

  @override
  Future<void> deleteCourse(String courseId) async {
    deletedCourseId = courseId;
    courses.removeWhere((c) => c.id == courseId);
    batches.removeWhere((b) => b.courseId == courseId);
  }

  @override
  Future<void> deleteBatch(String batchId) async {
    batches.removeWhere((b) => b.id == batchId);
  }
}

class MockFollowUpMaterialRepo implements StudyMaterialRepository {
  List<StudyMaterialModel> materials;
  String? deletedMaterialId;

  MockFollowUpMaterialRepo({required this.materials});

  @override
  Future<List<StudyMaterialModel>> getMaterials() async => materials;

  @override
  Future<StudyMaterialModel> uploadMaterial(StudyMaterialModel m) async => m;

  @override
  Future<String> uploadMaterialFile({
    required String courseId,
    required String fileName,
    required dynamic fileBytes,
  }) async => 'path/$fileName';

  @override
  Future<void> deleteMaterial(String materialId, {String? fileUrl}) async {
    deletedMaterialId = materialId;
    materials.removeWhere((m) => m.id == materialId);
  }
}

class FakeTestAuthRepo implements AuthRepository {
  final UserModel? user;
  FakeTestAuthRepo({this.user});

  @override
  bool get isConnected => true;

  @override
  Future<UserModel?> getInitialSession() async => user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  final sampleTest = TestModel(
    id: 'test-101',
    courseId: 'crs-1',
    batchId: 'batch-1',
    title: 'BPSC Prelims Full Mock 1',
    subject: 'General Studies',
    duration: const Duration(minutes: 60),
    totalMarks: 100.0,
    passingMarks: 40.0,
    totalQuestions: 2,
    questions: const [
      QuestionModel(
        id: 'q1',
        type: QuestionType.singleChoice,
        text: 'Who was the founder of Nalanda University?',
        options: ['Kumaragupta I', 'Samudragupta', 'Chandragupta', 'Harsha'],
        correctOptionIndices: [0],
        marks: 50.0,
        explanation: 'Kumaragupta I of the Gupta dynasty founded Nalanda in the 5th century CE.',
      ),
      QuestionModel(
        id: 'q2',
        type: QuestionType.singleChoice,
        text: 'Champaran Satyagraha took place in which year?',
        options: ['1915', '1917', '1919', '1920'],
        correctOptionIndices: [1],
        marks: 50.0,
        explanation: 'Mahatma Gandhi led the Champaran Satyagraha in Bihar in 1917.',
      ),
    ],
    scheduledDate: DateTime.now(),
  );

  final sampleSubmissions = [
    TestResultModel(
      id: 'sub-1',
      testId: 'test-101',
      testTitle: 'BPSC Prelims Full Mock 1',
      studentId: 'stud-1',
      studentName: 'Aarav Kumar Patna',
      score: 100.0,
      maxScore: 100.0,
      percentage: 100.0,
      totalQuestions: 2,
      correctCount: 2,
      incorrectCount: 0,
      unattemptedCount: 0,
      totalTimeTaken: const Duration(minutes: 25),
      submittedAt: DateTime.now().subtract(const Duration(hours: 2)),
      responses: {},
    ),
    TestResultModel(
      id: 'sub-2',
      testId: 'test-101',
      testTitle: 'BPSC Prelims Full Mock 1',
      studentId: 'stud-2',
      studentName: 'Pooja Kumari Gaya',
      score: 0.0,
      maxScore: 100.0,
      percentage: 0.0,
      totalQuestions: 2,
      correctCount: 0,
      incorrectCount: 2,
      unattemptedCount: 0,
      totalTimeTaken: const Duration(minutes: 30),
      submittedAt: DateTime.now().subtract(const Duration(hours: 1)),
      responses: {},
    ),
  ];

  group('Requirement 1: Teacher Test Management & Individual Student Results', () {
    testWidgets('Teacher view hides Start Mock Test and shows View Student Results and Delete Test', (tester) async {
      final testRepo = MockFollowUpTestRepo(mockTests: [sampleTest]);
      final testProvider = TestProvider(repository: testRepo);
      final authRepo = FakeTestAuthRepo(
        user: const UserModel(
          id: 'tch_1',
          name: 'Faculty Modern Classes',
          email: 'teacher@modernclassespatna.org',
          phone: '+91 9999999999',
          role: UserRole.teacher,
        ),
      );
      final authProvider = AuthProvider(repository: authRepo);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: testProvider),
            ChangeNotifierProvider.value(value: authProvider),
            ChangeNotifierProvider(create: (_) => ThemeProvider(autoLoad: false)),
          ],
          child: const MaterialApp(home: TestsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Start Mock Test must NOT be shown to teachers
      expect(find.text('Start Mock Test'), findsNothing);
      expect(find.text('Retake'), findsNothing);

      // Teacher controls must be visible
      expect(find.text('View Student Results'), findsOneWidget);
      expect(find.byKey(const Key('delete_test_test-101')), findsOneWidget);

      // Tap Delete Test and verify confirmation dialog
      await tester.tap(find.byKey(const Key('delete_test_test-101')));
      await tester.pumpAndSettle();

      expect(find.text('Delete Test Paper?'), findsOneWidget);
      expect(find.text('Delete Test'), findsOneWidget);

      // Confirm deletion
      await tester.tap(find.text('Delete Test'));
      await tester.pumpAndSettle();

      expect(testRepo.lastDeletedId, equals('test-101'));
      expect(testProvider.tests, isEmpty);
    });

    testWidgets('Student view shows Start Mock Test and does not show Delete Test', (tester) async {
      final testRepo = MockFollowUpTestRepo(mockTests: [sampleTest]);
      final testProvider = TestProvider(repository: testRepo);
      final authRepo = FakeTestAuthRepo(
        user: const UserModel(
          id: 'std_1',
          name: 'Student Aspirant',
          email: 'student@modernclassespatna.org',
          phone: '+91 8888888888',
          role: UserRole.student,
        ),
      );
      final authProvider = AuthProvider(repository: authRepo);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: testProvider),
            ChangeNotifierProvider.value(value: authProvider),
            ChangeNotifierProvider(create: (_) => ThemeProvider(autoLoad: false)),
          ],
          child: const MaterialApp(home: TestsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Start Mock Test'), findsOneWidget);
      expect(find.text('View Student Results'), findsNothing);
      expect(find.byKey(const Key('delete_test_test-101')), findsNothing);
    });

    testWidgets('TeacherTestResultsScreen renders student scores, percentages, and filter chips', (tester) async {
      final testRepo = MockFollowUpTestRepo(
        mockTests: [sampleTest],
        mockSubmissions: sampleSubmissions,
      );
      final testProvider = TestProvider(repository: testRepo);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: testProvider),
            ChangeNotifierProvider(create: (_) => ThemeProvider(autoLoad: false)),
          ],
          child: MaterialApp(home: TeacherTestResultsScreen(test: sampleTest)),
        ),
      );
      await tester.pumpAndSettle();

      // Verify student names and evaluation badges
      expect(find.text('Aarav Kumar Patna'), findsOneWidget);
      expect(find.text('Pooja Kumari Gaya'), findsOneWidget);
      expect(find.text('PASSED'), findsOneWidget);
      expect(find.text('NEEDS PRACTICE'), findsOneWidget);

      // Verify Inspect Solutions buttons exist
      expect(find.text('Inspect Solutions'), findsNWidgets(2));
    });
  });

  group('Requirement 4: Course Deletion for Admins', () {
    testWidgets('Admin can delete course with confirmation dialog', (tester) async {
      final course = const CourseModel(
        id: 'crs-delete-1',
        title: 'BPSC History Optional 2026',
        description: 'Comprehensive History Optional',
        price: 4999,
        originalPrice: 7999,
        category: 'History',
        teacherId: 'tch_1',
        teacherName: 'Dr. Madhurendra Kumar',
        totalLessons: 40,
        totalHours: 80,
        totalTests: 10,
        totalNotes: 20,
        rating: 4.8,
        reviewsCount: 150,
        coverImageUrl: 'https://example.com/cover.png',
        highlights: [],
      );

      final courseRepo = MockFollowUpCourseRepo(courses: [course], batches: []);
      final courseProvider = CourseProvider(repository: courseRepo);
      await courseProvider.fetchCatalog();

      final authRepo = FakeTestAuthRepo(
        user: const UserModel(
          id: 'adm_1',
          name: 'Executive Admin',
          email: 'admin@modernclassespatna.org',
          phone: '+91 9999999990',
          role: UserRole.admin,
        ),
      );
      final authProvider = AuthProvider(repository: authRepo);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: courseProvider),
            ChangeNotifierProvider.value(value: authProvider),
            ChangeNotifierProvider(create: (_) => ThemeProvider(autoLoad: false)),
          ],
          child: const MaterialApp(home: ManageCoursesScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('BPSC History Optional 2026'), findsOneWidget);
      expect(find.byKey(const Key('delete_course_crs-delete-1')), findsOneWidget);

      // Tap delete
      await tester.tap(find.byKey(const Key('delete_course_crs-delete-1')));
      await tester.pumpAndSettle();

      expect(find.text('Delete Course?'), findsOneWidget);

      // Enter CONFIRM to enable delete button
      await tester.enterText(find.byType(TextField), 'CONFIRM');
      await tester.pumpAndSettle();

      // Confirm
      await tester.tap(find.text('Delete Course'));
      await tester.pumpAndSettle();

      expect(courseRepo.deletedCourseId, equals('crs-delete-1'));
      expect(courseProvider.courses, isEmpty);
    });
  });

  group('Requirement 5: Teacher Deletion of Uploaded Study Materials', () {
    testWidgets('Teacher sees delete action on study materials and can delete', (tester) async {
      final sampleMat = StudyMaterialModel(
        id: 'mat-delete-1',
        courseId: 'crs-1',
        batchId: 'batch-1',
        title: 'Modern Indian History Class Notes Vol 1',
        subject: 'History',
        chapter: '1857 Revolt',
        fileUrl: 'https://example.com/sample.pdf',
        fileSize: '4.2 MB',
        pageCount: 35,
        type: StudyDocType.pdf,
        previewPages: [],
        uploaderName: 'Dr. Madhurendra Kumar',
        uploadedAt: DateTime.now(),
      );

      final matRepo = MockFollowUpMaterialRepo(materials: [sampleMat]);
      final matProvider = StudyMaterialProvider(repository: matRepo);

      final authRepo = FakeTestAuthRepo(
        user: const UserModel(
          id: 'tch_1',
          name: 'Dr. Madhurendra Kumar',
          email: 'teacher@modernclassespatna.org',
          phone: '+91 9999999999',
          role: UserRole.teacher,
        ),
      );
      final authProvider = AuthProvider(repository: authRepo);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: matProvider),
            ChangeNotifierProvider.value(value: authProvider),
            ChangeNotifierProvider(create: (_) => ThemeProvider(autoLoad: false)),
          ],
          child: const MaterialApp(home: StudyMaterialsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Modern Indian History Class Notes Vol 1'), findsOneWidget);
      expect(find.byKey(const Key('delete_material_mat-delete-1')), findsOneWidget);

      // Tap delete
      await tester.tap(find.byKey(const Key('delete_material_mat-delete-1')));
      await tester.pumpAndSettle();

      expect(find.text('Delete Study Material?'), findsOneWidget);

      // Confirm
      await tester.tap(find.text('Delete Material'));
      await tester.pumpAndSettle();

      expect(matRepo.deletedMaterialId, equals('mat-delete-1'));
      expect(matProvider.materials, isEmpty);
    });
  });

  group('Requirement 2: Overflow Defects Verification', () {
    testWidgets('TeacherDashboardScreen Live Lecture Operations card renders on 320px phone without overflow', (tester) async {
      tester.view.physicalSize = const Size(320.0, 700.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final authRepo = FakeTestAuthRepo(
        user: const UserModel(
          id: 'tch_1',
          name: 'Dr. Madhurendra Kumar',
          email: 'teacher@modernclassespatna.org',
          phone: '+91 9999999999',
          role: UserRole.teacher,
        ),
      );
      final authProvider = AuthProvider(repository: authRepo);
      final courseRepo = MockFollowUpCourseRepo(courses: [], batches: []);
      final courseProvider = CourseProvider(repository: courseRepo);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authProvider),
            ChangeNotifierProvider.value(value: courseProvider),
            ChangeNotifierProvider(create: (_) => DoubtProvider()),
            ChangeNotifierProvider(create: (_) => OrganizationProvider()),
            ChangeNotifierProvider(create: (_) => ThemeProvider(autoLoad: false)),
          ],
          child: const MaterialApp(home: TeacherDashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Go Live & Broadcast Lecture'), findsOneWidget);
    });

    testWidgets('TeacherBroadcastPrototypeScreen renders in landscape 640x360 without 146px overflow', (tester) async {
      tester.view.physicalSize = const Size(640.0, 360.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final courseRepo = MockFollowUpCourseRepo(courses: [], batches: [
        BatchModel(
          id: 'b1',
          courseId: 'c1',
          name: 'BPSC 71st Intensive Batch',
          timing: '08:00 AM',
          batchPrice: 9999,
          teacherId: 't1',
          teacherName: 'Teacher',
          totalStudents: 100,
          medium: 'Hindi',
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 12, 31),
        )
      ]);
      final courseProvider = CourseProvider(repository: courseRepo);
      await courseProvider.fetchCatalog();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: courseProvider),
            ChangeNotifierProvider(create: (_) => ThemeProvider(autoLoad: false)),
          ],
          child: const MaterialApp(home: TeacherBroadcastPrototypeScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text('Live Broadcast Studio'), findsOneWidget);
      expect(find.byKey(const Key('broadcast_action_button')), findsOneWidget);
    });
  });
}
