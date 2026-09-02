/// Individual Reply to a Doubt Question.
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

  factory DoubtReplyModel.fromMap(Map<String, dynamic> map) {
    return DoubtReplyModel(
      id: map['id']?.toString() ?? '',
      authorId: map['author_id']?.toString() ?? '',
      authorName: map['author_name'] ?? 'User',
      authorRole: map['author_role'] ?? 'Student',
      message: map['message'] ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isOfficialTeacherAnswer: map['is_official_teacher_answer'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'author_id': authorId,
      'author_name': authorName,
      'author_role': authorRole,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'is_official_teacher_answer': isOfficialTeacherAnswer,
    };
  }
}

/// Student Doubt Question Model.
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

  factory DoubtModel.fromMap(Map<String, dynamic> map) {
    final rawReplies = (map['replies'] as List?)
            ?.map((r) => DoubtReplyModel.fromMap(r as Map<String, dynamic>))
            .toList() ??
        const [];

    return DoubtModel(
      id: map['id']?.toString() ?? '',
      studentId: map['student_id']?.toString() ?? '',
      studentName: map['student_name'] ?? 'Student Aspirant',
      subject: map['subject'] ?? 'General Studies',
      topic: map['topic'] ?? 'Topic Query',
      questionText: map['question_text'] ?? '',
      imageUrl: map['image_url'],
      askedAt: map['asked_at'] != null
          ? DateTime.tryParse(map['asked_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isResolved: map['is_resolved'] ?? false,
      replies: rawReplies,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'student_name': studentName,
      'subject': subject,
      'topic': topic,
      'question_text': questionText,
      'image_url': imageUrl,
      'asked_at': askedAt.toIso8601String(),
      'is_resolved': isResolved,
      'replies': replies.map((r) => r.toMap()).toList(),
    };
  }

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
