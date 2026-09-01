enum AttendanceStatus { present, absent, excused }

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
}
