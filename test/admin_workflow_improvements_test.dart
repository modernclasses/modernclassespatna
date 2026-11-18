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
import 'package:modern_classes_patna/screens/admin/manage_courses_screen.dart';
import 'package:modern_classes_patna/core/widgets/multi_teacher_selector.dart';

import 'fake_course_repository.dart';

class MockWorkflowAuthProvider extends ChangeNotifier implements AuthProvider {
  final List<UserModel> _teachers = [
    const UserModel(
      id: 'teacher-1',
      name: 'Dr. Anand Kumar',
      email: 'anand@modernclasses.com',
      phone: '9876543210',
      role: UserRole.teacher,
    ),
    const UserModel(
      id: 'teacher-2',
      name: 'Prof. R. K. Singh',
      email: 'rksingh@modernclasses.com',
      phone: '9876543211',
      role: UserRole.teacher,
    ),
    const UserModel(
      id: 'teacher-3',
      name: 'Er. S. N. Verma',
      email: 'snverma@modernclasses.com',
      phone: '9876543212',
      role: UserRole.teacher,
    ),
  ];

  @override
  Future<List<UserModel>> getAllProfiles() async => _teachers;

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

class MockWorkflowCourseRepository extends FakeCourseRepository {
  final List<CourseModel> courses = [];
  final List<BatchModel> batches = [];
  final Map<String, List<String>> batchTeachers = {};

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
    final savedCourse = course.copyWith(id: generatedId);
    courses.add(savedCourse);

    if (initialBatches != null) {
      for (int i = 0; i < initialBatches.length; i++) {
        final b = initialBatches[i];
        final bId = 'b-${batches.length + 1}';
        final tIds = batchTeacherIds?[i] ?? b.teacherIds;
        final savedBatch = b.copyWith(
          id: bId,
          courseId: generatedId,
          teacherIds: tIds,
        );
        batches.add(savedBatch);
        batchTeachers[bId] = List.from(tIds);
      }
    }
  }

  @override
  Future<void> updateCourse(CourseModel course) async {
    final idx = courses.indexWhere((c) => c.id == course.id);
    if (idx != -1) {
      courses[idx] = course;
    } else {
      courses.add(course);
    }
  }

  @override
  Future<void> createBatch(BatchModel batch, {List<String>? teacherIds}) async {
    final bId = 'b-${batches.length + 1}';
    final assigned = teacherIds ?? batch.teacherIds;
    final saved = batch.copyWith(id: bId, teacherIds: assigned);
    batches.add(saved);
    batchTeachers[bId] = List.from(assigned);
  }

  @override
  Future<void> updateBatch(BatchModel batch, {List<String>? teacherIds}) async {
    final assigned = teacherIds ?? batch.teacherIds;
    final updated = batch.copyWith(teacherIds: assigned);
    final idx = batches.indexWhere((b) => b.id == batch.id);
    if (idx != -1) {
      batches[idx] = updated;
    } else {
      batches.add(updated);
    }
    batchTeachers[batch.id] = List.from(assigned);
  }

  @override
  Future<List<String>> getBatchTeacherIds(String batchId) async {
    return List.from(batchTeachers[batchId] ?? []);
  }

  @override
  Future<void> updateBatchTeachers(String batchId, List<String> teacherIds) async {
    batchTeachers[batchId] = List.from(teacherIds);
    final idx = batches.indexWhere((b) => b.id == batchId);
    if (idx != -1) {
      batches[idx] = batches[idx].copyWith(teacherIds: teacherIds);
    }
  }

  @override
  Future<void> deleteBatch(String batchId) async {
    batches.removeWhere((b) => b.id == batchId);
    batchTeachers.remove(batchId);
  }

  @override
  Future<void> deleteCourse(String courseId) async {
    courses.removeWhere((c) => c.id == courseId);
    batches.removeWhere((b) => b.courseId == courseId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockWorkflowCourseRepository repository;
  late CourseProvider courseProvider;
  late MockWorkflowAuthProvider authProvider;

  setUp(() {
    repository = MockWorkflowCourseRepository();
    courseProvider = CourseProvider(repository: repository);
    authProvider = MockWorkflowAuthProvider();
  });

  Widget buildTestableWidget(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<CourseProvider>.value(value: courseProvider),
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ],
      child: MaterialApp(
        home: Scaffold(body: child),
      ),
    );
  }

  group('1. Course Creation Wizard (Two-Step Flow)', () {
    testWidgets('Step 1 requires Title and Category before advancing to Step 2', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => CourseCreationWizardDialog.show(ctx),
              child: const Text('Open Wizard'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Wizard'));
      await tester.pumpAndSettle();

      expect(find.text('Create Course — Step 1: Basic Information'), findsOneWidget);
      expect(find.text('Next: Course Setup'), findsOneWidget);

      // Attempt to proceed with empty title
      await tester.tap(find.text('Next: Course Setup'));
      await tester.pumpAndSettle();

      expect(find.text('Course title is required'), findsOneWidget);
      // Still on step 1
      expect(find.text('Create Course — Step 1: Basic Information'), findsOneWidget);

      // Enter title
      await tester.enterText(find.widgetWithText(TextField, 'Course Name *'), 'BPSC Prelims 2026');
      await tester.pump();

      // Proceed to Step 2
      await tester.tap(find.text('Next: Course Setup'));
      await tester.pumpAndSettle();

      expect(find.text('Create Course — Step 2: Course Setup & Timings'), findsOneWidget);
      expect(find.text('Course Pricing'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
      expect(find.text('Create Course'), findsOneWidget);
    });

    testWidgets('Navigating Back from Step 2 to Step 1 preserves entered values', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => CourseCreationWizardDialog.show(ctx),
              child: const Text('Open Wizard'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Wizard'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Course Name *'), 'BPSC Mains Intensive');
      await tester.enterText(find.widgetWithText(TextField, 'Category *'), 'BPSC Advanced');
      await tester.enterText(find.widgetWithText(TextField, 'Detail / Highlights'), 'Answer Writing\nModel Answers');

      await tester.tap(find.text('Next: Course Setup'));
      await tester.pumpAndSettle();

      // In Step 2, enter fee
      await tester.enterText(find.widgetWithText(TextField, 'Course Fee (₹) *'), '4999');
      await tester.pump();

      // Press Back to return to Step 1
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Create Course — Step 1: Basic Information'), findsOneWidget);
      expect(find.text('BPSC Mains Intensive'), findsOneWidget);
      expect(find.text('BPSC Advanced'), findsOneWidget);
      expect(find.text('Answer Writing\nModel Answers'), findsOneWidget);

      // Go forward to Step 2 again and verify Fee is preserved
      await tester.tap(find.text('Next: Course Setup'));
      await tester.pumpAndSettle();

      expect(find.text('Create Course — Step 2: Course Setup & Timings'), findsOneWidget);
      expect(find.text('4999'), findsOneWidget);
    });

    testWidgets('Step 2 creates Course with initial timing slots and multi-teacher assignments', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => CourseCreationWizardDialog.show(ctx),
              child: const Text('Open Wizard'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Wizard'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Course Name *'), 'UPSC GS Foundation');
      await tester.tap(find.text('Next: Course Setup'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Course Fee (₹) *'), '1499');
      await tester.pump();

      // Submit wizard
      await tester.tap(find.text('Create Course'));
      await tester.pumpAndSettle();

      // Wizard dialog should have closed
      expect(find.text('Create Course — Step 2: Course Setup & Timings'), findsNothing);

      // Check repository persistence
      expect(repository.courses.length, 1);
      expect(repository.courses.first.title, 'UPSC GS Foundation');
      expect(repository.courses.first.price, 1499);
      expect(repository.batches.length, 1);
      expect(repository.batches.first.timing, '08:00 AM - 10:00 AM (Mon-Sat)');
    });
  });

  group('2. Single-Page Edit Course Screen', () {
    testWidgets('Renders all course fields in single scrollable view and saves updates', (tester) async {
      const initialCourse = CourseModel(
        id: 'c-edit-1',
        title: 'Original Title',
        category: 'BPSC',
        description: 'Original Description',
        coverImageUrl: 'https://example.com/thumb.png',
        price: 2499,
        originalPrice: 2999,
        teacherName: 'Faculty',
        teacherId: '',
        totalLessons: 40,
        totalHours: 80,
        totalTests: 10,
        totalNotes: 20,
        highlights: ['Highlight 1', 'Highlight 2'],
      );
      repository.courses.add(initialCourse);

      await tester.pumpWidget(
        buildTestableWidget(
          const EditCourseScreen(course: initialCourse),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Course: Original Title'), findsOneWidget);
      expect(find.text('Basic Information'), findsOneWidget);
      expect(find.text('Pricing & Offers'), findsOneWidget);
      expect(find.text('Course Settings & Media'), findsOneWidget);
      expect(find.text('Class Timings & Batches (0)'), findsOneWidget);

      // Edit title and price
      final titleField = find.widgetWithText(TextField, 'Course Title *');
      await tester.enterText(titleField, 'Updated Master Title');

      final priceField = find.widgetWithText(TextField, 'Selling Price (₹) *');
      await tester.enterText(priceField, '3199');

      // Tap Save
      await tester.tap(find.text('Save Course Changes'));
      await tester.pumpAndSettle();

      expect(repository.courses.first.title, 'Updated Master Title');
      expect(repository.courses.first.price, 3199);
    });
  });

  group('3. Edit Batch Dialog - Infinite Spinner Fix', () {
    testWidgets('Edit Batch completes, resets loading state in finally block, and closes safely', (tester) async {
      final initialCourse = const CourseModel(
        id: 'c-100',
        title: 'BPSC 71st Batch Course',
        category: 'BPSC',
        description: '',
        coverImageUrl: '',
        price: 1999,
        originalPrice: 1999,
        teacherName: 'Dr. Anand Kumar',
        teacherId: 'teacher-1',
        totalLessons: 10,
        totalHours: 20,
        totalTests: 2,
        totalNotes: 5,
        highlights: [],
      );
      final initialBatch = BatchModel(
        id: 'b-100',
        courseId: 'c-100',
        name: 'Morning Batch 1',
        timing: '07:00 AM - 09:00 AM (Mon-Sat)',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 90)),
        teacherName: 'Dr. Anand Kumar',
        teacherId: 'teacher-1',
        totalStudents: 15,
        maxStudents: 500,
        batchPrice: 1999,
        medium: 'Bilingual (Hindi + English)',
        teacherIds: const ['teacher-1'],
      );

      repository.courses.add(initialCourse);
      repository.batches.add(initialBatch);
      repository.batchTeachers['b-100'] = ['teacher-1'];
      await courseProvider.fetchCatalog();

      await tester.pumpWidget(
        buildTestableWidget(const ManageCoursesScreen()),
      );
      await tester.pumpAndSettle();

      // Open Edit Batch Dialog via Edit Batch icon button
      final editBatchBtn = find.byTooltip('Edit Batch');
      expect(editBatchBtn, findsOneWidget);
      await tester.tap(editBatchBtn);
      await tester.pumpAndSettle();

      expect(find.text('Edit Batch: Morning Batch 1'), findsOneWidget);

      // Change batch fee and save
      final feeField = find.widgetWithText(TextField, 'Batch Fee (₹) *');
      await tester.enterText(feeField, '2499');

      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      // Dialog must be closed and not stuck saving forever
      expect(find.text('Edit Batch: Morning Batch 1'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Verify update in repository
      final updatedBatch = repository.batches.firstWhere((b) => b.id == 'b-100');
      expect(updatedBatch.batchPrice, 2499);
    });
  });

  group('4. Course Card Redundant Button Removal & Edit Course Navigation', () {
    testWidgets('Course card renders Edit Course button and does not render redundant Add Timing Slot header button', (tester) async {
      final course = const CourseModel(
        id: 'c-card-1',
        title: 'BPSC Modern History Special',
        category: 'History',
        description: 'Deep dive into Bihar and Indian Modern History',
        coverImageUrl: '',
        price: 999,
        originalPrice: 1999,
        teacherName: 'Faculty',
        teacherId: '',
        totalLessons: 15,
        totalHours: 30,
        totalTests: 3,
        totalNotes: 5,
        highlights: [],
      );
      final batch = BatchModel(
        id: 'b-card-1',
        courseId: 'c-card-1',
        name: 'Evening Slot',
        timing: '06:00 PM - 08:00 PM (Mon-Sat)',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 60)),
        teacherName: 'Dr. Anand Kumar',
        teacherId: 'teacher-1',
        totalStudents: 10,
        maxStudents: 100,
        batchPrice: 999,
        medium: 'Bilingual (Hindi + English)',
      );

      repository.courses.add(course);
      repository.batches.add(batch);
      await courseProvider.fetchCatalog();

      await tester.pumpWidget(
        buildTestableWidget(const ManageCoursesScreen()),
      );
      await tester.pumpAndSettle();

      // Edit Course button should exist
      expect(find.byKey(const Key('edit_course_c-card-1')), findsOneWidget);
      expect(find.byKey(const Key('delete_course_c-card-1')), findsOneWidget);

      // Standalone redundant "Add Timing Slot" button in course card header should be removed
      expect(find.widgetWithText(ElevatedButton, 'Add Timing Slot'), findsNothing);

      // Tapping Edit Course opens EditCourseScreen
      await tester.tap(find.byKey(const Key('edit_course_c-card-1')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Course: BPSC Modern History Special'), findsOneWidget);
    });
  });

  group('5. Multi-Teacher Assignment per Batch', () {
    testWidgets('MultiTeacherSelector renders chips and allows assigning multiple teachers', (tester) async {
      final allTeachers = [
        const UserModel(
          id: 't-1',
          name: 'Teacher Alpha',
          email: 'alpha@test.com',
          phone: '1111111111',
          role: UserRole.teacher,
        ),
        const UserModel(
          id: 't-2',
          name: 'Teacher Beta',
          email: 'beta@test.com',
          phone: '2222222222',
          role: UserRole.teacher,
        ),
      ];

      List<String> selected = ['t-1'];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (ctx, setState) => MultiTeacherSelector(
                allTeachers: allTeachers,
                selectedTeacherIds: selected,
                onChanged: (newIds) => setState(() => selected = newIds),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify chip for Teacher Alpha is displayed
      expect(find.text('Teacher Alpha'), findsOneWidget);

      // Open assignment modal
      await tester.tap(find.text('Edit Faculty'));
      await tester.pumpAndSettle();

      expect(find.text('Assign Faculty Members'), findsOneWidget);
      expect(find.text('Teacher Beta'), findsOneWidget);

      // Select Teacher Beta
      await tester.tap(find.text('Teacher Beta'));
      await tester.pumpAndSettle();

      // Confirm modal
      await tester.tap(find.text('Apply Selection'));
      await tester.pumpAndSettle();

      expect(selected, containsAll(['t-1', 't-2']));
    });

    testWidgets('CourseProvider and Repository accurately sync and retrieve multiple teachers', (tester) async {
      final batch = BatchModel(
        id: 'b-sync-1',
        courseId: 'c-sync-1',
        name: 'Combined GS Batch',
        timing: '10:00 AM - 12:00 PM (Mon-Sat)',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 90)),
        teacherName: 'Dr. Anand Kumar, Prof. R. K. Singh',
        teacherId: 'teacher-1',
        totalStudents: 0,
        maxStudents: 500,
        batchPrice: 2000,
        medium: 'Bilingual (Hindi + English)',
        teacherIds: const ['teacher-1', 'teacher-2'],
      );

      await courseProvider.addBatch(batch, teacherIds: ['teacher-1', 'teacher-2']);

      // Check repository retrieval
      final retrievedIds = await courseProvider.getBatchTeacherIds('b-1');
      expect(retrievedIds, ['teacher-1', 'teacher-2']);

      // Update with new set of teachers
      await courseProvider.updateBatchTeachers('b-1', ['teacher-2', 'teacher-3']);
      final updatedIds = await courseProvider.getBatchTeacherIds('b-1');
      expect(updatedIds, ['teacher-2', 'teacher-3']);
    });
  });
}
