/// Student Doubt Question Model.
class DoubtModel {
  final String id;
  final String studentId;
  final String batchId;
  final String? batchName;
  final String studentName;
  final String? studentPhone;
  final String subject;
  final String questionText;
  final String? attachmentUrl;
  final bool isResolved;
  final String? facultyReply;
  final String? facultyName;
  final String? resolvedBy;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  const DoubtModel({
    this.id = '',
    required this.studentId,
    required this.batchId,
    this.batchName,
    required this.studentName,
    this.studentPhone,
    required this.subject,
    required this.questionText,
    this.attachmentUrl,
    this.isResolved = false,
    this.facultyReply,
    this.facultyName,
    this.resolvedBy,
    required this.createdAt,
    this.resolvedAt,
  });

  factory DoubtModel.fromMap(Map<String, dynamic> map) {
    return DoubtModel(
      id: map['id']?.toString() ?? '',
      studentId: map['student_id']?.toString() ?? '',
      batchId: map['batch_id']?.toString() ?? '',
      batchName: map['batches'] != null
          ? map['batches']['name']?.toString()
          : null,
      studentName: map['student_name'] ?? 'Student Aspirant',
      studentPhone: map['student_phone']?.toString(),
      subject: map['subject'] ?? 'General Studies',
      questionText: map['question_text'] ?? '',
      attachmentUrl: map['attachment_url'],
      isResolved: map['is_resolved'] ?? false,
      facultyReply: map['faculty_reply'],
      facultyName: map['faculty_name'],
      resolvedBy: map['resolved_by'],
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      resolvedAt: map['resolved_at'] != null
          ? DateTime.tryParse(map['resolved_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toInsertMap() {
    final map = <String, dynamic>{
      'student_id': studentId,
      'batch_id': batchId,
      'student_name': studentName,
      'subject': subject,
      'question_text': questionText,
    };
    if (studentPhone != null) map['student_phone'] = studentPhone;
    if (attachmentUrl != null) map['attachment_url'] = attachmentUrl;
    return map;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'batch_id': batchId,
      'student_name': studentName,
      'student_phone': studentPhone,
      'subject': subject,
      'question_text': questionText,
      'attachment_url': attachmentUrl,
      'is_resolved': isResolved,
      'faculty_reply': facultyReply,
      'faculty_name': facultyName,
      'resolved_by': resolvedBy,
      'created_at': createdAt.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
    };
  }

  DoubtModel copyWith({
    bool? isResolved,
    String? facultyReply,
    String? facultyName,
    String? resolvedBy,
    DateTime? resolvedAt,
  }) {
    return DoubtModel(
      id: id,
      studentId: studentId,
      batchId: batchId,
      batchName: batchName,
      studentName: studentName,
      studentPhone: studentPhone,
      subject: subject,
      questionText: questionText,
      attachmentUrl: attachmentUrl,
      isResolved: isResolved ?? this.isResolved,
      facultyReply: facultyReply ?? this.facultyReply,
      facultyName: facultyName ?? this.facultyName,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      createdAt: createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }
}
