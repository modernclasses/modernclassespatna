import 'package:flutter_test/flutter_test.dart';
import 'package:modern_classes_patna/features/courses/data/models/course_model.dart';
import 'package:modern_classes_patna/features/courses/data/models/batch_model.dart';
import 'package:modern_classes_patna/features/courses/logic/course_provider.dart';
import 'package:modern_classes_patna/features/courses/data/repositories/course_repository.dart';
import 'package:modern_classes_patna/models/payment_model.dart';

class FakeCourseRepository implements CourseRepository {
  List<CourseModel> courses = [];
  List<BatchModel> batches = [];
  bool shouldFailFetch = false;
  bool shouldFailCreate = false;
  bool shouldFailUpdate = false;
  int createCourseCallCount = 0;
  int createBatchCallCount = 0;
  int updateBatchCallCount = 0;

  @override
  Future<List<CourseModel>> getCourses() async {
    if (shouldFailFetch) throw Exception('Fetch failed');
    return List.from(courses);
  }

  @override
  Future<List<BatchModel>> getBatches() async {
    if (shouldFailFetch) throw Exception('Fetch failed');
    return List.from(batches);
  }

  int updateCourseCallCount = 0;
  bool shouldFailCourseUpdate = false;
  Map<String, List<String>> batchTeachers = {};

  @override
  Future<void> createCourse(
    CourseModel course, {
    List<BatchModel>? initialBatches,
    Map<int, List<String>>? batchTeacherIds,
  }) async {
    createCourseCallCount++;
    if (shouldFailCreate) throw Exception('Create failed');
    courses.insert(0, course);
    if (initialBatches != null) {
      for (int i = 0; i < initialBatches.length; i++) {
        final b = initialBatches[i];
        batches.add(b);
        if (batchTeacherIds?[i] != null) {
          batchTeachers[b.id] = batchTeacherIds![i]!;
        }
      }
    }
  }

  @override
  Future<void> updateCourse(CourseModel course) async {
    updateCourseCallCount++;
    if (shouldFailCourseUpdate) throw Exception('Course update failed');
    final idx = courses.indexWhere((c) => c.id == course.id);
    if (idx != -1) {
      courses[idx] = course;
    } else {
      courses.add(course);
    }
  }

  @override
  Future<void> deleteCourse(String courseId) async {}

  @override
  Future<void> deleteLesson(
    String lessonId, {
    String? videoPath,
    String? thumbnailPath,
  }) async {}

  @override
  Future<void> createBatch(BatchModel batch, {List<String>? teacherIds}) async {
    createBatchCallCount++;
    if (shouldFailCreate) throw Exception('Create failed');
    batches.insert(0, batch);
    if (teacherIds != null) {
      batchTeachers[batch.id] = List.from(teacherIds);
    }
  }

  @override
  Future<void> updateBatch(BatchModel batch, {List<String>? teacherIds}) async {
    updateBatchCallCount++;
    if (shouldFailUpdate) throw Exception('Update failed');
    final idx = batches.indexWhere((b) => b.id == batch.id);
    if (idx != -1) {
      batches[idx] = batch;
    } else {
      batches.add(batch);
    }
    if (teacherIds != null) {
      batchTeachers[batch.id] = List.from(teacherIds);
    }
  }

  @override
  Future<void> deleteBatch(String batchId) async {
    batches.removeWhere((b) => b.id == batchId);
    batchTeachers.remove(batchId);
  }

  @override
  Future<List<String>> getBatchTeacherIds(String batchId) async {
    return batchTeachers[batchId] ?? [];
  }

  @override
  Future<void> updateBatchTeachers(
    String batchId,
    List<String> teacherIds,
  ) async {
    batchTeachers[batchId] = List.from(teacherIds);
  }

  @override
  Future<List<BatchModel>> adminGetAllBatches() async => batches;

  @override
  Future<List<Map<String, dynamic>>> getTeacherAssignments(
    String teacherId,
  ) async => [];

  @override
  Future<void> assignTeacherToBatch(String teacherId, String batchId) async {}
  @override
  Future<void> removeTeacherFromBatch(String teacherId, String batchId) async {}
  @override
  Future<void> setPrimaryBatchTeacher(String teacherId, String batchId) async {}

  @override
  Future<Map<String, List<String>>> getMyEnrollments() async => {
    'courseIds': [],
    'batchIds': [],
  };

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
  Future<List<PaymentTransactionModel>> getStudentTransactions(
    String studentId,
  ) async => [];

  @override
  Future<List<PaymentTransactionModel>> getAdminLedger(
    int offset,
    int limit,
  ) async => [];

  @override
  Future<double?> getAdminManualCollectionsTotal() async => 0.0;

  @override
  Future<String> uploadLectureVideo({
    required String batchId,
    required String fileName,
    dynamic fileBytes,
    String? filePath,
    void Function(int uploadedBytes, int totalBytes)? onProgress,
    bool Function()? isCancelled,
  }) async => '$batchId/test_$fileName';

  @override
  Future<List<VideoLessonModel>> getLessonsForBatches(List<String> batchIds) async => [];

  @override
  Future<String> uploadCourseCoverImage({
    required String fileName,
    required dynamic fileBytes,
  }) async => 'https://mock.storage/course-thumbnails/test_$fileName';

  @override
  Future<String> uploadLessonThumbnail({
    required String batchId,
    required String fileName,
    required dynamic fileBytes,
  }) async => '$batchId/thumbnails/test_$fileName';

  @override
  Future<VideoLessonModel> updateLessonThumbnail({
    required String lessonId,
    required String thumbnailUrl,
  }) async {
    return VideoLessonModel(
      id: lessonId,
      courseId: 'mock-course',
      batchId: 'mock-batch',
      title: 'Mock Lesson',
      chapter: 'Mock Chapter',
      duration: Duration.zero,
      videoUrl: 'mock.mp4',
      thumbnailUrl: thumbnailUrl,
      uploadedAt: DateTime.now(),
    );
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
    return VideoLessonModel(
      id: 'test_lesson_${DateTime.now().millisecondsSinceEpoch}',
      courseId: courseId,
      batchId: batchId,
      title: title,
      chapter: chapter,
      videoUrl: videoUrl,
      duration: Duration(seconds: durationSeconds),
      uploadedAt: DateTime.now(),
    );
  }

  @override
  Future<String> getLessonVideoSignedUrl(String videoUrlOrPath) async =>
      'https://signed.supabase.co/storage/v1/object/sign/lecture-videos/$videoUrlOrPath?token=test';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('CourseProvider - Course & Batch Management', () {
    late FakeCourseRepository fakeRepo;
    late CourseProvider provider;

    setUp(() {
      fakeRepo = FakeCourseRepository();
      provider = CourseProvider(repository: fakeRepo);
    });

    test('Successful course creation persists and refreshes list', () async {
      final newCourse = const CourseModel(
        id: 'test_1',
        title: 'Test',
        category: 'Test',
        description: 'Test',
        coverImageUrl: '',
        price: 100,
        originalPrice: 200,
        teacherName: 'T',
        teacherId: 'T1',
        totalLessons: 0,
        totalHours: 0,
        totalTests: 0,
        totalNotes: 0,
        highlights: [],
      );

      // Wait for initial fetch to complete
      await Future.delayed(const Duration(milliseconds: 50));
      expect(provider.courses.length, 0);

      await provider.addCourse(newCourse);

      // Verify repo was called and list refreshed
      expect(fakeRepo.createCourseCallCount, 1);
      expect(provider.courses.length, 1);
      expect(provider.courses.first.title, 'Test');
    });

    test(
      'Failed creation shows error and does not create phantom course',
      () async {
        final newCourse = const CourseModel(
          id: 'test_1',
          title: 'Test',
          category: 'Test',
          description: 'Test',
          coverImageUrl: '',
          price: 100,
          originalPrice: 200,
          teacherName: 'T',
          teacherId: 'T1',
          totalLessons: 0,
          totalHours: 0,
          totalTests: 0,
          totalNotes: 0,
          highlights: [],
        );

        // Wait for initial fetch to complete
        await Future.delayed(const Duration(milliseconds: 50));
        fakeRepo.shouldFailCreate = true;

        try {
          await provider.addCourse(newCourse);
          fail('Should throw');
        } catch (e) {
          expect(e.toString(), contains('Create failed'));
        }

        expect(fakeRepo.createCourseCallCount, 1);
        expect(provider.courses.length, 0); // No phantom course
        expect(provider.errorMessage, contains('Create failed'));
      },
    );

    test('Successful batch creation persists and refreshes list', () async {
      final newBatch = BatchModel(
        id: 'b1',
        courseId: 'c1',
        name: 'Batch 1',
        timing: 'Morning',
        startDate: DateTime.now(),
        endDate: DateTime.now(),
        teacherName: '',
        teacherId: '',
        totalStudents: 0,
        batchPrice: 100,
      );

      await Future.delayed(const Duration(milliseconds: 50));
      expect(provider.batches.length, 0);

      await provider.addBatch(newBatch);

      expect(fakeRepo.createBatchCallCount, 1);
      expect(provider.batches.length, 1);
      expect(provider.batches.first.name, 'Batch 1');
    });

    test(
      'Successful course creation but refresh fails does not hide creation success',
      () async {
        final newCourse = const CourseModel(
          id: 'test_1',
          title: 'Test',
          category: 'Test',
          description: 'Test',
          coverImageUrl: '',
          price: 100,
          originalPrice: 200,
          teacherName: 'T',
          teacherId: 'T1',
          totalLessons: 0,
          totalHours: 0,
          totalTests: 0,
          totalNotes: 0,
          highlights: [],
        );

        await Future.delayed(const Duration(milliseconds: 50));

        // Let create succeed but fetch fail
        fakeRepo.shouldFailCreate = false;
        fakeRepo.shouldFailFetch = true;

        try {
          await provider.addCourse(newCourse);
          fail('Should throw refresh_failed');
        } catch (e) {
          expect(e.toString(), contains('refresh_failed'));
        }

        expect(fakeRepo.createCourseCallCount, 1);
        expect(provider.errorMessage, contains('failed to refresh catalog'));
      },
    );

    test(
      'Successful batch creation but refresh fails does not hide creation success',
      () async {
        final newBatch = BatchModel(
          id: 'b1',
          courseId: 'c1',
          name: 'Batch 1',
          timing: 'Morning',
          startDate: DateTime.now(),
          endDate: DateTime.now(),
          teacherName: '',
          teacherId: '',
          totalStudents: 0,
          batchPrice: 100,
        );

        await Future.delayed(const Duration(milliseconds: 50));

        // Let create succeed but fetch fail
        fakeRepo.shouldFailCreate = false;
        fakeRepo.shouldFailFetch = true;

        try {
          await provider.addBatch(newBatch);
          fail('Should throw refresh_failed');
        } catch (e) {
          expect(e.toString(), contains('refresh_failed'));
        }

        expect(fakeRepo.createBatchCallCount, 1);
        expect(provider.errorMessage, contains('failed to refresh catalog'));
      },
    );

    test('Successful batch update persists and refreshes list', () async {
      final initialBatch = BatchModel(
        id: 'b1',
        courseId: 'c1',
        name: 'Batch 1',
        timing: 'Morning',
        startDate: DateTime.now(),
        endDate: DateTime.now(),
        teacherName: '',
        teacherId: '',
        totalStudents: 0,
        batchPrice: 100,
      );
      fakeRepo.batches = [initialBatch];
      await provider.fetchCatalog();

      expect(provider.batches.length, 1);
      expect(provider.batches.first.name, 'Batch 1');

      final updatedBatch = BatchModel(
        id: 'b1',
        courseId: 'c1',
        name: 'Batch 1 Updated',
        timing: 'Evening',
        startDate: DateTime.now(),
        endDate: DateTime.now(),
        teacherName: 'Prof Kumar',
        teacherId: 't1',
        totalStudents: 5,
        batchPrice: 199,
      );

      await provider.updateBatch(updatedBatch);

      expect(fakeRepo.updateBatchCallCount, 1);
      expect(provider.batches.length, 1);
      expect(provider.batches.first.name, 'Batch 1 Updated');
      expect(provider.batches.first.batchPrice, 199);
      expect(provider.batches.first.teacherName, 'Prof Kumar');
    });

    test(
      'Failed batch update surfaces error and does not corrupt state',
      () async {
        final initialBatch = BatchModel(
          id: 'b1',
          courseId: 'c1',
          name: 'Batch 1',
          timing: 'Morning',
          startDate: DateTime.now(),
          endDate: DateTime.now(),
          teacherName: '',
          teacherId: '',
          totalStudents: 0,
          batchPrice: 100,
        );
        fakeRepo.batches = [initialBatch];
        await provider.fetchCatalog();

        fakeRepo.shouldFailUpdate = true;

        final updatedBatch = BatchModel(
          id: 'b1',
          courseId: 'c1',
          name: 'Batch Fail',
          timing: 'Evening',
          startDate: DateTime.now(),
          endDate: DateTime.now(),
          teacherName: '',
          teacherId: '',
          totalStudents: 0,
          batchPrice: 200,
        );

        try {
          await provider.updateBatch(updatedBatch);
          fail('Should throw');
        } catch (e) {
          expect(e.toString(), contains('Update failed'));
        }

        expect(fakeRepo.updateBatchCallCount, 1);
        expect(provider.errorMessage, contains('Update failed'));
      },
    );
  });
}
