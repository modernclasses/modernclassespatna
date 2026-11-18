import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_classes_patna/features/tests/data/models/test_model.dart';
import 'package:modern_classes_patna/features/tests/data/repositories/test_repository.dart';
import 'package:modern_classes_patna/features/tests/logic/test_provider.dart';
import 'package:modern_classes_patna/screens/student/test_result_screen.dart';

class FakeTestRepository implements TestRepository {
  TestResultModel? lastSubmittedResult;

  @override
  Future<List<TestModel>> getTests() async => [];

  @override
  Future<void> submitTestResult(TestResultModel result) async {
    lastSubmittedResult = result;
  }

  @override
  Future<TestModel> getTestPaper(String testId) async {
    throw UnimplementedError();
  }

  @override
  Future<void> createTest(TestModel test) async {}

  @override
  Future<void> deleteTest(String testId) async {}

  @override
  Future<List<TestResultModel>> getTestSubmissionsForTest(String testId) async => [];
}

void main() {
  final sampleTest = TestModel(
    id: 'test_1',
    courseId: 'crs_1',
    batchId: 'batch_1',
    title: 'BPSC Mock Test 01',
    subject: 'General Studies',
    duration: const Duration(minutes: 30),
    totalMarks: 20.0,
    passingMarks: 8.0,
    totalQuestions: 1,
    questions: const [
      QuestionModel(
        id: 'q1',
        text: 'Who was the leader of the 1857 Revolt in Jagdishpur?',
        type: QuestionType.singleChoice,
        options: ['Nana Saheb', 'Veer Kunwar Singh'],
        correctOptionIndices: [1],
        explanation: 'Veer Kunwar Singh led the revolt.',
        marks: 2.0,
      ),
    ],
    scheduledDate: DateTime(2026, 1, 1),
    isLive: true,
    allowsRetake: true,
    attemptsCount: 200,
  );

  group('TestResultModel Nullable Ranking & Percentile', () {
    test('instantiates with null rank, totalParticipants, and percentile', () {
      final result = TestResultModel(
        id: 'res_001',
        testId: 'test_1',
        testTitle: 'BPSC Mock Test 01',
        studentId: 'std_1',
        studentName: 'Student Name',
        score: 18.0,
        maxScore: 20.0,
        percentage: 90.0,
        totalQuestions: 1,
        correctCount: 1,
        incorrectCount: 0,
        unattemptedCount: 0,
        rank: null,
        totalParticipants: null,
        percentile: null,
        totalTimeTaken: const Duration(minutes: 5),
        submittedAt: DateTime(2026, 1, 1),
        responses: const {},
      );

      expect(result.rank, isNull);
      expect(result.totalParticipants, isNull);
      expect(result.percentile, isNull);

      final map = result.toMap();
      expect(map['rank'], isNull);
      expect(map['total_participants'], isNull);
      expect(map['percentile'], isNull);
    });

    test(
      'fromMap parses null and missing rank keys as null without fake fallbacks',
      () {
        final mapWithNulls = <String, dynamic>{
          'id': 'res_001',
          'test_id': 'test_1',
          'test_title': 'Mock Test',
          'student_id': 'std_1',
          'student_name': 'Student',
          'score': 10.0,
          'max_score': 20.0,
          'percentage': 50.0,
          'total_questions': 1,
          'correct_count': 1,
          'incorrect_count': 0,
          'unattempted_count': 0,
          'rank': null,
          'total_participants': null,
          'percentile': null,
          'total_time_taken_seconds': 60,
          'submitted_at': '2026-01-01T12:00:00.000Z',
          'responses': <String, dynamic>{},
        };

        final parsed = TestResultModel.fromMap(mapWithNulls);
        expect(parsed.rank, isNull);
        expect(parsed.totalParticipants, isNull);
        expect(parsed.percentile, isNull);

        // Verify omitted keys also resolve to null, not 1 or 99.0
        mapWithNulls.remove('rank');
        mapWithNulls.remove('total_participants');
        mapWithNulls.remove('percentile');

        final parsedOmitted = TestResultModel.fromMap(mapWithNulls);
        expect(parsedOmitted.rank, isNull);
        expect(parsedOmitted.totalParticipants, isNull);
        expect(parsedOmitted.percentile, isNull);
      },
    );

    test('fromMap correctly preserves real cohort data when provided', () {
      final mapWithRealData = <String, dynamic>{
        'id': 'res_002',
        'test_id': 'test_1',
        'test_title': 'Mock Test',
        'student_id': 'std_1',
        'student_name': 'Student',
        'score': 18.0,
        'max_score': 20.0,
        'percentage': 90.0,
        'total_questions': 1,
        'correct_count': 1,
        'incorrect_count': 0,
        'unattempted_count': 0,
        'rank': 7,
        'total_participants': 140,
        'percentile': 95.2,
        'total_time_taken_seconds': 120,
        'submitted_at': '2026-01-01T12:00:00.000Z',
        'responses': <String, dynamic>{},
      };

      final parsed = TestResultModel.fromMap(mapWithRealData);
      expect(parsed.rank, 7);
      expect(parsed.totalParticipants, 140);
      expect(parsed.percentile, 95.2);
    });
  });

  group('TestProvider Submission Metrics Remediation', () {
    test(
      'submitTest does not fabricate rank, attempts count, or percentile',
      () async {
        final fakeRepo = FakeTestRepository();
        final provider = TestProvider(repository: fakeRepo);

        provider.startTest(sampleTest);
        provider.selectOptionForCurrentQuestion(1);

        final result = await provider.submitTest(
          studentId: 'student_99',
          studentName: 'Aspirant',
        );

        // Verify values are strictly null, not hardcoded placeholders
        expect(result.rank, isNull);
        expect(result.totalParticipants, isNull);
        expect(result.percentile, isNull);

        // Explicitly assert that old mock values are absent
        expect(result.rank, isNot(3));
        expect(result.totalParticipants, isNot(201));
        expect(result.totalParticipants, isNot(285));
        expect(result.percentile, isNot(98.4));
        expect(result.percentile, isNot(86.2));
        expect(result.percentile, isNot(62.1));

        // Verify repository received the clean result
        expect(fakeRepo.lastSubmittedResult?.rank, isNull);
        expect(fakeRepo.lastSubmittedResult?.totalParticipants, isNull);
        expect(fakeRepo.lastSubmittedResult?.percentile, isNull);
      },
    );
  });

  group('TestResultScreen Neutral State Display', () {
    testWidgets(
      'renders neutral Pending state when rank and percentile are null',
      (WidgetTester tester) async {
        final neutralResult = TestResultModel(
          id: 'res_neutral',
          testId: sampleTest.id,
          testTitle: sampleTest.title,
          studentId: 'student_99',
          studentName: 'Aspirant',
          score: 18.0,
          maxScore: 20.0,
          percentage: 90.0,
          totalQuestions: 1,
          correctCount: 1,
          incorrectCount: 0,
          unattemptedCount: 0,
          rank: null,
          totalParticipants: null,
          percentile: null,
          totalTimeTaken: const Duration(minutes: 10),
          submittedAt: DateTime(2026, 1, 1),
          responses: const {},
        );

        await tester.pumpWidget(
          MaterialApp(
            home: TestResultScreen(result: neutralResult, test: sampleTest),
          ),
        );
        await tester.pumpAndSettle();

        // Ensure no exceptions or layout overflows
        expect(tester.takeException(), isNull);

        // Verify neutral indicators '—' and 'Pending' are displayed
        expect(find.text('—'), findsNWidgets(2));
        expect(find.text('Pending'), findsNWidgets(2));

        // Assert that fabricated values are NOT rendered
        expect(find.text('#3'), findsNothing);
        expect(find.textContaining('out of 285'), findsNothing);
        expect(find.textContaining('out of 201'), findsNothing);
        expect(find.text('98.4%'), findsNothing);
        expect(find.text('86.2%'), findsNothing);
        expect(find.text('62.1%'), findsNothing);
      },
    );

    testWidgets(
      'renders real rank and percentile when authorized data is provided',
      (WidgetTester tester) async {
        final cohortResult = TestResultModel(
          id: 'res_cohort',
          testId: sampleTest.id,
          testTitle: sampleTest.title,
          studentId: 'student_99',
          studentName: 'Aspirant',
          score: 18.0,
          maxScore: 20.0,
          percentage: 90.0,
          totalQuestions: 1,
          correctCount: 1,
          incorrectCount: 0,
          unattemptedCount: 0,
          rank: 4,
          totalParticipants: 85,
          percentile: 96.5,
          totalTimeTaken: const Duration(minutes: 10),
          submittedAt: DateTime(2026, 1, 1),
          responses: const {},
        );

        await tester.pumpWidget(
          MaterialApp(
            home: TestResultScreen(result: cohortResult, test: sampleTest),
          ),
        );
        await tester.pumpAndSettle();

        // Ensure no exceptions or layout overflows
        expect(tester.takeException(), isNull);

        // Verify real metrics are rendered properly
        expect(find.text('#4'), findsOneWidget);
        expect(find.text('out of 85'), findsOneWidget);
        expect(find.text('96.5%'), findsOneWidget);

        // Neutral placeholders should not appear
        expect(find.text('—'), findsNothing);
        expect(find.text('Pending'), findsNothing);
      },
    );
  });
}
