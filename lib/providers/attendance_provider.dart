import 'package:flutter/material.dart';
import '../models/attendance_model.dart';
import '../data/mock_data.dart';

class AttendanceProvider extends ChangeNotifier {
  final List<AttendanceRecordModel> _records = List.from(MockData.attendanceRecords);

  List<AttendanceRecordModel> get records => _records;

  List<AttendanceRecordModel> getRecordsForStudent(String studentId) {
    return _records.where((r) => r.studentId == studentId).toList();
  }

  double calculateAttendancePercentage(String studentId) {
    final studentRecords = getRecordsForStudent(studentId);
    if (studentRecords.isEmpty) return 100.0;

    final presentCount = studentRecords.where((r) => r.status == AttendanceStatus.present).length;
    return (presentCount / studentRecords.length) * 100;
  }

  void markBatchAttendance({
    required String batchId,
    required String batchName,
    required Map<String, AttendanceStatus> studentStatusMap,
    required Map<String, String> studentNames,
    required String teacherName,
    required DateTime date,
  }) {
    studentStatusMap.forEach((studentId, status) {
      final studentName = studentNames[studentId] ?? "Student";
      final record = AttendanceRecordModel(
        id: "att_${DateTime.now().millisecondsSinceEpoch}_$studentId",
        batchId: batchId,
        batchName: batchName,
        studentId: studentId,
        studentName: studentName,
        date: date,
        status: status,
        markedByTeacherName: teacherName,
        remarks: "Marked via Teacher Portal",
      );
      _records.insert(0, record);
    });
    notifyListeners();
  }
}
