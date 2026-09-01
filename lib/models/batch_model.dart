class BatchModel {
  final String id;
  final String courseId;
  final String name; // e.g. "Morning Target Batch A (Crash Course)"
  final String timing; // e.g. "08:00 AM - 10:00 AM"
  final DateTime startDate;
  final DateTime endDate;
  final String teacherName;
  final String teacherId;
  final int totalStudents;
  final int maxStudents;
  final double batchPrice; // e.g. 799
  final String medium; // "Hindi / English"

  const BatchModel({
    required this.id,
    required this.courseId,
    required this.name,
    required this.timing,
    required this.startDate,
    required this.endDate,
    required this.teacherName,
    required this.teacherId,
    required this.totalStudents,
    this.maxStudents = 500,
    required this.batchPrice,
    this.medium = "Bilingual (Hindi + English)",
  });
}
