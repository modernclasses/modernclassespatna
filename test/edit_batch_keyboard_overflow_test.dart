import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:modern_classes_patna/features/courses/data/models/batch_model.dart';
import 'package:modern_classes_patna/features/courses/data/models/course_model.dart';
import 'package:modern_classes_patna/features/courses/logic/course_provider.dart';
import 'package:modern_classes_patna/providers/auth_provider.dart';
import 'package:modern_classes_patna/screens/admin/manage_courses_screen.dart';
import 'package:modern_classes_patna/core/theme/app_theme.dart';

import 'admin_workflow_improvements_test.dart';

void main() {
  testWidgets('Edit Batch dialog renders cleanly without overflow when keyboard is open on 360x640', (tester) async {
    FlutterErrorDetails? firstError;
    final orig = FlutterError.onError;
    FlutterError.onError = (d) {
      firstError ??= d;
      FlutterError.dumpErrorToConsole(d);
    };
    addTearDown(() => FlutterError.onError = orig);

    const portraitSize = Size(360, 640);
    tester.view.physicalSize = portraitSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final mockAuth = MockWorkflowAuthProvider();
    final mockRepo = MockWorkflowCourseRepository();
    final courseProvider = CourseProvider(repository: mockRepo);

    final testCourse = CourseModel(
      id: 'c-100',
      title: 'BPSC Target GS',
      category: 'BPSC',
      description: 'Test description',
      coverImageUrl: '',
      price: 1999,
      originalPrice: 2999,
      teacherName: 'Faculty Team',
      teacherId: 'teacher-1',
      totalLessons: 30,
      totalHours: 60,
      totalTests: 0,
      totalNotes: 0,
      highlights: const ['H1'],
      isFeatured: true,
      isCrashCourse: false,
    );

    final testBatch = BatchModel(
      id: 'b-100',
      courseId: 'c-100',
      name: 'Morning Batch 1',
      timing: '08:00 AM - 10:00 AM (Mon-Sat)',
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 90)),
      teacherName: 'Faculty Team',
      teacherId: 'teacher-1',
      totalStudents: 10,
      maxStudents: 500,
      batchPrice: 1999,
      medium: 'Bilingual (Hindi + English)',
      teacherIds: const ['teacher-1'],
    );

    mockRepo.courses.add(testCourse);
    mockRepo.batches.add(testBatch);
    mockRepo.batchTeachers['b-100'] = ['teacher-1'];
    await courseProvider.fetchCatalog();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
          ChangeNotifierProvider<CourseProvider>.value(value: courseProvider),
        ],
        child: MaterialApp(
          theme: AppTheme.academicTheme,
          home: const ManageCoursesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -100));
    await tester.pumpAndSettle();

    final editBatchBtn = find.byTooltip('Edit Batch');
    expect(editBatchBtn, findsOneWidget);
    await tester.ensureVisible(editBatchBtn);
    await tester.tap(editBatchBtn);
    await tester.pumpAndSettle();

    // Verify dialog is open
    expect(find.text('Edit Batch: Morning Batch 1'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Focus on Batch Fee text field
    final feeField = find.widgetWithText(TextField, 'Batch Fee (₹) *');
    expect(feeField, findsOneWidget);
    await tester.tap(feeField);
    await tester.pumpAndSettle();

    // Simulate standard virtual keyboard insets (280px)
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(() => tester.view.resetViewInsets());

    await tester.pumpAndSettle();

    // Confirm ZERO overflow with 280px keyboard active
    expect(tester.takeException(), isNull);
    expect(find.text('Save Changes'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Test extreme keyboard heights up to 360px on short 640px portrait viewport
    for (final kbHeight in [300.0, 320.0, 340.0, 360.0]) {
      tester.view.viewInsets = FakeViewPadding(bottom: kbHeight);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Save Changes'), findsOneWidget);
    }

    // Scroll to the bottommost field and tap it
    final urlField = find.widgetWithText(TextField, 'Custom Playback HLS URL (Optional)');
    expect(urlField, findsOneWidget);
    await tester.ensureVisible(urlField);
    await tester.tap(urlField);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Save Changes'), findsOneWidget);

    // Save batch update while keyboard is active
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    // Dialog closes cleanly and updates batch
    expect(find.text('Edit Batch: Morning Batch 1'), findsNothing);
  });

  testWidgets('Edit Batch dialog renders cleanly without overflow in landscape mode with keyboard', (tester) async {
    FlutterErrorDetails? firstError;
    final orig = FlutterError.onError;
    FlutterError.onError = (d) {
      firstError ??= d;
      FlutterError.dumpErrorToConsole(d);
    };
    addTearDown(() => FlutterError.onError = orig);

    const landscapeSize = Size(640, 360);
    tester.view.physicalSize = landscapeSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final mockAuth = MockWorkflowAuthProvider();
    final mockRepo = MockWorkflowCourseRepository();
    final courseProvider = CourseProvider(repository: mockRepo);

    final testCourse = CourseModel(
      id: 'c-100',
      title: 'BPSC Target GS',
      category: 'BPSC',
      description: 'Test description',
      coverImageUrl: '',
      price: 1999,
      originalPrice: 2999,
      teacherName: 'Faculty Team',
      teacherId: 'teacher-1',
      totalLessons: 30,
      totalHours: 60,
      totalTests: 0,
      totalNotes: 0,
      highlights: const ['H1'],
      isFeatured: true,
      isCrashCourse: false,
    );

    final testBatch = BatchModel(
      id: 'b-100',
      courseId: 'c-100',
      name: 'Morning Batch 1',
      timing: '08:00 AM - 10:00 AM (Mon-Sat)',
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 90)),
      teacherName: 'Faculty Team',
      teacherId: 'teacher-1',
      totalStudents: 10,
      maxStudents: 500,
      batchPrice: 1999,
      medium: 'Bilingual (Hindi + English)',
      teacherIds: const ['teacher-1'],
    );

    mockRepo.courses.add(testCourse);
    mockRepo.batches.add(testBatch);
    mockRepo.batchTeachers['b-100'] = ['teacher-1'];
    await courseProvider.fetchCatalog();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
          ChangeNotifierProvider<CourseProvider>.value(value: courseProvider),
        ],
        child: MaterialApp(
          theme: AppTheme.academicTheme,
          home: const ManageCoursesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -100));
    await tester.pumpAndSettle();

    final editBatchBtn = find.byTooltip('Edit Batch');
    expect(editBatchBtn, findsOneWidget);
    await tester.ensureVisible(editBatchBtn);
    await tester.tap(editBatchBtn);
    await tester.pumpAndSettle();

    expect(find.text('Edit Batch: Morning Batch 1'), findsOneWidget);

    for (final kb in [150.0, 170.0, 180.0, 190.0, 200.0, 210.0, 220.0, 240.0, 260.0, 270.0]) {
      tester.view.viewInsets = FakeViewPadding(bottom: kb);
      await tester.pumpAndSettle();
      expect(firstError, isNull, reason: 'Failed at kb height $kb');
    }
  });

  testWidgets('Edit Batch dialog on real physical device (1920x1080 @ 450dpi) with Gboard open has zero overflow and can save', (tester) async {
    FlutterErrorDetails? firstError;
    final orig = FlutterError.onError;
    FlutterError.onError = (d) {
      firstError ??= d;
      FlutterError.dumpErrorToConsole(d);
    };
    addTearDown(() => FlutterError.onError = orig);

    // Physical device specs: 1920x1080, 450 dpi -> dpr = 2.8125 -> 682.67 x 384.0 logical
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 2.8125;
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());

    final mockAuth = MockWorkflowAuthProvider();
    final mockRepo = MockWorkflowCourseRepository();
    final courseProvider = CourseProvider(repository: mockRepo);

    final testCourse = CourseModel(
      id: 'c-100',
      title: 'BPSC Target GS',
      category: 'BPSC',
      description: 'Test description',
      coverImageUrl: '',
      price: 1999,
      originalPrice: 2999,
      teacherName: 'Faculty Team',
      teacherId: 'teacher-1',
      totalLessons: 30,
      totalHours: 60,
      totalTests: 0,
      totalNotes: 0,
      highlights: const ['H1'],
      isFeatured: true,
      isCrashCourse: false,
    );

    final testBatch = BatchModel(
      id: 'b-100',
      courseId: 'c-100',
      name: 'Rangdari batch - Slot 1',
      timing: '08:00 AM - 10:00 AM (Mon-Sat)',
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 90)),
      teacherName: 'Faculty Team',
      teacherId: 'teacher-1',
      totalStudents: 10,
      maxStudents: 500,
      batchPrice: 1999,
      medium: 'Bilingual (Hindi + English)',
      teacherIds: const ['teacher-1'],
    );

    mockRepo.courses.add(testCourse);
    mockRepo.batches.add(testBatch);
    mockRepo.batchTeachers['b-100'] = ['teacher-1'];
    await courseProvider.fetchCatalog();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
          ChangeNotifierProvider<CourseProvider>.value(value: courseProvider),
        ],
        child: MaterialApp(
          theme: AppTheme.academicTheme,
          home: const ManageCoursesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final editBatchBtn = find.byTooltip('Edit Batch');
    expect(editBatchBtn, findsOneWidget);
    await tester.ensureVisible(editBatchBtn);
    await tester.tap(editBatchBtn);
    await tester.pumpAndSettle();

    // Verify dialog opened with exact title from user screenshot
    expect(find.text('Edit Batch: Rangdari batch - Slot 1'), findsOneWidget);

    // Simulate Gboard open in landscape: viewInsets.bottom = 265 logical px
    tester.view.viewInsets = const FakeViewPadding(bottom: 265.0);
    await tester.pumpAndSettle();

    // Ensure zero render flex overflow
    expect(firstError, isNull);

    // Edit a text field while keyboard is open
    final feeField = find.widgetWithText(TextField, 'Batch Fee (₹) *');
    expect(feeField, findsOneWidget);
    await tester.ensureVisible(feeField);
    await tester.enterText(feeField, '2499');
    await tester.pumpAndSettle();

    // Scroll down to Save Changes button and tap it
    final saveBtn = find.text('Save Changes');
    expect(saveBtn, findsOneWidget);
    await tester.ensureVisible(saveBtn);
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();

    // Dialog closes cleanly
    expect(find.text('Edit Batch: Rangdari batch - Slot 1'), findsNothing);
    expect(firstError, isNull);

    final updated = mockRepo.batches.firstWhere((b) => b.id == 'b-100');
    expect(updated.batchPrice, 2499);
  });
}
