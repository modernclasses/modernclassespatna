import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:modern_classes_patna/features/tests/data/models/test_model.dart';
import 'package:modern_classes_patna/features/tests/data/repositories/test_repository.dart';
import 'package:modern_classes_patna/features/tests/logic/test_provider.dart';
import 'package:modern_classes_patna/screens/student/test_taking_screen.dart';
import 'package:modern_classes_patna/screens/student/tests_screen.dart';

class MockFailingRepository implements TestRepository {
  bool shouldFail = true;
  List<TestModel> testList = [];
  TestResultModel? savedResult;

  @override
  Future<List<TestModel>> getTests() async => testList;

  @override
  Future<void> submitTestResult(TestResultModel result) async {
    if (shouldFail) {
      throw Exception(
        'duplicate key value violates unique constraint "test_submissions_test_id_student_id_key"',
      );
    }
    savedResult = result;
  }

  @override
  Future<TestModel> getTestPaper(String testId) async {
    if (shouldFail) {
      throw Exception(
        'Failed to load test paper from server: function get_test_paper(uuid) does not exist',
      );
    }
    return TestModel(
      id: testId,
      courseId: 'c1',
      batchId: 'b1',
      title: 'Mock Safe Paper',
      subject: 'General Studies',
      duration: const Duration(minutes: 30),
      totalMarks: 50.0,
      totalQuestions: 1,
      questions: const [
        QuestionModel(
          id: 'q_safe_1',
          text: 'Safe Question?',
          type: QuestionType.singleChoice,
          options: ['Yes', 'No'],
          correctOptionIndices: [],
          explanation: '',
          marks: 50.0,
        ),
      ],
      scheduledDate: DateTime.now(),
    );
  }

  @override
  Future<void> createTest(TestModel test) async {}

  @override
  Future<void> deleteTest(String testId) async {}

  @override
  Future<List<TestResultModel>> getTestSubmissionsForTest(String testId) async => [];
}

void main() {
  group('Phase B: Student-Safe Question Sanitization', () {
    test(
      'QuestionModel.toStudentSafe removes correct answers and explanation',
      () {
        const q = QuestionModel(
          id: 'q101',
          text: 'Who was the first President of India?',
          type: QuestionType.singleChoice,
          options: [
            'Dr. Rajendra Prasad',
            'Dr. S. Radhakrishnan',
            'Jawaharlal Nehru',
          ],
          correctOptionIndices: [0],
          explanation:
              'Dr. Rajendra Prasad was from Bihar and served as the first President.',
          marks: 4.0,
        );

        final safeQ = q.toStudentSafe();

        expect(safeQ.id, 'q101');
        expect(safeQ.text, 'Who was the first President of India?');
        expect(safeQ.options.length, 3);
        expect(safeQ.marks, 4.0);
        // Security Assertions:
        expect(safeQ.correctOptionIndices, isEmpty);
        expect(safeQ.explanation, isEmpty);
      },
    );

    test('TestModel.toStudentSafe sanitizes every question in the paper', () {
      final testPaper = TestModel(
        id: 'test_bpsc_01',
        courseId: 'crs_bpsc',
        batchId: 'batch_morning',
        title: 'BPSC Prelims Practice 01',
        subject: 'History',
        duration: const Duration(minutes: 60),
        totalMarks: 100.0,
        passingMarks: 40.0,
        negativeMarking: 0.25,
        totalQuestions: 2,
        questions: const [
          QuestionModel(
            id: 'q1',
            text: 'Question 1',
            type: QuestionType.singleChoice,
            options: ['A', 'B'],
            correctOptionIndices: [0],
            explanation: 'Answer is A',
            marks: 2.0,
          ),
          QuestionModel(
            id: 'q2',
            text: 'Question 2',
            type: QuestionType.multipleChoice,
            options: ['A', 'B', 'C'],
            correctOptionIndices: [0, 2],
            explanation: 'Answer is A and C',
            marks: 4.0,
          ),
        ],
        scheduledDate: DateTime(2026, 1, 1),
      );

      final safePaper = testPaper.toStudentSafe();

      expect(safePaper.title, 'BPSC Prelims Practice 01');
      expect(safePaper.negativeMarking, 0.25);
      expect(safePaper.questions.length, 2);
      expect(safePaper.questions[0].correctOptionIndices, isEmpty);
      expect(safePaper.questions[0].explanation, isEmpty);
      expect(safePaper.questions[1].correctOptionIndices, isEmpty);
      expect(safePaper.questions[1].explanation, isEmpty);
    });
  });

  group('Phase C: Objective Auto-Grading Rules & Score Boundaries', () {
    late MockFailingRepository repo;
    late TestProvider provider;

    setUp(() {
      repo = MockFailingRepository()..shouldFail = false;
      provider = TestProvider(repository: repo);
    });

    test(
      'scores single choice correctly (positive and negative marks)',
      () async {
        final singleChoiceTest = TestModel(
          id: 't_single',
          courseId: 'c1',
          batchId: 'b1',
          title: 'Single Choice Test',
          subject: 'General Studies',
          duration: const Duration(minutes: 10),
          totalMarks: 10.0,
          negativeMarking: 0.25,
          totalQuestions: 2,
          questions: const [
            QuestionModel(
              id: 'q1',
              text: 'Question 1',
              type: QuestionType.singleChoice,
              options: ['A', 'B'],
              correctOptionIndices: [0],
              explanation: '',
              marks: 4.0,
            ),
            QuestionModel(
              id: 'q2',
              text: 'Question 2',
              type: QuestionType.singleChoice,
              options: ['A', 'B'],
              correctOptionIndices: [1],
              explanation: '',
              marks: 4.0,
            ),
          ],
          scheduledDate: DateTime.now(),
        );

        provider.startTest(singleChoiceTest);
        // q1 correct (opt 0)
        provider.jumpToQuestion(0);
        provider.selectOptionForCurrentQuestion(0);
        // q2 wrong (selected opt 0 instead of 1)
        provider.jumpToQuestion(1);
        provider.selectOptionForCurrentQuestion(0);

        final result = await provider.submitTest(
          studentId: 'std_1',
          studentName: 'Student',
        );

        expect(result.correctCount, 1);
        expect(result.incorrectCount, 1);
        expect(result.unattemptedCount, 0);
        // Score: 4.0 - (4.0 * 0.25) = 3.0
        expect(result.score, 3.0);
      },
    );

    test(
      'multiple choice requires exact match (rejects subsets and extra options)',
      () async {
        final multiChoiceTest = TestModel(
          id: 't_multi',
          courseId: 'c1',
          batchId: 'b1',
          title: 'Multi Choice Test',
          subject: 'General Studies',
          duration: const Duration(minutes: 10),
          totalMarks: 12.0,
          negativeMarking: 0.33,
          totalQuestions: 2,
          questions: const [
            QuestionModel(
              id: 'q1',
              text: 'Question 1',
              type: QuestionType.multipleChoice,
              options: ['A', 'B', 'C', 'D'],
              correctOptionIndices: [0, 2], // A and C
              explanation: '',
              marks: 6.0,
            ),
            QuestionModel(
              id: 'q2',
              text: 'Question 2',
              type: QuestionType.multipleChoice,
              options: ['A', 'B', 'C', 'D'],
              correctOptionIndices: [1, 3], // B and D
              explanation: '',
              marks: 6.0,
            ),
          ],
          scheduledDate: DateTime.now(),
        );

        provider.startTest(multiChoiceTest);
        // q1: exact match [0, 2]
        provider.jumpToQuestion(0);
        provider.selectOptionForCurrentQuestion(0);
        provider.selectOptionForCurrentQuestion(2);

        // q2: partial match [1] only (missing 3)
        provider.jumpToQuestion(1);
        provider.selectOptionForCurrentQuestion(1);

        final result = await provider.submitTest(
          studentId: 'std_1',
          studentName: 'Student',
        );

        expect(result.correctCount, 1);
        expect(result.incorrectCount, 1);
        // Score: 6.0 - (6.0 * 0.33) = 6.0 - 1.98 = 4.02
        expect(result.score, closeTo(4.02, 0.01));
      },
    );

    test('true/false questions evaluate accurately', () async {
      final tfTest = TestModel(
        id: 't_tf',
        courseId: 'c1',
        batchId: 'b1',
        title: 'True False Test',
        subject: 'General Studies',
        duration: const Duration(minutes: 10),
        totalMarks: 4.0,
        negativeMarking: 0.5,
        totalQuestions: 1,
        questions: const [
          QuestionModel(
            id: 'q1',
            text: 'Patna High Court was established in 1916.',
            type: QuestionType.trueFalse,
            options: ['True', 'False'],
            correctOptionIndices: [0],
            explanation: '',
            marks: 4.0,
          ),
        ],
        scheduledDate: DateTime.now(),
      );

      provider.startTest(tfTest);
      provider.selectOptionForCurrentQuestion(0); // True

      final result = await provider.submitTest(
        studentId: 'std_1',
        studentName: 'Student',
      );

      expect(result.correctCount, 1);
      expect(result.score, 4.0);
    });

    test(
      'descriptive questions are preserved for manual review and NOT penalized with negative marks',
      () async {
        final descTest = TestModel(
          id: 't_desc',
          courseId: 'c1',
          batchId: 'b1',
          title: 'Descriptive Test',
          subject: 'Mains Essay',
          duration: const Duration(minutes: 30),
          totalMarks: 20.0,
          negativeMarking: 0.33,
          totalQuestions: 1,
          questions: const [
            QuestionModel(
              id: 'q_desc_1',
              text:
                  'Discuss the historical significance of the Champaran Satyagraha in 1917.',
              type: QuestionType.descriptive,
              options: [],
              correctOptionIndices: [],
              explanation: 'Key points: Tinkathia system protest...',
              marks: 20.0,
            ),
          ],
          scheduledDate: DateTime.now(),
        );

        provider.startTest(descTest);
        provider.setDescriptiveAnswer(
          'Mahatma Gandhi visited Champaran to protest against European indigo planters...',
        );

        final result = await provider.submitTest(
          studentId: 'std_1',
          studentName: 'Student',
        );

        // Crucial rule: Descriptive must NOT be penalized as wrong in auto-grader
        expect(result.correctCount, 0);
        expect(result.incorrectCount, 0);
        expect(result.unattemptedCount, 0);
        expect(result.score, 0.0); // No negative deduction!
        expect(
          result.responses['q_desc_1']?.writtenAnswer,
          contains('Mahatma Gandhi'),
        );
      },
    );

    test(
      'unanswered questions increment unattemptedCount without penalty',
      () async {
        final unattemptedTest = TestModel(
          id: 't_unatt',
          courseId: 'c1',
          batchId: 'b1',
          title: 'Skip Test',
          subject: 'General Studies',
          duration: const Duration(minutes: 10),
          totalMarks: 10.0,
          negativeMarking: 0.33,
          totalQuestions: 2,
          questions: const [
            QuestionModel(
              id: 'q1',
              text: 'Q1',
              type: QuestionType.singleChoice,
              options: ['A', 'B'],
              correctOptionIndices: [0],
              explanation: '',
              marks: 5.0,
            ),
            QuestionModel(
              id: 'q2',
              text: 'Q2',
              type: QuestionType.singleChoice,
              options: ['A', 'B'],
              correctOptionIndices: [1],
              explanation: '',
              marks: 5.0,
            ),
          ],
          scheduledDate: DateTime.now(),
        );

        provider.startTest(unattemptedTest);
        // Answer Q1 correctly, leave Q2 unattempted
        provider.jumpToQuestion(0);
        provider.selectOptionForCurrentQuestion(0);

        final result = await provider.submitTest(
          studentId: 'std_1',
          studentName: 'Student',
        );

        expect(result.correctCount, 1);
        expect(result.incorrectCount, 0);
        expect(result.unattemptedCount, 1);
        expect(result.score, 5.0);
      },
    );

    test(
      'score boundary: clamped to zero floor even if penalties exceed correct score',
      () async {
        final penalizingTest = TestModel(
          id: 't_pen',
          courseId: 'c1',
          batchId: 'b1',
          title: 'Penalizing Test',
          subject: 'General Studies',
          duration: const Duration(minutes: 10),
          totalMarks: 10.0,
          negativeMarking: 0.5,
          totalQuestions: 2,
          questions: const [
            QuestionModel(
              id: 'q1',
              text: 'Q1',
              type: QuestionType.singleChoice,
              options: ['A', 'B'],
              correctOptionIndices: [0],
              explanation: '',
              marks: 5.0,
            ),
            QuestionModel(
              id: 'q2',
              text: 'Q2',
              type: QuestionType.singleChoice,
              options: ['A', 'B'],
              correctOptionIndices: [0],
              explanation: '',
              marks: 5.0,
            ),
          ],
          scheduledDate: DateTime.now(),
        );

        provider.startTest(penalizingTest);
        // Answer both wrong (opt 1 instead of 0)
        provider.jumpToQuestion(0);
        provider.selectOptionForCurrentQuestion(1);
        provider.jumpToQuestion(1);
        provider.selectOptionForCurrentQuestion(1);

        final result = await provider.submitTest(
          studentId: 'std_1',
          studentName: 'Student',
        );

        expect(result.correctCount, 0);
        expect(result.incorrectCount, 2);
        // Raw score would be -5.0, clamped to 0.0 floor
        expect(result.score, 0.0);
      },
    );
  });

  group('Phase D: Schema-Compliant Persistence & Failure Handling', () {
    test(
      'TestResultModel.toSubmissionJson maps strictly to live test_submissions columns',
      () {
        final result = TestResultModel(
          id: 'client_temp_id_123',
          testId: '3fa85f64-5717-4562-b3fc-2c963f66afa6',
          testTitle: 'Client Test Title',
          studentId: '4fa85f64-5717-4562-b3fc-2c963f66afa7',
          studentName: 'Student Name',
          score: 16.5,
          maxScore: 20.0,
          percentage: 82.5,
          totalQuestions: 5,
          correctCount: 4,
          incorrectCount: 1,
          unattemptedCount: 0,
          totalTimeTaken: const Duration(seconds: 450),
          submittedAt: DateTime.parse('2026-10-16T12:00:00Z'),
          responses: const {},
        );

        final json = result.toSubmissionJson();

        // Verified live schema columns
        expect(json['test_id'], '3fa85f64-5717-4562-b3fc-2c963f66afa6');
        expect(json['student_id'], '4fa85f64-5717-4562-b3fc-2c963f66afa7');
        expect(json['score'], 16.5);
        expect(json['total_marks'], 20); // Integer in live DB
        expect(json['correct_count'], 4);
        expect(json['incorrect_count'], 1);
        expect(json['unattempted_count'], 0);
        expect(json['time_taken_seconds'], 450);
        expect(json['answers_json'], isA<Map>());
        expect(json['submitted_at'], '2026-10-16T12:00:00.000Z');

        // Crucial: Client temporary ID and unmapped fields are EXCLUDED
        expect(json.containsKey('id'), false);
        expect(json.containsKey('test_title'), false);
        expect(json.containsKey('student_name'), false);
        expect(json.containsKey('max_score'), false);
        expect(json.containsKey('percentage'), false);
        expect(json.containsKey('rank'), false);
        expect(json.containsKey('total_participants'), false);
        expect(json.containsKey('percentile'), false);
      },
    );

    test('TestResultModel.fromMap parses Supabase live row format', () {
      final dbRow = <String, dynamic>{
        'id': '5fa85f64-5717-4562-b3fc-2c963f66afa8',
        'test_id': '3fa85f64-5717-4562-b3fc-2c963f66afa6',
        'student_id': '4fa85f64-5717-4562-b3fc-2c963f66afa7',
        'score': 15.0,
        'total_marks': 20,
        'correct_count': 3,
        'incorrect_count': 1,
        'unattempted_count': 1,
        'time_taken_seconds': 300,
        'answers_json': <String, dynamic>{},
        'submitted_at': '2026-10-16T12:00:00Z',
      };

      final parsed = TestResultModel.fromMap(dbRow);

      expect(parsed.id, '5fa85f64-5717-4562-b3fc-2c963f66afa8');
      expect(parsed.testId, '3fa85f64-5717-4562-b3fc-2c963f66afa6');
      expect(parsed.score, 15.0);
      expect(parsed.maxScore, 20.0);
      expect(parsed.percentage, 75.0); // Computed dynamically
      expect(parsed.correctCount, 3);
      expect(parsed.totalTimeTaken.inSeconds, 300);
      expect(parsed.rank, isNull);
      expect(parsed.percentile, isNull);
    });

    test(
      'submission failure preserves active test responses for safe retry',
      () async {
        final failingRepo = MockFailingRepository()..shouldFail = true;
        final provider = TestProvider(repository: failingRepo);

        final testPaper = TestModel(
          id: 't_fail',
          courseId: 'c1',
          batchId: 'b1',
          title: 'Fail Test',
          subject: 'General Studies',
          duration: const Duration(minutes: 10),
          totalMarks: 5.0,
          totalQuestions: 1,
          questions: const [
            QuestionModel(
              id: 'q1',
              text: 'Q1',
              type: QuestionType.singleChoice,
              options: ['A', 'B'],
              correctOptionIndices: [0],
              explanation: '',
              marks: 5.0,
            ),
          ],
          scheduledDate: DateTime.now(),
        );

        provider.startTest(testPaper);
        provider.selectOptionForCurrentQuestion(0);

        // Attempt 1: Expect exception from repository
        await expectLater(
          provider.submitTest(studentId: 'std_1', studentName: 'Student'),
          throwsException,
        );

        // Critical state preservation: Responses and active session are NOT erased on failure
        expect(provider.activeTest, isNotNull);
        expect(provider.currentResponses['q1']?.selectedOptionIndices, [0]);
        expect(
          provider.errorMessage,
          contains('duplicate key value violates unique constraint'),
        );
        expect(
          provider.getResultForTest('t_fail'),
          isNull,
        ); // Result not marked completed

        // Attempt 2: After resolving failure, retry succeeds
        failingRepo.shouldFail = false;
        final retryResult = await provider.submitTest(
          studentId: 'std_1',
          studentName: 'Student',
        );

        expect(retryResult.score, 5.0);
        expect(provider.getResultForTest('t_fail'), isNotNull);
        expect(provider.activeTest, isNull); // Cleaned up only after success
      },
    );

    test(
      'getTestPaper fails clearly when RPC is not deployed rather than silently falling back',
      () async {
        final failingRepo = MockFailingRepository()..shouldFail = true;
        final provider = TestProvider(repository: failingRepo);

        // RPC not deployed / server returns error: MUST throw rather than return fallback
        await expectLater(
          provider.getTestPaper('t_undeployed'),
          throwsException,
        );

        // When deployed, delivers the paper
        failingRepo.shouldFail = false;
        final paper = await provider.getTestPaper('t_deployed');
        expect(paper.id, 't_deployed');
        expect(paper.questions.first.correctOptionIndices, isEmpty);
        expect(paper.questions.first.explanation, isEmpty);
      },
    );

    testWidgets(
      'TestTakingScreen cannot begin with an empty paper not fetched via RPC',
      (tester) async {
        final emptyPaper = TestModel(
          id: 't_empty',
          courseId: 'c1',
          batchId: 'b1',
          title: 'Empty Metadata Only Test',
          subject: 'General Studies',
          duration: const Duration(minutes: 30),
          totalMarks: 50.0,
          totalQuestions: 0,
          questions: const [],
          scheduledDate: DateTime.now(),
        );

        final fakeRepo = MockFailingRepository()..shouldFail = false;
        final provider = TestProvider(repository: fakeRepo);

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider<TestProvider>.value(
              value: provider,
              child: TestTakingScreen(test: emptyPaper),
            ),
          ),
        );

        // Verify the empty questions error screen is shown
        expect(find.text("No Question Paper Available"), findsOneWidget);
        expect(
          find.text(
            "The question paper could not be loaded from the secure server. Please return to the test series and try again.",
          ),
          findsOneWidget,
        );
        expect(find.text("Go Back"), findsOneWidget);

        // Verify timer did not start and active test is NOT registered
        expect(provider.activeTest, isNull);
      },
    );

    testWidgets(
      'TestsScreen shows clear error dialog when RPC get_test_paper fails and prevents entering TestTakingScreen',
      (tester) async {
        final testMetadata = TestModel(
          id: 't_meta',
          courseId: 'c1',
          batchId: 'b1',
          title: 'BPSC Prelims Mock',
          subject: 'General Studies',
          duration: const Duration(minutes: 30),
          totalMarks: 50.0,
          totalQuestions: 10,
          questions: const [], // List metadata has no questions
          scheduledDate: DateTime.now(),
        );

        final failingRepo = MockFailingRepository()
          ..shouldFail = true
          ..testList = [testMetadata];
        final provider = TestProvider(repository: failingRepo);

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider<TestProvider>.value(
              value: provider,
              child: const TestsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle(); // Settle initial fetchTests()

        expect(find.text("Start Mock Test"), findsOneWidget);
        await tester.tap(find.text("Start Mock Test"));
        await tester.pump(); // Show loading dialog
        await tester.pumpAndSettle(); // Resolve failure and show error dialog

        // Verify error dialog appears
        expect(find.text("Unable to Load Test Paper"), findsOneWidget);
        expect(
          find.textContaining(
            "Fallback to raw queries or mock data is strictly prohibited.",
          ),
          findsOneWidget,
        );
        expect(find.text("Retry"), findsOneWidget);

        // Verify we did NOT navigate to TestTakingScreen
        expect(find.text("No Question Paper Available"), findsNothing);
        expect(find.text("Question 1"), findsNothing);
        expect(provider.activeTest, isNull);
      },
    );
  });
}
