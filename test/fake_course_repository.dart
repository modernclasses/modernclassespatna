import 'package:modern_classes_patna/features/courses/data/repositories/course_repository.dart';
import 'package:modern_classes_patna/features/courses/data/models/course_model.dart';
import 'package:modern_classes_patna/features/courses/data/models/batch_model.dart';
import 'package:modern_classes_patna/models/payment_model.dart';

class FakeCourseRepository implements CourseRepository {
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
  Future<List<CourseModel>> getCourses() async {
    return [
      const CourseModel(
        id: "course_001",
        title: "BPSC Pre + Mains Target Batch",
        category: "BPSC",
        description: "description",
        coverImageUrl: "url",
        price: 1500,
        originalPrice: 2000,
        teacherId: "tch_001",
        teacherName: "Saurabh Kumar",
        totalLessons: 10,
        totalHours: 10,
        totalTests: 10,
        totalNotes: 10,
        rating: 4.9,
        reviewsCount: 100,
        highlights: [],
        isFeatured: false,
        isCrashCourse: false,
        playProductId: null,
      ),
    ];
  }

  @override
  Future<List<BatchModel>> adminGetAllBatches() async {
    return [
      BatchModel(
        id: "batch_001",
        courseId: "course_001",
        name: "Morning Batch",
        timing: "08:00 AM",
        batchPrice: 1500,
        teacherId: "tch_001",
        teacherName: "Saurabh Kumar",
        totalStudents: 10,
        medium: "Hindi",
        startDate: DateTime.now(),
        endDate: DateTime.now(),
      ),
    ];
  }

  @override
  Future<List<BatchModel>> getBatches() async {
    return [
      BatchModel(
        id: "batch_001",
        courseId: "course_001",
        name: "Morning Batch",
        timing: "08:00 AM",
        batchPrice: 1500,
        teacherId: "tch_001",
        teacherName: "Saurabh Kumar",
        totalStudents: 10,
        medium: "Hindi",
        startDate: DateTime.now(),
        endDate: DateTime.now(),
      ),
    ];
  }

  @override
  Future<List<VideoLessonModel>> getVideoLessons(String courseId) async {
    return [];
  }

  @override
  Future<void> enrollInBatch({
    String? purchaseToken,
    String? batchId,
    String? couponCode,
    double? amountPaid,
  }) async {}

  @override
  Future<Map<String, List<String>>> getMyEnrollments() async {
    return {
      'courseIds': ["crs_001", "crs_003"],
      'batchIds': ["batch_001"],
    };
  }

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
  Future<VideoLessonModel> updateLesson({
    required String lessonId,
    String? title,
    String? chapter,
    String? thumbnailUrl,
    String? notesPdfUrl,
  }) async {
    return VideoLessonModel(
      id: lessonId,
      courseId: 'mock-course',
      batchId: 'mock-batch',
      title: title ?? 'Updated Mock Lesson',
      chapter: chapter ?? 'Updated Mock Chapter',
      duration: Duration.zero,
      videoUrl: 'mock.mp4',
      thumbnailUrl: thumbnailUrl,
      notesPdfUrl: notesPdfUrl,
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

  final List<CouponModel> _mockCoupons = [];

  @override
  Future<List<CouponModel>> getCoupons() async => List.from(_mockCoupons);

  @override
  Future<CouponModel> createCoupon(CouponModel coupon) async {
    _mockCoupons.add(coupon);
    return coupon;
  }

  @override
  Future<void> updateCoupon(CouponModel coupon) async {
    final idx = _mockCoupons.indexWhere((c) => c.code == coupon.code);
    if (idx != -1) {
      _mockCoupons[idx] = coupon;
    } else {
      _mockCoupons.add(coupon);
    }
  }

  @override
  Future<void> deleteCoupon(String couponId) async {
    _mockCoupons.removeWhere((c) => c.id == couponId || c.code == couponId);
  }
}
