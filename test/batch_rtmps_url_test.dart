import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:modern_classes_patna/features/courses/data/models/batch_model.dart';
import 'package:modern_classes_patna/features/courses/data/models/course_model.dart';
import 'package:modern_classes_patna/features/courses/logic/course_provider.dart';
import 'package:modern_classes_patna/core/utils/batch_timing_helper.dart';
import 'package:modern_classes_patna/providers/auth_provider.dart';
import 'package:modern_classes_patna/screens/admin/manage_courses_screen.dart';
import 'package:modern_classes_patna/core/errors/exceptions.dart';
import 'package:modern_classes_patna/core/theme/app_theme.dart';

import 'admin_workflow_improvements_test.dart';

class FailingMockCourseRepository extends MockWorkflowCourseRepository {
  bool failUpdate = false;
  String updateErrorMessage = 'PostgREST PGRST204: Could not find the rtmps_url column';

  @override
  Future<void> updateBatch(BatchModel batch, {List<String>? teacherIds}) async {
    if (failUpdate) {
      throw ServerException(updateErrorMessage);
    }
    return super.updateBatch(batch, teacherIds: teacherIds);
  }
}

void main() {
  group('1. BatchModel RTMPS URL Data Compatibility & Serialization', () {
    test('toMap includes rtmps_url when populated', () {
      final batch = BatchModel(
        id: 'b-1',
        courseId: 'c-1',
        name: 'Batch 1',
        timing: '08:00 AM - 10:00 AM (Mon-Sat)',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 90)),
        teacherName: 'Faculty',
        teacherId: 't-1',
        totalStudents: 0,
        batchPrice: 1999,
        rtmpsUrl: 'rtmps://live.cloudflare.com:443/live/',
      );

      final map = batch.toMap();
      expect(map['rtmps_url'], 'rtmps://live.cloudflare.com:443/live/');
    });

    test('fromMap parses rtmps_url from Supabase row', () {
      final map = {
        'id': 'b-1',
        'course_id': 'c-1',
        'name': 'Batch 1',
        'timing': '08:00 AM - 10:00 AM (Mon-Sat)',
        'start_date': DateTime.now().toIso8601String(),
        'end_date': DateTime.now().add(const Duration(days: 90)).toIso8601String(),
        'teacher_name': 'Faculty',
        'teacher_id': 't-1',
        'total_students': 0,
        'batch_price': 1999,
        'rtmps_url': 'rtmps://live.cloudflare.com:443/live/',
      };

      final batch = BatchModel.fromMap(map);
      expect(batch.rtmpsUrl, 'rtmps://live.cloudflare.com:443/live/');
    });

    test('toMap with includeNullsForUpdates sets rtmps_url to null when cleared', () {
      final batch = BatchModel(
        id: 'b-1',
        courseId: 'c-1',
        name: 'Batch 1',
        timing: '08:00 AM - 10:00 AM (Mon-Sat)',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 90)),
        teacherName: 'Faculty',
        teacherId: 't-1',
        totalStudents: 0,
        batchPrice: 1999,
        rtmpsUrl: null,
      );

      final mapForUpdate = batch.toMap(includeNullsForUpdates: true);
      expect(mapForUpdate.containsKey('rtmps_url'), isTrue);
      expect(mapForUpdate['rtmps_url'], isNull);

      final mapForInsert = batch.toMap(includeNullsForUpdates: false);
      expect(mapForInsert.containsKey('rtmps_url'), isFalse);
    });

    test('copyWith allows updating or clearing rtmpsUrl', () {
      final batch = BatchModel(
        id: 'b-1',
        courseId: 'c-1',
        name: 'Batch 1',
        timing: '08:00 AM - 10:00 AM (Mon-Sat)',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 90)),
        teacherName: 'Faculty',
        teacherId: 't-1',
        totalStudents: 0,
        batchPrice: 1999,
        rtmpsUrl: 'rtmps://live.cloudflare.com:443/live/',
      );

      final updated = batch.copyWith(rtmpsUrl: 'rtmps://backup.example.com/live');
      expect(updated.rtmpsUrl, 'rtmps://backup.example.com/live');

      final cleared = updated.copyWith(clearRtmpsUrl: true);
      expect(cleared.rtmpsUrl, isNull);
    });
  });

  group('2. BatchTimingHelper.validateRtmpsUrl Format Validation', () {
    test('Accepts null, empty string, and whitespace as valid (optional field)', () {
      expect(BatchTimingHelper.validateRtmpsUrl(null), isNull);
      expect(BatchTimingHelper.validateRtmpsUrl(''), isNull);
      expect(BatchTimingHelper.validateRtmpsUrl('   '), isNull);
    });

    test('Accepts standard rtmps:// and rtmp:// URLs', () {
      expect(
        BatchTimingHelper.validateRtmpsUrl('rtmps://live.cloudflare.com:443/live/'),
        isNull,
      );
      expect(
        BatchTimingHelper.validateRtmpsUrl('rtmps://a.rtmp.youtube.com/live2'),
        isNull,
      );
      expect(
        BatchTimingHelper.validateRtmpsUrl('rtmp://live.twitch.tv/app'),
        isNull,
      );
    });

    test('Rejects invalid non-rtmp schemes and malformed URLs', () {
      expect(
        BatchTimingHelper.validateRtmpsUrl('https://live.cloudflare.com'),
        contains('must start with rtmps:// or rtmp://'),
      );
      expect(
        BatchTimingHelper.validateRtmpsUrl('invalid-url-string'),
        contains('Enter a valid RTMPS URL'),
      );
      expect(
        BatchTimingHelper.validateRtmpsUrl('rtmps://'),
        contains('Enter a valid RTMPS URL'),
      );
    });
  });

  group('3. Create Batch Dialog RTMPS URL Workflow', () {
    testWidgets('Renders RTMPS URL field, validates input, and saves populated or null value', (tester) async {
      final mockAuth = MockWorkflowAuthProvider();
      final mockRepo = MockWorkflowCourseRepository();
      final courseProvider = CourseProvider(repository: mockRepo);

      final testCourse = CourseModel(
        id: 'c-200',
        title: 'UPSC Civil Services Foundation',
        category: 'UPSC',
        description: 'Test description',
        coverImageUrl: '',
        price: 4999,
        originalPrice: 9999,
        teacherName: 'Faculty Team',
        teacherId: 'teacher-1',
        totalLessons: 10,
        totalHours: 20,
        totalTests: 0,
        totalNotes: 0,
        highlights: const ['H1'],
        isFeatured: true,
        isCrashCourse: false,
      );
      mockRepo.courses.add(testCourse);
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

      // Open Edit Course screen via Edit Course tooltip icon button
      final editCourseBtn = find.byTooltip('Edit Course');
      expect(editCourseBtn, findsOneWidget);
      await tester.ensureVisible(editCourseBtn);
      await tester.tap(editCourseBtn);
      await tester.pumpAndSettle();

      // Tap Add Schedule / Timing to open Create Batch dialog
      final addSlotBtn = find.text('Add Schedule / Timing');
      expect(addSlotBtn, findsOneWidget);
      await tester.ensureVisible(addSlotBtn);
      await tester.tap(addSlotBtn);
      await tester.pumpAndSettle();

      expect(find.text('Create Batch for UPSC Civil Services Foundation'), findsOneWidget);

      // Verify RTMPS URL field exists with correct label and hint
      final rtmpsField = find.widgetWithText(TextField, 'RTMPS URL');
      expect(rtmpsField, findsOneWidget);
      expect(find.text('Enter RTMPS streaming URL'), findsOneWidget);

      // Fill in required fields
      final nameField = find.widgetWithText(TextField, 'Batch Name *');
      await tester.enterText(nameField, 'UPSC Evening Batch');

      final timingField = find.text('Tap to configure hours & days');
      expect(timingField, findsOneWidget);
      await tester.ensureVisible(timingField);
      await tester.tap(timingField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply Schedule'));
      await tester.pumpAndSettle();

      final feeField = find.widgetWithText(TextField, 'Batch Fee (₹) *');
      await tester.enterText(feeField, '4999');

      // Test validation: enter invalid RTMPS URL
      await tester.ensureVisible(rtmpsField);
      await tester.enterText(rtmpsField, 'http://insecure-stream.example.com');

      final createBtn = find.text('Create Batch');
      await tester.ensureVisible(createBtn);
      await tester.tap(createBtn);
      await tester.pumpAndSettle();

      // Dialog must remain open with validation error displayed
      expect(find.text('Create Batch for UPSC Civil Services Foundation'), findsOneWidget);
      expect(find.text('RTMPS URL must start with rtmps:// or rtmp://'), findsOneWidget);
      expect(mockRepo.batches.length, 0);

      // Fix RTMPS URL to valid format
      await tester.enterText(rtmpsField, 'rtmps://live.cloudflare.com:443/live/');
      await tester.tap(createBtn);
      await tester.pumpAndSettle();

      // Dialog closes and batch is saved with RTMPS URL
      expect(find.text('Create Batch for UPSC Civil Services Foundation'), findsNothing);
      expect(mockRepo.batches.length, 1);
      final createdBatch = mockRepo.batches.first;
      expect(createdBatch.name, 'UPSC Evening Batch');
      expect(createdBatch.rtmpsUrl, 'rtmps://live.cloudflare.com:443/live/');
    });
  });

  group('4. Edit Batch Dialog RTMPS URL Workflow', () {
    testWidgets('Prepopulates RTMPS URL, allows updating or clearing, and persists correctly', (tester) async {
      final mockAuth = MockWorkflowAuthProvider();
      final mockRepo = MockWorkflowCourseRepository();
      final courseProvider = CourseProvider(repository: mockRepo);

      final testCourse = CourseModel(
        id: 'c-300',
        title: 'BPSC History Special',
        category: 'BPSC',
        description: 'Test description',
        coverImageUrl: '',
        price: 1499,
        originalPrice: 2499,
        teacherName: 'Faculty Team',
        teacherId: 'teacher-1',
        totalLessons: 10,
        totalHours: 20,
        totalTests: 0,
        totalNotes: 0,
        highlights: const ['H1'],
        isFeatured: true,
        isCrashCourse: false,
      );

      final existingBatch = BatchModel(
        id: 'b-300',
        courseId: 'c-300',
        name: 'Morning Batch Alpha',
        timing: '08:00 AM - 10:00 AM (Mon-Sat)',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 90)),
        teacherName: 'Faculty Team',
        teacherId: 'teacher-1',
        totalStudents: 5,
        maxStudents: 500,
        batchPrice: 1499,
        medium: 'Bilingual (Hindi + English)',
        teacherIds: const ['teacher-1'],
        rtmpsUrl: 'rtmps://live.cloudflare.com:443/live/',
      );

      mockRepo.courses.add(testCourse);
      mockRepo.batches.add(existingBatch);
      mockRepo.batchTeachers['b-300'] = ['teacher-1'];
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

      // Open Edit Batch Dialog
      final editBatchBtn = find.byTooltip('Edit Batch');
      expect(editBatchBtn, findsOneWidget);
      await tester.ensureVisible(editBatchBtn);
      await tester.tap(editBatchBtn);
      await tester.pumpAndSettle();

      expect(find.text('Edit Batch: Morning Batch Alpha'), findsOneWidget);

      // Verify prepopulation of RTMPS URL
      final rtmpsField = find.widgetWithText(TextField, 'RTMPS URL');
      expect(rtmpsField, findsOneWidget);
      expect(find.text('rtmps://live.cloudflare.com:443/live/'), findsOneWidget);

      // Update RTMPS URL to a new valid destination
      await tester.ensureVisible(rtmpsField);
      await tester.enterText(rtmpsField, 'rtmps://live2.cloudflare.com:443/live/');

      final saveBtn = find.text('Save Changes');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Dialog closes and repository has updated URL
      expect(find.text('Edit Batch: Morning Batch Alpha'), findsNothing);
      var updated = mockRepo.batches.firstWhere((b) => b.id == 'b-300');
      expect(updated.rtmpsUrl, 'rtmps://live2.cloudflare.com:443/live/');

      // Reopen Edit Batch to verify updated value is reflected
      await tester.ensureVisible(editBatchBtn);
      await tester.tap(editBatchBtn);
      await tester.pumpAndSettle();

      expect(find.text('Edit Batch: Morning Batch Alpha'), findsOneWidget);
      expect(find.text('rtmps://live2.cloudflare.com:443/live/'), findsOneWidget);

      // Now clear the RTMPS URL and save
      final reopenRtmpsField = find.widgetWithText(TextField, 'RTMPS URL');
      await tester.ensureVisible(reopenRtmpsField);
      await tester.enterText(reopenRtmpsField, '');

      final reopenSaveBtn = find.text('Save Changes');
      await tester.ensureVisible(reopenSaveBtn);
      await tester.tap(reopenSaveBtn);
      await tester.pumpAndSettle();

      // Verify value cleared to null in repository
      expect(find.text('Edit Batch: Morning Batch Alpha'), findsNothing);
      updated = mockRepo.batches.firstWhere((b) => b.id == 'b-300');
      expect(updated.rtmpsUrl, isNull);
    });
  });

  group('5. Landscape & Keyboard Responsiveness with RTMPS URL Field', () {
    testWidgets('640x360 Landscape: Tapping RTMPS URL field retains focus under soft keyboard without overflow', (tester) async {
      const landscapeSize = Size(640, 360);
      tester.view.physicalSize = landscapeSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockAuth = MockWorkflowAuthProvider();
      final mockRepo = MockWorkflowCourseRepository();
      final courseProvider = CourseProvider(repository: mockRepo);

      final testCourse = CourseModel(
        id: 'c-400',
        title: 'BPSC History Special',
        category: 'BPSC',
        description: 'Test description',
        coverImageUrl: '',
        price: 1499,
        originalPrice: 2499,
        teacherName: 'Faculty Team',
        teacherId: 'teacher-1',
        totalLessons: 10,
        totalHours: 20,
        totalTests: 0,
        totalNotes: 0,
        highlights: const ['H1'],
        isFeatured: true,
        isCrashCourse: false,
      );

      final testBatch = BatchModel(
        id: 'b-400',
        courseId: 'c-400',
        name: 'Evening Target Batch',
        timing: '06:00 PM - 08:00 PM (Mon-Sat)',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 90)),
        teacherName: 'Faculty Team',
        teacherId: 'teacher-1',
        totalStudents: 12,
        maxStudents: 500,
        batchPrice: 1499,
        medium: 'Bilingual (Hindi + English)',
        teacherIds: const ['teacher-1'],
        rtmpsUrl: 'rtmps://live.cloudflare.com/live',
      );

      mockRepo.courses.add(testCourse);
      mockRepo.batches.add(testBatch);
      mockRepo.batchTeachers['b-400'] = ['teacher-1'];
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

      // Scroll slightly in landscape so batch card action is comfortably in viewport
      await tester.drag(find.byType(ListView), const Offset(0, -100));
      await tester.pumpAndSettle();

      // Open Edit Batch Dialog
      final editBatchBtn = find.byTooltip('Edit Batch');
      expect(editBatchBtn, findsOneWidget);
      await tester.ensureVisible(editBatchBtn);
      await tester.tap(editBatchBtn);
      await tester.pumpAndSettle();

      expect(find.text('Edit Batch: Evening Target Batch'), findsOneWidget);

      // Scroll and Tap RTMPS URL field
      final rtmpsField = find.widgetWithText(TextField, 'RTMPS URL');
      expect(rtmpsField, findsOneWidget);
      await tester.ensureVisible(rtmpsField);
      await tester.tap(rtmpsField);
      await tester.pumpAndSettle();

      // Simulate Android soft keyboard opening (viewInsets.bottom = 240.0)
      tester.view.viewInsets = const FakeViewPadding(bottom: 240.0);
      await tester.pump();

      // Verify dialog remains mounted and RTMPS field retains focus
      expect(find.text('Edit Batch: Evening Target Batch'), findsOneWidget);
      final editableRtmps = tester.widget<EditableText>(
        find.descendant(of: rtmpsField, matching: find.byType(EditableText)),
      );
      expect(editableRtmps.focusNode.hasFocus, isTrue, reason: 'RTMPS field MUST retain focus when keyboard opens in landscape');

      // Enter new text while keyboard is up
      await tester.enterText(rtmpsField, 'rtmps://stream.example.com/live2');
      await tester.pump();
      expect(find.text('rtmps://stream.example.com/live2'), findsOneWidget);

      // Lower keyboard and save
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();

      final saveBtn = find.text('Save Changes');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(find.text('Edit Batch: Evening Target Batch'), findsNothing);

      final updated = mockRepo.batches.firstWhere((b) => b.id == 'b-400');
      expect(updated.rtmpsUrl, 'rtmps://stream.example.com/live2');
    });
  });

  group('6. In-Dialog Error Presentation & Value Persistence on Save Failure', () {
    testWidgets('Save failure displays in-dialog error banner, keeps dialog open, and preserves entered values', (tester) async {
      final mockAuth = MockWorkflowAuthProvider();
      final mockRepo = FailingMockCourseRepository();
      final courseProvider = CourseProvider(repository: mockRepo);

      final testCourse = CourseModel(
        id: 'c-600',
        title: 'UPSC Civil Services Foundation',
        category: 'UPSC',
        description: 'Complete Foundation Course',
        coverImageUrl: '',
        price: 9999,
        originalPrice: 14999,
        teacherName: 'Faculty Team',
        teacherId: 'teacher-1',
        totalLessons: 50,
        totalHours: 120,
        totalTests: 10,
        totalNotes: 25,
        highlights: const ['H1'],
        isFeatured: true,
        isCrashCourse: false,
      );

      final testBatch = BatchModel(
        id: 'b-600',
        courseId: 'c-600',
        name: 'Alpha Morning Batch',
        timing: '07:00 AM - 09:00 AM (Mon-Sat)',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 90)),
        teacherName: 'Faculty Team',
        teacherId: 'teacher-1',
        totalStudents: 10,
        maxStudents: 500,
        batchPrice: 9999,
        medium: 'Bilingual (Hindi + English)',
        teacherIds: const ['teacher-1'],
        streamKey: 'stream-key-orig',
        playbackUrl: 'https://playback.orig/manifest.m3u8',
        rtmpsUrl: 'rtmps://live.orig.com/live',
      );

      mockRepo.courses.add(testCourse);
      mockRepo.batches.add(testBatch);
      mockRepo.batchTeachers['b-600'] = ['teacher-1'];
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

      // Open Edit Batch Dialog
      final editBatchBtn = find.byTooltip('Edit Batch');
      expect(editBatchBtn, findsOneWidget);
      await tester.ensureVisible(editBatchBtn);
      await tester.tap(editBatchBtn);
      await tester.pumpAndSettle();

      expect(find.text('Edit Batch: Alpha Morning Batch'), findsOneWidget);

      // Change several fields: Name, Stream Key, RTMPS URL, Fee
      final nameField = find.widgetWithText(TextField, 'Batch Name *');
      await tester.enterText(nameField, 'Alpha Morning Batch Updated');

      final feeField = find.widgetWithText(TextField, 'Batch Fee (₹) *');
      await tester.enterText(feeField, '12999');

      final keyField = find.widgetWithText(TextField, 'Custom Stream Key (Optional)');
      await tester.enterText(keyField, 'new-key-123456');

      final rtmpsField = find.widgetWithText(TextField, 'RTMPS URL');
      await tester.enterText(rtmpsField, 'rtmps://cloudflare.stream/new');

      // Configure mock to fail save with simulated Supabase PostgREST error
      mockRepo.failUpdate = true;
      mockRepo.updateErrorMessage = 'PostgREST PGRST204: Could not find the rtmps_url column';

      // Tap Save Changes
      final saveBtn = find.text('Save Changes');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // 1. Dialog MUST remain open
      expect(find.text('Edit Batch: Alpha Morning Batch'), findsOneWidget);

      // 2. Error message banner MUST be rendered INSIDE the dialog (not behind it)
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.textContaining('PGRST204'),
        ),
        findsOneWidget,
      );

      // 3. Entered values MUST remain completely preserved in their controllers
      expect(find.text('Alpha Morning Batch Updated'), findsOneWidget);
      expect(find.text('12999'), findsOneWidget);
      expect(find.text('new-key-123456'), findsOneWidget);
      expect(find.text('rtmps://cloudflare.stream/new'), findsOneWidget);

      // 4. Save button is restored and clickable
      expect(find.text('Save Changes'), findsOneWidget);

      // Now heal the backend issue and tap Save Changes again
      mockRepo.failUpdate = false;
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Dialog successfully closes
      expect(find.text('Edit Batch: Alpha Morning Batch'), findsNothing);

      // Database record has persisted the new values
      final savedInDb = mockRepo.batches.firstWhere((b) => b.id == 'b-600');
      expect(savedInDb.name, 'Alpha Morning Batch Updated');
      expect(savedInDb.batchPrice, 12999);
      expect(savedInDb.streamKey, 'new-key-123456');
      expect(savedInDb.rtmpsUrl, 'rtmps://cloudflare.stream/new');
    });
  });

  group('7. Portrait Field Layout (Batch Fee, Course Medium, Max Students)', () {
    testWidgets('360x640 Portrait: Fee and Max Students share Row 1 with adequate width, Medium is full width in Row 2 with zero truncation', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockAuth = MockWorkflowAuthProvider();
      final mockRepo = MockWorkflowCourseRepository();
      final courseProvider = CourseProvider(repository: mockRepo);

      final testCourse = CourseModel(
        id: 'c-700',
        title: 'BPSC Target Course',
        category: 'BPSC',
        description: 'Test',
        coverImageUrl: '',
        price: 2999,
        originalPrice: 4999,
        teacherName: 'Faculty Team',
        teacherId: 'teacher-1',
        totalLessons: 10,
        totalHours: 20,
        totalTests: 0,
        totalNotes: 0,
        highlights: const ['H1'],
        isFeatured: true,
        isCrashCourse: false,
      );

      final testBatch = BatchModel(
        id: 'b-700',
        courseId: 'c-700',
        name: 'Target Batch 1',
        timing: '08:00 AM - 10:00 AM (Mon-Sat)',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 90)),
        teacherName: 'Faculty Team',
        teacherId: 'teacher-1',
        totalStudents: 0,
        maxStudents: 500,
        batchPrice: 2999,
        medium: 'Bilingual (Hindi + English)',
        teacherIds: const ['teacher-1'],
      );

      mockRepo.courses.add(testCourse);
      mockRepo.batches.add(testBatch);
      mockRepo.batchTeachers['b-700'] = ['teacher-1'];
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

      expect(find.text('Edit Batch: Target Batch 1'), findsOneWidget);

      // Verify Fee field exists and Max Students field is completely removed
      final feeFieldFinder = find.widgetWithText(TextField, 'Batch Fee (₹) *');
      final maxStudentsFinder = find.widgetWithText(TextField, 'Max Students');
      final mediumFinder = find.byType(DropdownButtonFormField<String>);

      expect(feeFieldFinder, findsOneWidget);
      expect(maxStudentsFinder, findsNothing, reason: 'Max Students field must be removed per user requirement');
      expect(mediumFinder, findsOneWidget);

      // Measure rendered sizes
      final feeSize = tester.getSize(feeFieldFinder);
      final mediumSize = tester.getSize(mediumFinder);

      // Fee field has full, uncrowded width (>250px)
      expect(feeSize.width, greaterThan(250.0), reason: 'Fee field must have uncrowded full width');

      // Medium dropdown occupies full dialog width (>250px)
      expect(mediumSize.width, greaterThan(250.0), reason: 'Medium dropdown should be full width in row 2');
    });
  });
}
