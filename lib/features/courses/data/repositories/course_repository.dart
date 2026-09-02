import '../../../../core/errors/error_handler.dart';
import '../datasources/course_remote_data_source.dart';
import '../models/course_model.dart';
import '../models/batch_model.dart';

abstract class CourseRepository {
  Future<List<CourseModel>> getCourses();
  Future<List<BatchModel>> getBatches();
  Future<List<VideoLessonModel>> getVideoLessons(String courseId);
  Future<void> enrollInBatch({
    required String studentId,
    required String courseId,
    required String batchId,
    required String transactionId,
  });
}

class CourseRepositoryImpl implements CourseRepository {
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
  Future<List<BatchModel>> getBatches() async {
    try {
      return await _remoteDataSource.getBatches();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<List<VideoLessonModel>> getVideoLessons(String courseId) async {
    try {
      return await _remoteDataSource.getVideoLessons(courseId);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> enrollInBatch({
    required String studentId,
    required String courseId,
    required String batchId,
    required String transactionId,
  }) async {
    try {
      await _remoteDataSource.enrollInBatch(
        studentId: studentId,
        courseId: courseId,
        batchId: batchId,
        transactionId: transactionId,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
