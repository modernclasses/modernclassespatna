import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:modern_classes_patna/core/widgets/app_scaffold.dart';
import 'package:modern_classes_patna/features/auth/data/models/user_model.dart';
import 'package:modern_classes_patna/features/auth/data/repositories/auth_repository.dart';
import 'package:modern_classes_patna/features/auth/logic/auth_provider.dart';
import 'package:modern_classes_patna/features/courses/data/models/batch_model.dart';
import 'package:modern_classes_patna/features/courses/data/models/course_model.dart';
import 'package:modern_classes_patna/features/courses/logic/course_provider.dart';
import 'package:modern_classes_patna/features/doubts/logic/doubt_provider.dart';
import 'package:modern_classes_patna/features/notifications/logic/notification_provider.dart';
import 'package:modern_classes_patna/features/study_materials/data/models/study_material_model.dart';
import 'package:modern_classes_patna/features/study_materials/data/repositories/study_material_repository.dart';
import 'package:modern_classes_patna/features/study_materials/logic/study_material_provider.dart';
import 'package:modern_classes_patna/features/tests/data/models/test_model.dart';
import 'package:modern_classes_patna/features/tests/data/repositories/test_repository.dart';
import 'package:modern_classes_patna/features/tests/logic/test_provider.dart';
import 'package:modern_classes_patna/providers/organization_provider.dart';
import 'package:modern_classes_patna/providers/theme_provider.dart';
import 'package:modern_classes_patna/screens/teacher/teacher_broadcast_prototype_screen.dart';
import 'package:modern_classes_patna/screens/teacher/teacher_dashboard_screen.dart';
import 'fake_course_repository.dart';

class InMemoryAuditTestRepo implements TestRepository {
  final Map<String, TestModel> tests = {};
  final List<TestResultModel> submissions = [];

  InMemoryAuditTestRepo({List<TestModel>? initialTests}) {
    if (initialTests != null) {
      for (final t in initialTests) {
        tests[t.id] = t;
      }
    }
  }

  @override
  Future<List<TestModel>> getTests() async => tests.values.toList();

  @override
  Future<TestModel> getTestPaper(String testId) async {
    final t = tests[testId];
    if (t == null) throw Exception('Test not found: $testId');
    return t;
  }

  @override
  Future<void> createTest(TestModel test) async {
    tests[test.id] = test;
  }

  @override
  Future<void> submitTestResult(TestResultModel result) async {
    submissions.removeWhere((s) => s.testId == result.testId && s.studentId == result.studentId);
    submissions.add(result);
  }

  @override
  Future<void> deleteTest(String testId) async {
    tests.remove(testId);
    submissions.removeWhere((s) => s.testId == testId);
  }

  @override
  Future<List<TestResultModel>> getTestSubmissionsForTest(String testId) async {
    return submissions.where((s) => s.testId == testId).toList();
  }
}

class InMemoryAuditCourseRepo extends FakeCourseRepository {
  List<CourseModel> courses;
  List<BatchModel> batches;

  InMemoryAuditCourseRepo({required this.courses, required this.batches});

  @override
  Future<List<CourseModel>> getCourses() async => List.from(courses);

  @override
  Future<List<BatchModel>> getBatches() async => List.from(batches);

  @override
  Future<void> deleteCourse(String courseId) async {
    courses.removeWhere((c) => c.id == courseId);
    batches.removeWhere((b) => b.courseId == courseId);
  }

  @override
  Future<void> deleteBatch(String batchId) async {
    batches.removeWhere((b) => b.id == batchId);
  }

  @override
  Future<void> deleteLesson(String lessonId, {String? videoPath, String? thumbnailPath}) async {}
}

class InMemoryAuditMaterialRepo implements StudyMaterialRepository {
  List<StudyMaterialModel> materials;

  InMemoryAuditMaterialRepo({required this.materials});

  @override
  Future<List<StudyMaterialModel>> getMaterials() async => List.from(materials);

  @override
  Future<StudyMaterialModel> uploadMaterial(StudyMaterialModel m) async {
    materials.add(m);
    return m;
  }

  @override
  Future<String> uploadMaterialFile({
    required String courseId,
    required String fileName,
    required dynamic fileBytes,
  }) async => 'materials/$fileName';

  @override
  Future<void> deleteMaterial(String materialId, {String? fileUrl}) async {
    materials.removeWhere((m) => m.id == materialId);
  }
}

class SimpleFakeAuthRepo implements AuthRepository {
  final UserModel? user;
  SimpleFakeAuthRepo({this.user});

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

  final sampleBatch = BatchModel(
    id: 'batch-target-1',
    courseId: 'course-1',
    name: 'BPSC 71st GS Comprehensive Foundation Batch',
    timing: '08:00 AM - 10:30 AM',
    batchPrice: 4999,
    teacherId: 'tch_1',
    teacherName: 'Dr. Madhurendra Kumar',
    totalStudents: 120,
    medium: 'Hindi',
    startDate: DateTime(2026, 1, 1),
    endDate: DateTime(2026, 12, 31),
  );

  const sampleCourse = CourseModel(
    id: 'course-1',
    title: 'General Studies Prelims Masterclass',
    description: 'Comprehensive GS Foundation for BPSC',
    category: 'BPSC',
    coverImageUrl: 'https://example.com/cover.jpg',
    price: 4999,
    originalPrice: 7999,
    teacherName: 'Dr. Madhurendra Kumar',
    teacherId: 'tch_1',
    totalLessons: 80,
    totalHours: 120,
    totalTests: 15,
    totalNotes: 30,
    highlights: ['Live Classes', 'Full Mock Tests'],
    isFeatured: true,
  );

  group('Requirement 1: Verify the two exact overflow defects across multiple screen dimensions', () {
    final dashboardViewports = [
      {'name': '300x600 Ultra Narrow', 'width': 300.0, 'height': 600.0},
      {'name': '320x480 Small Android', 'width': 320.0, 'height': 480.0},
      {'name': '320x640 Narrow Phone', 'width': 320.0, 'height': 640.0},
      {'name': '320x700 Tall Narrow', 'width': 320.0, 'height': 700.0},
      {'name': '360x640 Budget Android', 'width': 360.0, 'height': 640.0},
      {'name': '412x915 Flagship Android', 'width': 412.0, 'height': 915.0},
    ];

    for (final vp in dashboardViewports) {
      testWidgets('TeacherDashboardScreen Academic Operations card renders without overflow on ${vp['name']}', (tester) async {
        tester.view.physicalSize = Size(vp['width'] as double, vp['height'] as double);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final authRepo = SimpleFakeAuthRepo(
          user: const UserModel(
            id: 'tch_1',
            name: 'Dr. Madhurendra Kumar',
            email: 'teacher@modernclassespatna.org',
            phone: '+91 9999999999',
            role: UserRole.teacher,
          ),
        );
        final authProvider = AuthProvider(repository: authRepo);
        final courseRepo = InMemoryAuditCourseRepo(courses: [sampleCourse], batches: [sampleBatch]);
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

        expect(tester.takeException(), isNull, reason: 'Layout must not throw overflow exception on ${vp['name']}');
        expect(find.text('Academic Operations'), findsOneWidget);
        expect(find.text('Go Live & Broadcast Lecture'), findsOneWidget);
        expect(find.text('Student Doubts Desk'), findsOneWidget);
        expect(find.text('Upload Lecture Video'), findsOneWidget);
      });
    }

    final broadcastViewports = [
      {'name': '640x360 Landscape (Target Batch / Console)', 'width': 640.0, 'height': 360.0},
      {'name': '720x360 Landscape Wide', 'width': 720.0, 'height': 360.0},
      {'name': '800x480 Landscape Tablet/Phone', 'width': 800.0, 'height': 480.0},
      {'name': '320x640 Portrait Narrow', 'width': 320.0, 'height': 640.0},
      {'name': '360x640 Portrait Budget', 'width': 360.0, 'height': 640.0},
    ];

    for (final vp in broadcastViewports) {
      testWidgets('TeacherBroadcastPrototypeScreen renders without overflow on ${vp['name']}', (tester) async {
        tester.view.physicalSize = Size(vp['width'] as double, vp['height'] as double);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final courseRepo = InMemoryAuditCourseRepo(courses: [sampleCourse], batches: [sampleBatch]);
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

        expect(tester.takeException(), isNull, reason: 'No RenderFlex overflow allowed on ${vp['name']}');
        expect(find.text('Live Broadcast Studio'), findsOneWidget);
        expect(find.byKey(const Key('broadcast_action_button')), findsOneWidget);
      });
    }
  });

  group('Requirement 2: Verify Test Management & Student Result Persistence', () {
    test('Student attempt submission persists and teacher retrieves exact score and answers', () async {
      final repo = InMemoryAuditTestRepo(
        initialTests: [
          TestModel(
            id: 'test-202',
            courseId: 'course-1',
            batchId: 'batch-target-1',
            title: 'Ancient Bihar History Mock 1',
            subject: 'History',
            duration: const Duration(minutes: 45),
            totalMarks: 50.0,
            passingMarks: 20.0,
            totalQuestions: 2,
            scheduledDate: DateTime(2026, 1, 1),
            questions: const [
              QuestionModel(
                id: 'q1',
                text: 'Where was Lord Buddha enlightened?',
                type: QuestionType.singleChoice,
                options: ['Bodh Gaya', 'Sarnath', 'Kushinagar', 'Rajgir'],
                correctOptionIndices: [0],
                marks: 25.0,
                explanation: 'Gautam Buddha attained enlightenment under the Bodhi Tree in Bodh Gaya.',
              ),
              QuestionModel(
                id: 'q2',
                text: 'Who was the founder of Magadha Empire?',
                type: QuestionType.singleChoice,
                options: ['Bimbisara', 'Ajatashatru', 'Chandragupta', 'Ashoka'],
                correctOptionIndices: [0],
                marks: 25.0,
                explanation: 'Bimbisara established the Haryanka dynasty and expanded Magadha.',
              ),
            ],
          ),
        ],
      );

      final provider = TestProvider(repository: repo);

      // Verify initial test list
      await provider.fetchTests();
      expect(provider.tests.length, 1);
      expect(provider.tests.first.id, 'test-202');

      // Student submits attempt: q1 correct (0), q2 correct (0) -> 50/50 marks (100%)
      final studentSubmission = TestResultModel(
        id: 'sub-202-stud1',
        testId: 'test-202',
        testTitle: 'Ancient Bihar History Mock 1',
        studentId: 'student_vikas_patna',
        studentName: 'Vikas Kumar (Patna)',
        score: 50.0,
        maxScore: 50.0,
        percentage: 100.0,
        totalQuestions: 2,
        correctCount: 2,
        incorrectCount: 0,
        unattemptedCount: 0,
        totalTimeTaken: const Duration(minutes: 18),
        submittedAt: DateTime.now(),
        responses: {
          'q1': const UserQuestionResponse(questionId: 'q1', selectedOptionIndices: [0]),
          'q2': const UserQuestionResponse(questionId: 'q2', selectedOptionIndices: [0]),
        },
      );

      await repo.submitTestResult(studentSubmission);

      // Teacher retrieves results for this test
      final teacherResults = await provider.getTestSubmissionsForTest('test-202');
      expect(teacherResults.length, 1);
      final retrieved = teacherResults.first;
      expect(retrieved.studentId, 'student_vikas_patna');
      expect(retrieved.studentName, 'Vikas Kumar (Patna)');
      expect(retrieved.score, 50.0);
      expect(retrieved.maxScore, 50.0);
      expect(retrieved.percentage, 100.0);
      expect(retrieved.responses['q1']?.selectedOptionIndices, [0]);
      expect(retrieved.responses['q2']?.selectedOptionIndices, [0]);

      // Teacher deletes the test
      await provider.deleteTest('test-202');

      // Verify test and submissions are cascaded and removed
      expect(provider.tests.any((t) => t.id == 'test-202'), isFalse);
      final remainingSubmissions = await provider.getTestSubmissionsForTest('test-202');
      expect(remainingSubmissions, isEmpty);
    });
  });

  group('Requirement 3: Audit Deletion Paths and Refetch Persistence', () {
    test('Admin course deletion removes course and stays deleted after refetch', () async {
      final repo = InMemoryAuditCourseRepo(
        courses: [sampleCourse],
        batches: [sampleBatch],
      );
      final provider = CourseProvider(repository: repo);
      await provider.fetchCatalog();
      expect(provider.courses.length, 1);

      // Admin deletes course
      await provider.deleteCourse('course-1');
      expect(provider.courses.isEmpty, isTrue);

      // Refetch from backend simulates app restart / refresh
      await provider.fetchCatalog();
      expect(provider.courses.isEmpty, isTrue);
      expect(provider.batches.isEmpty, isTrue);
    });

    test('Teacher study material deletion removes material and stays deleted after refetch', () async {
      final sampleMaterial = StudyMaterialModel(
        id: 'mat-1',
        courseId: 'course-1',
        batchId: 'batch-target-1',
        title: 'BPSC GS Paper 1 Mains Notes',
        subject: 'General Studies',
        chapter: 'Modern Bihar History',
        type: StudyDocType.pdf,
        pageCount: 45,
        fileSize: '2.4 MB',
        fileUrl: 'materials/bpsc_mains_notes.pdf',
        previewPages: ['Page 1 preview', 'Page 2 preview'],
        uploadedAt: DateTime.now(),
        uploaderName: 'Dr. Madhurendra Kumar',
      );

      final repo = InMemoryAuditMaterialRepo(materials: [sampleMaterial]);
      final provider = StudyMaterialProvider(repository: repo);
      await provider.fetchMaterials();
      expect(provider.materials.length, 1);

      // Teacher deletes material
      await provider.deleteMaterial('mat-1', fileUrl: sampleMaterial.fileUrl);
      expect(provider.materials.isEmpty, isTrue);

      // Refetch
      await provider.fetchMaterials();
      expect(provider.materials.isEmpty, isTrue);
    });
  });

  group('Requirement 5: Synchronized Top and Bottom Navigation Bars', () {
    testWidgets('Bars smoothly hide on scroll down, reappear on scroll up, and reset on tab switch', (tester) async {
      final authRepo = SimpleFakeAuthRepo(
        user: const UserModel(
          id: 'stud_1',
          name: 'Student Patna',
          email: 'student@example.com',
          phone: '+91 9999999999',
          role: UserRole.student,
        ),
      );
      final authProvider = AuthProvider(repository: authRepo);
      final notifProvider = NotificationProvider();

      Widget buildApp({required int tabIndex}) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authProvider),
            ChangeNotifierProvider.value(value: notifProvider),
            ChangeNotifierProvider(create: (_) => ThemeProvider(autoLoad: false)),
          ],
          child: MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                return ModernAppScaffold(
                  title: 'Modern Classes Patna',
                  selectedNavIndex: tabIndex,
                  onNavIndexChanged: (_) {},
                  bottomNavigationBar: NavigationBar(
                    selectedIndex: tabIndex,
                    destinations: const [
                      NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
                      NavigationDestination(icon: Icon(Icons.school), label: 'Courses'),
                    ],
                  ),
                  body: ListView.builder(
                    itemCount: 60,
                    itemBuilder: (ctx, idx) => ListTile(
                      title: Text('Syllabus Topic Module #$idx'),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }

      await tester.pumpWidget(buildApp(tabIndex: 0));
      await tester.pumpAndSettle();

      final titleFinder = find.text('Modern Classes Patna');
      expect(titleFinder, findsOneWidget);
      final initialTitleOffset = tester.getTopLeft(titleFinder);

      // 1. Scroll DOWN (finger drags up, negative dy)
      await tester.drag(find.byType(Scrollable), const Offset(0, -400));
      await tester.pumpAndSettle();

      // Top bar title moved up or faded away
      final postScrollOffset = tester.getTopLeft(titleFinder);
      expect(postScrollOffset.dy, lessThan(initialTitleOffset.dy));

      // 2. Scroll UP (finger drags down, positive dy)
      await tester.drag(find.byType(Scrollable), const Offset(0, 400));
      await tester.pumpAndSettle();

      // Top bar restored to initial position
      final restoredOffset = tester.getTopLeft(titleFinder);
      expect(restoredOffset.dy, equals(initialTitleOffset.dy));

      // 3. Scroll down again to hide
      await tester.drag(find.byType(Scrollable), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(titleFinder).dy, lessThan(initialTitleOffset.dy));

      // 4. Switch tab -> bars must immediately reappear
      await tester.pumpWidget(buildApp(tabIndex: 1));
      await tester.pumpAndSettle();

      final tabSwitchTitleOffset = tester.getTopLeft(titleFinder);
      expect(tabSwitchTitleOffset.dy, equals(initialTitleOffset.dy));
      expect(tester.takeException(), isNull);
    });
  });
}
