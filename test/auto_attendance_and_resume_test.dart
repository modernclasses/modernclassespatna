import 'package:flutter_test/flutter_test.dart';
import 'package:modern_classes_patna/features/attendance/data/models/attendance_model.dart';
import 'package:modern_classes_patna/features/attendance/data/repositories/attendance_repository.dart';
import 'package:modern_classes_patna/features/attendance/logic/attendance_provider.dart';
import 'package:modern_classes_patna/features/courses/data/models/course_model.dart';
import 'package:modern_classes_patna/features/courses/data/models/recent_lecture_playback.dart';
import 'package:modern_classes_patna/features/live_classes/data/models/live_class_model.dart';

class FakeAttendanceRepository implements AttendanceRepository {
  List<AttendanceRecordModel> savedRecords = [];

  @override
  Future<List<AttendanceRecordModel>> getAttendanceRecords() async {
    return List.from(savedRecords);
  }

  @override
  Future<void> saveAttendanceRecords(List<AttendanceRecordModel> records) async {
    savedRecords.addAll(records);
  }
}

void main() {
  group('Auto Attendance 75% Rule Tests', () {
    late AttendanceProvider attendanceProvider;
    late FakeAttendanceRepository fakeRepo;

    setUp(() {
      fakeRepo = FakeAttendanceRepository();
      attendanceProvider = AttendanceProvider(repository: fakeRepo);
    });

    test('Does NOT mark attendance if watch progress is under 75%', () async {
      final result = await attendanceProvider.logLectureAttendanceAuto(
        batchId: 'batch_01',
        batchName: 'BPSC Foundation',
        studentId: 'student_123',
        studentName: 'Rahul Kumar',
        lessonTitle: 'Ancient Bihar History 01',
        watchPercentage: 0.74, // Below 75%
      );

      expect(result, isFalse);
      expect(attendanceProvider.records.isEmpty, isTrue);
      expect(fakeRepo.savedRecords.isEmpty, isTrue);
    });

    test('Marks attendance as present once watch progress reaches 75%', () async {
      final result = await attendanceProvider.logLectureAttendanceAuto(
        batchId: 'batch_01',
        batchName: 'BPSC Foundation',
        studentId: 'student_123',
        studentName: 'Rahul Kumar',
        lessonTitle: 'Ancient Bihar History 01',
        watchPercentage: 0.75, // Exactly 75%
      );

      expect(result, isTrue);
      expect(attendanceProvider.records.length, 1);
      final record = attendanceProvider.records.first;
      expect(record.status, AttendanceStatus.present);
      expect(record.remarks, contains('75% of lecture'));
      expect(record.studentId, 'student_123');
      expect(fakeRepo.savedRecords.length, 1);
    });

    test('Prevents duplicate attendance logging for the same lecture on the same day', () async {
      final first = await attendanceProvider.logLectureAttendanceAuto(
        batchId: 'batch_01',
        batchName: 'BPSC Foundation',
        studentId: 'student_123',
        studentName: 'Rahul Kumar',
        lessonTitle: 'Ancient Bihar History 01',
        watchPercentage: 0.80,
      );
      expect(first, isTrue);
      expect(attendanceProvider.records.length, 1);

      // Attempt second log for same lecture
      final second = await attendanceProvider.logLectureAttendanceAuto(
        batchId: 'batch_01',
        batchName: 'BPSC Foundation',
        studentId: 'student_123',
        studentName: 'Rahul Kumar',
        lessonTitle: 'Ancient Bihar History 01',
        watchPercentage: 0.95,
      );

      expect(second, isFalse);
      expect(attendanceProvider.records.length, 1);
    });
  });

  group('Resume Learning Active Lesson Resolution Tests', () {
    test('Resolves in-progress lesson first over uncompleted or completed ones', () {
      final lessons = [
        VideoLessonModel(
          id: 'l1',
          courseId: 'c1',
          batchId: 'b1',
          title: 'Lesson 1: Intro',
          chapter: 'Ch 1',
          videoUrl: 'https://cdn.example.com/l1.mp4',
          duration: const Duration(minutes: 30),
          progressPercent: 1.0,
          isCompleted: true,
          uploadedAt: DateTime(2026, 1, 1),
        ),
        VideoLessonModel(
          id: 'l2',
          courseId: 'c1',
          batchId: 'b1',
          title: 'Lesson 2: In-Progress Deep Dive',
          chapter: 'Ch 2',
          videoUrl: 'https://cdn.example.com/l2.mp4',
          duration: const Duration(minutes: 45),
          progressPercent: 0.40, // 40% in-progress
          isCompleted: false,
          uploadedAt: DateTime(2026, 1, 2),
        ),
        VideoLessonModel(
          id: 'l3',
          courseId: 'c1',
          batchId: 'b1',
          title: 'Lesson 3: Future Lesson',
          chapter: 'Ch 3',
          videoUrl: 'https://cdn.example.com/l3.mp4',
          duration: const Duration(minutes: 50),
          progressPercent: 0.0,
          isCompleted: false,
          uploadedAt: DateTime(2026, 1, 3),
        ),
      ];

      final active = lessons.firstWhere(
        (l) => l.progressPercent > 0 && l.progressPercent < 1.0,
        orElse: () => lessons.firstWhere(
          (l) => !l.isCompleted,
          orElse: () => lessons.first,
        ),
      );

      expect(active.id, 'l2');
      expect(active.title, 'Lesson 2: In-Progress Deep Dive');
      expect(active.progressPercent, 0.40);
    });
  });

  group('Recent Lecture Playback Recording & Resumption Tests', () {
    test('RecentLecturePlayback serialization and LiveClassModel conversion', () {
      final playback = RecentLecturePlayback(
        lectureId: 'lec_999',
        courseId: 'course_1',
        batchId: 'batch_1',
        courseName: 'UPSC Foundation',
        batchName: 'Morning Batch A',
        title: 'Geomorphology Lecture 04',
        subject: 'Geography',
        teacherName: 'Dr. Verma',
        videoUrl: 'https://customer.stream.cloudflare.com/mock/manifest/video.m3u8',
        duration: const Duration(minutes: 60),
        progressPercent: 0.45,
        positionSeconds: 1620,
        lastWatchedAt: DateTime.now(),
      );

      final jsonMap = playback.toMap();
      final fromJson = RecentLecturePlayback.fromMap(jsonMap);

      expect(fromJson.lectureId, 'lec_999');
      expect(fromJson.title, 'Geomorphology Lecture 04');
      expect(fromJson.positionSeconds, 1620);
      expect(fromJson.progressPercent, 0.45);

      final liveClassModel = fromJson.toLiveClassModel();
      expect(liveClassModel.id, 'lec_999');
      expect(liveClassModel.title, 'Geomorphology Lecture 04');
      expect(liveClassModel.subject, 'Geography');
      expect(liveClassModel.status, LiveStatus.ended);
      expect(liveClassModel.recordingStatus, 'ready');
    });

    test('Recent playback list promotes the most recently played lecture to the head of the list', () {
      final p1 = RecentLecturePlayback(
        lectureId: 'l1',
        courseId: 'c1',
        batchId: 'b1',
        courseName: 'C1',
        batchName: 'B1',
        title: 'L1: Intro',
        subject: 'Sub1',
        teacherName: 'T1',
        videoUrl: 'url1',
        duration: const Duration(minutes: 30),
        progressPercent: 0.20,
        positionSeconds: 360,
        lastWatchedAt: DateTime.now().subtract(const Duration(hours: 1)),
      );

      final p2 = RecentLecturePlayback(
        lectureId: 'l2',
        courseId: 'c1',
        batchId: 'b1',
        courseName: 'C1',
        batchName: 'B1',
        title: 'L2: Advanced',
        subject: 'Sub1',
        teacherName: 'T1',
        videoUrl: 'url2',
        duration: const Duration(minutes: 40),
        progressPercent: 0.70,
        positionSeconds: 1680,
        lastWatchedAt: DateTime.now(),
      );

      final playbacks = [p1];
      // When user plays L2:
      playbacks.removeWhere((p) => p.lectureId == p2.lectureId);
      playbacks.insert(0, p2);

      expect(playbacks.first.lectureId, 'l2');
      expect(playbacks.first.title, 'L2: Advanced');
      expect(playbacks.first.progressPercent, 0.70);

      // Now user resumes L1:
      final updatedP1 = p1.copyWith(
        progressPercent: 0.50,
        positionSeconds: 900,
        lastWatchedAt: DateTime.now(),
      );
      playbacks.removeWhere((p) => p.lectureId == updatedP1.lectureId);
      playbacks.insert(0, updatedP1);

      expect(playbacks.first.lectureId, 'l1');
      expect(playbacks.first.title, 'L1: Intro');
      expect(playbacks.first.positionSeconds, 900);
      expect(playbacks.first.progressPercent, 0.50);
    });
  });
}
