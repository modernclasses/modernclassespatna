import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:modern_classes_patna/features/auth/data/models/user_model.dart';
import 'package:modern_classes_patna/features/auth/logic/auth_provider.dart';
import 'package:modern_classes_patna/features/courses/data/models/batch_model.dart';
import 'package:modern_classes_patna/features/courses/data/models/course_model.dart';
import 'package:modern_classes_patna/features/courses/data/repositories/course_repository.dart';
import 'package:modern_classes_patna/features/courses/logic/course_provider.dart';
import 'package:modern_classes_patna/features/live_classes/data/models/live_class_model.dart';
import 'package:modern_classes_patna/features/live_classes/data/repositories/live_class_repository.dart';
import 'package:modern_classes_patna/features/live_classes/logic/live_class_provider.dart';
import 'package:modern_classes_patna/features/notifications/data/models/notification_model.dart';
import 'package:modern_classes_patna/features/notifications/data/repositories/notification_repository.dart';
import 'package:modern_classes_patna/features/notifications/logic/notification_provider.dart';
import 'package:modern_classes_patna/features/study_materials/data/models/study_material_model.dart';
import 'package:modern_classes_patna/features/study_materials/data/repositories/study_material_repository.dart';
import 'package:modern_classes_patna/features/study_materials/logic/study_material_provider.dart';
import 'package:modern_classes_patna/core/utils/batch_timing_helper.dart';
import 'package:modern_classes_patna/features/live_classes/data/models/lecture_recording_model.dart';
import 'package:modern_classes_patna/screens/teacher/upload_material_screen.dart';

class MockLiveClassRepository implements LiveClassRepository {
  List<LiveClassModel> classes = [];
  bool failSchedule = false;

  @override
  Future<List<LiveClassModel>> getLiveClasses() async => List.from(classes);

  @override
  Future<LiveClassModel> scheduleLiveClass(
    LiveClassModel liveClass, {
    String? teacherId,
  }) async {
    if (failSchedule) throw Exception('Database error scheduling class');
    final saved = LiveClassModel(
      id: 'live_test_uuid_${classes.length + 1}',
      courseId: liveClass.courseId,
      batchId: liveClass.batchId,
      courseName: liveClass.courseName,
      batchName: liveClass.batchName,
      title: liveClass.title,
      subject: liveClass.subject,
      teacherName: liveClass.teacherName,
      teacherAvatar: liveClass.teacherAvatar,
      scheduledStartTime: liveClass.scheduledStartTime,
      estimatedDuration: liveClass.estimatedDuration,
      status: liveClass.status,
      streamUrl: liveClass.streamUrl,
    );
    classes.insert(0, saved);
    return saved;
  }

  @override
  Future<void> updateLiveClassStatus(String id, LiveStatus status) async {
    final idx = classes.indexWhere((c) => c.id == id);
    if (idx != -1) {
      classes[idx] = classes[idx].copyWith(status: status);
    }
  }

  @override
  Future<String> uploadLiveClassThumbnail({
    required String fileName,
    required dynamic fileBytes,
  }) async => 'https://mock.supabase.co/storage/v1/object/public/course-thumbnails/$fileName';

  @override
  Future<SlotValidationResult> validateBatchSchedule(String batchId) async =>
      const SlotValidationResult(isValid: true, message: 'Valid');

  @override
  Future<LiveClassModel> startAuthenticatedLiveSession({
    required String batchId,
    required String title,
    required String subject,
    required String streamUrl,
    String? thumbnailUrl,
    String? liveInputUid,
  }) async =>
      scheduleLiveClass(LiveClassModel(
        id: 'mock_live_id',
        courseId: 'mock_course',
        batchId: batchId,
        courseName: 'Mock Course',
        batchName: 'Mock Batch',
        title: title,
        subject: subject,
        teacherName: 'Teacher',
        teacherAvatar: '',
        scheduledStartTime: DateTime.now(),
        status: LiveStatus.live,
        streamUrl: streamUrl,
        thumbnailUrl: thumbnailUrl,
      ));

  @override
  Future<void> endAuthenticatedLiveSession(String liveClassId, {int? durationSeconds, DateTime? endTime}) async {}

  @override
  Future<List<LectureRecordingModel>> getLectureRecordings({
    String? courseId,
    String? batchId,
    String? teacherId,
  }) async => [];

  @override
  Future<LectureRecordingModel?> syncBroadcastRecording({
    required String batchId,
    required String courseId,
    required String title,
    String? liveClassId,
    String? liveInputUid,
    String? teacherId,
    String? playbackUrl,
    int? durationSeconds,
    DateTime? startTime,
    DateTime? endTime,
  }) async => null;

  @override
  Future<LectureRecordingModel?> refreshRecordingStatus(String videoUid) async => null;

  @override
  Future<Map<String, dynamic>> checkCloudflareLiveStatus(String liveInputUid) async =>
      {'status': 'connected', 'connected': true};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockStudyMaterialRepository implements StudyMaterialRepository {
  @override
  Future<void> deleteMaterial(String materialId, {String? fileUrl}) async {}

  List<StudyMaterialModel> materials = [];
  bool bucketMissing = false;

  @override
  Future<List<StudyMaterialModel>> getMaterials() async => List.from(materials);

  @override
  Future<String> uploadMaterialFile({
    required String courseId,
    required String fileName,
    required Uint8List fileBytes,
  }) async {
    if (bucketMissing) {
      throw Exception("StorageApiError: Bucket not found (NoSuchBucket)");
    }
    return "$courseId/mock_$fileName";
  }

  @override
  Future<StudyMaterialModel> uploadMaterial(StudyMaterialModel material) async {
    final saved = StudyMaterialModel(
      id: 'mat_test_uuid_${materials.length + 1}',
      courseId: material.courseId,
      batchId: material.batchId,
      title: material.title,
      subject: material.subject,
      chapter: material.chapter,
      type: material.type,
      pageCount: material.pageCount,
      fileSize: material.fileSize,
      fileUrl: material.fileUrl,
      previewPages: material.previewPages,
      uploadedAt: material.uploadedAt,
      uploaderName: material.uploaderName,
    );
    materials.insert(0, saved);
    return saved;
  }
}

class MockNotificationRepository implements NotificationRepository {
  List<NotificationModel> notifications = [];

  @override
  Future<List<NotificationModel>> getNotifications() async =>
      List.from(notifications);

  @override
  Future<void> broadcastAnnouncement(NotificationModel notification) async {
    notifications.insert(0, notification);
  }

  Future<void> markAsRead(String id) async {}

  Future<void> markAllAsRead() async {}
}

class FakeCourseRepoForMaterial implements CourseRepository {
  @override
  Future<void> deleteCourse(String courseId) async {}

  @override
  Future<void> deleteLesson(
    String lessonId, {
    String? videoPath,
    String? thumbnailPath,
  }) async {}

  List<CourseModel> courses = [];
  List<BatchModel> batches = [];

  @override
  Future<List<CourseModel>> getCourses() async => List.from(courses);

  @override
  Future<List<BatchModel>> getBatches() async => List.from(batches);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  UserModel _user = const UserModel(
    id: 'tch_001',
    name: 'Dr. Kumar',
    email: 'kumar@example.com',
    phone: '9876543210',
    role: UserRole.teacher,
  );

  @override
  UserModel get currentUser => _user;

  void setUser(UserModel user) {
    _user = user;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('LiveClassProvider Broadcasting Lifecycle', () {
    late MockLiveClassRepository repo;
    late LiveClassProvider provider;

    setUp(() {
      repo = MockLiveClassRepository();
      provider = LiveClassProvider(repository: repo);
    });

    test('scheduleLiveClass inserts class and starts live session', () async {
      final scheduled = await provider.scheduleLiveClass(
        courseId: 'c1',
        batchId: 'b1',
        courseName: 'BPSC Prelims',
        batchName: 'Batch Alpha',
        title: 'Polity Live',
        subject: 'Polity',
        teacherName: 'Teacher Vikram',
        teacherAvatar: '',
        scheduledStartTime: DateTime.now(),
        streamUrl: 'rtmp://test.stream/live',
        status: LiveStatus.live,
      );

      expect(scheduled.id, startsWith('live_test_uuid_'));
      expect(scheduled.status, LiveStatus.live);
      expect(provider.liveNow.length, 1);
      expect(provider.liveNow.first.title, 'Polity Live');
    });

    test(
      'endLiveClass transitions status to ended in state and repository',
      () async {
        final scheduled = await provider.scheduleLiveClass(
          courseId: 'c1',
          batchId: 'b1',
          courseName: 'BPSC Prelims',
          batchName: 'Batch Alpha',
          title: 'History Live',
          subject: 'History',
          teacherName: 'Teacher Vikram',
          teacherAvatar: '',
          scheduledStartTime: DateTime.now(),
          streamUrl: 'rtmp://test.stream/live',
          status: LiveStatus.live,
        );

        expect(provider.liveNow.length, 1);
        await provider.endLiveClass(scheduled.id);

        expect(provider.liveNow.length, 0);
        expect(provider.pastRecordings.length, 1);
        expect(provider.pastRecordings.first.status, LiveStatus.ended);
      },
    );
  });

  group('StudyMaterialProvider & UploadMaterialScreen', () {
    late MockStudyMaterialRepository matRepo;
    late StudyMaterialProvider matProvider;
    late FakeCourseRepoForMaterial courseRepo;
    late CourseProvider courseProvider;
    late MockNotificationRepository notifRepo;
    late NotificationProvider notifProvider;
    late FakeAuthProvider authProvider;

    setUp(() {
      matRepo = MockStudyMaterialRepository();
      matProvider = StudyMaterialProvider(repository: matRepo);

      courseRepo = FakeCourseRepoForMaterial();
      courseRepo.courses = [
        CourseModel(
          id: 'course-1',
          title: 'BPSC 71st Foundation Course',
          category: 'Civil Services',
          description: 'Complete syllabus',
          price: 4999,
          originalPrice: 9999,
          coverImageUrl: 'https://placeholder.com/course.jpg',
          teacherName: 'Dr. Kumar',
          teacherId: 'tch_001',
          totalLessons: 10,
          totalHours: 20,
          totalTests: 5,
          totalNotes: 8,
          rating: 4.9,
          reviewsCount: 120,
          highlights: const [],
          isFeatured: false,
          isCrashCourse: false,
        ),
      ];
      courseRepo.batches = [
        BatchModel(
          id: 'batch-1',
          courseId: 'course-1',
          name: 'Morning Target Batch',
          timing: '8:00 AM - 10:00 AM',
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 12, 31),
          maxStudents: 100,
          totalStudents: 45,
          batchPrice: 4999,
          medium: 'Hindi',
          teacherName: 'Dr. Kumar',
          teacherId: 'tch_001',
        ),
      ];
      courseProvider = CourseProvider(repository: courseRepo);

      notifRepo = MockNotificationRepository();
      notifProvider = NotificationProvider(repository: notifRepo);
      authProvider = FakeAuthProvider();
    });

    Widget createTestApp(Widget child) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider.value(value: courseProvider),
          ChangeNotifierProvider.value(value: matProvider),
          ChangeNotifierProvider.value(value: notifProvider),
        ],
        child: MaterialApp(home: child),
      );
    }

    testWidgets('UploadMaterialScreen renders fields and loads sample notes', (
      tester,
    ) async {
      await tester.pumpWidget(createTestApp(const UploadMaterialScreen()));
      await tester.pumpAndSettle();

      expect(find.text("Upload Study Material / PDF"), findsOneWidget);
      expect(find.text("Assign to Course & Batch"), findsOneWidget);
      expect(find.text("Document File (PDF / DOC)"), findsOneWidget);
      expect(find.text("Use Sample Notes"), findsOneWidget);

      // Tap Use Sample Notes
      await tester.tap(find.text("Use Sample Notes"));
      await tester.pumpAndSettle();

      // Verify that sample handout is attached
      expect(find.textContaining("handout_"), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    test('StudyMaterialProvider upload and state management', () async {
      final path = await matProvider.uploadMaterialFile(
        courseId: 'course-1',
        fileName: 'notes.pdf',
        fileBytes: Uint8List.fromList([1, 2, 3, 4]),
      );
      expect(path, 'course-1/mock_notes.pdf');

      final mat = StudyMaterialModel(
        id: '',
        courseId: 'course-1',
        batchId: 'batch-1',
        title: 'Complete Bihar GK Notes',
        subject: 'General Knowledge',
        chapter: 'Ancient Bihar',
        type: StudyDocType.pdf,
        pageCount: 12,
        fileSize: '1.2 MB',
        fileUrl: path,
        previewPages: ['Overview'],
        uploadedAt: DateTime.now(),
        uploaderName: 'Dr. R. K. Singh',
      );

      final saved = await matProvider.addStudyMaterial(mat);
      expect(saved.id, startsWith('mat_test_uuid_'));
      expect(matProvider.materials.length, 1);
      expect(matProvider.materials.first.title, 'Complete Bihar GK Notes');
    });
  });
}
