class DoubtReplyModel {
  final String id;
  final String authorId;
  final String authorName;
  final String authorRole; // "Teacher", "Student", "Admin"
  final String message;
  final DateTime timestamp;
  final bool isOfficialTeacherAnswer;

  const DoubtReplyModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.message,
    required this.timestamp,
    this.isOfficialTeacherAnswer = false,
  });
}

class DoubtModel {
  final String id;
  final String studentId;
  final String studentName;
  final String subject;
  final String topic;
  final String questionText;
  final String? imageUrl;
  final DateTime askedAt;
  final bool isResolved;
  final List<DoubtReplyModel> replies;

  const DoubtModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.subject,
    required this.topic,
    required this.questionText,
    this.imageUrl,
    required this.askedAt,
    this.isResolved = false,
    this.replies = const [],
  });

  DoubtModel copyWith({
    bool? isResolved,
    List<DoubtReplyModel>? replies,
  }) {
    return DoubtModel(
      id: id,
      studentId: studentId,
      studentName: studentName,
      subject: subject,
      topic: topic,
      questionText: questionText,
      imageUrl: imageUrl,
      askedAt: askedAt,
      isResolved: isResolved ?? this.isResolved,
      replies: replies ?? this.replies,
    );
  }
}
