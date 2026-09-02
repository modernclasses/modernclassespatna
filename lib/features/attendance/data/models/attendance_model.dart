enum AttendanceStatus { present, absent, excused }

/// Daily Student Attendance Record.
class AttendanceRecordModel {
  final String id;
  final String batchId;
  final String batchName;
  final String studentId;
  final String studentName;
  final DateTime date;
  final AttendanceStatus status;
  final String? markedByTeacherName;
  final String? remarks;

  const AttendanceRecordModel({
    required this.id,
    required this.batchId,
    required this.batchName,
    required this.studentId,
    required this.studentName,
    required this.date,
    required this.status,
    this.markedByTeacherName,
    this.remarks,
  });

  factory AttendanceRecordModel.fromMap(Map<String, dynamic> map) {
    AttendanceStatus parsedStatus = AttendanceStatus.present;
    final statusStr = map['status']?.toString().toLowerCase();
    if (statusStr == 'absent') {
      parsedStatus = AttendanceStatus.absent;
    } else if (statusStr == 'excused') {
      parsedStatus = AttendanceStatus.excused;
    }

    return AttendanceRecordModel(
      id: map['id']?.toString() ?? '',
      batchId: map['batch_id']?.toString() ?? '',
      batchName: map['batch_name'] ?? 'Target Batch',
      studentId: map['student_id']?.toString() ?? '',
      studentName: map['student_name'] ?? 'Student Aspirant',
      date: map['date'] != null
          ? DateTime.tryParse(map['date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      status: parsedStatus,
      markedByTeacherName: map['marked_by_teacher_name'],
      remarks: map['remarks'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'batch_id': batchId,
      'batch_name': batchName,
      'student_id': studentId,
      'student_name': studentName,
      'date': date.toIso8601String(),
      'status': status.name,
      'marked_by_teacher_name': markedByTeacherName,
      'remarks': remarks,
    };
  }
}
