import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../data/mock_data.dart';
import '../models/test_model.dart';

abstract class TestRemoteDataSource {
  Future<List<TestModel>> getTests();
  Future<void> submitTestResult(TestResultModel result);
  Future<void> createTest(TestModel test);
}

class TestRemoteDataSourceImpl implements TestRemoteDataSource {
  SupabaseClient? get _supabase {
    if (!AppConfig.isSupabaseConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<TestModel>> getTests() async {
    final client = _supabase;
    if (client == null) {
      return List.from(MockData.tests);
    }

    try {
      final response = await client
          .from('tests')
          .select()
          .order('scheduled_date', ascending: false);

      final list = (response as List)
          .map((item) => TestModel.fromMap(item as Map<String, dynamic>))
          .toList();

      return list.isNotEmpty ? list : List.from(MockData.tests);
    } catch (e) {
      debugPrint('Error fetching tests from Supabase: $e');
      return List.from(MockData.tests);
    }
  }

  @override
  Future<void> submitTestResult(TestResultModel result) async {
    final client = _supabase;
    if (client == null) return;

    try {
      await client.from('test_submissions').insert(result.toMap());
    } catch (e) {
      debugPrint('Error saving test result in Supabase: $e');
      throw ServerException('Failed to submit test results to cloud', e);
    }
  }

  @override
  Future<void> createTest(TestModel test) async {
    final client = _supabase;
    if (client == null) return;

    try {
      await client.from('tests').insert(test.toMap());
    } catch (e) {
      debugPrint('Error creating test in Supabase: $e');
      throw ServerException('Failed to create new test paper', e);
    }
  }
}
