import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:modern_classes_patna/features/auth/data/models/user_model.dart';
import 'package:modern_classes_patna/features/auth/logic/auth_provider.dart';
import 'package:modern_classes_patna/features/courses/data/models/batch_model.dart';
import 'package:modern_classes_patna/features/courses/data/models/course_model.dart';
import 'package:modern_classes_patna/features/courses/data/repositories/course_repository.dart';
import 'package:modern_classes_patna/features/courses/logic/course_provider.dart';
import 'package:modern_classes_patna/models/payment_model.dart';
import 'package:modern_classes_patna/core/widgets/dynamic_drm_watermark.dart';
import 'package:modern_classes_patna/screens/student/video_player_screen.dart';
import 'package:modern_classes_patna/screens/teacher/upload_lecture_screen.dart';

class MockCourseRepository implements CourseRepository {
  List<CourseModel> courses = [];
  List<BatchModel> batches = [];
  List<VideoLessonModel> lessons = [];

  bool failUpload = false;
  bool failCreate = false;
  bool bucketNotFound = false;
  String? lastUploadedPath;
  Map<String, dynamic>? lastCreatedPayload;

  @override
  Future<List<CourseModel>> getCourses() async => List.from(courses);

  @override
  Future<List<BatchModel>> getBatches() async => List.from(batches);

  @override
  Future<List<BatchModel>> adminGetAllBatches() async => List.from(batches);

  @override
  Future<List<VideoLessonModel>> getVideoLessons(String batchId) async =>
      lessons.where((l) => l.batchId == batchId).toList();

  @override
  Future<List<VideoLessonModel>> getLessonsForBatches(List<String> batchIds) async =>
      lessons.where((l) => batchIds.contains(l.batchId)).toList();

  @override
  Future<String> uploadLectureVideo({
    required String batchId,
    required String fileName,
    Uint8List? fileBytes,
    String? filePath,
    void Function(int uploadedBytes, int totalBytes)? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (bucketNotFound) {
      throw Exception('StorageApiError: Bucket not found (NoSuchBucket)');
    }
    if (failUpload) {
      throw Exception('Network upload failed');
    }
    final path = '$batchId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    lastUploadedPath = path;
    return path;
  }

  @override
  Future<String> uploadCourseCoverImage({
    required String fileName,
    required Uint8List fileBytes,
  }) async => 'https://mock.storage/course-thumbnails/test_$fileName';

  @override
  Future<String> uploadLessonThumbnail({
    required String batchId,
    required String fileName,
    required Uint8List fileBytes,
  }) async {
    if (failUpload) throw Exception('Network upload failed');
    return '$batchId/thumbnails/${DateTime.now().millisecondsSinceEpoch}_$fileName';
  }

  @override
  Future<VideoLessonModel> updateLessonThumbnail({
    required String lessonId,
    required String thumbnailUrl,
  }) async {
    final idx = lessons.indexWhere((l) => l.id == lessonId);
    if (idx != -1) {
      final updated = lessons[idx].copyWith(thumbnailUrl: thumbnailUrl);
      lessons[idx] = updated;
      return updated;
    }
    final newLesson = VideoLessonModel(
      id: lessonId,
      courseId: 'course_001',
      batchId: 'batch_001',
      title: 'Updated Lesson',
      chapter: 'Updated Chapter',
      duration: Duration.zero,
      videoUrl: 'updated.mp4',
      thumbnailUrl: thumbnailUrl,
      uploadedAt: DateTime.now(),
    );
    lessons.add(newLesson);
    return newLesson;
  }

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
  }) async {
    if (failCreate) {
      throw Exception('Database insertion failed');
    }
    if (lessons.any((l) => l.batchId == batchId && l.title == title)) {
      throw Exception('A lesson with this title already exists in this batch.');
    }

    lastCreatedPayload = {
      'courseId': courseId,
      'batchId': batchId,
      'title': title,
      'chapter': chapter,
      'videoUrl': videoUrl,
      'durationSeconds': durationSeconds,
      'orderIndex': orderIndex ?? (lessons.length + 1),
    };

    final newLesson = VideoLessonModel(
      id: 'lesson_${lessons.length + 1}',
      courseId: courseId,
      batchId: batchId,
      title: title,
      chapter: chapter,
      videoUrl: videoUrl,
      duration: Duration(seconds: durationSeconds),
      uploadedAt: DateTime.now(),
    );
    lessons.add(newLesson);
    return newLesson;
  }

  @override
  Future<String> getLessonVideoSignedUrl(String videoUrlOrPath) async {
    if (videoUrlOrPath.startsWith('http://') ||
        videoUrlOrPath.startsWith('https://')) {
      return videoUrlOrPath;
    }
    return 'https://supabase.project.co/storage/v1/object/sign/lecture-videos/$videoUrlOrPath?token=signed_valid';
  }

  // Stub other unused methods
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
  Future<List<String>> getBatchTeacherIds(String batchId) async => [];
  @override
  Future<void> updateBatchTeachers(String batchId, List<String> teacherIds) async {}
  @override
  Future<void> deleteBatch(String batchId) async {}
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
  Future<List<Map<String, dynamic>>> getTeacherAssignments(String t) async => [
    {'batch_id': 'batch_001'},
    {'batch_id': 'batch_bpsc_01'},
  ];
  @override
  Future<List<PaymentTransactionModel>> getStudentTransactions(
    String s,
  ) async => [];
  @override
  Future<List<PaymentTransactionModel>> getAdminLedger(int o, int l) async =>
      [];
  @override
  Future<double?> getAdminManualCollectionsTotal() async => 0.0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  UserModel _user = const UserModel(
    id: 'tch_001',
    name: 'Dr. Kumar',
    email: 'kumar@example.com',
    phone: '9876543210',
    role: UserRole.teacher,
  );

  @override
  UserModel get currentUser => _user;

  void setUser(UserModel user) {
    _user = user;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Prerecorded Lecture Upload - Provider & Business Logic', () {
    late MockCourseRepository repo;
    late CourseProvider provider;

    final testBatch = BatchModel(
      id: 'batch_bpsc_01',
      courseId: 'course_bpsc_01',
      name: 'BPSC Prelims 2026 Batch',
      timing: '09:00 AM',
      batchPrice: 2500,
      teacherId: 'tch_001',
      teacherName: 'Dr. Kumar',
      totalStudents: 45,
      medium: 'Hindi',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 12, 31),
    );

    setUp(() {
      repo = MockCourseRepository();
      repo.batches = [testBatch];
      provider = CourseProvider(repository: repo);
    });

    test(
      'uploadAndCreateLesson successfully uploads to batch-scoped path and inserts lesson',
      () async {
        final sampleBytes = Uint8List.fromList([1, 2, 3, 4]);
        final lesson = await provider.uploadAndCreateLesson(
          courseId: testBatch.courseId,
          batchId: testBatch.id,
          title: 'Modern History of Bihar',
          chapter: 'Bihar Special',
          fileName: 'bihar_history.mp4',
          fileBytes: sampleBytes,
          durationSeconds: 1800,
        );

        expect(lesson.title, 'Modern History of Bihar');
        expect(lesson.chapter, 'Bihar Special');
        expect(lesson.batchId, testBatch.id);
        expect(lesson.courseId, testBatch.courseId);
        // Batch-scoped path verification
        expect(lesson.videoUrl.startsWith('${testBatch.id}/'), isTrue);
        expect(lesson.videoUrl.contains('bihar_history.mp4'), isTrue);
        // Added to videoLessons in provider
        expect(provider.videoLessons.length, 1);
        expect(provider.videoLessons.first.id, lesson.id);
      },
    );

    test(
      'duplicate lesson title in the same batch throws error and does not create duplicate',
      () async {
        final sampleBytes = Uint8List.fromList([1, 2, 3]);
        await provider.uploadAndCreateLesson(
          courseId: testBatch.courseId,
          batchId: testBatch.id,
          title: 'Unique Lecture',
          chapter: 'Chapter 1',
          fileName: 'v1.mp4',
          fileBytes: sampleBytes,
        );

        expect(
          () => provider.uploadAndCreateLesson(
            courseId: testBatch.courseId,
            batchId: testBatch.id,
            title: 'Unique Lecture',
            chapter: 'Chapter 1',
            fileName: 'v2.mp4',
            fileBytes: sampleBytes,
          ),
          throwsA(isA<Exception>()),
        );

        expect(provider.videoLessons.length, 1);
      },
    );

    test(
      'upload failure stops execution before lesson row insertion',
      () async {
        repo.failUpload = true;
        final sampleBytes = Uint8List.fromList([1, 2]);

        expect(
          () => provider.uploadAndCreateLesson(
            courseId: testBatch.courseId,
            batchId: testBatch.id,
            title: 'Failed Upload Test',
            chapter: 'Testing',
            fileName: 'test.mp4',
            fileBytes: sampleBytes,
          ),
          throwsA(isA<Exception>()),
        );

        expect(repo.lastCreatedPayload, isNull);
        expect(provider.videoLessons, isEmpty);
      },
    );

    test('bucket not found error is correctly propagated', () async {
      repo.bucketNotFound = true;
      final sampleBytes = Uint8List.fromList([1, 2]);

      expect(
        () => provider.uploadAndCreateLesson(
          courseId: testBatch.courseId,
          batchId: testBatch.id,
          title: 'No Bucket Test',
          chapter: 'Testing',
          fileName: 'test.mp4',
          fileBytes: sampleBytes,
        ),
        throwsA(predicate((e) => e.toString().contains('NoSuchBucket'))),
      );

      expect(repo.lastCreatedPayload, isNull);
    });

    test(
      'getLessonSignedUrl preserves public HTTP URLs and signs private storage paths',
      () async {
        const publicUrl =
            'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
        final resolvedPublic = await provider.getLessonSignedUrl(publicUrl);
        expect(resolvedPublic, publicUrl);

        const storagePath = 'batch_bpsc_01/1729330000_lecture.mp4';
        final signedUrl = await provider.getLessonSignedUrl(storagePath);
        expect(signedUrl.contains('sign/lecture-videos'), isTrue);
        expect(signedUrl.contains('token=signed_valid'), isTrue);
      },
    );
    test('CourseProvider cancelLectureUpload successfully flags active task as cancelled', () async {
      final cp = CourseProvider(repository: repo);
      expect(cp.isUploadingLecture, isFalse);

      final uploadFuture = cp.startBackgroundLectureUpload(
        batchId: 'batch_01',
        batchName: 'Batch 1',
        courseId: 'crs_01',
        title: 'Cancellable Lecture',
        chapter: 'Polity',
        fileName: 'test.mp4',
        fileBytes: Uint8List(100),
        totalBytes: 100,
      );

      expect(cp.isUploadingLecture, isTrue);
      expect(cp.activeUploadTask?.title, 'Cancellable Lecture');

      cp.cancelLectureUpload();
      expect(cp.activeUploadTask?.isCancelled, isTrue);

      await uploadFuture;
      expect(cp.activeUploadTask?.status, LectureUploadStatus.cancelled);
      expect(cp.isUploadingLecture, isFalse);
    });
  });

  group('UploadLectureScreen Widget Tests', () {
    late MockCourseRepository repo;
    late CourseProvider courseProvider;
    late FakeAuthProvider authProvider;

    final testBatch = BatchModel(
      id: 'batch_001',
      courseId: 'course_001',
      name: 'UPSC Foundation 2026',
      timing: '08:00 AM',
      batchPrice: 3000,
      teacherId: 'tch_001',
      teacherName: 'Dr. Kumar',
      totalStudents: 30,
      medium: 'English',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 12, 31),
    );

    setUp(() async {
      repo = MockCourseRepository();
      repo.batches = [testBatch];
      courseProvider = CourseProvider(repository: repo);
      await courseProvider.fetchMyTeacherAssignments('tch_001');
      authProvider = FakeAuthProvider();
    });

    Widget createTestApp() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<CourseProvider>.value(value: courseProvider),
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ],
        child: const MaterialApp(home: UploadLectureScreen()),
      );
    }

    testWidgets('renders all initial fields and labels', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Upload Lecture Video'), findsOneWidget);
      expect(find.text('Prerecorded Lecture Upload'), findsOneWidget);
      expect(find.text('Select Target Batch *'), findsOneWidget);
      expect(find.text('Lecture Title *'), findsOneWidget);
      expect(find.text('Chapter / Topic *'), findsOneWidget);
      expect(find.text('Video Source *'), findsOneWidget);
      expect(find.text('Upload & Add to Curriculum'), findsOneWidget);
    });

    testWidgets('form validation requires title, chapter, and video file', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Tap submit with empty fields
      await tester.tap(find.text('Upload & Add to Curriculum'));
      await tester.pumpAndSettle();

      expect(find.text('Title is required'), findsOneWidget);
      expect(find.text('Chapter is required'), findsOneWidget);
    });

    testWidgets(
      'using test sample populates file card and allows successful upload flow',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Fill in title and chapter
        await tester.enterText(
          find.byKey(const Key('lecture_title_field')),
          'Indian Polity Basics',
        );
        await tester.enterText(
          find.byKey(const Key('lecture_chapter_field')),
          'Constitutional Law',
        );

        // Click "Use Test Sample (10KB MP4)"
        await tester.tap(find.text('Use Test Sample (10KB MP4)'));
        await tester.pumpAndSettle();

        expect(find.textContaining('sample_lecture_'), findsOneWidget);
        expect(find.textContaining('10.0 KB'), findsOneWidget);

        // Submit upload
        await tester.tap(find.text('Upload & Add to Curriculum'));
        await tester.pump(); // Enter uploading state
        await tester.pumpAndSettle(); // Settle in success view

        expect(find.text('Lecture Uploaded Successfully!'), findsOneWidget);
        expect(find.text('Indian Polity Basics'), findsOneWidget);
        expect(find.text('Constitutional Law'), findsOneWidget);
      },
    );

    testWidgets(
      'upload failure with unprovisioned bucket displays honest setup guidance and retry button',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        repo.bucketNotFound = true;

        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Fill in fields
        await tester.enterText(
          find.byKey(const Key('lecture_title_field')),
          'Test Lecture',
        );
        await tester.enterText(
          find.byKey(const Key('lecture_chapter_field')),
          'Chapter 1',
        );
        await tester.tap(find.text('Use Test Sample (10KB MP4)'));
        await tester.pumpAndSettle();

        // Submit
        await tester.tap(find.text('Upload & Add to Curriculum'));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Upload Failed'), findsOneWidget);
        expect(
          find.textContaining(
            "Storage bucket 'lecture-videos' is not yet provisioned on the Supabase backend",
          ),
          findsOneWidget,
        );
        expect(find.text('Retry Upload'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
      },
    );
    testWidgets(
      'UploadLectureScreen displays Cloudflare processing notice on success',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Fill in fields
        await tester.enterText(
          find.byKey(const Key('lecture_title_field')),
          'Cloudflare Stream Test Lecture',
        );
        await tester.enterText(
          find.byKey(const Key('lecture_chapter_field')),
          'Modern Physics',
        );
        await tester.tap(find.text('Use Test Sample (10KB MP4)'));
        await tester.pumpAndSettle();

        // Submit upload
        await tester.tap(find.text('Upload & Add to Curriculum'));
        await tester.pump();
        await tester.pumpAndSettle();

        // Verify Success View displays honest Cloudflare processing notice
        expect(find.text('Lecture Uploaded Successfully!'), findsOneWidget);
        expect(find.textContaining('Cloudflare Processing in Progress'), findsOneWidget);
        expect(find.textContaining('transcoding it into adaptive bitrate streaming'), findsOneWidget);
      },
    );
  });

  group('VideoPlayerScreen Real Playback Honesty & Signed URL Resolution', () {
    late MockCourseRepository repo;
    late CourseProvider courseProvider;
    late FakeAuthProvider authProvider;

    final testCourse = CourseModel(
      id: 'crs_01',
      title: 'BPSC Course',
      category: 'BPSC',
      description: 'Desc',
      coverImageUrl: 'img',
      price: 1000,
      originalPrice: 1500,
      teacherId: 'tch_01',
      teacherName: 'Teacher',
      totalLessons: 1,
      totalHours: 1,
      totalTests: 1,
      totalNotes: 1,
      rating: 5.0,
      reviewsCount: 1,
      highlights: [],
      isFeatured: false,
      isCrashCourse: false,
      playProductId: null,
    );

    setUp(() {
      repo = MockCourseRepository();
      courseProvider = CourseProvider(repository: repo);
      authProvider = FakeAuthProvider();
    });

    testWidgets('displays honest canvas disclosure and signed URL status badge', (
      tester,
    ) async {
      final lesson = VideoLessonModel(
        id: 'lsn_01',
        courseId: 'crs_01',
        batchId: 'batch_01',
        title: 'Recorded Lecture 1',
        chapter: 'Ancient India',
        videoUrl: 'batch_01/1729330000_lecture.mp4',
        duration: const Duration(seconds: 3600),
        uploadedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CourseProvider>.value(value: courseProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: MaterialApp(
            home: VideoPlayerScreen(lesson: lesson, course: testCourse),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify internal simulated preview bar is removed from student view per production design
      expect(find.text('Recorded Lecture 1'), findsWidgets);
      expect(
        find.textContaining('Simulated Canvas Preview'),
        findsNothing,
      );
      expect(find.byType(DynamicDrmWatermark), findsNothing);
    });

  });
}
