/// Batch Entity for Classroom & Live Timings.
class BatchModel {
  final String id;
  final String courseId;
  final String name; // e.g. "Morning Target Batch A"
  final String timing; // e.g. "08:00 AM - 10:00 AM"
  final DateTime startDate;
  final DateTime endDate;
  final String teacherName;
  final String teacherId;
  final int totalStudents;
  final int maxStudents;
  final double batchPrice;
  final String medium; // "Bilingual (Hindi + English)"
  final bool isActive;

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
    this.isActive = true,
  });

  /// Deserialize from Supabase `public.batches` row.
  factory BatchModel.fromMap(Map<String, dynamic> map) {
    return BatchModel(
      id: map['id']?.toString() ?? '',
      courseId: map['course_id']?.toString() ?? '',
      name: map['name'] ?? 'Target Batch',
      timing: map['timing'] ?? '08:00 AM - 10:00 AM',
      startDate: map['start_date'] != null
          ? DateTime.tryParse(map['start_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      endDate: map['end_date'] != null
          ? DateTime.tryParse(map['end_date'].toString()) ??
              DateTime.now().add(const Duration(days: 90))
          : DateTime.now().add(const Duration(days: 90)),
      teacherName: map['teacher_name'] ?? 'Faculty Member',
      teacherId: map['teacher_id']?.toString() ?? '',
      totalStudents: (map['total_students'] as num?)?.toInt() ?? 0,
      maxStudents: (map['max_students'] as num?)?.toInt() ?? 500,
      batchPrice: (map['batch_price'] as num?)?.toDouble() ?? 799.0,
      medium: map['medium'] ?? 'Bilingual (Hindi + English)',
      isActive: map['is_active'] ?? true,
    );
  }

  /// Serialize to Supabase `public.batches` format.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'course_id': courseId,
      'name': name,
      'timing': timing,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'teacher_name': teacherName,
      'teacher_id': teacherId,
      'total_students': totalStudents,
      'max_students': maxStudents,
      'batch_price': batchPrice,
      'medium': medium,
      'is_active': isActive,
    };
  }
}
