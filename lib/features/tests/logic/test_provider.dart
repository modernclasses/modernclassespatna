import 'package:flutter/material.dart';
import '../../../../data/mock_data.dart';
import '../data/models/test_model.dart';
import '../data/repositories/test_repository.dart';

class TestProvider extends ChangeNotifier {
  final TestRepository _repository;

  List<TestModel> _tests = List.from(MockData.tests);
  final Map<String, TestResultModel> _testResults = {};
  bool _isLoading = false;
  String? _errorMessage;

  // Active Test Session State
  TestModel? _activeTest;
  int _currentQuestionIndex = 0;
  Map<String, UserQuestionResponse> _currentResponses = {};
  Duration _timeElapsed = Duration.zero;

  List<TestModel> get tests => _tests;
  Map<String, TestResultModel> get testResults => _testResults;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  TestModel? get activeTest => _activeTest;
  int get currentQuestionIndex => _currentQuestionIndex;
  Map<String, UserQuestionResponse> get currentResponses => _currentResponses;
  Duration get timeElapsed => _timeElapsed;

  TestProvider({TestRepository? repository})
      : _repository = repository ?? TestRepositoryImpl() {
    fetchTests();
  }

  Future<void> fetchTests() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetched = await _repository.getTests();
      if (fetched.isNotEmpty) _tests = fetched;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  TestResultModel? getResultForTest(String testId) => _testResults[testId];

  void startTest(TestModel test) {
    _activeTest = test;
    _currentQuestionIndex = 0;
    _currentResponses = {
      for (var q in test.questions)
        q.id: UserQuestionResponse(questionId: q.id),
    };
    _timeElapsed = Duration.zero;
    notifyListeners();
  }

  void jumpToQuestion(int index) {
    if (_activeTest != null && index >= 0 && index < _activeTest!.questions.length) {
      _currentQuestionIndex = index;
      notifyListeners();
    }
  }

  void selectOptionForCurrentQuestion(int optionIndex) {
    if (_activeTest == null) return;
    final currentQ = _activeTest!.questions[_currentQuestionIndex];
    final currentResp = _currentResponses[currentQ.id] ?? UserQuestionResponse(questionId: currentQ.id);

    if (currentQ.type == QuestionType.singleChoice || currentQ.type == QuestionType.trueFalse) {
      _currentResponses[currentQ.id] = currentResp.copyWith(
        selectedOptionIndices: [optionIndex],
      );
    } else if (currentQ.type == QuestionType.multipleChoice) {
      final list = List<int>.from(currentResp.selectedOptionIndices);
      if (list.contains(optionIndex)) {
        list.remove(optionIndex);
      } else {
        list.add(optionIndex);
      }
      _currentResponses[currentQ.id] = currentResp.copyWith(
        selectedOptionIndices: list,
      );
    }
    notifyListeners();
  }

  void setDescriptiveAnswer(String text) {
    if (_activeTest == null) return;
    final currentQ = _activeTest!.questions[_currentQuestionIndex];
    final currentResp = _currentResponses[currentQ.id] ?? UserQuestionResponse(questionId: currentQ.id);

    _currentResponses[currentQ.id] = currentResp.copyWith(
      writtenAnswer: text,
    );
    notifyListeners();
  }

  void toggleMarkForReview() {
    if (_activeTest == null) return;
    final currentQ = _activeTest!.questions[_currentQuestionIndex];
    final currentResp = _currentResponses[currentQ.id] ?? UserQuestionResponse(questionId: currentQ.id);

    _currentResponses[currentQ.id] = currentResp.copyWith(
      isMarkedForReview: !currentResp.isMarkedForReview,
    );
    notifyListeners();
  }

  void updateTimeElapsed(Duration duration) {
    _timeElapsed = duration;
    notifyListeners();
  }

  void updateTimer(Duration elapsed) => updateTimeElapsed(elapsed);

  void clearCurrentResponse() {
    if (_activeTest == null) return;
    final currentQ = _activeTest!.questions[_currentQuestionIndex];
    _currentResponses[currentQ.id] = UserQuestionResponse(questionId: currentQ.id);
    notifyListeners();
  }

  TestResultModel submitTest({
    required String studentId,
    required String studentName,
  }) {
    if (_activeTest == null) {
      throw Exception("No active test to submit");
    }

    final test = _activeTest!;
    int correctCount = 0;
    int incorrectCount = 0;
    int unattemptedCount = 0;
    double score = 0.0;

    for (var q in test.questions) {
      final resp = _currentResponses[q.id];
      if (resp == null || (resp.selectedOptionIndices.isEmpty && (resp.writtenAnswer == null || resp.writtenAnswer!.trim().isEmpty))) {
        unattemptedCount++;
      } else {
        bool isCorrect = false;
        if (q.type == QuestionType.singleChoice || q.type == QuestionType.trueFalse) {
          if (resp.selectedOptionIndices.isNotEmpty &&
              q.correctOptionIndices.isNotEmpty &&
              resp.selectedOptionIndices.first == q.correctOptionIndices.first) {
            isCorrect = true;
          }
        } else if (q.type == QuestionType.multipleChoice) {
          final selected = Set.from(resp.selectedOptionIndices);
          final correct = Set.from(q.correctOptionIndices);
          if (selected.length == correct.length && selected.containsAll(correct)) {
            isCorrect = true;
          }
        }

        if (isCorrect) {
          correctCount++;
          score += q.marks;
        } else {
          incorrectCount++;
          // Negative marking (1/3rd of marks)
          score -= (q.marks / 3.0);
        }
      }
    }

    score = score.clamp(0.0, test.totalMarks);
    final percentage = (score / test.totalMarks) * 100.0;

    final result = TestResultModel(
      id: "res_${DateTime.now().millisecondsSinceEpoch}",
      testId: test.id,
      testTitle: test.title,
      studentId: studentId,
      studentName: studentName,
      score: score,
      maxScore: test.totalMarks,
      percentage: percentage,
      totalQuestions: test.totalQuestions,
      correctCount: correctCount,
      incorrectCount: incorrectCount,
      unattemptedCount: unattemptedCount,
      rank: 3,
      totalParticipants: test.attemptsCount + 1,
      percentile: percentage >= 80 ? 98.4 : (percentage >= 50 ? 86.2 : 62.1),
      totalTimeTaken: _timeElapsed,
      submittedAt: DateTime.now(),
      responses: Map.from(_currentResponses),
    );

    _testResults[test.id] = result;
    _repository.submitTestResult(result);

    // Reset active test
    _activeTest = null;
    _currentResponses = {};
    _currentQuestionIndex = 0;
    _timeElapsed = Duration.zero;

    notifyListeners();
    return result;
  }

  void addTest(TestModel test) {
    _tests.insert(0, test);
    _repository.createTest(test);
    notifyListeners();
  }
}
