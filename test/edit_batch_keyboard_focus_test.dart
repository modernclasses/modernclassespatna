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
  group('Edit Batch Keyboard Focus and Interaction Regression Tests', () {
    testWidgets('640x360 Landscape: TextField retains focus when keyboard opens, allows typing, switching fields, and saving without overflow', (tester) async {
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

      // 1. Open dialog in landscape dimensions
      await tester.drag(find.byType(ListView), const Offset(0, -100));
      await tester.pumpAndSettle();

      final editBatchBtn = find.byTooltip('Edit Batch');
      expect(editBatchBtn, findsOneWidget);
      await tester.ensureVisible(editBatchBtn);
      await tester.tap(editBatchBtn);
      await tester.pumpAndSettle();

      expect(find.text('Edit Batch: Morning Batch 1'), findsOneWidget);

      // 2. Tap Batch Name field and request focus
      final nameField = find.widgetWithText(TextField, 'Batch Name *');
      expect(nameField, findsOneWidget);
      await tester.tap(nameField);
      await tester.pumpAndSettle();

      final editableNameBefore = tester.widget<EditableText>(
        find.descendant(of: nameField, matching: find.byType(EditableText)),
      );
      expect(editableNameBefore.focusNode.hasFocus, isTrue, reason: 'Field has focus before keyboard appears');

      // 3. Simulate Android keyboard opening (viewInsets.bottom = 240.0)
      tester.view.viewInsets = const FakeViewPadding(bottom: 240.0);
      await tester.pump();

      // 4. Verify dialog remains mounted and field retains focus
      expect(find.text('Edit Batch: Morning Batch 1'), findsOneWidget, reason: 'Dialog must remain mounted');
      final editableNameAfter = tester.widget<EditableText>(
        find.descendant(of: nameField, matching: find.byType(EditableText)),
      );
      expect(editableNameAfter.focusNode.hasFocus, isTrue, reason: 'Field MUST retain focus when keyboard opens');

      // 5. Enter text and verify value persists
      await tester.enterText(nameField, 'Super Morning Batch Alpha');
      await tester.pump();
      expect(find.text('Super Morning Batch Alpha'), findsOneWidget);

      // 6. Tap another field (Batch Fee) and verify it receives focus smoothly without dismissing dialog
      final feeField = find.widgetWithText(TextField, 'Batch Fee (₹) *');
      expect(feeField, findsOneWidget);
      await tester.ensureVisible(feeField);
      await tester.tap(feeField);
      await tester.pump();

      final editableFee = tester.widget<EditableText>(
        find.descendant(of: feeField, matching: find.byType(EditableText)),
      );
      expect(editableFee.focusNode.hasFocus, isTrue, reason: 'Fee field receives focus cleanly');

      await tester.enterText(feeField, '2999');
      await tester.pump();
      expect(find.text('2999'), findsOneWidget);

      // 7. Verify zero layout overflow exceptions under keyboard
      expect(firstError, isNull, reason: 'No RenderFlex overflow allowed with keyboard open in landscape');

      // 8. Lower keyboard and tap Save Changes
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();

      final saveBtn = find.text('Save Changes');
      expect(saveBtn, findsOneWidget);
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify dialog saved and closed cleanly
      expect(find.text('Edit Batch: Morning Batch 1'), findsNothing);
      expect(firstError, isNull);

      final updated = mockRepo.batches.firstWhere((b) => b.id == 'b-100');
      expect(updated.name, 'Super Morning Batch Alpha');
      expect(updated.batchPrice, 2999.0);
    });

    testWidgets('1920x1080 @ 450dpi Real Physical Landscape: Field retains focus under Gboard insets, Cancel dismisses cleanly', (tester) async {
      FlutterErrorDetails? firstError;
      final orig = FlutterError.onError;
      FlutterError.onError = (d) {
        firstError ??= d;
        FlutterError.dumpErrorToConsole(d);
      };
      addTearDown(() => FlutterError.onError = orig);

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
      await tester.ensureVisible(editBatchBtn);
      await tester.tap(editBatchBtn);
      await tester.pumpAndSettle();

      expect(find.text('Edit Batch: Rangdari batch - Slot 1'), findsOneWidget);

      final nameField = find.widgetWithText(TextField, 'Batch Name *');
      await tester.tap(nameField);
      await tester.pumpAndSettle();

      // Gboard keyboard opens with 265 logical px
      tester.view.viewInsets = const FakeViewPadding(bottom: 265.0);
      await tester.pump();

      // Verify focus is retained
      final editable = tester.widget<EditableText>(
        find.descendant(of: nameField, matching: find.byType(EditableText)),
      );
      expect(editable.focusNode.hasFocus, isTrue, reason: 'Field retains focus on physical device specs');
      expect(firstError, isNull);

      // Verify Cancel works cleanly
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();

      final cancelBtn = find.text('Cancel');
      await tester.ensureVisible(cancelBtn);
      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();

      expect(find.text('Edit Batch: Rangdari batch - Slot 1'), findsNothing);
      expect(firstError, isNull);
    });
  });
}
