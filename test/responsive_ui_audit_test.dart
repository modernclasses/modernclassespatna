import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:modern_classes_patna/features/courses/data/models/batch_model.dart';
import 'package:modern_classes_patna/features/courses/data/models/course_model.dart';
import 'package:modern_classes_patna/features/courses/logic/course_provider.dart';
import 'package:modern_classes_patna/models/user_model.dart';
import 'package:modern_classes_patna/providers/auth_provider.dart';
import 'package:modern_classes_patna/screens/admin/course_creation_wizard_dialog.dart';
import 'package:modern_classes_patna/screens/admin/edit_course_screen.dart';
import 'package:modern_classes_patna/screens/admin/manage_students_screen.dart';
import 'package:modern_classes_patna/core/widgets/multi_teacher_selector.dart';

import 'fake_course_repository.dart';

class MockAuditAuthProvider extends ChangeNotifier implements AuthProvider {
  final List<UserModel> _profiles = [
    const UserModel(
      id: 'teacher-1',
      name: 'Dr. Anand Kumar (Physics HOD)',
      email: 'anand@modernclasses.com',
      phone: '9876543210',
      role: UserRole.teacher,
    ),
    const UserModel(
      id: 'teacher-2',
      name: 'Prof. R. K. Singh (Chemistry Faculty)',
      email: 'rksingh@modernclasses.com',
      phone: '9876543211',
      role: UserRole.teacher,
    ),
    const UserModel(
      id: 'student-1',
      name: 'Pooja Kumari',
      email: 'pooja@example.com',
      phone: '9123456780',
      role: UserRole.student,
      targetExam: 'BPSC 71st Civil Services',
    ),
    const UserModel(
      id: 'student-2',
      name: 'Rahul Kumar Sharma',
      email: 'rahul@example.com',
      phone: '9123456781',
      role: UserRole.student,
      targetExam: 'Bihar Daroga / SI',
    ),
  ];

  @override
  Future<List<UserModel>> getAllProfiles() async => _profiles;

  @override
  Future<List<UserModel>> getAllStudents() async =>
      _profiles.where((u) => u.role == UserRole.student).toList();

  @override
  UserModel get currentUser => const UserModel(
        id: 'admin-1',
        name: 'Admin User',
        email: 'admin@modernclasses.com',
        phone: '9876543200',
        role: UserRole.admin,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockAuditCourseRepository extends FakeCourseRepository {
  final List<CourseModel> courses = [];
  final List<BatchModel> batches = [];

  @override
  Future<List<CourseModel>> getCourses() async => List.from(courses);

  @override
  Future<List<BatchModel>> getBatches() async => List.from(batches);

  @override
  Future<List<BatchModel>> adminGetAllBatches() async => List.from(batches);

  @override
  Future<void> createCourse(
    CourseModel course, {
    List<BatchModel>? initialBatches,
    Map<int, List<String>>? batchTeacherIds,
  }) async {
    final generatedId = 'c-${courses.length + 1}';
    courses.add(course.copyWith(id: generatedId));
    if (initialBatches != null) {
      for (int i = 0; i < initialBatches.length; i++) {
        batches.add(initialBatches[i].copyWith(
          id: 'b-${batches.length + 1}',
          courseId: generatedId,
          teacherIds: batchTeacherIds?[i] ?? initialBatches[i].teacherIds,
        ));
      }
    }
  }

  @override
  Future<void> updateCourse(CourseModel course) async {
    final idx = courses.indexWhere((c) => c.id == course.id);
    if (idx != -1) courses[idx] = course;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuditAuthProvider mockAuth;
  late MockAuditCourseRepository mockRepo;
  late CourseProvider courseProvider;

  setUp(() {
    mockAuth = MockAuditAuthProvider();
    mockRepo = MockAuditCourseRepository();
    courseProvider = CourseProvider(repository: mockRepo);
  });

  Widget buildTestWidget({
    required Widget child,
    required Size screenSize,
    EdgeInsets viewInsets = EdgeInsets.zero,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
        ChangeNotifierProvider<CourseProvider>.value(value: courseProvider),
      ],
      child: MaterialApp(
        theme: ThemeData.light(),
        home: MediaQuery(
          data: MediaQueryData(
            size: screenSize,
            viewInsets: viewInsets,
          ),
          child: child,
        ),
      ),
    );
  }

  group('Area 1: MultiTeacherSelector Narrow Portrait Responsiveness', () {
    final narrowViewports = [
      const Size(300, 600), // Ultra-narrow split/small phone
      const Size(320, 640), // Narrow 320px
      const Size(360, 640), // Standard budget Android (6.3px overflow was reported here)
    ];

    for (final size in narrowViewports) {
      testWidgets('renders MultiTeacherSelector inside AlertDialog on ${size.width}x${size.height} without overflow',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final teachers = [
          const UserModel(
            id: 't-1',
            name: 'Dr. Anand Kumar (Physics HOD)',
            email: 'anand@test.com',
            phone: '1234',
            role: UserRole.teacher,
          ),
          const UserModel(
            id: 't-2',
            name: 'Prof. R. K. Singh',
            email: 'rk@test.com',
            phone: '5678',
            role: UserRole.teacher,
          ),
        ];

        List<String> selected = ['t-1'];

        await tester.pumpWidget(
          buildTestWidget(
            screenSize: size,
            child: Builder(
              builder: (ctx) => Scaffold(
                body: Center(
                  child: AlertDialog(
                    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    title: const Text("Edit Batch: Slot 1", overflow: TextOverflow.ellipsis),
                    content: MultiTeacherSelector(
                      allTeachers: teachers,
                      selectedTeacherIds: selected,
                      onChanged: (ids) => selected = ids,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // Faculty label and Edit Faculty button must be present
        expect(find.textContaining('Assigned Faculty (1)'), findsOneWidget);
        final editButtonText = size.width < 340 ? 'Edit' : 'Edit Faculty';
        expect(find.text(editButtonText), findsOneWidget);

        // Tap Edit Faculty to open modal
        await tester.tap(find.text(editButtonText));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Assign Faculty Members'), findsOneWidget);

        // Close modal
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      });
    }

    testWidgets('MultiTeacherSelector modal renders without overflow on 640x360 landscape', (tester) async {
      const landscapeSize = Size(640, 360);
      tester.view.physicalSize = landscapeSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final teachers = [
        const UserModel(id: 't-1', name: 'Dr. Anand Kumar', email: 'anand@test.com', phone: '1234', role: UserRole.teacher),
        const UserModel(id: 't-2', name: 'Prof. R. K. Singh', email: 'rk@test.com', phone: '5678', role: UserRole.teacher),
        const UserModel(id: 't-3', name: 'Er. S. N. Verma', email: 'sn@test.com', phone: '9012', role: UserRole.teacher),
      ];

      await tester.pumpWidget(
        buildTestWidget(
          screenSize: landscapeSize,
          child: Scaffold(
            body: Center(
              child: MultiTeacherSelector(
                allTeachers: teachers,
                selectedTeacherIds: const ['t-1'],
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Edit Faculty'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Assign Faculty Members'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
  });

  group('Area 2: CourseCreationWizardDialog Landscape and Keyboard Responsiveness', () {
    const landscapeSize = Size(640, 360);

    testWidgets('Step 1 renders cleanly on 640x360 landscape without overflow', (tester) async {
      tester.view.physicalSize = landscapeSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestWidget(
          screenSize: landscapeSize,
          child: const Scaffold(
            body: CourseCreationWizardDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Step 1: Basic Information'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('Step 1 handles on-screen keyboard (180px insets) in landscape without overflow', (tester) async {
      tester.view.physicalSize = landscapeSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestWidget(
          screenSize: landscapeSize,
          viewInsets: const EdgeInsets.only(bottom: 180), // Simulating open virtual keyboard
          child: const Scaffold(
            body: CourseCreationWizardDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Crucial verification: zero overflow when keyboard is open in landscape
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Step 1: Basic Information'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('Step 2 renders cleanly on 640x360 landscape and handles keyboard without overflow', (tester) async {
      tester.view.physicalSize = landscapeSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestWidget(
          screenSize: landscapeSize,
          child: const Scaffold(
            body: CourseCreationWizardDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter Step 1 info
      await tester.enterText(find.widgetWithText(TextField, 'Course Name *'), 'BPSC Target GS');
      await tester.pumpAndSettle();

      // Advance to Step 2
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Step 2: Course Setup & Timings'), findsOneWidget);
      expect(find.text('Course Pricing'), findsOneWidget);
      expect(find.text('Create Course'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);

      // Now simulate keyboard insets on Step 2
      await tester.pumpWidget(
        buildTestWidget(
          screenSize: landscapeSize,
          viewInsets: const EdgeInsets.only(bottom: 180),
          child: const Scaffold(
            body: CourseCreationWizardDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Data entered in Step 1 is preserved when navigating to Step 2 and back', (tester) async {
      tester.view.physicalSize = landscapeSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestWidget(
          screenSize: landscapeSize,
          child: const Scaffold(
            body: CourseCreationWizardDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter data in Step 1
      await tester.enterText(find.widgetWithText(TextField, 'Course Name *'), 'Physics Special 2026');
      await tester.enterText(find.widgetWithText(TextField, 'Category *'), 'UPSC & BPSC');
      await tester.enterText(find.widgetWithText(TextField, 'Detail / Highlights'), 'Daily Mock Tests\nLive Q&A');
      await tester.enterText(find.widgetWithText(TextField, 'Description'), 'Complete syllabus coverage in 90 days');
      await tester.pumpAndSettle();

      // Move to Step 2
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('Step 2: Course Setup & Timings'), findsOneWidget);

      // Go back to Step 1
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      // Verify all entered fields are perfectly preserved
      expect(find.text('Physics Special 2026'), findsOneWidget);
      expect(find.text('UPSC & BPSC'), findsOneWidget);
      expect(find.text('Daily Mock Tests\nLive Q&A'), findsOneWidget);
      expect(find.text('Complete syllabus coverage in 90 days'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CourseCreationWizardDialog renders without overflow on 300x600 ultra-narrow portrait', (tester) async {
      const narrowSize = Size(300, 600);
      tester.view.physicalSize = narrowSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestWidget(
          screenSize: narrowSize,
          child: const Scaffold(
            body: CourseCreationWizardDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });
  });

  group('Area 3: ManageStudentsScreen Landscape Usability', () {
    testWidgets('renders compact horizontal toolbar on 640x360 landscape', (tester) async {
      const landscapeSize = Size(640, 360);
      tester.view.physicalSize = landscapeSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestWidget(
          screenSize: landscapeSize,
          child: const ManageStudentsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Compact toolbar elements
      expect(find.textContaining('Students ('), findsOneWidget);
      expect(find.text('2 Active'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('renders stacked header on 360x640 portrait', (tester) async {
      const portraitSize = Size(360, 640);
      tester.view.physicalSize = portraitSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestWidget(
          screenSize: portraitSize,
          child: const ManageStudentsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Enrolled Students Directory ('), findsOneWidget);
    });

    testWidgets('renders without overflow on 300x600 ultra-narrow portrait', (tester) async {
      const narrowSize = Size(300, 600);
      tester.view.physicalSize = narrowSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestWidget(
          screenSize: narrowSize,
          child: const ManageStudentsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('Area 4: EditCourseScreen Responsive Layout', () {
    final testCourse = CourseModel(
      id: 'course-test-1',
      title: 'BPSC 71st Prelims GS Foundation',
      category: 'Civil Services',
      description: 'Comprehensive general studies foundation course for competitive aspirants.',
      coverImageUrl: '',
      price: 1999.0,
      originalPrice: 3999.0,
      teacherName: 'Dr. Anand Kumar',
      teacherId: 'teacher-1',
      totalLessons: 45,
      totalHours: 90,
      totalTests: 12,
      totalNotes: 30,
      highlights: const ['Live Interactive Classes', 'Digital Study Material', 'Weekly Test Series'],
      isFeatured: true,
      isCrashCourse: false,
    );

    testWidgets('renders EditCourseScreen without overflow on 640x360 landscape', (tester) async {
      const landscapeSize = Size(640, 360);
      tester.view.physicalSize = landscapeSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestWidget(
          screenSize: landscapeSize,
          child: EditCourseScreen(course: testCourse),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Save Course Changes'), findsOneWidget);
    });

    testWidgets('renders EditCourseScreen without overflow on 300x600 ultra-narrow portrait', (tester) async {
      const narrowSize = Size(300, 600);
      tester.view.physicalSize = narrowSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestWidget(
          screenSize: narrowSize,
          child: EditCourseScreen(course: testCourse),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Save Course Changes'), findsOneWidget);
    });
  });
}
