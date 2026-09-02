import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../data/mock_data.dart';
import '../models/course_model.dart';
import '../models/batch_model.dart';

abstract class CourseRemoteDataSource {
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

class CourseRemoteDataSourceImpl implements CourseRemoteDataSource {
  SupabaseClient? get _supabase {
    if (!AppConfig.isSupabaseConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<CourseModel>> getCourses() async {
    final client = _supabase;
    if (client == null) {
      // Offline / Local Mock Fallback
      return List.from(MockData.courses);
    }

    try {
      final response = await client
          .from('courses')
          .select()
          .order('created_at', ascending: false);

      final list = (response as List)
          .map((item) => CourseModel.fromMap(item as Map<String, dynamic>))
          .toList();

      return list.isNotEmpty ? list : List.from(MockData.courses);
    } catch (e) {
      debugPrint('Error fetching courses from Supabase: $e');
      // Fallback to local catalog if table is empty or error occurs
      return List.from(MockData.courses);
    }
  }

  @override
  Future<List<BatchModel>> getBatches() async {
    final client = _supabase;
    if (client == null) {
      return List.from(MockData.batches);
    }

    try {
      final response = await client
          .from('batches')
          .select()
          .order('start_date', ascending: true);

      final list = (response as List)
          .map((item) => BatchModel.fromMap(item as Map<String, dynamic>))
          .toList();

      return list.isNotEmpty ? list : List.from(MockData.batches);
    } catch (e) {
      debugPrint('Error fetching batches from Supabase: $e');
      return List.from(MockData.batches);
    }
  }

  @override
  Future<List<VideoLessonModel>> getVideoLessons(String courseId) async {
    final client = _supabase;
    if (client == null) {
      return MockData.videoLessons
          .where((v) => v.courseId == courseId)
          .toList();
    }

    try {
      final response = await client
          .from('lessons')
          .select()
          .eq('course_id', courseId)
          .order('order_index', ascending: true);

      return (response as List)
          .map((item) => VideoLessonModel.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching lessons from Supabase: $e');
      return MockData.videoLessons
          .where((v) => v.courseId == courseId)
          .toList();
    }
  }

  @override
  Future<void> enrollInBatch({
    required String studentId,
    required String courseId,
    required String batchId,
    required String transactionId,
  }) async {
    final client = _supabase;
    if (client == null) return;

    try {
      await client.from('enrollments').insert({
        'student_id': studentId,
        'course_id': courseId,
        'batch_id': batchId,
        'transaction_id': transactionId,
        'status': 'active',
        'enrolled_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error creating enrollment in Supabase: $e');
      throw ServerException('Failed to complete enrollment in database', e);
    }
  }
}
