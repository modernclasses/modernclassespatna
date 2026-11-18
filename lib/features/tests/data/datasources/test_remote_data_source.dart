import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/test_model.dart';

abstract class TestRemoteDataSource {
  Future<List<TestModel>> getTests();
  Future<TestModel> getTestPaper(String testId);
  Future<void> submitTestResult(TestResultModel result);
  Future<void> createTest(TestModel test);
  Future<void> deleteTest(String testId);
  Future<List<TestResultModel>> getTestSubmissionsForTest(String testId);
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
      throw const ServerException('Supabase not configured');
    }

    try {
      final response = await client
          .from('tests')
          .select(
            'id, course_id, batch_id, title, category, subject, duration_minutes, total_marks, negative_marking, status, created_at',
          )
          .order('created_at', ascending: false);

      final list = (response as List)
          .map((item) => TestModel.fromMap(item as Map<String, dynamic>))
          .toList();

      return list;
    } catch (e) {
      debugPrint('Error fetching tests from Supabase: $e');
      throw ServerException('Failed to fetch tests', e);
    }
  }

  @override
  Future<TestModel> getTestPaper(String testId) async {
    final client = _supabase;
    if (client == null) {
      throw const ServerException('Supabase not configured');
    }

    try {
      final response = await client.rpc(
        'get_test_paper',
        params: {'p_test_id': testId},
      );

      if (response != null) {
        final Map<String, dynamic> data = response is Map<String, dynamic>
            ? response
            : (response is List && response.isNotEmpty
                  ? response.first as Map<String, dynamic>
                  : throw const ServerException(
                      'Malformed test paper response from server',
                    ));

        return TestModel.fromMap(data);
      }
    } catch (e) {
      debugPrint('RPC get_test_paper fallback triggered: $e');
    }

    // Authoritative fallback query from public.tests table
    try {
      final response = await client
          .from('tests')
          .select()
          .eq('id', testId)
          .maybeSingle();

      if (response != null) {
        final model = TestModel.fromMap(response);
        return model.toStudentSafe();
      }
      throw const ServerException('Test paper not found on server');
    } catch (e) {
      debugPrint('Error fetching test paper from Supabase: $e');
      throw ServerException('Failed to load test paper from server', e);
    }
  }

  @override
  Future<void> submitTestResult(TestResultModel result) async {
    final client = _supabase;
    if (client == null) return;

    // 1. Authoritative server-side grading via RPC
    try {
      final answersJson = result.toSubmissionJson()['answers_json'] ?? {};
      await client.rpc('submit_student_test', params: {
        'p_test_id': result.testId,
        'p_answers_json': answersJson,
        'p_time_taken_seconds': result.totalTimeTaken.inSeconds,
      });
      return;
    } catch (rpcErr) {
      debugPrint('RPC submit_student_test notice: $rpcErr. Falling back to direct insert...');
    }

    // 2. Direct insert fallback
    try {
      await client.from('test_submissions').insert(result.toSubmissionJson());
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
      await client.from('tests').insert(test.toDbMap());

      // Auto-update total_tests on courses
      try {
        final countRes = await client.from('tests').select('id').eq('course_id', test.courseId);
        final count = (countRes as List).length;
        await client.from('courses').update({
          'total_tests': count,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', test.courseId);
      } catch (statsErr) {
        debugPrint('Non-critical: Failed to auto-update course test stats: $statsErr');
      }
    } catch (e) {
      debugPrint('Error creating test in Supabase: $e');
      throw ServerException('Failed to create new test paper', e);
    }
  }

  @override
  Future<void> deleteTest(String testId) async {
    final client = _supabase;
    if (client == null) {
      throw const ServerException('Supabase not configured');
    }

    try {
      String? courseId;
      try {
        final testRow = await client.from('tests').select('course_id').eq('id', testId).maybeSingle();
        courseId = testRow?['course_id']?.toString();
      } catch (_) {}

      await client.from('tests').delete().eq('id', testId);

      if (courseId != null) {
        try {
          final countRes = await client.from('tests').select('id').eq('course_id', courseId);
          final count = (countRes as List).length;
          await client.from('courses').update({
            'total_tests': count,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', courseId);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error deleting test from Supabase: $e');
      throw ServerException('Failed to delete test', e);
    }
  }

  @override
  Future<List<TestResultModel>> getTestSubmissionsForTest(String testId) async {
    final client = _supabase;
    if (client == null) {
      throw const ServerException('Supabase not configured');
    }

    try {
      dynamic response;
      try {
        response = await client
            .from('test_submissions')
            .select('*, profiles!student_id(full_name, email)')
            .eq('test_id', testId)
            .order('submitted_at', ascending: false);
      } catch (_) {
        response = await client
            .from('test_submissions')
            .select()
            .eq('test_id', testId)
            .order('submitted_at', ascending: false);
      }

      final submissions = response as List;
      if (submissions.isEmpty) return [];

      TestModel? testPaper;
      try {
        testPaper = await getTestPaper(testId);
      } catch (_) {}

      final results = <TestResultModel>[];
      for (final raw in submissions) {
        final item = raw as Map<String, dynamic>;
        final profile = item['profiles'] as Map<String, dynamic>?;
        final studentName = profile?['full_name'] ??
            profile?['email'] ??
            'Student (${(item['student_id']?.toString() ?? 'ID').split('-').first})';

        final scoreVal = (item['score'] as num?)?.toDouble() ?? 0.0;
        final totalMarksVal =
            (item['total_marks'] as num?)?.toDouble() ??
            testPaper?.totalMarks ??
            100.0;
        final percentageVal = totalMarksVal > 0
            ? (scoreVal / totalMarksVal) * 100.0
            : 0.0;

        final answersJson =
            (item['answers_json'] as Map<String, dynamic>?) ?? {};
        final parsedResponses = <String, UserQuestionResponse>{};

        if (testPaper != null && testPaper.questions.isNotEmpty) {
          for (int i = 0; i < testPaper.questions.length; i++) {
            final q = testPaper.questions[i];
            final ans = answersJson[q.id] ?? answersJson[i.toString()];
            if (ans != null) {
              if (ans is int) {
                parsedResponses[q.id] = UserQuestionResponse(
                  questionId: q.id,
                  selectedOptionIndices: [ans],
                );
              } else if (ans is List) {
                parsedResponses[q.id] = UserQuestionResponse(
                  questionId: q.id,
                  selectedOptionIndices: List<int>.from(ans.map((e) => int.tryParse(e.toString()) ?? 0)),
                );
              } else if (ans is String) {
                parsedResponses[q.id] = UserQuestionResponse(
                  questionId: q.id,
                  writtenAnswer: ans,
                );
              }
            }
          }
        }

        results.add(
          TestResultModel(
            id: item['id']?.toString() ?? '',
            testId: testId,
            testTitle: testPaper?.title ?? 'Test Paper',
            studentId: item['student_id']?.toString() ?? '',
            studentName: studentName.toString(),
            score: scoreVal,
            maxScore: totalMarksVal,
            percentage: percentageVal,
            totalQuestions: testPaper?.totalQuestions ??
                ((item['correct_count'] as num?)?.toInt() ?? 0) +
                    ((item['incorrect_count'] as num?)?.toInt() ?? 0) +
                    ((item['unattempted_count'] as num?)?.toInt() ?? 0),
            correctCount: (item['correct_count'] as num?)?.toInt() ?? 0,
            incorrectCount: (item['incorrect_count'] as num?)?.toInt() ?? 0,
            unattemptedCount: (item['unattempted_count'] as num?)?.toInt() ?? 0,
            totalTimeTaken: Duration(
              seconds: (item['time_taken_seconds'] as num?)?.toInt() ?? 0,
            ),
            submittedAt: item['submitted_at'] != null
                ? DateTime.tryParse(item['submitted_at'].toString()) ??
                    DateTime.now()
                : DateTime.now(),
            responses: parsedResponses,
          ),
        );
      }

      return results;
    } catch (e) {
      debugPrint('Error fetching test submissions: $e');
      throw ServerException('Failed to load test submissions from server', e);
    }
  }
}
