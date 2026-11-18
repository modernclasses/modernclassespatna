import 'dart:typed_data';
import '../../../../core/errors/error_handler.dart';
import '../datasources/course_remote_data_source.dart';
import '../models/course_model.dart';
import '../models/batch_model.dart';
import '../../../../models/payment_model.dart';

abstract class CourseRepository {
  Future<List<CourseModel>> getCourses();
  Future<List<BatchModel>> getBatches();
  Future<List<BatchModel>> adminGetAllBatches();
  Future<List<VideoLessonModel>> getVideoLessons(String batchId);
  Future<void> enrollInBatch({
    String? purchaseToken,
    String? batchId,
    String? couponCode,
    double? amountPaid,
  });
  Future<Map<String, List<String>>> getMyEnrollments();
  Future<void> assignTeacherToBatch(String teacherId, String batchId);
  Future<void> setPrimaryBatchTeacher(String teacherId, String batchId);
  Future<void> removeTeacherFromBatch(String teacherId, String batchId);
  Future<List<Map<String, dynamic>>> getTeacherAssignments(String teacherId);
  Future<void> createCourse(
    CourseModel course, {
    List<BatchModel>? initialBatches,
    Map<int, List<String>>? batchTeacherIds,
  });
  Future<void> updateCourse(CourseModel course);
  Future<void> createBatch(BatchModel batch, {List<String>? teacherIds});
  Future<void> updateBatch(BatchModel batch, {List<String>? teacherIds});
  Future<void> deleteBatch(String batchId);
  Future<List<String>> getBatchTeacherIds(String batchId);
  Future<void> updateBatchTeachers(String batchId, List<String> teacherIds);

  Future<String> uploadLectureVideo({
    required String batchId,
    required String fileName,
    Uint8List? fileBytes,
    String? filePath,
    void Function(int uploadedBytes, int totalBytes)? onProgress,
    bool Function()? isCancelled,
  });

  Future<List<VideoLessonModel>> getLessonsForBatches(List<String> batchIds);

  Future<String> uploadCourseCoverImage({
    required String fileName,
    required Uint8List fileBytes,
  });

  Future<String> uploadLessonThumbnail({
    required String batchId,
    required String fileName,
    required Uint8List fileBytes,
  });

  Future<VideoLessonModel> updateLessonThumbnail({
    required String lessonId,
    required String thumbnailUrl,
  });

  Future<VideoLessonModel> updateLesson({
    required String lessonId,
    String? title,
    String? chapter,
    String? thumbnailUrl,
    String? notesPdfUrl,
  });

  Future<VideoLessonModel> createLesson({
    required String courseId,
    required String batchId,
    required String title,
    required String chapter,
    required String videoUrl,
    String? thumbnailUrl,
    int durationSeconds = 0,
    int? orderIndex,
  });

  Future<String> getLessonVideoSignedUrl(String videoUrlOrPath);

  Future<List<PaymentTransactionModel>> getStudentTransactions(
    String studentId,
  );
  Future<List<PaymentTransactionModel>> getAdminLedger(int offset, int limit);
  Future<double?> getAdminManualCollectionsTotal();
  Future<void> deleteCourse(String courseId);
  Future<void> deleteLesson(
    String lessonId, {
    String? videoPath,
    String? thumbnailPath,
  });
  Future<List<CouponModel>> getCoupons();
  Future<CouponModel> createCoupon(CouponModel coupon);
  Future<void> updateCoupon(CouponModel coupon);
  Future<void> deleteCoupon(String couponId);
}

class CourseRepositoryImpl implements CourseRepository {
  @override
  Future<void> createCourse(
    CourseModel course, {
    List<BatchModel>? initialBatches,
    Map<int, List<String>>? batchTeacherIds,
  }) async {
    try {
      await _remoteDataSource.createCourse(
        course,
        initialBatches: initialBatches,
        batchTeacherIds: batchTeacherIds,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> updateCourse(CourseModel course) async {
    try {
      await _remoteDataSource.updateCourse(course);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  final CourseRemoteDataSource _remoteDataSource;

  CourseRepositoryImpl({CourseRemoteDataSource? remoteDataSource})
    : _remoteDataSource = remoteDataSource ?? CourseRemoteDataSourceImpl();

  @override
  Future<List<CourseModel>> getCourses() async {
    try {
      return await _remoteDataSource.getCourses();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<List<BatchModel>> adminGetAllBatches() async {
    try {
      return await _remoteDataSource.adminGetAllBatches();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<List<BatchModel>> getBatches() async {
    try {
      return await _remoteDataSource.getBatches();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<List<VideoLessonModel>> getVideoLessons(String batchId) async {
    try {
      return await _remoteDataSource.getVideoLessons(batchId);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> enrollInBatch({
    String? purchaseToken,
    String? batchId,
    String? couponCode,
    double? amountPaid,
  }) async {
    try {
      await _remoteDataSource.enrollInBatch(
        purchaseToken: purchaseToken,
        batchId: batchId,
        couponCode: couponCode,
        amountPaid: amountPaid,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> assignTeacherToBatch(String teacherId, String batchId) async {
    try {
      await _remoteDataSource.assignTeacherToBatch(teacherId, batchId);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> setPrimaryBatchTeacher(String teacherId, String batchId) async {
    try {
      await _remoteDataSource.setPrimaryBatchTeacher(teacherId, batchId);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> removeTeacherFromBatch(String teacherId, String batchId) async {
    try {
      await _remoteDataSource.removeTeacherFromBatch(teacherId, batchId);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getTeacherAssignments(
    String teacherId,
  ) async {
    try {
      return await _remoteDataSource.getTeacherAssignments(teacherId);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<Map<String, List<String>>> getMyEnrollments() async {
    try {
      return await _remoteDataSource.getMyEnrollments();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> createBatch(BatchModel batch, {List<String>? teacherIds}) async {
    try {
      await _remoteDataSource.createBatch(batch, teacherIds: teacherIds);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> updateBatch(BatchModel batch, {List<String>? teacherIds}) async {
    try {
      await _remoteDataSource.updateBatch(batch, teacherIds: teacherIds);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<List<String>> getBatchTeacherIds(String batchId) async {
    try {
      return await _remoteDataSource.getBatchTeacherIds(batchId);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> updateBatchTeachers(
    String batchId,
    List<String> teacherIds,
  ) async {
    try {
      await _remoteDataSource.updateBatchTeachers(batchId, teacherIds);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> deleteBatch(String batchId) async {
    try {
      await _remoteDataSource.deleteBatch(batchId);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<List<PaymentTransactionModel>> getStudentTransactions(
    String studentId,
  ) async {
    try {
      return await _remoteDataSource.getStudentTransactions(studentId);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<List<PaymentTransactionModel>> getAdminLedger(
    int offset,
    int limit,
  ) async {
    try {
      return await _remoteDataSource.getAdminLedger(offset, limit);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<double?> getAdminManualCollectionsTotal() async {
    try {
      return await _remoteDataSource.getAdminManualCollectionsTotal();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<String> uploadLectureVideo({
    required String batchId,
    required String fileName,
    Uint8List? fileBytes,
    String? filePath,
    void Function(int uploadedBytes, int totalBytes)? onProgress,
    bool Function()? isCancelled,
  }) async {
    try {
      return await _remoteDataSource.uploadLectureVideo(
        batchId: batchId,
        fileName: fileName,
        fileBytes: fileBytes,
        filePath: filePath,
        onProgress: onProgress,
        isCancelled: isCancelled,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<List<VideoLessonModel>> getLessonsForBatches(List<String> batchIds) async {
    try {
      return await _remoteDataSource.getLessonsForBatches(batchIds);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<String> uploadCourseCoverImage({
    required String fileName,
    required Uint8List fileBytes,
  }) async {
    try {
      return await _remoteDataSource.uploadCourseCoverImage(
        fileName: fileName,
        fileBytes: fileBytes,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<String> uploadLessonThumbnail({
    required String batchId,
    required String fileName,
    required Uint8List fileBytes,
  }) async {
    try {
      return await _remoteDataSource.uploadLessonThumbnail(
        batchId: batchId,
        fileName: fileName,
        fileBytes: fileBytes,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<VideoLessonModel> updateLessonThumbnail({
    required String lessonId,
    required String thumbnailUrl,
  }) async {
    try {
      return await _remoteDataSource.updateLessonThumbnail(
        lessonId: lessonId,
        thumbnailUrl: thumbnailUrl,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<VideoLessonModel> updateLesson({
    required String lessonId,
    String? title,
    String? chapter,
    String? thumbnailUrl,
    String? notesPdfUrl,
  }) async {
    try {
      return await _remoteDataSource.updateLesson(
        lessonId: lessonId,
        title: title,
        chapter: chapter,
        thumbnailUrl: thumbnailUrl,
        notesPdfUrl: notesPdfUrl,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
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
    try {
      return await _remoteDataSource.createLesson(
        courseId: courseId,
        batchId: batchId,
        title: title,
        chapter: chapter,
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
        durationSeconds: durationSeconds,
        orderIndex: orderIndex,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<String> getLessonVideoSignedUrl(String videoUrlOrPath) async {
    try {
      return await _remoteDataSource.getLessonVideoSignedUrl(videoUrlOrPath);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> deleteCourse(String courseId) async {
    try {
      await _remoteDataSource.deleteCourse(courseId);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> deleteLesson(
    String lessonId, {
    String? videoPath,
    String? thumbnailPath,
  }) async {
    try {
      await _remoteDataSource.deleteLesson(
        lessonId,
        videoPath: videoPath,
        thumbnailPath: thumbnailPath,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<List<CouponModel>> getCoupons() async {
    try {
      return await _remoteDataSource.getCoupons();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<CouponModel> createCoupon(CouponModel coupon) async {
    try {
      return await _remoteDataSource.createCoupon(coupon);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> updateCoupon(CouponModel coupon) async {
    try {
      await _remoteDataSource.updateCoupon(coupon);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> deleteCoupon(String couponId) async {
    try {
      await _remoteDataSource.deleteCoupon(couponId);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
