import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:modern_classes_patna/features/courses/data/models/batch_model.dart';
import 'package:modern_classes_patna/features/courses/data/models/course_model.dart';
import 'package:modern_classes_patna/features/courses/logic/course_provider.dart';
import 'package:modern_classes_patna/features/tests/data/models/test_model.dart';
import 'package:modern_classes_patna/models/user_model.dart';
import 'package:modern_classes_patna/providers/auth_provider.dart';
import 'package:modern_classes_patna/screens/student/ask_doubt_dialog.dart';
import 'package:modern_classes_patna/screens/student/test_result_screen.dart';
import 'package:modern_classes_patna/screens/admin/manage_courses_screen.dart';
import 'fake_course_repository.dart';

class MockAuthProviderForTest extends ChangeNotifier implements AuthProvider {
  final UserModel _currentUser;
  MockAuthProviderForTest(this._currentUser);

  @override
  UserModel get currentUser => _currentUser;

  @override
  bool get isAuthenticated => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class CustomFakeCourseRepo extends FakeCourseRepository {
  final List<CourseModel> customCourses;
  final List<BatchModel> customBatches;
  final List<String> enrolledBatchIds;
  final List<String> enrolledCourseIds;

  CustomFakeCourseRepo({
    required this.customCourses,
    required this.customBatches,
    required this.enrolledBatchIds,
    required this.enrolledCourseIds,
  });

  @override
  Future<List<CourseModel>> getCourses() async => customCourses;

  @override
  Future<List<BatchModel>> getBatches() async => customBatches;

  @override
  Future<Map<String, List<String>>> getMyEnrollments() async => {
    'courseIds': enrolledCourseIds,
    'batchIds': enrolledBatchIds,
  };

  @override
  Future<void> updateCourse(CourseModel course) async {
    final idx = customCourses.indexWhere((c) => c.id == course.id);
    if (idx != -1) {
      customCourses[idx] = course;
    }
  }
}

void main() {
  group('1. CourseModel Subjects and Curriculum Auto-Stats', () {
    test('CourseModel correctly serializes and deserializes subjects and dynamic stats', () {
      final map = {
        'id': 'c101',
        'title': 'BPSC Prelims 72nd Crash Course',
        'category': 'BPSC',
        'description': 'Target course for BPSC aspirants',
        'cover_image_url': 'https://example.com/cover.png',
        'price': 1499.0,
        'original_price': 2999.0,
        'teacher_name': 'Madhurendra Sir',
        'teacher_id': 't1',
        'total_lessons': 10,
        'total_hours': 20,
        'live_total_lessons': 18,
        'live_total_hours': 35,
        'live_total_tests': 14,
        'total_tests': 5,
        'total_notes': 12,
        'highlights': ['Live Classes', 'PDF Notes'],
        'subjects': ['Bihar History', 'General Science', 'Polity', 'Geography'],
        'is_featured': true,
        'is_crash_course': true,
      };

      final course = CourseModel.fromMap(map);

      // Verify live stats override static counts
      expect(course.totalLessons, 18);
      expect(course.totalHours, 35);
      expect(course.totalTests, 14);
      expect(course.subjects, ['Bihar History', 'General Science', 'Polity', 'Geography']);

      final serialized = course.toMap();
      expect(serialized['subjects'], ['Bihar History', 'General Science', 'Polity', 'Geography']);
      expect(serialized['total_lessons'], 18);
      expect(serialized['total_hours'], 35);
    });

    test('CourseModel copyWith supports modifying subjects', () {
      const course = CourseModel(
        id: 'c1',
        title: 'Title',
        category: 'UPSC',
        description: 'Desc',
        coverImageUrl: 'url',
        price: 500,
        originalPrice: 1000,
        teacherName: 'Faculty',
        teacherId: 't1',
        totalLessons: 0,
        totalHours: 0,
        totalTests: 0,
        totalNotes: 0,
        highlights: [],
        subjects: ['Economy'],
      );

      final updated = course.copyWith(
        subjects: ['Economy', 'International Relations', 'Ethics'],
      );

      expect(updated.subjects.length, 3);
      expect(updated.subjects.contains('Ethics'), isTrue);
    });
  });

  group('2. Test Solutions Review - Hide Retake Test for Teachers', () {
    final sampleTest = TestModel(
      id: 'test_01',
      courseId: 'course_01',
      batchId: 'batch_01',
      title: 'BPSC Prelims Mock 1',
      subject: 'History',
      totalMarks: 100,
      passingMarks: 40,
      totalQuestions: 1,
      duration: const Duration(minutes: 60),
      scheduledDate: DateTime.now(),
      allowsRetake: true,
      questions: const [
        QuestionModel(
          id: 'q1',
          text: 'Who founded Patna?',
          type: QuestionType.singleChoice,
          options: ['Ajatashatru', 'Ashoka', 'Bimbisara', 'Chandragupta'],
          correctOptionIndices: [0],
          explanation: 'Ajatashatru founded Pataliputra.',
          marks: 2.0,
        ),
      ],
    );

    final sampleResult = TestResultModel(
      id: 'res_01',
      testId: 'test_01',
      testTitle: 'BPSC Prelims Mock 1',
      studentId: 'student_123',
      studentName: 'Aman Kumar',
      score: 80,
      maxScore: 100,
      percentage: 80.0,
      totalQuestions: 1,
      correctCount: 1,
      incorrectCount: 0,
      unattemptedCount: 0,
      totalTimeTaken: const Duration(minutes: 10),
      submittedAt: DateTime.now(),
      responses: {
        'q1': const UserQuestionResponse(
          questionId: 'q1',
          selectedOptionIndices: [0],
        ),
      },
    );

    testWidgets('TestResultScreen DOES show Retake Test button for students when test.allowsRetake is true', (tester) async {
      final studentUser = UserModel(
        id: 'student_123',
        name: 'Aman Kumar',
        email: 'aman@example.com',
        phone: '9876543210',
        role: UserRole.student,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(
              create: (_) => MockAuthProviderForTest(studentUser),
            ),
          ],
          child: MaterialApp(
            home: TestResultScreen(
              result: sampleResult,
              test: sampleTest,
              isTeacherView: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Retake Test'), findsOneWidget);
    });

    testWidgets('TestResultScreen DOES NOT show Retake Test button when isTeacherView is true', (tester) async {
      final teacherUser = UserModel(
        id: 'teacher_456',
        name: 'Madhurendra Sir',
        email: 'teacher@example.com',
        phone: '9876543210',
        role: UserRole.teacher,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(
              create: (_) => MockAuthProviderForTest(teacherUser),
            ),
          ],
          child: MaterialApp(
            home: TestResultScreen(
              result: sampleResult,
              test: sampleTest,
              isTeacherView: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Retake Test'), findsNothing);
    });

    testWidgets('TestResultScreen DOES NOT show Retake Test button for teachers even if isTeacherView is false', (tester) async {
      final teacherUser = UserModel(
        id: 'teacher_456',
        name: 'Madhurendra Sir',
        email: 'teacher@example.com',
        phone: '9876543210',
        role: UserRole.teacher,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(
              create: (_) => MockAuthProviderForTest(teacherUser),
            ),
          ],
          child: MaterialApp(
            home: TestResultScreen(
              result: sampleResult,
              test: sampleTest,
              isTeacherView: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Retake Test'), findsNothing);
    });
  });

  group('3. Ask Doubt Dialog Dynamic Course Subjects', () {
    testWidgets('AskDoubtDialog populates subjects from the selected batch course', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final studentUser = UserModel(
        id: 'student_123',
        name: 'Student One',
        email: 'student@example.com',
        phone: '9876543210',
        role: UserRole.student,
      );

      const courseWithCustomSubjects = CourseModel(
        id: 'course_bpsc',
        title: 'BPSC 72nd Foundation Course',
        category: 'BPSC',
        description: 'Desc',
        coverImageUrl: 'url',
        price: 1999,
        originalPrice: 3999,
        teacherName: 'Madhurendra Sir',
        teacherId: 't1',
        totalLessons: 25,
        totalHours: 50,
        totalTests: 10,
        totalNotes: 20,
        highlights: [],
        subjects: ['Ancient History', 'Bihar Polity', 'General Geography'],
      );

      final batch = BatchModel(
        id: 'batch_bpsc_01',
        courseId: 'course_bpsc',
        name: 'BPSC Morning Batch',
        timing: '08:00 AM - 10:00 AM',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 90)),
        teacherName: 'Madhurendra Sir',
        teacherId: 't1',
        totalStudents: 10,
        batchPrice: 1999,
        medium: 'Hindi',
      );

      final customRepo = CustomFakeCourseRepo(
        customCourses: [courseWithCustomSubjects],
        customBatches: [batch],
        enrolledCourseIds: ['course_bpsc'],
        enrolledBatchIds: ['batch_bpsc_01'],
      );

      final courseProvider = CourseProvider(repository: customRepo);
      await courseProvider.fetchCatalog();
      await courseProvider.fetchMyEnrollments();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(
              create: (_) => MockAuthProviderForTest(studentUser),
            ),
            ChangeNotifierProvider<CourseProvider>.value(
              value: courseProvider,
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AskDoubtDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify that the dropdown displays the course's actual subject rather than hardcoded mock
      expect(find.text('Ancient History'), findsOneWidget);
      expect(find.text('Bihar History'), findsNothing);
    });
  });

  group('4. Admin Course Subjects Management', () {
    testWidgets('ManageCoursesScreen displays subjects and opens subjects editor', (tester) async {
      final adminUser = UserModel(
        id: 'admin_1',
        email: 'admin@modernclasses.com',
        phone: '9999999999',
        name: 'Admin Sir',
        role: UserRole.admin,
      );

      final course = CourseModel(
        id: 'course_1',
        title: 'BPSC Prelims Foundation',
        category: 'BPSC',
        description: 'Foundation course',
        coverImageUrl: '',
        price: 999,
        originalPrice: 1999,
        teacherName: 'Admin',
        teacherId: 'admin_1',
        totalLessons: 10,
        totalHours: 20,
        totalTests: 5,
        totalNotes: 5,
        rating: 4.8,
        reviewsCount: 10,
        highlights: const ['Live Classes'],
        subjects: const ['History', 'Polity'],
        isFeatured: false,
        isCrashCourse: false,
      );

      final batch = BatchModel(
        id: 'batch_1',
        courseId: 'course_1',
        name: 'Morning Batch',
        timing: '08:00 AM - 10:00 AM (Mon-Sat)',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 90)),
        teacherName: 'Admin',
        teacherId: 'admin_1',
        totalStudents: 5,
        batchPrice: 999,
        medium: 'Bilingual',
      );

      final customRepo = CustomFakeCourseRepo(
        customCourses: [course],
        customBatches: [batch],
        enrolledCourseIds: [],
        enrolledBatchIds: [],
      );

      final courseProvider = CourseProvider(repository: customRepo);
      await courseProvider.fetchCatalog();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(
              create: (_) => MockAuthProviderForTest(adminUser),
            ),
            ChangeNotifierProvider<CourseProvider>.value(
              value: courseProvider,
            ),
          ],
          child: const MaterialApp(
            home: ManageCoursesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify subjects are displayed on course card
      expect(find.text('Subjects (2):'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Polity'), findsOneWidget);
      expect(find.byKey(const Key('edit_subjects_course_1')), findsOneWidget);

      // 2. Tap Edit Subjects button
      await tester.tap(find.byKey(const Key('edit_subjects_course_1')));
      await tester.pumpAndSettle();

      // 3. Verify Edit Subjects dialog opens
      expect(find.text('Course Subjects'), findsOneWidget);
      expect(find.text('Current Subjects (2):'), findsOneWidget);
      expect(find.text('Save Subjects'), findsOneWidget);

      // 4. Tap preset 'Geography' chip to add
      final geoChip = find.widgetWithText(ActionChip, 'Geography');
      expect(geoChip, findsOneWidget);
      await tester.tap(geoChip);
      await tester.pumpAndSettle();

      // Verify 'Geography' is now in current subjects
      expect(find.text('Current Subjects (3):'), findsOneWidget);

      // 5. Tap 'Save Subjects'
      await tester.tap(find.text('Save Subjects'));
      await tester.pumpAndSettle();

      // Verify dialog is dismissed and course card displays updated subjects
      expect(find.text('Subjects (3):'), findsOneWidget);
      expect(find.text('Geography'), findsOneWidget);
    });
  });
}
