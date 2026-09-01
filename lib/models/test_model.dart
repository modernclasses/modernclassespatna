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
}

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
}

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
}
