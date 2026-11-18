import 'package:flutter/material.dart';
import '../data/models/attendance_model.dart';
import '../data/repositories/attendance_repository.dart';

class AttendanceProvider extends ChangeNotifier {
  final AttendanceRepository _repository;

  List<AttendanceRecordModel> _records = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<AttendanceRecordModel> get records => _records;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AttendanceProvider({AttendanceRepository? repository})
    : _repository = repository ?? AttendanceRepositoryImpl() {
    fetchAttendance();
  }

  Future<void> fetchAttendance() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetched = await _repository.getAttendanceRecords();
      _records = fetched;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  List<AttendanceRecordModel> getRecordsForStudent(String studentId) {
    return _records.where((r) => r.studentId == studentId).toList();
  }

  double calculateAttendancePercentage(String studentId) {
    final studentRecords = getRecordsForStudent(studentId);
    if (studentRecords.isEmpty) return 100.0;

    final presentCount = studentRecords
        .where((r) => r.status == AttendanceStatus.present)
        .length;
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
    final newRecords = <AttendanceRecordModel>[];
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
      newRecords.add(record);
      _records.insert(0, record);
    });

    _repository.saveAttendanceRecords(newRecords);
    notifyListeners();
  }

  /// Automatically marks student attendance once they watch at least 75% of a lecture.
  Future<bool> logLectureAttendanceAuto({
    required String batchId,
    required String batchName,
    required String studentId,
    required String studentName,
    required String lessonTitle,
    required double watchPercentage,
  }) async {
    // Enforce 75% watch rule strictly
    if (watchPercentage < 0.75) return false;

    final today = DateTime.now();
    final alreadyLogged = _records.any((r) =>
        r.studentId == studentId &&
        r.batchId == batchId &&
        (r.remarks ?? '').contains(lessonTitle) &&
        r.date.year == today.year &&
        r.date.month == today.month &&
        r.date.day == today.day);

    if (alreadyLogged) return false;

    final record = AttendanceRecordModel(
      id: "auto_att_${DateTime.now().millisecondsSinceEpoch}_$studentId",
      batchId: batchId,
      batchName: batchName,
      studentId: studentId,
      studentName: studentName,
      date: today,
      status: AttendanceStatus.present,
      markedByTeacherName: "System Auto-Attendance (75% Watch Rule)",
      remarks: "Auto-logged: ${(watchPercentage * 100).toInt()}% of lecture '$lessonTitle' watched",
    );

    _records.insert(0, record);
    notifyListeners();

    try {
      await _repository.saveAttendanceRecords([record]);
      return true;
    } catch (e) {
      debugPrint("Failed to persist auto attendance: $e");
      return true;
    }
  }
}
