import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:modern_classes_patna/features/live_classes/data/models/live_class_model.dart';
import 'package:modern_classes_patna/features/live_classes/data/repositories/live_class_repository.dart';
import 'package:modern_classes_patna/features/live_classes/logic/live_class_provider.dart';
import 'package:modern_classes_patna/features/courses/data/models/batch_model.dart';
import 'package:modern_classes_patna/features/courses/data/models/course_model.dart';
import 'package:modern_classes_patna/features/courses/data/repositories/course_repository.dart';
import 'package:modern_classes_patna/providers/auth_provider.dart';
import 'package:modern_classes_patna/providers/course_provider.dart';
import 'package:modern_classes_patna/providers/notification_provider.dart';
import 'package:modern_classes_patna/features/notifications/data/models/notification_model.dart';
import 'package:modern_classes_patna/features/notifications/data/repositories/notification_repository.dart';
import 'package:modern_classes_patna/models/user_model.dart';
import 'package:modern_classes_patna/screens/teacher/schedule_live_class_screen.dart';
import 'package:modern_classes_patna/screens/student/live_classes_screen.dart';
import 'package:modern_classes_patna/screens/student/live_classroom_screen.dart';
import 'package:modern_classes_patna/core/utils/batch_timing_helper.dart';
import 'package:modern_classes_patna/features/live_classes/data/models/lecture_recording_model.dart';
import 'package:modern_classes_patna/core/widgets/image_upload_picker_widget.dart';

class MockLiveClassRepository implements LiveClassRepository {
  final List<LiveClassModel> classes = [];

  @override
  Future<List<LiveClassModel>> getLiveClasses() async => List.from(classes);

  @override
  Future<LiveClassModel> scheduleLiveClass(
    LiveClassModel liveClass, {
    String? teacherId,
  }) async {
    final saved = LiveClassModel(
      id: liveClass.id.isNotEmpty
          ? liveClass.id
          : 'live_${DateTime.now().millisecondsSinceEpoch}',
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
      recordingUrl: liveClass.recordingUrl,
      thumbnailUrl: liveClass.thumbnailUrl,
      activeViewersCount: liveClass.activeViewersCount,
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
    required Uint8List fileBytes,
  }) async {
    return 'https://mock.supabase.co/storage/v1/object/public/course-thumbnails/live-classes/$fileName';
  }

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

class FakeCourseRepo implements CourseRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<CourseModel>> getCourses() async => [
        const CourseModel(
          id: 'course-1',
          title: 'BPSC Foundation GS',
          category: 'BPSC',
          description: 'Comprehensive GS Foundation for BPSC',
          coverImageUrl: 'https://example.com/cover.jpg',
          price: 4999,
          originalPrice: 7999,
          teacherName: 'Dr. Kumar',
          teacherId: 'teacher-1',
          totalLessons: 40,
          totalHours: 120,
          totalTests: 15,
          totalNotes: 25,
          highlights: ['Live Classes', 'Recorded Lectures', 'Test Series'],
        ),
      ];

  @override
  Future<List<BatchModel>> getBatches() async => [
        BatchModel(
          id: 'batch-1',
          courseId: 'course-1',
          name: 'Batch Alpha 2026',
          timing: '09:00 AM - 11:00 AM (Mon-Sat)',
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 90)),
          teacherName: 'Dr. Kumar',
          teacherId: 'teacher-1',
          totalStudents: 45,
          maxStudents: 100,
          batchPrice: 4999,
          medium: 'Hinglish',
        ),
      ];
}

class FakeNotificationRepo implements NotificationRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> broadcastAnnouncement(NotificationModel notification) async {}

  @override
  Future<List<NotificationModel>> getNotifications() async => [];
}

class FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  UserModel get currentUser => const UserModel(
        id: 'teacher-1',
        name: 'Dr. Kumar',
        email: 'kumar@modernclasses.com',
        phone: '9876543210',
        role: UserRole.teacher,
      );

  @override
  bool get isAuthenticated => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LiveClassModel Thumbnail Field Tests', () {
    test('LiveClassModel serializes and deserializes thumbnailUrl properly', () {
      final model = LiveClassModel(
        id: 'lc-101',
        courseId: 'course-1',
        batchId: 'batch-1',
        courseName: 'GS Prelims',
        batchName: 'Batch Alpha',
        title: 'Bihar History Deep Dive',
        subject: 'History',
        teacherName: 'Dr. Kumar',
        teacherAvatar: '',
        scheduledStartTime: DateTime(2026, 11, 1, 10, 0),
        status: LiveStatus.upcoming,
        streamUrl:
            'https://customer-xyz.cloudflarestream.com/manifest/video.m3u8',
        thumbnailUrl: 'https://cdn.example.com/thumbnails/bihar_history.jpg',
      );

      final map = model.toMap();
      expect(
          map['thumbnail_url'], 'https://cdn.example.com/thumbnails/bihar_history.jpg');

      final insertMap = model.toInsertMap(teacherId: 'teacher-1');
      expect(insertMap['thumbnail_url'],
          'https://cdn.example.com/thumbnails/bihar_history.jpg');

      final fromMapModel = LiveClassModel.fromMap(map);
      expect(fromMapModel.thumbnailUrl,
          'https://cdn.example.com/thumbnails/bihar_history.jpg');
      expect(fromMapModel.title, 'Bihar History Deep Dive');
    });

    test('LiveClassModel handles null and empty thumbnailUrl backward compatibility', () {
      final modelWithoutThumb = LiveClassModel(
        id: 'lc-102',
        courseId: 'course-1',
        batchId: 'batch-1',
        courseName: 'GS Prelims',
        batchName: 'Batch Alpha',
        title: 'Modern India',
        subject: 'History',
        teacherName: 'Dr. Kumar',
        teacherAvatar: '',
        scheduledStartTime: DateTime(2026, 11, 1, 10, 0),
        status: LiveStatus.upcoming,
        streamUrl:
            'https://customer-xyz.cloudflarestream.com/manifest/video.m3u8',
        thumbnailUrl: null,
      );

      final insertMap = modelWithoutThumb.toInsertMap();
      expect(insertMap.containsKey('thumbnail_url'), isFalse);

      final legacyRawMap = {
        'id': 'legacy-1',
        'title': 'Legacy Lecture Without Thumb',
        'subject': 'Polity',
        'status': 'live',
        'stream_url': 'https://stream.example.com/video.m3u8',
      };
      final fromLegacy = LiveClassModel.fromMap(legacyRawMap);
      expect(fromLegacy.thumbnailUrl, isNull);
      expect(fromLegacy.title, 'Legacy Lecture Without Thumb');
    });

    test('LiveClassModel copyWith updates thumbnailUrl correctly', () {
      final original = LiveClassModel(
        id: 'lc-103',
        courseId: 'c1',
        batchId: 'b1',
        courseName: 'Course',
        batchName: 'Batch',
        title: 'Title',
        subject: 'Subject',
        teacherName: 'Teacher',
        teacherAvatar: '',
        scheduledStartTime: DateTime.now(),
        status: LiveStatus.upcoming,
        streamUrl: 'url',
      );
      expect(original.thumbnailUrl, isNull);

      final updated = original.copyWith(
        thumbnailUrl: 'https://new-thumbnail.png',
      );
      expect(updated.thumbnailUrl, 'https://new-thumbnail.png');
    });
  });

  group('LiveClassProvider Thumbnail Integration Tests', () {
    test('scheduleLiveClass stores thumbnailUrl and uploadLiveClassThumbnail returns URL',
        () async {
      final repo = MockLiveClassRepository();
      final provider = LiveClassProvider(repository: repo);

      final uploadedUrl = await provider.uploadLiveClassThumbnail(
        fileName: 'poster.jpg',
        fileBytes: Uint8List.fromList([1, 2, 3]),
      );
      expect(uploadedUrl, contains('poster.jpg'));

      final created = await provider.scheduleLiveClass(
        courseId: 'course-1',
        batchId: 'batch-1',
        courseName: 'BPSC GS',
        batchName: 'Alpha',
        title: 'Economy Budget Analysis',
        subject: 'Economics',
        teacherName: 'Dr. Kumar',
        teacherAvatar: '',
        scheduledStartTime: DateTime.now().add(const Duration(hours: 2)),
        streamUrl: 'https://stream.cloudflare.com/hls.m3u8',
        thumbnailUrl: uploadedUrl,
      );

      expect(created.thumbnailUrl, uploadedUrl);
      expect(provider.classes.first.thumbnailUrl, uploadedUrl);
    });
  });

  group('Widget UI Verification Tests', () {
    late MockLiveClassRepository mockLiveRepo;
    late LiveClassProvider liveProvider;
    late CourseProvider courseProvider;
    late NotificationProvider notificationProvider;
    late FakeAuthProvider authProvider;

    setUp(() {
      mockLiveRepo = MockLiveClassRepository();
      liveProvider = LiveClassProvider(repository: mockLiveRepo);
      courseProvider = CourseProvider(repository: FakeCourseRepo());
      notificationProvider =
          NotificationProvider(repository: FakeNotificationRepo());
      authProvider = FakeAuthProvider();
    });

    Widget createTestApp(Widget child) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<LiveClassProvider>.value(value: liveProvider),
          ChangeNotifierProvider<CourseProvider>.value(value: courseProvider),
          ChangeNotifierProvider<NotificationProvider>.value(
              value: notificationProvider),
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ],
        child: MaterialApp(
          home: child,
        ),
      );
    }

    testWidgets('ScheduleLiveClassScreen displays ImageUploadPickerWidget for thumbnail',
        (tester) async {
      await courseProvider.fetchCatalog();

      await tester.pumpWidget(createTestApp(const ScheduleLiveClassScreen()));
      await tester.pumpAndSettle();

      expect(find.text('LECTURE THUMBNAIL (POSTER)'), findsOneWidget);
      expect(find.byType(ImageUploadPickerWidget), findsOneWidget);
      expect(find.text('Live Lecture Thumbnail Poster'), findsOneWidget);
    });

    testWidgets('LiveClassesScreen renders thumbnail on LIVE NOW card and fallbacks',
        (tester) async {
      mockLiveRepo.classes.add(
        LiveClassModel(
          id: 'live-now-1',
          courseId: 'course-1',
          batchId: 'batch-1',
          courseName: 'BPSC GS',
          batchName: 'Batch Alpha',
          title: 'Live Indian Economy Session',
          subject: 'Economics',
          teacherName: 'Dr. Kumar',
          teacherAvatar: '',
          scheduledStartTime: DateTime.now(),
          status: LiveStatus.live,
          streamUrl: 'https://stream.cloudflare.com/test.m3u8',
          thumbnailUrl:
              'https://images.unsplash.com/photo-1590283603385-17ffb3a7f29f',
          activeViewersCount: 24,
        ),
      );
      await liveProvider.fetchLiveClasses();

      await tester.pumpWidget(createTestApp(const LiveClassesScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Live Indian Economy Session'), findsOneWidget);
      expect(find.text('LIVE STREAM'), findsOneWidget);
      expect(find.byType(AspectRatio), findsWidgets);
    });

    testWidgets('LiveClassesScreen renders upcoming classes with thumbnail',
        (tester) async {
      mockLiveRepo.classes.add(
        LiveClassModel(
          id: 'upcoming-1',
          courseId: 'course-1',
          batchId: 'batch-1',
          courseName: 'BPSC GS',
          batchName: 'Batch Alpha',
          title: 'Upcoming Geography Lecture',
          subject: 'Geography',
          teacherName: 'Dr. Kumar',
          teacherAvatar: '',
          scheduledStartTime: DateTime.now().add(const Duration(hours: 1)),
          status: LiveStatus.upcoming,
          streamUrl: 'https://stream.cloudflare.com/test.m3u8',
          thumbnailUrl:
              'https://images.unsplash.com/photo-1590283603385-17ffb3a7f29f',
        ),
      );
      await liveProvider.fetchLiveClasses();

      await tester.pumpWidget(createTestApp(const LiveClassesScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Upcoming Geography Lecture'), findsOneWidget);
      expect(find.byType(Image), findsWidgets);
    });

    testWidgets('LiveClassroomScreen renders with custom thumbnailUrl or fallback',
        (tester) async {
      final liveWithThumb = LiveClassModel(
        id: 'classroom-1',
        courseId: 'course-1',
        batchId: 'batch-1',
        courseName: 'BPSC GS',
        batchName: 'Batch Alpha',
        title: 'Bihar Economy Masterclass',
        subject: 'Economics',
        teacherName: 'Dr. Kumar',
        teacherAvatar: '',
        scheduledStartTime: DateTime.now(),
        status: LiveStatus.live,
        streamUrl: 'https://stream.cloudflare.com/test.m3u8',
        thumbnailUrl:
            'https://images.unsplash.com/photo-1590283603385-17ffb3a7f29f',
      );

      await tester.pumpWidget(
          createTestApp(LiveClassroomScreen(liveClass: liveWithThumb)));
      await tester.pump();

      expect(find.text('🔴 LIVE STREAM ACTIVE'), findsOneWidget);
      expect(find.text('Bihar Economy Masterclass'), findsOneWidget);
    });
  });
}
