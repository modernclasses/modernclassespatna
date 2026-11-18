import 'package:flutter/material.dart';
import '../data/models/test_model.dart';
import '../data/repositories/test_repository.dart';

class TestProvider extends ChangeNotifier {
  final TestRepository _repository;

  List<TestModel> _tests = [];
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
      _tests = fetched;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  TestResultModel? getResultForTest(String testId) => _testResults[testId];

  Future<TestModel> getTestPaper(String testId) async {
    try {
      return await _repository.getTestPaper(testId);
    } catch (e) {
      debugPrint('Error loading test paper: $e');
      rethrow;
    }
  }

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
    if (_activeTest != null &&
        index >= 0 &&
        index < _activeTest!.questions.length) {
      _currentQuestionIndex = index;
      notifyListeners();
    }
  }

  void selectOptionForCurrentQuestion(int optionIndex) {
    if (_activeTest == null) return;
    final currentQ = _activeTest!.questions[_currentQuestionIndex];
    final currentResp =
        _currentResponses[currentQ.id] ??
        UserQuestionResponse(questionId: currentQ.id);

    final isMulti = currentQ.type == QuestionType.multipleChoice ||
        (currentQ.type == QuestionType.caseBased && currentQ.correctOptionIndices.length > 1);

    if (currentQ.type == QuestionType.singleChoice ||
        currentQ.type == QuestionType.trueFalse ||
        (currentQ.type == QuestionType.caseBased && !isMulti)) {
      _currentResponses[currentQ.id] = currentResp.copyWith(
        selectedOptionIndices: [optionIndex],
      );
    } else if (isMulti) {
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

  void setDescriptiveAnswerForQuestion(String qId, String text) {
    if (_activeTest == null) return;
    final currentResp =
        _currentResponses[qId] ?? UserQuestionResponse(questionId: qId);
    _currentResponses[qId] = currentResp.copyWith(writtenAnswer: text);
    notifyListeners();
  }

  void setDescriptiveAnswer(String text) {
    if (_activeTest == null) return;
    final currentQ = _activeTest!.questions[_currentQuestionIndex];
    setDescriptiveAnswerForQuestion(currentQ.id, text);
  }

  void toggleMarkForReview() {
    if (_activeTest == null) return;
    final currentQ = _activeTest!.questions[_currentQuestionIndex];
    final currentResp =
        _currentResponses[currentQ.id] ??
        UserQuestionResponse(questionId: currentQ.id);

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
    _currentResponses[currentQ.id] = UserQuestionResponse(
      questionId: currentQ.id,
    );
    notifyListeners();
  }

  void resetActiveTest() {
    _activeTest = null;
    _currentResponses = {};
    _currentQuestionIndex = 0;
    _timeElapsed = Duration.zero;
    notifyListeners();
  }

  Future<TestResultModel> submitTest({
    required String studentId,
    required String studentName,
  }) async {
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
      if (resp == null ||
          (resp.selectedOptionIndices.isEmpty &&
              (resp.writtenAnswer == null ||
                  resp.writtenAnswer!.trim().isEmpty))) {
        unattemptedCount++;
      } else if (q.type == QuestionType.descriptive ||
          q.type == QuestionType.shortAnswer ||
          q.type == QuestionType.longAnswer ||
          (q.type == QuestionType.caseBased && q.options.isEmpty)) {
        // Descriptive, short answer, long answer, and text-based case studies are subjective.
        // They are preserved in answers_json for teacher/faculty review.
        // They are not penalized with negative marks, and no score is auto-awarded.
      } else {
        bool isCorrect = false;
        if (q.type == QuestionType.singleChoice ||
            q.type == QuestionType.trueFalse ||
            (q.type == QuestionType.caseBased && q.correctOptionIndices.length <= 1)) {
          if (resp.selectedOptionIndices.length == 1 &&
              q.correctOptionIndices.isNotEmpty &&
              resp.selectedOptionIndices.first ==
                  q.correctOptionIndices.first) {
            isCorrect = true;
          }
        } else if (q.type == QuestionType.multipleChoice ||
            (q.type == QuestionType.caseBased && q.correctOptionIndices.length > 1)) {
          final selected = Set.from(resp.selectedOptionIndices);
          final correct = Set.from(q.correctOptionIndices);
          if (selected.length == correct.length &&
              selected.containsAll(correct)) {
            isCorrect = true;
          }
        }

        if (isCorrect) {
          correctCount++;
          score += q.marks;
        } else {
          incorrectCount++;
          // Negative marking driven by test configuration
          score -= (q.marks * test.negativeMarking);
        }
      }
    }

    score = score.clamp(0.0, test.totalMarks);
    final percentage = test.totalMarks > 0
        ? (score / test.totalMarks) * 100.0
        : 0.0;

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
      rank: null,
      totalParticipants: null,
      percentile: null,
      totalTimeTaken: _timeElapsed,
      submittedAt: DateTime.now(),
      responses: Map.from(_currentResponses),
    );

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.submitTestResult(result);
      _testResults[test.id] = result;

      // Reset active test session only after confirmed persistence
      _activeTest = null;
      _currentResponses = {};
      _currentQuestionIndex = 0;
      _timeElapsed = Duration.zero;
      _isLoading = false;

      notifyListeners();
      return result;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> addTest(TestModel test) async {
    _tests.insert(0, test);
    notifyListeners();
    try {
      await _repository.createTest(test);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteTest(String testId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.deleteTest(testId);
      _tests.removeWhere((t) => t.id == testId);
      _testResults.remove(testId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<List<TestResultModel>> getTestSubmissionsForTest(String testId) async {
    try {
      return await _repository.getTestSubmissionsForTest(testId);
    } catch (e) {
      debugPrint('Error getting test submissions in provider: $e');
      rethrow;
    }
  }
}
