import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:modern_classes_patna/core/errors/exceptions.dart';
import 'package:modern_classes_patna/core/utils/formatters.dart';
import 'package:modern_classes_patna/features/courses/data/datasources/course_remote_data_source.dart';
import 'package:modern_classes_patna/features/courses/logic/course_provider.dart';
import 'package:modern_classes_patna/features/courses/data/repositories/course_repository.dart';
import 'package:modern_classes_patna/models/payment_model.dart';
import 'package:modern_classes_patna/features/courses/data/models/course_model.dart';
import 'package:modern_classes_patna/features/courses/data/models/batch_model.dart';
import 'package:modern_classes_patna/screens/admin/admin_dashboard_screen.dart';
import 'package:modern_classes_patna/screens/admin/revenue_reports_screen.dart';
import 'package:modern_classes_patna/screens/student/payment_history_screen.dart';
import 'package:modern_classes_patna/features/auth/logic/auth_provider.dart';
import 'package:modern_classes_patna/features/auth/data/repositories/auth_repository.dart';
import 'package:modern_classes_patna/features/auth/data/models/user_model.dart';
import 'package:modern_classes_patna/features/tests/data/repositories/test_repository.dart';
import 'package:modern_classes_patna/features/tests/data/models/test_model.dart';
import 'package:modern_classes_patna/features/tests/logic/test_provider.dart';

class FakeCourseRepository implements CourseRepository {
  List<PaymentTransactionModel> studentTransactions = [];
  List<PaymentTransactionModel> adminLedger = [];
  bool throwError = false;
  double? mockTotal = 1000.0;
  int collectionsTotalCallCount = 0;

  @override
  Future<List<PaymentTransactionModel>> getStudentTransactions(
    String studentId,
  ) async {
    if (throwError) throw Exception('Network error');
    return studentTransactions;
  }

  @override
  Future<List<PaymentTransactionModel>> getAdminLedger(
    int offset,
    int limit,
  ) async {
    if (throwError) throw Exception('Network error');
    final end = (offset + limit < adminLedger.length)
        ? offset + limit
        : adminLedger.length;
    if (offset >= adminLedger.length) return [];
    return adminLedger.sublist(offset, end);
  }

  @override
  Future<double?> getAdminManualCollectionsTotal() async {
    collectionsTotalCallCount++;
    if (throwError) throw Exception('Network error');
    return mockTotal;
  }

  // Stub unused methods
  @override
  Future<void> createCourse(
    CourseModel course, {
    List<BatchModel>? initialBatches,
    Map<int, List<String>>? batchTeacherIds,
  }) async {}

  @override
  Future<void> updateCourse(CourseModel course) async {}

  @override
  Future<void> deleteCourse(String courseId) async {}

  @override
  Future<void> deleteLesson(
    String lessonId, {
    String? videoPath,
    String? thumbnailPath,
  }) async {}
  @override
  Future<void> createBatch(BatchModel batch, {List<String>? teacherIds}) async {}
  @override
  Future<void> updateBatch(BatchModel batch, {List<String>? teacherIds}) async {}
  @override
  Future<void> deleteBatch(String batchId) async {}
  @override
  Future<List<String>> getBatchTeacherIds(String batchId) async => [];
  @override
  Future<void> updateBatchTeachers(String batchId, List<String> teacherIds) async {}
  @override
  Future<List<CourseModel>> getCourses() async => [];
  @override
  Future<List<BatchModel>> getBatches() async => [];
  @override
  Future<List<BatchModel>> adminGetAllBatches() async => [];
  @override
  Future<List<VideoLessonModel>> getVideoLessons(String batchId) async => [];
  @override
  Future<void> enrollInBatch({
    String? purchaseToken,
    String? batchId,
    String? couponCode,
    double? amountPaid,
  }) async {}
  @override
  Future<Map<String, List<String>>> getMyEnrollments() async => {};
  @override
  Future<void> assignTeacherToBatch(String t, String b) async {}
  @override
  Future<void> setPrimaryBatchTeacher(String t, String b) async {}
  @override
  Future<void> removeTeacherFromBatch(String t, String b) async {}
  @override
  Future<List<Map<String, dynamic>>> getTeacherAssignments(String t) async =>
      [];
  @override
  Future<String> uploadLectureVideo({
    required String batchId,
    required String fileName,
    dynamic fileBytes,
    String? filePath,
    void Function(int uploadedBytes, int totalBytes)? onProgress,
    bool Function()? isCancelled,
  }) async => '';

  @override
  Future<List<VideoLessonModel>> getLessonsForBatches(List<String> batchIds) async => [];
  @override
  Future<String> uploadCourseCoverImage({
    required String fileName,
    required dynamic fileBytes,
  }) async => '';
  @override
  Future<String> uploadLessonThumbnail({
    required String batchId,
    required String fileName,
    required dynamic fileBytes,
  }) async => '';
  @override
  Future<VideoLessonModel> updateLessonThumbnail({
    required String lessonId,
    required String thumbnailUrl,
  }) async => throw UnimplementedError();
  @override
  Future<VideoLessonModel> updateLesson({
    required String lessonId,
    String? title,
    String? chapter,
    String? thumbnailUrl,
    String? notesPdfUrl,
  }) async => throw UnimplementedError();
  @override
  Future<VideoLessonModel> createLesson({
    required String courseId,
    required String batchId,
    required String title,
    required String chapter,
    required String videoUrl,
    String? thumbnailUrl,
    int durationSeconds = 0,
    int? orderIndex,
  }) async => throw UnimplementedError();
  @override
  Future<String> getLessonVideoSignedUrl(String v) async => '';

  @override
  Future<List<CouponModel>> getCoupons() async => [];
  @override
  Future<CouponModel> createCoupon(CouponModel coupon) async => coupon;
  @override
  Future<void> updateCoupon(CouponModel coupon) async {}
  @override
  Future<void> deleteCoupon(String couponId) async {}
}


class FakeRevenueAuthRepo implements AuthRepository {
  final UserModel? user;
  FakeRevenueAuthRepo({this.user});

  @override
  bool get isConnected => true;

  @override
  Future<UserModel?> getInitialSession() async => user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeTestRepository implements TestRepository {
  @override
  Future<List<TestModel>> getTests() async => [];
  @override
  Future<TestModel> getTestPaper(String testId) async => throw UnimplementedError();
  @override
  Future<void> submitTestResult(TestResultModel result) async {}
  @override
  Future<void> createTest(TestModel test) async {}
  @override
  Future<void> deleteTest(String testId) async {}
  @override
  Future<List<TestResultModel>> getTestSubmissionsForTest(String testId) async => [];
}

void main() {
  late CourseProvider provider;
  late FakeCourseRepository repo;

  setUp(() {
    repo = FakeCourseRepository();
    provider = CourseProvider(repository: repo);
  });

  group('Student Transactions', () {
    test('fetches successfully', () async {
      repo.studentTransactions = [
        PaymentTransactionModel(
          id: '1',
          transactionReference: 'tx1',
          studentId: 'student1',
          studentName: 'Student One',
          courseId: 'c1',
          courseTitle: 'Course 1',
          batchId: 'b1',
          batchName: 'Batch 1',
          originalAmount: 100,
          amountPaid: 100,
          status: PaymentStatus.success,
          timestamp: DateTime.now(),
          invoiceNumber: 'INV1',
        ),
      ];

      await provider.fetchStudentTransactions('student1');
      expect(provider.studentTransactions.length, 1);
      expect(provider.studentTransactions.first.id, '1');
      expect(provider.ledgerError, isNull);
    });

    test('handles error gracefully', () async {
      repo.throwError = true;
      await provider.fetchStudentTransactions('student1');
      expect(provider.studentTransactions, isEmpty);
      expect(provider.ledgerError, isNotNull);
    });
  });

  group('Admin Ledger Pagination', () {
    setUp(() {
      repo.adminLedger = List.generate(
        25,
        (index) => PaymentTransactionModel(
          id: index.toString(),
          transactionReference: 'tx$index',
          studentId: 'st$index',
          studentName: 'Student $index',
          courseId: 'c1',
          courseTitle: 'C1',
          batchId: 'b1',
          batchName: 'B1',
          originalAmount: 100,
          amountPaid: 100,
          status: PaymentStatus.success,
          timestamp: DateTime.now(),
          invoiceNumber: 'INV$index',
        ),
      );
    });

    test('fetches page 1 correctly', () async {
      await provider.fetchAdminLedger(refresh: true);
      expect(provider.adminLedger.length, 20);
      expect(provider.hasMoreLedger, isTrue);
    });

    test('fetches page 2 correctly', () async {
      await provider.fetchAdminLedger(refresh: true);
      await provider.fetchAdminLedger();
      expect(provider.adminLedger.length, 25);
      expect(provider.hasMoreLedger, isFalse);
    });
  });

  group('RPC Result Parsing', () {
    test('parses numeric int, double, and string correctly', () {
      expect(CourseRemoteDataSourceImpl.parseCollectionsTotal(100), 100.0);
      expect(CourseRemoteDataSourceImpl.parseCollectionsTotal(250.75), 250.75);
      expect(
        CourseRemoteDataSourceImpl.parseCollectionsTotal('1500.50'),
        1500.50,
      );
      expect(CourseRemoteDataSourceImpl.parseCollectionsTotal('0.00'), 0.0);
    });

    test('handles null RPC response', () {
      expect(CourseRemoteDataSourceImpl.parseCollectionsTotal(null), isNull);
    });

    test('throws ServerException on malformed response', () {
      expect(
        () => CourseRemoteDataSourceImpl.parseCollectionsTotal('not_a_number'),
        throwsA(isA<ServerException>()),
      );
      expect(
        () => CourseRemoteDataSourceImpl.parseCollectionsTotal(true),
        throwsA(isA<ServerException>()),
      );
      expect(
        () => CourseRemoteDataSourceImpl.parseCollectionsTotal({'key': 'val'}),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('Admin Manual Collections Total Provider & 15% Google Commission', () {
    test('fetches successful numeric result and updates state with 15% Google commission cut', () async {
      repo.mockTotal = 2500.0;
      await provider.fetchAdminManualCollectionsTotal();
      expect(provider.adminManualCollectionsTotal, 2500.0);
      expect(provider.adminNetCollectionsTotal, 2500.0 * 0.85); // 2125.0
      expect(provider.adminGoogleCommissionTotal, 2500.0 * 0.15); // 375.0
      expect(provider.isLoadingCollectionsTotal, false);
      expect(provider.collectionsTotalError, isNull);
    });

    test('correctly calculates 15% Google commission for Rs 9 purchase', () async {
      repo.mockTotal = 9.0;
      await provider.fetchAdminManualCollectionsTotal();
      expect(provider.adminManualCollectionsTotal, 9.0);
      expect(provider.adminNetCollectionsTotal, 7.65);
      expect(provider.adminGoogleCommissionTotal, 1.35);
      expect(Formatters.formatCurrencyWithDecimals(provider.adminNetCollectionsTotal!), '₹7.65');
      expect(Formatters.formatCurrency(provider.adminManualCollectionsTotal!), '₹9');
    });

    test('handles null result gracefully without error', () async {
      repo.mockTotal = null;
      await provider.fetchAdminManualCollectionsTotal();
      expect(provider.adminManualCollectionsTotal, isNull);
      expect(provider.adminNetCollectionsTotal, isNull);
      expect(provider.adminGoogleCommissionTotal, isNull);
      expect(provider.isLoadingCollectionsTotal, false);
      expect(provider.collectionsTotalError, isNull);
    });

    test('handles RPC failure with error state and null total', () async {
      repo.throwError = true;
      await provider.fetchAdminManualCollectionsTotal();
      expect(provider.adminManualCollectionsTotal, isNull);
      expect(provider.adminNetCollectionsTotal, isNull);
      expect(provider.adminGoogleCommissionTotal, isNull);
      expect(provider.isLoadingCollectionsTotal, false);
      expect(provider.collectionsTotalError, isNotNull);
    });

    test('deduplicates concurrent fetches', () async {
      repo.mockTotal = 1500.0;
      final f1 = provider.fetchAdminManualCollectionsTotal();
      final f2 = provider.fetchAdminManualCollectionsTotal();
      await Future.wait([f1, f2]);
      expect(repo.collectionsTotalCallCount, 1);
      expect(provider.adminManualCollectionsTotal, 1500.0);
      expect(provider.adminNetCollectionsTotal, 1275.0);
    });
  });

  group('Admin Dashboard Screen Initial Load', () {
    testWidgets('triggers total collections fetch on mount and displays Net Collections (-15% Google)', (tester) async {
      final testRepo = FakeTestRepository();
      final testProvider = TestProvider(repository: testRepo);
      repo.mockTotal = 5400.0;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CourseProvider>.value(value: provider),
            ChangeNotifierProvider<TestProvider>.value(value: testProvider),
          ],
          child: const MaterialApp(home: AdminDashboardScreen()),
        ),
      );

      // Settle post-frame callback
      await tester.pumpAndSettle();

      expect(repo.collectionsTotalCallCount, 1);
      expect(provider.adminManualCollectionsTotal, 5400.0);
      expect(provider.adminNetCollectionsTotal, 5400.0 * 0.85); // 4590.0
      // Net amount displayed as main value
      expect(find.text(Formatters.formatCurrencyWithDecimals(4590.0)), findsOneWidget);
      // Subtext displays gross with -15% Google indicator
      expect(find.textContaining('Gross ₹5,400 (-15% Google)'), findsOneWidget);
    });
  });

    group('Admin & Student Screens High Monetary Amount Overflow Resilience', () {
    testWidgets('AdminDashboardScreen does not overflow on 320px (Balmuda) or 300px with Rs 9.99 Crore', (tester) async {
      tester.view.physicalSize = const Size(320.0, 640.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testRepo = FakeTestRepository();
      final testProvider = TestProvider(repository: testRepo);
      repo.mockTotal = 99999999.0;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CourseProvider>.value(value: provider),
            ChangeNotifierProvider<TestProvider>.value(value: testProvider),
          ],
          child: const MaterialApp(home: AdminDashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(Formatters.formatCurrencyWithDecimals(99999999.0 * 0.85)), findsOneWidget);

      // Now test on ultra-narrow 300px viewport
      tester.view.physicalSize = const Size(300.0, 600.0);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('RevenueReportsScreen does not overflow on 320px or 300px with Rs 1.5 Crore total & transactions', (tester) async {
      tester.view.physicalSize = const Size(320.0, 640.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      repo.mockTotal = 15000000.0;
      repo.adminLedger = [
        PaymentTransactionModel(
          id: 'tx_huge',
          transactionReference: 'TXN-99999999',
          studentId: 'st_1',
          studentName: 'Test Student with Very Long Full Name',
          courseId: 'c1',
          courseTitle: 'Comprehensive GS Foundation for BPSC',
          batchId: 'b1',
          batchName: 'Morning Batch 2026',
          originalAmount: 15000000.0,
          amountPaid: 15000000.0,
          status: PaymentStatus.success,
          timestamp: DateTime.now(),
          invoiceNumber: 'INV-2026-0001',
        ),
      ];

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CourseProvider>.value(value: provider),
          ],
          child: const MaterialApp(home: RevenueReportsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining(Formatters.formatCurrency(15000000.0)), findsWidgets);

      // Ultra narrow 300px test
      tester.view.physicalSize = const Size(300.0, 600.0);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('PaymentHistoryScreen does not overflow on 320px or 300px with Rs 1.5 Crore receipt', (tester) async {
      tester.view.physicalSize = const Size(320.0, 640.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final authRepo = FakeRevenueAuthRepo(
        user: const UserModel(
          id: 'st_1',
          name: 'Student One',
          email: 'student@example.org',
          phone: '+91 9999999999',
          role: UserRole.student,
        ),
      );
      final authProvider = AuthProvider(repository: authRepo);

      repo.studentTransactions = [
        PaymentTransactionModel(
          id: 'tx_huge',
          transactionReference: 'TXN-99999999',
          studentId: 'st_1',
          studentName: 'Test Student',
          courseId: 'c1',
          courseTitle: 'Comprehensive GS Foundation for BPSC',
          batchId: 'b1',
          batchName: 'Morning Batch 2026',
          originalAmount: 15000000.0,
          amountPaid: 15000000.0,
          status: PaymentStatus.success,
          timestamp: DateTime.now(),
          invoiceNumber: 'INV-2026-0001',
        ),
      ];

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<CourseProvider>.value(value: provider),
          ],
          child: const MaterialApp(home: PaymentHistoryScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(Formatters.formatCurrency(15000000.0)), findsOneWidget);

      // Ultra narrow 300px test
      tester.view.physicalSize = const Size(300.0, 600.0);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}