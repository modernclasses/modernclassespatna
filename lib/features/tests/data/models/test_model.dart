enum QuestionType {
  singleChoice,
  multipleChoice,
  trueFalse,
  descriptive,
}

enum QuestionStatus {
  unvisited,
  answered,
  markedForReview,
  unanswered,
}

/// Individual Question Model.
class QuestionModel {
  final String id;
  final String text;
  final QuestionType type;
  final List<String> options; // For MCQ & Multiple Correct
  final List<int> correctOptionIndices; // 0-indexed correct answers
  final String explanation;
  final double marks;

  const QuestionModel({
    required this.id,
    required this.text,
    required this.type,
    this.options = const [],
    this.correctOptionIndices = const [],
    required this.explanation,
    this.marks = 2.0,
  });

  factory QuestionModel.fromMap(Map<String, dynamic> map) {
    QuestionType parsedType = QuestionType.singleChoice;
    switch (map['type']?.toString().toLowerCase()) {
      case 'multiplechoice':
      case 'multiple_choice':
        parsedType = QuestionType.multipleChoice;
        break;
      case 'truefalse':
      case 'true_false':
        parsedType = QuestionType.trueFalse;
        break;
      case 'descriptive':
        parsedType = QuestionType.descriptive;
        break;
      default:
        parsedType = QuestionType.singleChoice;
    }

    return QuestionModel(
      id: map['id']?.toString() ?? '',
      text: map['text'] ?? '',
      type: parsedType,
      options: map['options'] != null
          ? List<String>.from(map['options'])
          : const [],
      correctOptionIndices: map['correct_option_indices'] != null
          ? List<int>.from(map['correct_option_indices'])
          : const [],
      explanation: map['explanation'] ?? '',
      marks: (map['marks'] as num?)?.toDouble() ?? 2.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'type': type.name,
      'options': options,
      'correct_option_indices': correctOptionIndices,
      'explanation': explanation,
      'marks': marks,
    };
  }
}

/// Test/Exam Paper Model.
class TestModel {
  final String id;
  final String courseId;
  final String batchId;
  final String title;
  final String subject;
  final Duration duration; // e.g. 30 mins
  final double totalMarks;
  final double passingMarks;
  final int totalQuestions;
  final List<QuestionModel> questions;
  final DateTime scheduledDate;
  final bool isLive;
  final bool allowsRetake;
  final int attemptsCount;

  const TestModel({
    required this.id,
    required this.courseId,
    required this.batchId,
    required this.title,
    required this.subject,
    required this.duration,
    required this.totalMarks,
    this.passingMarks = 40.0,
    required this.totalQuestions,
    required this.questions,
    required this.scheduledDate,
    this.isLive = true,
    this.allowsRetake = true,
    this.attemptsCount = 284,
  });

  factory TestModel.fromMap(Map<String, dynamic> map) {
    final questionsList = (map['questions'] as List?)
            ?.map((q) => QuestionModel.fromMap(q as Map<String, dynamic>))
            .toList() ??
        const [];

    return TestModel(
      id: map['id']?.toString() ?? '',
      courseId: map['course_id']?.toString() ?? '',
      batchId: map['batch_id']?.toString() ?? '',
      title: map['title'] ?? 'Mock Test',
      subject: map['subject'] ?? 'General Studies',
      duration: Duration(
        minutes: (map['duration_minutes'] as num?)?.toInt() ?? 30,
      ),
      totalMarks: (map['total_marks'] as num?)?.toDouble() ?? 100.0,
      passingMarks: (map['passing_marks'] as num?)?.toDouble() ?? 40.0,
      totalQuestions: (map['total_questions'] as num?)?.toInt() ?? questionsList.length,
      questions: questionsList,
      scheduledDate: map['scheduled_date'] != null
          ? DateTime.tryParse(map['scheduled_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isLive: map['is_live'] ?? true,
      allowsRetake: map['allows_retake'] ?? true,
      attemptsCount: (map['attempts_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'course_id': courseId,
      'batch_id': batchId,
      'title': title,
      'subject': subject,
      'duration_minutes': duration.inMinutes,
      'total_marks': totalMarks,
      'passing_marks': passingMarks,
      'total_questions': totalQuestions,
      'questions': questions.map((q) => q.toMap()).toList(),
      'scheduled_date': scheduledDate.toIso8601String(),
      'is_live': isLive,
      'allows_retake': allowsRetake,
      'attempts_count': attemptsCount,
    };
  }
}

/// Student's response to an individual question.
class UserQuestionResponse {
  final String questionId;
  final List<int> selectedOptionIndices;
  final String? writtenAnswer;
  final bool isMarkedForReview;
  final Duration timeSpent;

  const UserQuestionResponse({
    required this.questionId,
    this.selectedOptionIndices = const [],
    this.writtenAnswer,
    this.isMarkedForReview = false,
    this.timeSpent = Duration.zero,
  });

  factory UserQuestionResponse.fromMap(Map<String, dynamic> map) {
    return UserQuestionResponse(
      questionId: map['question_id']?.toString() ?? '',
      selectedOptionIndices: map['selected_option_indices'] != null
          ? List<int>.from(map['selected_option_indices'])
          : const [],
      writtenAnswer: map['written_answer'],
      isMarkedForReview: map['is_marked_for_review'] ?? false,
      timeSpent: Duration(seconds: (map['time_spent_seconds'] as num?)?.toInt() ?? 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'question_id': questionId,
      'selected_option_indices': selectedOptionIndices,
      'written_answer': writtenAnswer,
      'is_marked_for_review': isMarkedForReview,
      'time_spent_seconds': timeSpent.inSeconds,
    };
  }

  UserQuestionResponse copyWith({
    List<int>? selectedOptionIndices,
    String? writtenAnswer,
    bool? isMarkedForReview,
    Duration? timeSpent,
  }) {
    return UserQuestionResponse(
      questionId: questionId,
      selectedOptionIndices: selectedOptionIndices ?? this.selectedOptionIndices,
      writtenAnswer: writtenAnswer ?? this.writtenAnswer,
      isMarkedForReview: isMarkedForReview ?? this.isMarkedForReview,
      timeSpent: timeSpent ?? this.timeSpent,
    );
  }
}

/// Final Test Scorecard & Evaluation Result.
class TestResultModel {
  final String id;
  final String testId;
  final String testTitle;
  final String studentId;
  final String studentName;
  final double score;
  final double maxScore;
  final double percentage;
  final int totalQuestions;
  final int correctCount;
  final int incorrectCount;
  final int unattemptedCount;
  final int rank;
  final int totalParticipants;
  final double percentile;
  final Duration totalTimeTaken;
  final DateTime submittedAt;
  final Map<String, UserQuestionResponse> responses;

  const TestResultModel({
    required this.id,
    required this.testId,
    required this.testTitle,
    required this.studentId,
    required this.studentName,
    required this.score,
    required this.maxScore,
    required this.percentage,
    required this.totalQuestions,
    required this.correctCount,
    required this.incorrectCount,
    required this.unattemptedCount,
    required this.rank,
    required this.totalParticipants,
    required this.percentile,
    required this.totalTimeTaken,
    required this.submittedAt,
    required this.responses,
  });

  factory TestResultModel.fromMap(Map<String, dynamic> map) {
    final rawResponses = map['responses'] as Map<String, dynamic>? ?? {};
    final parsedResponses = rawResponses.map(
      (k, v) => MapEntry(k, UserQuestionResponse.fromMap(v as Map<String, dynamic>)),
    );

    return TestResultModel(
      id: map['id']?.toString() ?? '',
      testId: map['test_id']?.toString() ?? '',
      testTitle: map['test_title'] ?? 'Mock Test',
      studentId: map['student_id']?.toString() ?? '',
      studentName: map['student_name'] ?? 'Student',
      score: (map['score'] as num?)?.toDouble() ?? 0.0,
      maxScore: (map['max_score'] as num?)?.toDouble() ?? 100.0,
      percentage: (map['percentage'] as num?)?.toDouble() ?? 0.0,
      totalQuestions: (map['total_questions'] as num?)?.toInt() ?? 0,
      correctCount: (map['correct_count'] as num?)?.toInt() ?? 0,
      incorrectCount: (map['incorrect_count'] as num?)?.toInt() ?? 0,
      unattemptedCount: (map['unattempted_count'] as num?)?.toInt() ?? 0,
      rank: (map['rank'] as num?)?.toInt() ?? 1,
      totalParticipants: (map['total_participants'] as num?)?.toInt() ?? 1,
      percentile: (map['percentile'] as num?)?.toDouble() ?? 99.0,
      totalTimeTaken: Duration(seconds: (map['total_time_taken_seconds'] as num?)?.toInt() ?? 0),
      submittedAt: map['submitted_at'] != null
          ? DateTime.tryParse(map['submitted_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      responses: parsedResponses,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'test_id': testId,
      'test_title': testTitle,
      'student_id': studentId,
      'student_name': studentName,
      'score': score,
      'max_score': maxScore,
      'percentage': percentage,
      'total_questions': totalQuestions,
      'correct_count': correctCount,
      'incorrect_count': incorrectCount,
      'unattempted_count': unattemptedCount,
      'rank': rank,
      'total_participants': totalParticipants,
      'percentile': percentile,
      'total_time_taken_seconds': totalTimeTaken.inSeconds,
      'submitted_at': submittedAt.toIso8601String(),
      'responses': responses.map((k, v) => MapEntry(k, v.toMap())),
    };
  }
}
