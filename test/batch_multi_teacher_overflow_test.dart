import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
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

class _LocalTestCourseRepo extends FakeCourseRepository {
  List<CourseModel> courses;
  List<BatchModel> batches;

  _LocalTestCourseRepo({required this.courses, required this.batches});

  @override
  Future<List<CourseModel>> getCourses() async => courses;

  @override
  Future<List<BatchModel>> getBatches() async => batches;

  @override
  Future<void> deleteCourse(String courseId) async {
    courses.removeWhere((c) => c.id == courseId);
    batches.removeWhere((b) => b.courseId == courseId);
  }

  @override
  Future<void> deleteBatch(String batchId) async {
    batches.removeWhere((b) => b.id == batchId);
  }
}

class _LocalTestAuthRepo implements AuthRepository {
  final UserModel? user;
  _LocalTestAuthRepo({this.user});

  @override
  bool get isConnected => true;

  @override
  Future<UserModel?> getInitialSession() async => user;

  @override
  Future<List<UserModel>> getAllProfiles() async {
    return [
      const UserModel(
        id: 't1',
        name: 'Dr. Madhurendra Kumar Yadav',
        email: 't1@patna.org',
        phone: '+91 9999999901',
        role: UserRole.teacher,
      ),
      const UserModel(
        id: 't2',
        name: 'Prof. R.D. Sharma',
        email: 't2@patna.org',
        phone: '+91 9999999902',
        role: UserRole.teacher,
      ),
      const UserModel(
        id: 't3',
        name: 'Dr. H.C. Verma Physics Specialist',
        email: 't3@patna.org',
        phone: '+91 9999999903',
        role: UserRole.teacher,
      ),
      const UserModel(
        id: 't4',
        name: 'Prof. Pradeep Kshetrapal IIT-JEE',
        email: 't4@patna.org',
        phone: '+91 9999999904',
        role: UserRole.teacher,
      ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {

  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('Batch Multi-Teacher Zero-Overflow & Delete CONFIRM Tests', () {
    testWidgets('Class Timings & Batches section has zero overflow with 4 long teacher names on 320px screen', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final course = CourseModel(
        id: 'crs-multi-1',
        title: 'BPSC GS Foundation 2026',
        description: 'Foundation course with faculty team',
        price: 2499,
        originalPrice: 4999,
        category: 'GS Prelims + Mains',
        teacherName: 'Dr. Madhurendra Kumar Yadav, Prof. R.D. Sharma, Dr. H.C. Verma, Prof. Pradeep Kshetrapal',
        teacherId: 't1',
        totalLessons: 60,
        totalHours: 120,
        totalTests: 15,
        totalNotes: 30,
        coverImageUrl: 'https://example.com/cover.png',
        highlights: const ['Live classes', 'PDF notes'],
      );

      final batch = BatchModel(
        id: 'b-multi-1',
        courseId: 'crs-multi-1',
        name: 'Morning Target Batch Slot 1',
        timing: '08:00 AM - 10:00 AM (Mon-Sat)',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 90)),
        teacherName: 'Dr. Madhurendra Kumar Yadav, Prof. R.D. Sharma, Dr. H.C. Verma, Prof. Pradeep Kshetrapal',
        teacherId: 't1',
        totalStudents: 42,
        batchPrice: 2499,
        medium: 'Bilingual (Hindi + English)',
      );

      final repo = _LocalTestCourseRepo(courses: [course], batches: [batch]);
      final courseProvider = CourseProvider(repository: repo);
      await courseProvider.fetchCatalog();

      final authRepo = _LocalTestAuthRepo(
        user: const UserModel(
          id: 'admin_1',
          name: 'Super Admin',
          email: 'admin@patna.org',
          phone: '+91 9999999999',
          role: UserRole.admin,
        ),
      );
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

      // Verify header is present
      expect(find.text('Class Timings & Batches (1)'), findsOneWidget);

      // Verify batch details are present
      expect(find.text('Morning Target Batch Slot 1'), findsOneWidget);
      expect(find.text('08:00 AM - 10:00 AM (Mon-Sat) • Bilingual (Hindi + English)'), findsOneWidget);
      expect(find.text('42 Enrolled'), findsOneWidget);

      // Verify all teachers are rendered in chips without overflowing
      expect(find.text('Dr. Madhurendra Kumar Yadav'), findsOneWidget);
      expect(find.text('Prof. R.D. Sharma'), findsOneWidget);
      expect(find.text('Dr. H.C. Verma'), findsOneWidget);
      expect(find.text('Prof. Pradeep Kshetrapal'), findsOneWidget);

      // Check zero render flex exceptions
      expect(tester.takeException(), isNull);

      // Verify edit batch and delete batch buttons were REMOVED from the batch item row
      expect(find.byTooltip('Delete Timing Slot'), findsNothing);
      expect(find.widgetWithIcon(IconButton, Icons.edit_outlined), findsNothing);
    });

    testWidgets('Delete Batch requires typing CONFIRM before delete button is enabled', (tester) async {
      final course = CourseModel(
        id: 'crs-del-1',
        title: 'BPSC Prelims 2026',
        description: 'Test deletion',
        price: 999,
        originalPrice: 1999,
        category: 'BPSC',
        teacherName: 'Dr. Faculty',
        teacherId: 't1',
        totalLessons: 10,
        totalHours: 20,
        totalTests: 2,
        totalNotes: 5,
        coverImageUrl: 'https://example.com/cover.png',
        highlights: const [],
      );

      final batch1 = BatchModel(
        id: 'b-del-1',
        courseId: 'crs-del-1',
        name: 'Slot 1 Morning',
        timing: '07:00 AM - 09:00 AM (Mon-Sat)',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 60)),
        teacherName: 'Dr. Faculty',
        teacherId: 't1',
        totalStudents: 0,
        batchPrice: 999,
        medium: 'Hindi',
      );

      final batch2 = BatchModel(
        id: 'b-del-2',
        courseId: 'crs-del-1',
        name: 'Slot 2 Evening',
        timing: '05:00 PM - 07:00 PM (Mon-Sat)',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 60)),
        teacherName: 'Dr. Faculty',
        teacherId: 't1',
        totalStudents: 0,
        batchPrice: 999,
        medium: 'English',
      );

      final repo = _LocalTestCourseRepo(courses: [course], batches: [batch1, batch2]);
      final courseProvider = CourseProvider(repository: repo);
      await courseProvider.fetchCatalog();

      final authRepo = _LocalTestAuthRepo(
        user: const UserModel(
          id: 'admin_1',
          name: 'Admin',
          email: 'admin@patna.org',
          phone: '+91 9999999999',
          role: UserRole.admin,
        ),
      );
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

      // Open Edit Dialog for batch 2 by tapping its batch card
      await tester.tap(find.text('Slot 2 Evening'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Batch: Slot 2 Evening'), findsOneWidget);

      // Verify "Delete Batch" button is visible because batches > 1
      final deleteBatchBtn = find.text('Delete Batch');
      expect(deleteBatchBtn, findsOneWidget);

      await tester.tap(deleteBatchBtn);
      await tester.pumpAndSettle();

      // Confirmation dialog is shown
      expect(find.text('Delete Batch?'), findsOneWidget);
      expect(find.text('Type CONFIRM to proceed with deletion:'), findsOneWidget);

      // The "Delete Batch" button in the confirmation dialog should initially be disabled
      final confirmDeleteBtnFinder = find.widgetWithText(ElevatedButton, 'Delete Batch');
      expect(confirmDeleteBtnFinder, findsOneWidget);
      ElevatedButton deleteBtnWidget = tester.widget<ElevatedButton>(confirmDeleteBtnFinder);
      expect(deleteBtnWidget.onPressed, isNull, reason: 'Delete button must be disabled before typing CONFIRM');

      // Type partial or wrong text
      await tester.enterText(find.widgetWithText(TextField, 'CONFIRM'), 'confirm');
      await tester.pumpAndSettle();
      deleteBtnWidget = tester.widget<ElevatedButton>(confirmDeleteBtnFinder);
      expect(deleteBtnWidget.onPressed, isNull, reason: 'Must be exact uppercase CONFIRM');

      // Type exact CONFIRM
      await tester.enterText(find.widgetWithText(TextField, 'CONFIRM'), 'CONFIRM');
      await tester.pumpAndSettle();
      deleteBtnWidget = tester.widget<ElevatedButton>(confirmDeleteBtnFinder);
      expect(deleteBtnWidget.onPressed, isNotNull, reason: 'Delete button must be enabled once CONFIRM is entered');

      // Tap delete
      await tester.tap(confirmDeleteBtnFinder);
      await tester.pumpAndSettle();

      // Batch 2 was deleted from repo
      expect(repo.batches.any((b) => b.id == 'b-del-2'), isFalse);
    });
  });
}
