import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:modern_classes_patna/features/auth/data/models/user_model.dart';
import 'package:modern_classes_patna/features/auth/data/repositories/auth_repository.dart';
import 'package:modern_classes_patna/features/auth/logic/auth_provider.dart';
import 'package:modern_classes_patna/features/courses/data/models/batch_model.dart';
import 'package:modern_classes_patna/features/courses/data/models/course_model.dart';
import 'package:modern_classes_patna/features/courses/logic/course_provider.dart';
import 'package:modern_classes_patna/providers/theme_provider.dart';
import 'package:modern_classes_patna/screens/admin/manage_courses_screen.dart';
import 'fake_course_repository.dart';

class _MultiScheduleTestCourseRepo extends FakeCourseRepository {
  List<CourseModel> courses;
  List<BatchModel> batches;

  _MultiScheduleTestCourseRepo({required this.courses, required this.batches});

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

class _MultiScheduleTestAuthRepo implements AuthRepository {
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
          name: 'Dr. Anand Kumar',
          email: 'anand@patna.org',
          phone: '9999999901',
          role: UserRole.teacher,
        ),
      ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Multiple Schedules and Timings Management Tests', () {
    testWidgets('1. Adding a schedule preserves the old timing, appends the new one, and lists both simultaneously', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      final course = CourseModel(
        id: 'crs-multi-1',
        title: 'BPSC GS Prelims 2026',
        description: 'Complete syllabus coverage',
        price: 1999,
        originalPrice: 3999,
        category: 'BPSC',
        teacherName: 'Dr. Anand Kumar',
        teacherId: 't1',
        totalLessons: 40,
        totalHours: 80,
        totalTests: 10,
        totalNotes: 20,
        coverImageUrl: '',
        highlights: const ['Live classes'],
      );

      final batch1 = BatchModel(
        id: 'b-slot-1',
        courseId: 'crs-multi-1',
        name: 'Morning Target Batch',
        timing: '08:00 AM - 10:00 AM (Mon-Sat)',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 90)),
        teacherName: 'Dr. Anand Kumar',
        teacherId: 't1',
        totalStudents: 15,
        batchPrice: 1999,
      );

      final repo = _MultiScheduleTestCourseRepo(courses: [course], batches: [batch1]);
      final courseProvider = CourseProvider(repository: repo);
      await courseProvider.fetchCatalog();

      final authRepo = _MultiScheduleTestAuthRepo();
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

      // Open Edit Dialog
      await tester.tap(find.text('Morning Target Batch').first);
      await tester.pumpAndSettle();

      // Verify initial state: 1 schedule displayed
      expect(find.text('Course Schedules & Timings (1)'), findsOneWidget);
      expect(find.text('Morning Target Batch'), findsWidgets);
      expect(find.text('08:00 AM - 10:00 AM (Mon-Sat)'), findsWidgets);

      // Tap "Add Schedule / Timing" inside the dialog
      final addScheduleBtn = find.descendant(
        of: find.byType(Dialog),
        matching: find.widgetWithText(TextButton, 'Add Schedule / Timing'),
      );
      expect(addScheduleBtn, findsOneWidget);
      await tester.tap(addScheduleBtn);
      await tester.pumpAndSettle();

      // In BatchTimingPickerDialog, default initialTiming is 04:00 PM - 06:00 PM (Mon-Sat)
      expect(find.text('Schedule (Hours & Days)'), findsOneWidget);
      await tester.tap(find.text('Apply Schedule'));
      await tester.pumpAndSettle();

      // The schedule picker closed
      expect(find.text('Schedule (Hours & Days)'), findsNothing);

      // CRITICAL ASSERTION: Course now has 2 schedules in provider
      final courseBatches = courseProvider.getBatchesForCourse('crs-multi-1');
      expect(courseBatches.length, 2);

      // BOTH schedules are present:
      expect(courseBatches[0].timing, '08:00 AM - 10:00 AM (Mon-Sat)');
      expect(courseBatches[1].timing, '04:00 PM - 06:00 PM (Mon-Sat)');

      // The old timing was NOT replaced: Schedule 1 and Schedule 2 are BOTH listed on screen!
      expect(find.text('Course Schedules & Timings (2)'), findsOneWidget);
      expect(find.text('Schedule 1'), findsOneWidget);
      expect(find.text('Schedule 2'), findsOneWidget);
      expect(find.text('08:00 AM - 10:00 AM (Mon-Sat)'), findsWidgets);
      expect(find.text('04:00 PM - 06:00 PM (Mon-Sat)'), findsWidgets);

      expect(tester.takeException(), isNull);
    });

    testWidgets('2. App rejects duplicate timings when attempting to add an already existing schedule', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      final course = CourseModel(
        id: 'crs-multi-2',
        title: 'BPSC GS Prelims 2026',
        description: 'Complete syllabus coverage',
        price: 1999,
        originalPrice: 3999,
        category: 'BPSC',
        teacherName: 'Dr. Anand Kumar',
        teacherId: 't1',
        totalLessons: 40,
        totalHours: 80,
        totalTests: 10,
        totalNotes: 20,
        coverImageUrl: '',
        highlights: const ['Live classes'],
      );

      // Existing batch already has 04:00 PM - 06:00 PM (Mon-Sat)
      final batch1 = BatchModel(
        id: 'b-slot-dup-1',
        courseId: 'crs-multi-2',
        name: 'Evening Target Batch',
        timing: '04:00 PM - 06:00 PM (Mon-Sat)',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 90)),
        teacherName: 'Dr. Anand Kumar',
        teacherId: 't1',
        totalStudents: 15,
        batchPrice: 1999,
      );

      final repo = _MultiScheduleTestCourseRepo(courses: [course], batches: [batch1]);
      final courseProvider = CourseProvider(repository: repo);
      await courseProvider.fetchCatalog();

      final authRepo = _MultiScheduleTestAuthRepo();
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

      // Open Edit Dialog
      await tester.tap(find.text('Evening Target Batch').first);
      await tester.pumpAndSettle();

      // Tap "Add Schedule / Timing" inside the dialog
      final addScheduleBtn = find.descendant(
        of: find.byType(Dialog),
        matching: find.widgetWithText(TextButton, 'Add Schedule / Timing'),
      );
      await tester.tap(addScheduleBtn);
      await tester.pumpAndSettle();

      // The dialog initial timing is 04:00 PM - 06:00 PM (Mon-Sat), which matches batch1
      // Verify in-dialog conflict banner is displayed and Apply Schedule button is disabled
      expect(find.textContaining('Overlaps with existing course slot'), findsOneWidget);
      final applyBtn = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Apply Schedule'));
      expect(applyBtn.onPressed, isNull);

      // Close dialog
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();

      // Provider still only has 1 batch (duplicate was BLOCKED)
      final courseBatches = courseProvider.getBatchesForCourse('crs-multi-2');
      expect(courseBatches.length, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('3. Managing schedules: Deleting a schedule removes it cleanly while preserving remaining schedules', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      final course = CourseModel(
        id: 'crs-multi-3',
        title: 'BPSC GS Prelims 2026',
        description: 'Complete syllabus coverage',
        price: 1999,
        originalPrice: 3999,
        category: 'BPSC',
        teacherName: 'Dr. Anand Kumar',
        teacherId: 't1',
        totalLessons: 40,
        totalHours: 80,
        totalTests: 10,
        totalNotes: 20,
        coverImageUrl: '',
        highlights: const ['Live classes'],
      );

      final batch1 = BatchModel(
        id: 'b-del-1',
        courseId: 'crs-multi-3',
        name: 'Morning Slot',
        timing: '08:00 AM - 10:00 AM (Mon-Sat)',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 90)),
        teacherName: 'Dr. Anand Kumar',
        teacherId: 't1',
        totalStudents: 15,
        batchPrice: 1999,
      );

      final batch2 = BatchModel(
        id: 'b-del-2',
        courseId: 'crs-multi-3',
        name: 'Evening Slot',
        timing: '05:00 PM - 07:00 PM (Mon-Sat)',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 90)),
        teacherName: 'Dr. Anand Kumar',
        teacherId: 't1',
        totalStudents: 10,
        batchPrice: 1999,
      );

      final repo = _MultiScheduleTestCourseRepo(courses: [course], batches: [batch1, batch2]);
      final courseProvider = CourseProvider(repository: repo);
      await courseProvider.fetchCatalog();

      final authRepo = _MultiScheduleTestAuthRepo();
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

      // Open Edit Dialog
      await tester.tap(find.text('Morning Slot').first);
      await tester.pumpAndSettle();

      expect(find.text('Course Schedules & Timings (2)'), findsOneWidget);

      // Find the delete button for the 2nd schedule
      final deleteScheduleBtns = find.byTooltip('Delete Schedule');
      expect(deleteScheduleBtns, findsNWidgets(2));

      // Tap delete on the 2nd schedule
      await tester.tap(deleteScheduleBtns.at(1));
      await tester.pumpAndSettle();

      // Confirm dialog appears
      expect(find.text('Delete Schedule?'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
      await tester.pumpAndSettle();

      // Batch 2 was deleted, Batch 1 remains
      final courseBatches = courseProvider.getBatchesForCourse('crs-multi-3');
      expect(courseBatches.length, 1);
      expect(courseBatches.first.id, 'b-del-1');
      expect(courseBatches.first.timing, '08:00 AM - 10:00 AM (Mon-Sat)');

      expect(find.text('Course Schedules & Timings (1)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
