import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:modern_classes_patna/core/theme/app_theme.dart';
import 'package:modern_classes_patna/core/widgets/batch_timing_picker_dialog.dart';
import 'package:modern_classes_patna/features/auth/data/models/user_model.dart';
import 'package:modern_classes_patna/features/auth/data/repositories/auth_repository.dart';
import 'package:modern_classes_patna/features/auth/logic/auth_provider.dart';
import 'package:modern_classes_patna/features/courses/data/models/batch_model.dart';
import 'package:modern_classes_patna/features/courses/data/models/course_model.dart';
import 'package:modern_classes_patna/features/courses/logic/course_provider.dart';
import 'package:modern_classes_patna/providers/theme_provider.dart';
import 'package:modern_classes_patna/screens/admin/course_creation_wizard_dialog.dart';
import 'package:modern_classes_patna/screens/admin/manage_courses_screen.dart';
import 'fake_course_repository.dart';

class _LocalTestCourseRepo extends FakeCourseRepository {
  List<CourseModel> courses;
  List<BatchModel> batches;

  _LocalTestCourseRepo({required this.courses, required this.batches});

  @override
  Future<List<CourseModel>> getCourses() async => List.from(courses);

  @override
  Future<List<BatchModel>> getBatches() async => List.from(batches);

  @override
  Future<void> createBatch(BatchModel batch, {List<String>? teacherIds}) async {
    final batchToInsert = batch.id.isEmpty
        ? batch.copyWith(id: 'batch_${DateTime.now().millisecondsSinceEpoch}_${batches.length + 1}')
        : batch;
    batches.add(batchToInsert);
  }

  @override
  Future<void> updateBatch(BatchModel batch, {List<String>? teacherIds}) async {
    final idx = batches.indexWhere((b) => b.id == batch.id);
    if (idx != -1) {
      batches[idx] = batch;
    }
  }

  @override
  Future<void> deleteBatch(String batchId) async {
    batches.removeWhere((b) => b.id == batchId);
  }
}

class _LocalTestAuthRepo implements AuthRepository {
  @override
  bool get isConnected => true;

  @override
  Future<UserModel?> getInitialSession() async => const UserModel(
        id: 'admin_1',
        name: 'Admin',
        email: 'admin@patna.org',
        phone: '9999999999',
        role: UserRole.admin,
      );

  @override
  Future<List<UserModel>> getAllProfiles() async => [
        const UserModel(
          id: 't1',
          name: 'Teacher 1',
          email: 't1@patna.org',
          phone: '9999999901',
          role: UserRole.teacher,
        ),
      ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Batch Timing Picker & Add Schedule Regression Suite', () {
    testWidgets('1. BatchTimingPickerDialog in Light Mode: Tapping Start Time and End Time never crashes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.academicTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => BatchTimingPickerDialog.show(
                  context,
                  initialTiming: '09:00 AM - 11:00 AM (Mon-Sat)',
                ),
                child: const Text('Open Picker'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      expect(find.text('Schedule (Hours & Days)'), findsOneWidget);

      // Tap Start Time
      await tester.tap(find.text('Start Time'));
      await tester.pumpAndSettle();

      // Ensure TimePicker dialog opened without ThemeData brightness assertions
      expect(find.byType(TimePickerDialog), findsOneWidget);

      // Tap OK in TimePicker
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Tap End Time
      await tester.tap(find.text('End Time'));
      await tester.pumpAndSettle();

      expect(find.byType(TimePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Apply schedule
      await tester.tap(find.text('Apply Schedule'));
      await tester.pumpAndSettle();

      expect(find.text('Schedule (Hours & Days)'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('2. BatchTimingPickerDialog in Dark Mode: Tapping Start Time works cleanly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => BatchTimingPickerDialog.show(
                  context,
                  initialTiming: '10:00 AM - 12:00 PM (Daily)',
                ),
                child: const Text('Open Picker Dark'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Picker Dark'));
      await tester.pumpAndSettle();

      expect(find.text('Schedule (Hours & Days)'), findsOneWidget);

      await tester.tap(find.text('Start Time'));
      await tester.pumpAndSettle();

      expect(find.byType(TimePickerDialog), findsOneWidget);
      // Tap Cancel in the TimePicker dialog (which is the topmost Cancel button)
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();

      expect(find.byType(TimePickerDialog), findsNothing);
      expect(find.text('Schedule (Hours & Days)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('3. ManageCoursesScreen: Tapping Add Schedule / Timing inside Edit Course adds schedule directly without switching to a different dialog box', (tester) async {
      final course = CourseModel(
        id: 'crs-reg-1',
        title: 'BPSC GS Foundation 2026',
        description: 'Foundation course with faculty team',
        price: 2499,
        originalPrice: 4999,
        category: 'GS Prelims + Mains',
        teacherName: 'Dr. Anand Kumar',
        teacherId: 't1',
        totalLessons: 60,
        totalHours: 120,
        totalTests: 15,
        totalNotes: 30,
        coverImageUrl: 'https://example.com/cover.png',
        highlights: const ['Live classes', 'PDF notes'],
      );

      final batch = BatchModel(
        id: 'b-reg-1',
        courseId: 'crs-reg-1',
        name: 'Batch 1',
        timing: '08:00 AM - 10:00 AM (Mon-Sat)',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 90)),
        teacherName: 'Teacher 1',
        teacherId: 't1',
        totalStudents: 10,
        batchPrice: 2499,
      );

      final repo = _LocalTestCourseRepo(courses: [course], batches: [batch]);
      final courseProvider = CourseProvider(repository: repo);
      await courseProvider.fetchCatalog();

      final authRepo = _LocalTestAuthRepo();
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

      // Open Edit Dialog via course action button
      final editBtn = find.byKey(const Key('edit_course_crs-reg-1'));
      expect(editBtn, findsOneWidget);
      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('Edit Course: BPSC GS Foundation 2026'), findsOneWidget);

      // Find "Add Schedule / Timing" button inside the Edit Dialog
      final addScheduleBtn = find.descendant(
        of: find.byType(Dialog),
        matching: find.widgetWithText(TextButton, 'Add Schedule / Timing'),
      );
      expect(addScheduleBtn, findsOneWidget);
      await tester.tap(addScheduleBtn);
      await tester.pumpAndSettle();

      // It must open BatchTimingPickerDialog directly, NOT a different dialog box!
      expect(find.text('Schedule (Hours & Days)'), findsOneWidget);
      expect(find.textContaining('Create Batch for'), findsNothing);

      // Apply the chosen schedule
      await tester.tap(find.text('Apply Schedule'));
      await tester.pumpAndSettle();

      // The schedule picker closed
      expect(find.text('Schedule (Hours & Days)'), findsNothing);

      // We are STILL in the Edit Course dialog (NOT navigated away to a different dialog)
      expect(find.textContaining('Edit Course: BPSC GS Foundation 2026'), findsOneWidget);

      // And the course in provider now has 2 batches!
      final courseBatches = courseProvider.getBatchesForCourse('crs-reg-1');
      expect(courseBatches.length, 2);

      // And the new batch schedule appears in the dialog header
      expect(find.textContaining('Schedule: BPSC GS Foundation 2026 - Batch 2'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('4. ManageCoursesScreen: Tapping Add Schedule / Timing on the Course Card adds schedule directly', (tester) async {
      final course = CourseModel(
        id: 'crs-card-1',
        title: 'BPSC GS Foundation 2026',
        description: 'Foundation course with faculty team',
        price: 2499,
        originalPrice: 4999,
        category: 'GS Prelims + Mains',
        teacherName: 'Dr. Anand Kumar',
        teacherId: 't1',
        totalLessons: 60,
        totalHours: 120,
        totalTests: 15,
        totalNotes: 30,
        coverImageUrl: 'https://example.com/cover.png',
        highlights: const ['Live classes', 'PDF notes'],
      );

      final batch = BatchModel(
        id: 'b-card-1',
        courseId: 'crs-card-1',
        name: 'Batch 1',
        timing: '08:00 AM - 10:00 AM (Mon-Sat)',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 90)),
        teacherName: 'Teacher 1',
        teacherId: 't1',
        totalStudents: 10,
        batchPrice: 2499,
      );

      final repo = _LocalTestCourseRepo(courses: [course], batches: [batch]);
      final courseProvider = CourseProvider(repository: repo);
      await courseProvider.fetchCatalog();

      final authRepo = _LocalTestAuthRepo();
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

      // Tapping "Add Schedule / Timing" on the Course Card
      final addScheduleCardBtn = find.widgetWithText(TextButton, 'Add Schedule / Timing');
      expect(addScheduleCardBtn, findsOneWidget);
      await tester.tap(addScheduleCardBtn);
      await tester.pumpAndSettle();

      // Timing picker opened directly
      expect(find.text('Schedule (Hours & Days)'), findsOneWidget);

      await tester.tap(find.text('Apply Schedule'));
      await tester.pumpAndSettle();

      // Provider has 2 batches now
      expect(courseProvider.getBatchesForCourse('crs-card-1').length, 2);

      // Course card reflects 2 batches
      expect(find.text('Class Timings & Batches (2)'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('4. CourseCreationWizardDialog: Add Schedule / Timing adds timing slot', (tester) async {
      final authRepo = _LocalTestAuthRepo();
      final authProvider = AuthProvider(repository: authRepo);

      final repo = _LocalTestCourseRepo(courses: [], batches: []);
      final courseProvider = CourseProvider(repository: repo);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authProvider),
            ChangeNotifierProvider.value(value: courseProvider),
          ],
          child: MaterialApp(
            theme: AppTheme.academicTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => CourseCreationWizardDialog.show(context),
                  child: const Text('Open Wizard'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Wizard'));
      await tester.pumpAndSettle();

      // Wizard dialog open
      expect(find.textContaining('Step 1: Basic Information'), findsOneWidget);

      // Fill title so Step 1 passes validation
      final titleField = find.widgetWithText(TextField, 'Course Name *');
      await tester.enterText(titleField, 'Test BPSC Course 2026');
      await tester.pumpAndSettle();

      // Tap "Next: Course Setup"
      await tester.tap(find.text('Next: Course Setup'));
      await tester.pumpAndSettle();

      // Now on Step 2
      expect(find.textContaining('Step 2: Course Setup & Timings'), findsOneWidget);

      // Find "Add Schedule / Timing" button in wizard
      final addTimingBtn = find.widgetWithText(OutlinedButton, 'Add Schedule / Timing');
      expect(addTimingBtn, findsOneWidget);

      await tester.tap(addTimingBtn);
      await tester.pumpAndSettle();

      // Timing picker opened
      expect(find.text('Schedule (Hours & Days)'), findsOneWidget);

      await tester.tap(find.text('Apply Schedule'));
      await tester.pumpAndSettle();

      // New slot added to wizard
      expect(find.text('Slot 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
