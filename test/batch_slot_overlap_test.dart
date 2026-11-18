import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:modern_classes_patna/core/utils/batch_timing_helper.dart';
import 'package:modern_classes_patna/core/widgets/batch_timing_picker_dialog.dart';
import 'package:modern_classes_patna/features/courses/data/models/batch_model.dart';
import 'package:modern_classes_patna/features/courses/data/models/course_model.dart';
import 'package:modern_classes_patna/features/courses/data/repositories/course_repository.dart';
import 'package:modern_classes_patna/features/courses/logic/course_provider.dart';
import 'package:modern_classes_patna/features/auth/logic/auth_provider.dart';
import 'package:modern_classes_patna/features/auth/presentation/screens/student_register_screen.dart';

class MockCourseRepository implements CourseRepository {
  List<CourseModel> courses = [];
  List<BatchModel> batches = [];

  @override
  Future<List<CourseModel>> getCourses() async => List.from(courses);

  @override
  Future<List<BatchModel>> getBatches() async => List.from(batches);

  @override
  Future<void> createBatch(BatchModel batch, {List<String>? teacherIds}) async {
    batches.add(batch);
  }

  @override
  Future<void> updateBatch(BatchModel batch, {List<String>? teacherIds}) async {
    final idx = batches.indexWhere((b) => b.id == batch.id);
    if (idx != -1) batches[idx] = batch;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  bool get isLoading => false;
  @override
  String? get errorMessage => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('BatchTimingHelper - Course Slot Overlap Detection', () {
    test('User exact example: 04:00 PM - 06:00 PM vs 04:30 PM - 06:00 PM overlaps', () {
      const slot1 = "04:00 PM - 06:00 PM (Mon-Sat)";
      const slot2 = "04:30 PM - 06:00 PM (Mon-Sat)";
      expect(BatchTimingHelper.doTimingsOverlap(slot1, slot2), isTrue);
      expect(BatchTimingHelper.doTimingsOverlap(slot2, slot1), isTrue);
    });

    test('Partial overlap earlier: 04:00 PM - 06:00 PM vs 03:00 PM - 04:30 PM overlaps', () {
      const slot1 = "04:00 PM - 06:00 PM (Mon-Sat)";
      const slot2 = "03:00 PM - 04:30 PM (Mon-Sat)";
      expect(BatchTimingHelper.doTimingsOverlap(slot1, slot2), isTrue);
    });

    test('Complete containment: 02:00 PM - 06:00 PM vs 03:00 PM - 04:00 PM overlaps', () {
      const slot1 = "02:00 PM - 06:00 PM (Mon-Sat)";
      const slot2 = "03:00 PM - 04:00 PM (Mon-Sat)";
      expect(BatchTimingHelper.doTimingsOverlap(slot1, slot2), isTrue);
    });

    test('Exact match: 04:00 PM - 06:00 PM vs 04:00 PM - 06:00 PM overlaps', () {
      const slot1 = "04:00 PM - 06:00 PM (Mon-Sat)";
      const slot2 = "04:00 PM - 06:00 PM (Mon-Sat)";
      expect(BatchTimingHelper.doTimingsOverlap(slot1, slot2), isTrue);
    });

    test('Back-to-back classes do NOT overlap (4-6 PM and 6-8 PM)', () {
      const slot1 = "04:00 PM - 06:00 PM (Mon-Sat)";
      const slot2 = "06:00 PM - 08:00 PM (Mon-Sat)";
      expect(BatchTimingHelper.doTimingsOverlap(slot1, slot2), isFalse);
    });

    test('Disjoint times do NOT overlap (8-10 AM and 4-6 PM)', () {
      const slot1 = "08:00 AM - 10:00 AM (Mon-Sat)";
      const slot2 = "04:00 PM - 06:00 PM (Mon-Sat)";
      expect(BatchTimingHelper.doTimingsOverlap(slot1, slot2), isFalse);
    });

    test('Same hours on different days do NOT overlap', () {
      const slot1 = "04:00 PM - 06:00 PM (Mon, Wed, Fri)";
      const slot2 = "04:00 PM - 06:00 PM (Tue, Thu, Sat)";
      expect(BatchTimingHelper.doTimingsOverlap(slot1, slot2), isFalse);
    });

    test('findOverlappingTiming returns conflicting slot string', () {
      final existing = [
        "08:00 AM - 10:00 AM (Mon-Sat)",
        "04:00 PM - 06:00 PM (Mon-Sat)",
      ];
      final conflict = BatchTimingHelper.findOverlappingTiming(
        "04:30 PM - 06:00 PM (Mon-Sat)",
        existing,
      );
      expect(conflict, equals("04:00 PM - 06:00 PM (Mon-Sat)"));
    });

    test('validateNoSlotOverlap returns error message for conflicting slots', () {
      final existing = ["04:00 PM - 06:00 PM (Mon-Sat)"];
      final err = BatchTimingHelper.validateNoSlotOverlap(
        "05:00 PM - 07:00 PM (Mon-Sat)",
        existing,
      );
      expect(err, isNotNull);
      expect(err, contains("Timing overlaps with an existing course slot"));
    });
  });

  group('CourseProvider - Overlap Guard on Batches', () {
    test('CourseProvider.addBatch throws when adding overlapping slot for same course', () async {
      final repo = MockCourseRepository();
      final provider = CourseProvider(repository: repo);

      // Add slot 1: 4 to 6 PM
      final batch1 = BatchModel(
        id: "b1",
        courseId: "c1",
        name: "Slot 1",
        timing: "04:00 PM - 06:00 PM (Mon-Sat)",
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 90)),
        teacherName: "Faculty",
        teacherId: "t1",
        totalStudents: 0,
        maxStudents: 500,
        batchPrice: 999,
        medium: "Bilingual",
      );
      await provider.addBatch(batch1);

      // Try adding overlapping slot 2: 4:30 to 6 PM
      final batch2 = BatchModel(
        id: "b2",
        courseId: "c1",
        name: "Slot 2",
        timing: "04:30 PM - 06:00 PM (Mon-Sat)",
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 90)),
        teacherName: "Faculty",
        teacherId: "t1",
        totalStudents: 0,
        maxStudents: 500,
        batchPrice: 999,
        medium: "Bilingual",
      );

      expect(() => provider.addBatch(batch2), throwsA(isA<Exception>()));
    });
  });

  group('BatchTimingPickerDialog - UI Overlap Prevention', () {
    testWidgets('Displays conflict banner and disables Apply Schedule button when overlapping', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BatchTimingPickerDialog(
              initialTiming: "04:30 PM - 06:00 PM (Mon-Sat)",
              existingTimings: const ["04:00 PM - 06:00 PM (Mon-Sat)"],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify conflict banner is visible
      expect(find.textContaining("Overlaps with existing course slot"), findsOneWidget);
      expect(find.textContaining("04:00 PM - 06:00 PM (Mon-Sat)"), findsOneWidget);

      // Verify Apply Schedule button is disabled
      final applyButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, "Apply Schedule"),
      );
      expect(applyButton.onPressed, isNull);
    });
  });

  group('StudentRegisterScreen - 2.8px Overflow Resolution', () {
    testWidgets('Header Column in StudentRegisterScreen renders with 0 overflow on 320px narrow viewport', (tester) async {
      final mockAuth = MockAuthProvider();
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      FlutterErrorDetails? errorDetails;
      final oldOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errorDetails = details;
      };

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
          ],
          child: const MaterialApp(
            home: StudentRegisterScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      FlutterError.onError = oldOnError;

      if (errorDetails != null) {
        debugPrint("ERROR DETAILS:\n${errorDetails.toString()}");
      }

      expect(find.text("Create Student Account"), findsOneWidget);
      expect(find.text("Join Modern Classes Patna academic community"), findsOneWidget);
      expect(errorDetails, isNull);
    });
  });
}
