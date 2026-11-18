import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:modern_classes_patna/core/utils/batch_timing_helper.dart';
import 'package:modern_classes_patna/core/widgets/batch_timing_picker_dialog.dart';
import 'package:modern_classes_patna/features/courses/data/models/course_model.dart';
import 'package:modern_classes_patna/features/courses/data/models/batch_model.dart';
import 'package:modern_classes_patna/features/courses/logic/course_provider.dart';
import 'package:modern_classes_patna/screens/student/course_detail_screen.dart';
import 'fake_course_repository.dart';

class MockMultiTimingRepository extends FakeCourseRepository {
  List<CourseModel> testCourses = [];
  List<BatchModel> testBatches = [];
  Map<String, List<String>> testEnrollments = {
    'courseIds': [],
    'batchIds': [],
  };

  @override
  Future<List<CourseModel>> getCourses() async => List.from(testCourses);

  @override
  Future<List<BatchModel>> getBatches() async => List.from(testBatches);

  @override
  Future<List<BatchModel>> adminGetAllBatches() async => List.from(testBatches);

  @override
  Future<void> createCourse(
    CourseModel course, {
    List<BatchModel>? initialBatches,
    Map<int, List<String>>? batchTeacherIds,
  }) async {
    testCourses.add(course);
    if (initialBatches != null) {
      testBatches.addAll(initialBatches);
    }
  }

  @override
  Future<void> deleteCourse(String courseId) async {
    testCourses.removeWhere((c) => c.id == courseId);
    testBatches.removeWhere((b) => b.courseId == courseId);
  }

  @override
  Future<void> createBatch(BatchModel batch, {List<String>? teacherIds}) async {
    testBatches.add(batch.copyWith(teacherIds: teacherIds ?? batch.teacherIds));
  }

  @override
  Future<void> updateBatch(BatchModel batch, {List<String>? teacherIds}) async {
    final updated = batch.copyWith(teacherIds: teacherIds ?? batch.teacherIds);
    final idx = testBatches.indexWhere((b) => b.id == batch.id);
    if (idx != -1) {
      testBatches[idx] = updated;
    } else {
      testBatches.add(updated);
    }
  }

  @override
  Future<void> deleteBatch(String batchId) async {
    final b = testBatches.firstWhere(
      (b) => b.id == batchId,
      orElse: () => throw Exception('Not found'),
    );
    if (b.totalStudents > 0) {
      throw Exception('Cannot delete timing slot: active enrollments exist.');
    }
    testBatches.removeWhere((b) => b.id == batchId);
  }

  @override
  Future<Map<String, List<String>>> getMyEnrollments() async => testEnrollments;
}

void main() {
  group('1. BatchTimingHelper Time Range & Duplicate Validation', () {
    test('validateTimeRange accepts end time strictly after start time', () {
      const start = TimeOfDay(hour: 12, minute: 0);
      const end = TimeOfDay(hour: 14, minute: 0);
      final error = BatchTimingHelper.validateTimeRange(start, end);
      expect(error, isNull);
    });

    test('validateTimeRange rejects end time equal to or before start time', () {
      const start = TimeOfDay(hour: 14, minute: 0);
      const sameEnd = TimeOfDay(hour: 14, minute: 0);
      final sameError = BatchTimingHelper.validateTimeRange(start, sameEnd);
      expect(sameError, isNotNull);
      expect(sameError, contains('End time must be after start time'));

      const earlierEnd = TimeOfDay(hour: 10, minute: 0);
      final earlierError = BatchTimingHelper.validateTimeRange(start, earlierEnd);
      expect(earlierError, isNotNull);
      expect(earlierError, contains('End time must be after start time'));
    });

    test('isDuplicateTiming detects identical timings ignoring case and whitespace', () {
      final existing = [
        '12:00 PM - 02:00 PM (Mon-Sat)',
        '04:00 PM - 06:00 PM (Mon-Fri)',
      ];

      expect(
        BatchTimingHelper.isDuplicateTiming('12:00 PM - 02:00 PM (Mon-Sat)', existing),
        isTrue,
      );
      expect(
        BatchTimingHelper.isDuplicateTiming('  12:00 pm - 02:00 pm (mon-sat)  ', existing),
        isTrue,
      );
      expect(
        BatchTimingHelper.isDuplicateTiming('08:00 AM - 10:00 AM (Mon-Sat)', existing),
        isFalse,
      );
    });
  });

  group('2. BatchTimingPickerDialog Interactive Behavior', () {
    testWidgets('Displays error and prevents applying schedule when end <= start', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => BatchTimingPickerDialog.show(
                  context,
                  initialTiming: '02:00 PM - 01:00 PM (Mon-Sat)', // Invalid: end before start
                ),
                child: const Text('Open Picker'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Verify inline error warning appears
      expect(find.text('End time must be after start time.'), findsOneWidget);

      // Attempt to tap Apply Schedule
      await tester.tap(find.text('Apply Schedule'));
      await tester.pumpAndSettle();

      // Dialog should still be open because end <= start
      expect(find.text('Schedule (Hours & Days)'), findsOneWidget);
    });

    testWidgets('Allows applying schedule when start < end', (tester) async {
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await BatchTimingPickerDialog.show(
                    context,
                    initialTiming: '12:00 PM - 02:00 PM (Mon-Sat)',
                  );
                },
                child: const Text('Open Picker'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      expect(find.text('Schedule (Hours & Days)'), findsOneWidget);
      expect(find.text('Lecture duration: 2 hrs (120 mins)'), findsOneWidget);

      await tester.tap(find.text('Apply Schedule'));
      await tester.pumpAndSettle();

      // Dialog should close and return formatted timing
      expect(find.text('Schedule (Hours & Days)'), findsNothing);
      expect(result, isNotNull);
      expect(result, contains('12:00 PM - 02:00 PM (Mon-Sat)'));
    });
  });

  group('3. Single Course Multiple Timings Architecture', () {
    late MockMultiTimingRepository repo;
    late CourseProvider provider;

    setUp(() {
      repo = MockMultiTimingRepository();
      provider = CourseProvider(repository: repo);
    });

    test('Assigning multiple batches to one course preserves single course entity', () async {
      final course = CourseModel(
        id: 'c-12-physics',
        title: 'Class 12 Physics',
        category: 'Class 12',
        description: 'Complete board preparation',
        coverImageUrl: '',
        price: 1999,
        originalPrice: 2999,
        teacherName: 'Er. R.K. Singh',
        teacherId: 't-1',
        totalLessons: 10,
        totalHours: 40,
        totalTests: 4,
        totalNotes: 5,
        highlights: [],
        isFeatured: true,
      );

      final slot1 = BatchModel(
        id: 'slot-12-2',
        courseId: 'c-12-physics',
        name: 'Slot 1 (Noon)',
        timing: '12:00 PM - 02:00 PM (Mon-Sat)',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 90)),
        teacherName: 'Er. R.K. Singh',
        teacherId: 't-1',
        totalStudents: 15,
        maxStudents: 50,
        batchPrice: 1999,
      );

      final slot2 = BatchModel(
        id: 'slot-4-6',
        courseId: 'c-12-physics',
        name: 'Slot 2 (Evening)',
        timing: '04:00 PM - 06:00 PM (Mon-Sat)',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 90)),
        teacherName: 'Dr. Anand Kumar',
        teacherId: 't-2',
        totalStudents: 0,
        maxStudents: 50,
        batchPrice: 1999,
      );

      repo.testCourses = [course];
      repo.testBatches = [slot1, slot2];

      await provider.fetchCatalog();

      // Verify single course in catalog
      expect(provider.courses.length, 1);
      expect(provider.courses.first.id, 'c-12-physics');

      // Verify multiple timing slots belong to this single course
      final courseBatches = provider.getBatchesForCourse('c-12-physics');
      expect(courseBatches.length, 2);
      expect(courseBatches.map((b) => b.timing), containsAll([
        '12:00 PM - 02:00 PM (Mon-Sat)',
        '04:00 PM - 06:00 PM (Mon-Sat)',
      ]));
    });

    test('Slot with active enrollments blocks deletion to protect student data', () async {
      final slotWithStudents = BatchModel(
        id: 'slot-active',
        courseId: 'c-12-physics',
        name: 'Active Slot',
        timing: '12:00 PM - 02:00 PM (Mon-Sat)',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 90)),
        teacherName: 'Faculty',
        teacherId: 't-1',
        totalStudents: 12, // Active students!
        batchPrice: 1999,
      );

      repo.testBatches = [slotWithStudents];
      await provider.fetchCatalog();

      expect(
        () => provider.deleteBatch('slot-active'),
        throwsA(isA<Exception>()),
      );
      // Batch must still remain in catalog
      expect(provider.batches.any((b) => b.id == 'slot-active'), isTrue);
    });

    test('Unused slot with 0 students deletes cleanly', () async {
      final unusedSlot = BatchModel(
        id: 'slot-empty',
        courseId: 'c-12-physics',
        name: 'Empty Slot',
        timing: '06:00 PM - 08:00 PM (Mon-Sat)',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 90)),
        teacherName: 'Faculty',
        teacherId: 't-1',
        totalStudents: 0,
        batchPrice: 1999,
      );

      repo.testBatches = [unusedSlot];
      await provider.fetchCatalog();

      await provider.deleteBatch('slot-empty');
      expect(provider.batches.any((b) => b.id == 'slot-empty'), isFalse);
    });
  });

  group('4. Student UI Multiple Timings & Enrollment Status', () {
    late MockMultiTimingRepository repo;
    late CourseProvider provider;
    late CourseModel course;
    late BatchModel slot1;
    late BatchModel slot2;

    setUp(() {
      repo = MockMultiTimingRepository();
      provider = CourseProvider(repository: repo);

      course = CourseModel(
        id: 'c-12-physics',
        title: 'Class 12 Physics',
        category: 'Class 12',
        description: 'Complete physics mastery',
        coverImageUrl: '',
        price: 1999,
        originalPrice: 2999,
        teacherName: 'Faculty Team',
        teacherId: 't-1',
        totalLessons: 10,
        totalHours: 40,
        totalTests: 4,
        totalNotes: 5,
        highlights: [],
        isFeatured: true,
      );

      slot1 = BatchModel(
        id: 'slot-1',
        courseId: 'c-12-physics',
        name: 'Morning Batch',
        timing: '12:00 PM - 02:00 PM (Mon-Sat)',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 90)),
        teacherName: 'Er. R.K. Singh',
        teacherId: 't-1',
        totalStudents: 50,
        maxStudents: 50, // FULL!
        batchPrice: 1999,
      );

      slot2 = BatchModel(
        id: 'slot-2',
        courseId: 'c-12-physics',
        name: 'Evening Batch',
        timing: '04:00 PM - 06:00 PM (Mon-Sat)',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 90)),
        teacherName: 'Dr. Anand Kumar',
        teacherId: 't-2',
        totalStudents: 10,
        maxStudents: 50, // 40 seats left
        batchPrice: 1999,
      );

      repo.testCourses = [course];
      repo.testBatches = [slot1, slot2];
    });

    testWidgets('Renders Available Class Timings without slot capacity restrictions', (tester) async {
      await provider.fetchCatalog();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: provider),
          ],
          child: MaterialApp(
            home: CourseDetailScreen(course: course),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Title & Timing Badge
      expect(find.text('Available Class Timings'), findsOneWidget);
      expect(find.text('2 Timings'), findsOneWidget);

      // Verify Slot names and schedules
      expect(find.text('Morning Batch'), findsOneWidget);
      expect(find.text('12:00 PM - 02:00 PM (Mon-Sat)'), findsOneWidget);

      expect(find.text('Evening Batch'), findsOneWidget);
      expect(find.text('04:00 PM - 06:00 PM (Mon-Sat)'), findsOneWidget);

      // Verify Max Students / Capacity limits are NOT rendered
      expect(find.text('SLOT FULL'), findsNothing, reason: 'Capacity blocking badge must be removed');
      expect(find.textContaining('seats left'), findsNothing, reason: 'Seats left indicator must be removed');

      // Verify ENROLL NOW button is enabled even if totalStudents is high
      expect(find.text('ENROLL NOW'), findsOneWidget);
    });

    testWidgets('Enrolled student sees ENROLLED status for their specific timing slot', (tester) async {
      repo.testEnrollments = {
        'courseIds': ['c-12-physics'],
        'batchIds': ['slot-2'], // Enrolled in slot 2
      };

      await provider.fetchCatalog();
      await provider.fetchMyEnrollments();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: provider),
          ],
          child: MaterialApp(
            home: CourseDetailScreen(course: course),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Slot 2 should show ENROLLED badge
      expect(find.text('ENROLLED'), findsWidgets);
    });
  });

  group('5. Admin Course Scheduling End-to-End Workflow', () {
    late MockMultiTimingRepository repo;
    late CourseProvider provider;

    setUp(() {
      repo = MockMultiTimingRepository();
      provider = CourseProvider(repository: repo);
    });

    test('Create course with 2 schedules, add 3rd schedule, edit 1 schedule, delete 1 schedule', () async {
      final course = CourseModel(
        id: 'c-bpsc-prelims',
        title: 'BPSC Prelims Foundation',
        category: 'Civil Services',
        description: 'Comprehensive preparation',
        coverImageUrl: '',
        price: 3499,
        originalPrice: 4999,
        teacherName: 'Faculty Team',
        teacherId: 't-1',
        totalLessons: 20,
        totalHours: 60,
        totalTests: 5,
        totalNotes: 10,
        highlights: const ['H1'],
        isFeatured: true,
      );

      final sched1 = BatchModel(
        id: 'sched-1',
        courseId: 'c-bpsc-prelims',
        name: 'Morning Slot',
        timing: '10:00 AM - 12:00 PM (Mon-Sat)',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 90)),
        teacherName: 'Teacher 1',
        teacherId: 't-1',
        totalStudents: 0,
        batchPrice: 3499,
      );

      final sched2 = BatchModel(
        id: 'sched-2',
        courseId: 'c-bpsc-prelims',
        name: 'Afternoon Slot',
        timing: '02:00 PM - 04:00 PM (Mon-Sat)',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 90)),
        teacherName: 'Teacher 2',
        teacherId: 't-2',
        totalStudents: 0,
        batchPrice: 3499,
      );

      // 1. Create course with 2 initial schedules
      await provider.addCourse(course, initialBatches: [sched1, sched2]);
      await provider.fetchCatalog();

      var schedules = provider.getBatchesForCourse('c-bpsc-prelims');
      expect(schedules.length, 2);
      expect(schedules.map((s) => s.timing).toList(), [
        '10:00 AM - 12:00 PM (Mon-Sat)',
        '02:00 PM - 04:00 PM (Mon-Sat)',
      ]);

      // 2. Add 3rd schedule via addBatch
      final sched3 = BatchModel(
        id: 'sched-3',
        courseId: 'c-bpsc-prelims',
        name: 'Evening Slot',
        timing: '06:00 PM - 08:00 PM (Mon-Sat)',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 90)),
        teacherName: 'Teacher 3',
        teacherId: 't-3',
        totalStudents: 0,
        batchPrice: 3499,
      );
      await provider.addBatch(sched3);
      await provider.fetchCatalog();

      schedules = provider.getBatchesForCourse('c-bpsc-prelims');
      expect(schedules.length, 3);
      expect(schedules.map((s) => s.id), containsAll(['sched-1', 'sched-2', 'sched-3']));

      // 3. Edit schedule 2 timing and name without affecting schedule 1 or 3
      final updatedSched2 = sched2.copyWith(
        name: 'Afternoon Slot (Updated)',
        timing: '03:00 PM - 05:00 PM (Mon-Sat)',
      );
      await provider.updateBatch(updatedSched2);
      await provider.fetchCatalog();

      schedules = provider.getBatchesForCourse('c-bpsc-prelims');
      expect(schedules.length, 3);
      final fetchedSched1 = schedules.firstWhere((s) => s.id == 'sched-1');
      final fetchedSched2 = schedules.firstWhere((s) => s.id == 'sched-2');
      final fetchedSched3 = schedules.firstWhere((s) => s.id == 'sched-3');

      // Schedule 2 changed
      expect(fetchedSched2.name, 'Afternoon Slot (Updated)');
      expect(fetchedSched2.timing, '03:00 PM - 05:00 PM (Mon-Sat)');
      // Schedule 1 and 3 are untouched
      expect(fetchedSched1.timing, '10:00 AM - 12:00 PM (Mon-Sat)');
      expect(fetchedSched3.timing, '06:00 PM - 08:00 PM (Mon-Sat)');

      // 4. Duplicate schedule validation prevents adding conflicting timing
      final duplicateTiming = '10:00 AM - 12:00 PM (Mon-Sat)';
      final isDup = BatchTimingHelper.isDuplicateTiming(
        duplicateTiming,
        schedules.map((s) => s.timing),
      );
      expect(isDup, isTrue);

      // 5. Delete schedule 3 while keeping schedule 1 and 2 functional
      await provider.deleteBatch('sched-3');
      await provider.fetchCatalog();

      schedules = provider.getBatchesForCourse('c-bpsc-prelims');
      expect(schedules.length, 2);
      expect(schedules.map((s) => s.id), containsAll(['sched-1', 'sched-2']));
      expect(schedules.any((s) => s.id == 'sched-3'), isFalse);
    });

    test('Student enrolls into specific schedule, persisting correct batch ID without capacity block', () async {
      final course = CourseModel(
        id: 'c-jee-maths',
        title: 'JEE Advanced Mathematics',
        category: 'Engineering',
        description: 'Advanced problem solving',
        coverImageUrl: '',
        price: 2999,
        originalPrice: 4999,
        teacherName: 'Er. R.K. Singh',
        teacherId: 't-1',
        totalLessons: 15,
        totalHours: 45,
        totalTests: 3,
        totalNotes: 6,
        highlights: const [],
        isFeatured: true,
      );

      final slotA = BatchModel(
        id: 'batch-slot-a',
        courseId: 'c-jee-maths',
        name: 'Weekend Slot',
        timing: '09:00 AM - 12:00 PM (Sat-Sun)',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 90)),
        teacherName: 'Er. R.K. Singh',
        teacherId: 't-1',
        totalStudents: 100, // Large number of students
        batchPrice: 2999,
      );

      final slotB = BatchModel(
        id: 'batch-slot-b',
        courseId: 'c-jee-maths',
        name: 'Weekday Evening Slot',
        timing: '05:00 PM - 07:00 PM (Mon-Fri)',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 90)),
        teacherName: 'Er. R.K. Singh',
        teacherId: 't-1',
        totalStudents: 200, // Even larger number
        batchPrice: 2999,
      );

      repo.testCourses = [course];
      repo.testBatches = [slotA, slotB];

      // Simulate student enrolling into Slot B
      repo.testEnrollments = {
        'courseIds': ['c-jee-maths'],
        'batchIds': ['batch-slot-b'],
      };

      await provider.fetchCatalog();
      await provider.fetchMyEnrollments();

      expect(provider.myEnrolledCourseIds.contains('c-jee-maths'), isTrue);
      expect(provider.myEnrolledBatchIds.contains('batch-slot-b'), isTrue);
      expect(provider.myEnrolledBatchIds.contains('batch-slot-a'), isFalse);
    });
  });
}
