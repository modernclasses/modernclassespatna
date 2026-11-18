import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:modern_classes_patna/features/auth/data/models/user_model.dart';
import 'package:modern_classes_patna/features/auth/data/repositories/auth_repository.dart';
import 'package:modern_classes_patna/features/courses/data/models/course_model.dart';
import 'package:modern_classes_patna/features/courses/data/models/batch_model.dart';
import 'package:modern_classes_patna/features/courses/data/repositories/course_repository.dart';
import 'package:modern_classes_patna/features/courses/logic/course_provider.dart';
import 'package:modern_classes_patna/features/live_classes/data/models/lecture_recording_model.dart';
import 'package:modern_classes_patna/features/live_classes/data/models/live_class_model.dart';
import 'package:modern_classes_patna/features/live_classes/data/repositories/live_class_repository.dart';
import 'package:modern_classes_patna/features/live_classes/logic/live_class_provider.dart';
import 'package:modern_classes_patna/providers/attendance_provider.dart';
import 'package:modern_classes_patna/providers/auth_provider.dart';
import 'package:modern_classes_patna/screens/student/live_classroom_screen.dart';
import 'package:modern_classes_patna/screens/student/video_player_screen.dart';
import 'package:modern_classes_patna/screens/teacher/teacher_recordings_screen.dart';

class FakeAuthRepository implements AuthRepository {
  final UserModel user;
  FakeAuthRepository(this.user);

  @override
  bool get isConnected => true;

  @override
  Future<UserModel?> getInitialSession() async => user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockLiveClassRepository implements LiveClassRepository {
  List<LectureRecordingModel> mockRecordings = [];
  List<LiveClassModel> mockClasses = [];

  @override
  Future<List<LectureRecordingModel>> getLectureRecordings({
    String? courseId,
    String? batchId,
    String? teacherId,
  }) async => mockRecordings;

  @override
  Future<LectureRecordingModel> updateRecordingDetails({
    required String recordingId,
    String? title,
    String? thumbnailUrl,
  }) async {
    final idx = mockRecordings.indexWhere((r) => r.id == recordingId);
    if (idx != -1) {
      final updated = mockRecordings[idx].copyWith(
        title: title,
        thumbnailUrl: thumbnailUrl,
      );
      mockRecordings[idx] = updated;
      return updated;
    }
    return LectureRecordingModel(
      id: recordingId,
      courseId: 'c1',
      batchId: 'b1',
      title: title ?? 'Updated Title',
      videoUid: 'vid_1',
      playbackUrl: 'https://videodelivery.net/vid_1/manifest/video.m3u8',
      thumbnailUrl: thumbnailUrl,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<List<LiveClassModel>> getLiveClasses() async => mockClasses;

  @override
  Future<void> deleteRecording(String recordingId) async {
    mockRecordings.removeWhere((r) => r.id == recordingId);
    mockClasses.removeWhere((c) => c.id == recordingId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockCourseRepository implements CourseRepository {
  List<VideoLessonModel> lessons = [];

  @override
  Future<VideoLessonModel> updateLesson({
    required String lessonId,
    String? title,
    String? chapter,
    String? thumbnailUrl,
    String? notesPdfUrl,
  }) async {
    final idx = lessons.indexWhere((l) => l.id == lessonId);
    final updated = VideoLessonModel(
      id: lessonId,
      courseId: idx != -1 ? lessons[idx].courseId : 'course_001',
      batchId: idx != -1 ? lessons[idx].batchId : 'batch_001',
      title: title ?? (idx != -1 ? lessons[idx].title : 'Updated Lesson'),
      chapter: chapter ?? (idx != -1 ? lessons[idx].chapter : 'Updated Chapter'),
      duration: idx != -1 ? lessons[idx].duration : const Duration(minutes: 45),
      videoUrl: idx != -1 ? lessons[idx].videoUrl : 'mock.mp4',
      thumbnailUrl: thumbnailUrl ?? (idx != -1 ? lessons[idx].thumbnailUrl : null),
      notesPdfUrl: notesPdfUrl ?? (idx != -1 ? lessons[idx].notesPdfUrl : null),
      uploadedAt: DateTime.now(),
    );
    if (idx != -1) {
      lessons[idx] = updated;
    } else {
      lessons.add(updated);
    }
    return updated;
  }

  @override
  Future<VideoLessonModel> updateLessonThumbnail({
    required String lessonId,
    required String thumbnailUrl,
  }) async => updateLesson(lessonId: lessonId, thumbnailUrl: thumbnailUrl);

  @override
  Future<List<VideoLessonModel>> getVideoLessons(String batchId) async =>
      lessons.where((l) => l.batchId == batchId).toList();

  @override
  Future<String> getLessonVideoSignedUrl(String videoUrlOrPath) async =>
      'https://mock.signed.url/$videoUrlOrPath';

  @override
  Future<void> deleteLesson(
    String lessonId, {
    String? videoPath,
    String? thumbnailPath,
  }) async {
    lessons.removeWhere((l) => l.id == lessonId);
  }

  @override
  Future<List<VideoLessonModel>> getLessonsForBatches(List<String> batchIds) async =>
      lessons.where((l) => batchIds.contains(l.batchId)).toList();

  @override
  Future<List<Map<String, dynamic>>> getTeacherAssignments(String teacherId) async => [
        {'teacher_id': teacherId, 'batch_id': 'batch_001', 'course_id': 'course_001'}
      ];

  @override
  Future<List<CourseModel>> getCourses() async => [
        const CourseModel(
          id: 'course_001',
          title: 'BPSC GS Paper 1',
          category: 'BPSC',
          description: 'Complete course',
          coverImageUrl: '',
          price: 1500,
          originalPrice: 2000,
          teacherId: 'tch_001',
          teacherName: 'Teacher Alok',
          totalLessons: 10,
          totalHours: 20,
          totalTests: 5,
          totalNotes: 5,
          highlights: [],
        ),
      ];

  @override
  Future<List<BatchModel>> getBatches() async => [
        BatchModel(
          id: 'batch_001',
          courseId: 'course_001',
          name: 'Morning Batch',
          timing: '08:00 AM - 10:00 AM',
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 12, 31),
          teacherName: 'Teacher Alok',
          teacherId: 'tch_001',
          totalStudents: 10,
          batchPrice: 1500.0,
          isActive: true,
        ),
      ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Teacher Lecture Editing Tests', () {
    late MockCourseRepository mockCourseRepo;
    late MockLiveClassRepository mockLiveRepo;
    late CourseProvider courseProvider;
    late LiveClassProvider liveClassProvider;

    setUp(() {
      mockCourseRepo = MockCourseRepository();
      mockLiveRepo = MockLiveClassRepository();

      mockCourseRepo.lessons = [
        VideoLessonModel(
          id: 'lesson_001',
          courseId: 'course_001',
          batchId: 'batch_001',
          title: 'Initial Ancient History Lecture',
          chapter: 'Chapter 1: Mauryan Empire',
          duration: const Duration(minutes: 50),
          videoUrl: 'lecture_001.mp4',
          thumbnailUrl: 'https://cdn.example.com/thumb1.jpg',
          uploadedAt: DateTime.now(),
        ),
      ];

      mockLiveRepo.mockRecordings = [
        LectureRecordingModel(
          id: 'rec_001',
          liveClassId: 'live_001',
          courseId: 'course_001',
          batchId: 'batch_001',
          courseName: 'BPSC GS Paper 1',
          batchName: 'Morning Batch',
          title: 'Live Session on Modern History',
          videoUid: 'cf_stream_rec_001',
          playbackUrl: 'https://videodelivery.net/cf_stream_rec_001/manifest/video.m3u8',
          thumbnailUrl: 'https://cdn.example.com/live_thumb1.jpg',
          status: RecordingStatus.ready,
          createdAt: DateTime.now(),
        ),
      ];

      courseProvider = CourseProvider(repository: mockCourseRepo);
      liveClassProvider = LiveClassProvider(repository: mockLiveRepo);
    });

    test('CourseProvider.updateLesson updates title, chapter, and thumbnail', () async {
      final updated = await courseProvider.updateLesson(
        lessonId: 'lesson_001',
        title: 'Edited History Lecture 1',
        chapter: 'Chapter 1: Detailed Mauryan Dynasty',
        thumbnailUrl: 'https://cdn.example.com/new_thumb.jpg',
      );

      expect(updated.title, 'Edited History Lecture 1');
      expect(updated.chapter, 'Chapter 1: Detailed Mauryan Dynasty');
      expect(updated.thumbnailUrl, 'https://cdn.example.com/new_thumb.jpg');
    });

    test('LiveClassProvider.updateRecordingDetails updates title and thumbnail', () async {
      await liveClassProvider.fetchLectureRecordings();
      expect(liveClassProvider.recordings.length, 1);

      final updated = await liveClassProvider.updateRecordingDetails(
        recordingId: 'rec_001',
        title: 'Comprehensive Modern History Revision',
        thumbnailUrl: 'https://cdn.example.com/revised_thumb.jpg',
      );

      expect(updated.title, 'Comprehensive Modern History Revision');
      expect(updated.thumbnailUrl, 'https://cdn.example.com/revised_thumb.jpg');

      final cached = liveClassProvider.recordings.first;
      expect(cached.title, 'Comprehensive Modern History Revision');
      expect(cached.thumbnailUrl, 'https://cdn.example.com/revised_thumb.jpg');
    });

    testWidgets('Teacher can edit recording details in TeacherRecordingsScreen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const teacher = UserModel(
        id: 'tch_001',
        email: 'teacher@modernclasses.com',
        phone: '9876543210',
        name: 'Teacher Alok',
        role: UserRole.teacher,
      );
      final teacherAuth = AuthProvider(repository: FakeAuthRepository(teacher));

      await liveClassProvider.fetchLectureRecordings();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: teacherAuth),
            ChangeNotifierProvider.value(value: courseProvider),
            ChangeNotifierProvider.value(value: liveClassProvider),
          ],
          child: const MaterialApp(
            home: TeacherRecordingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify recording title and "Edit Details" button
      expect(find.text('Live Session on Modern History'), findsOneWidget);
      final editBtnFinder = find.byKey(const Key('edit_recording_rec_001'));
      expect(editBtnFinder, findsOneWidget);

      // Tap "Edit Details" to open edit dialog
      await tester.tap(editBtnFinder);
      await tester.pumpAndSettle();

      expect(find.text('Edit Lecture Recording'), findsOneWidget);
      final titleInput = find.byKey(const Key('edit_recording_title_input'));
      expect(titleInput, findsOneWidget);

      // Change title
      await tester.enterText(titleInput, 'Renamed Live Broadcast Lecture');
      await tester.pump();

      // Tap "Save Changes"
      final saveBtn = find.byKey(const Key('save_recording_details_btn'));
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify recording title was updated in UI
      expect(find.text('Renamed Live Broadcast Lecture'), findsOneWidget);
      expect(find.text('Lecture details updated successfully!'), findsOneWidget);
    });

    testWidgets('Teacher can edit title and chapter in VideoPlayerScreen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const teacher = UserModel(
        id: 'tch_001',
        email: 'teacher@modernclasses.com',
        phone: '9876543210',
        name: 'Teacher Alok',
        role: UserRole.teacher,
      );
      final teacherAuth = AuthProvider(repository: FakeAuthRepository(teacher));

      final lesson = mockCourseRepo.lessons.first;
      const course = CourseModel(
        id: 'course_001',
        title: 'BPSC GS Paper 1',
        category: 'BPSC',
        description: 'Complete course',
        coverImageUrl: '',
        price: 1500,
        originalPrice: 2000,
        teacherId: 'tch_001',
        teacherName: 'Teacher Alok',
        totalLessons: 10,
        totalHours: 20,
        totalTests: 5,
        totalNotes: 5,
        highlights: [],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: teacherAuth),
            ChangeNotifierProvider.value(value: courseProvider),
            ChangeNotifierProvider.value(value: liveClassProvider),
            ChangeNotifierProvider(create: (_) => AttendanceProvider()),
          ],
          child: MaterialApp(
            home: VideoPlayerScreen(
              lesson: lesson,
              course: course,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify initial title and edit action presence
      expect(find.text('Initial Ancient History Lecture'), findsWidgets);
      final editActionFinder = find.byKey(const Key('edit_lecture_action'));
      expect(editActionFinder, findsOneWidget);

      // Tap edit lecture action
      await tester.tap(editActionFinder);
      await tester.pumpAndSettle();

      expect(find.text('Edit Lecture Details'), findsOneWidget);
      final titleInput = find.byKey(const Key('edit_lecture_title_input'));
      final chapterInput = find.byKey(const Key('edit_lecture_chapter_input'));

      await tester.enterText(titleInput, 'Advanced Ancient India');
      await tester.enterText(chapterInput, 'Chapter 2: Gupta Empire');
      await tester.pump();

      // Tap save
      final saveBtn = find.byKey(const Key('save_lecture_details_btn'));
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify immediate UI updates
      expect(find.text('Advanced Ancient India'), findsWidgets);
      expect(find.text('Chapter 2: Gupta Empire'), findsWidgets);
      expect(find.text('Lecture details updated successfully!'), findsOneWidget);
    });

    testWidgets('Student does NOT see lecture edit actions', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const student = UserModel(
        id: 'std_001',
        email: 'rohan@example.com',
        phone: '9876543211',
        name: 'Student Rohan',
        role: UserRole.student,
      );
      final studentAuth = AuthProvider(repository: FakeAuthRepository(student));

      final lesson = mockCourseRepo.lessons.first;
      const course = CourseModel(
        id: 'course_001',
        title: 'BPSC GS Paper 1',
        category: 'BPSC',
        description: 'Complete course',
        coverImageUrl: '',
        price: 1500,
        originalPrice: 2000,
        teacherId: 'tch_001',
        teacherName: 'Teacher Alok',
        totalLessons: 10,
        totalHours: 20,
        totalTests: 5,
        totalNotes: 5,
        highlights: [],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: studentAuth),
            ChangeNotifierProvider.value(value: courseProvider),
            ChangeNotifierProvider.value(value: liveClassProvider),
            ChangeNotifierProvider(create: (_) => AttendanceProvider()),
          ],
          child: MaterialApp(
            home: VideoPlayerScreen(
              lesson: lesson,
              course: course,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify edit button is NOT visible for student
      expect(find.byKey(const Key('edit_lecture_action')), findsNothing);
      expect(find.byKey(const Key('edit_thumbnail_action')), findsNothing);
            expect(find.byKey(const Key('delete_lecture_action')), findsNothing);
    });

    test('CourseProvider.deleteLesson removes lesson and clears recent playback', () async {
      expect(mockCourseRepo.lessons.length, 1);
      courseProvider.recordLecturePlayback(
        lectureId: 'lesson_001',
        courseId: 'course_001',
        batchId: 'batch_001',
        courseName: 'BPSC GS Paper 1',
        batchName: 'Morning Batch',
        title: 'Initial Ancient History Lecture',
        subject: 'History',
        teacherName: 'Teacher Alok',
        videoUrl: 'https://cdn.example.com/ancient_history.mp4',
        progressPercent: 0.5,
        positionSeconds: 120,
        duration: const Duration(minutes: 45),
      );
      expect(courseProvider.recentPlaybacks.length, 1);

      await courseProvider.deleteLesson('lesson_001');

      expect(mockCourseRepo.lessons.isEmpty, isTrue);
      expect(courseProvider.videoLessons.isEmpty, isTrue);
      expect(courseProvider.recentPlaybacks.isEmpty, isTrue);
    });

    test('LiveClassProvider.deleteRecording removes recording', () async {
      await liveClassProvider.fetchLectureRecordings();
      expect(liveClassProvider.recordings.length, 1);

      await liveClassProvider.deleteRecording('rec_001');

      expect(liveClassProvider.recordings.isEmpty, isTrue);
    });

    testWidgets('Teacher can delete prerecorded lecture in TeacherRecordingsScreen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const teacher = UserModel(
        id: 'tch_001',
        email: 'teacher@modernclasses.com',
        phone: '9876543210',
        name: 'Teacher Alok',
        role: UserRole.teacher,
      );
      final teacherAuth = AuthProvider(repository: FakeAuthRepository(teacher));
      await courseProvider.fetchMyTeacherAssignments('tch_001');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: teacherAuth),
            ChangeNotifierProvider.value(value: courseProvider),
            ChangeNotifierProvider.value(value: liveClassProvider),
          ],
          child: const MaterialApp(
            home: TeacherRecordingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final deleteBtnFinder = find.byKey(const Key('delete_lecture_lesson_001'));
      expect(deleteBtnFinder, findsOneWidget);

      await tester.tap(deleteBtnFinder);
      await tester.pumpAndSettle();

      expect(find.text('Delete Lecture?'), findsOneWidget);

      final confirmBtn = find.byKey(const Key('confirm_delete_lecture_btn'));
      expect(confirmBtn, findsOneWidget);

      // Verify button is disabled before typing confirm
      expect(tester.widget<ElevatedButton>(confirmBtn).onPressed, isNull);

      // Enter "confirm" into the text field
      await tester.enterText(find.byKey(const Key('confirm_delete_text_field')), 'confirm');
      await tester.pumpAndSettle();

      // Button is now enabled
      expect(tester.widget<ElevatedButton>(confirmBtn).onPressed, isNotNull);

      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(mockCourseRepo.lessons.isEmpty, isTrue);
    });

    testWidgets('Teacher can delete live recording in TeacherRecordingsScreen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const teacher = UserModel(
        id: 'tch_001',
        email: 'teacher@modernclasses.com',
        phone: '9876543210',
        name: 'Teacher Alok',
        role: UserRole.teacher,
      );
      final teacherAuth = AuthProvider(repository: FakeAuthRepository(teacher));

      await liveClassProvider.fetchLectureRecordings();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: teacherAuth),
            ChangeNotifierProvider.value(value: courseProvider),
            ChangeNotifierProvider.value(value: liveClassProvider),
          ],
          child: const MaterialApp(
            home: TeacherRecordingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final deleteBtnFinder = find.byKey(const Key('delete_recording_rec_001'));
      expect(deleteBtnFinder, findsOneWidget);

      await tester.tap(deleteBtnFinder);
      await tester.pumpAndSettle();

      expect(find.text('Delete Lecture?'), findsOneWidget);

      final confirmBtn = find.byKey(const Key('confirm_delete_lecture_btn'));
      expect(confirmBtn, findsOneWidget);

      // Verify disabled initially
      expect(tester.widget<ElevatedButton>(confirmBtn).onPressed, isNull);

      // Enter "CONFIRM" (case-insensitive test)
      await tester.enterText(find.byKey(const Key('confirm_delete_text_field')), 'CONFIRM');
      await tester.pumpAndSettle();

      expect(tester.widget<ElevatedButton>(confirmBtn).onPressed, isNotNull);

      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(liveClassProvider.recordings.isEmpty, isTrue);
    });

    testWidgets('Teacher sees delete action in LiveClassroomScreen for recorded lecture', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const teacher = UserModel(
        id: 'tch_001',
        email: 'teacher@modernclasses.com',
        phone: '9876543210',
        name: 'Teacher Alok',
        role: UserRole.teacher,
      );
      final teacherAuth = AuthProvider(repository: FakeAuthRepository(teacher));

      final recordedClass = LiveClassModel(
        id: 'lesson_001',
        courseId: 'course_001',
        batchId: 'batch_001',
        courseName: 'BPSC GS Paper 1',
        batchName: 'Morning Batch',
        title: 'Initial Ancient History Lecture',
        subject: 'History',
        teacherName: 'Teacher Alok',
        teacherAvatar: '',
        scheduledStartTime: DateTime.now().subtract(const Duration(hours: 2)),
        estimatedDuration: const Duration(minutes: 60),
        status: LiveStatus.ended,
        streamUrl: 'https://videodelivery.net/vid_1/manifest/video.m3u8',
        recordingUrl: 'https://videodelivery.net/vid_1/manifest/video.m3u8',
        recordingStatus: 'ready',
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: teacherAuth),
            ChangeNotifierProvider.value(value: courseProvider),
            ChangeNotifierProvider.value(value: liveClassProvider),
            ChangeNotifierProvider(create: (_) => AttendanceProvider()),
          ],
          child: MaterialApp(
            home: LiveClassroomScreen(
              liveClass: recordedClass,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('live_delete_lecture_action')), findsOneWidget);

      await tester.tap(find.byKey(const Key('live_delete_lecture_action')));
      await tester.pumpAndSettle();

      expect(find.text('Delete Lecture?'), findsOneWidget);
      final confirmBtn = find.byKey(const Key('confirm_live_delete_lecture_btn'));
      expect(confirmBtn, findsOneWidget);

      // Verify disabled initially
      expect(tester.widget<ElevatedButton>(confirmBtn).onPressed, isNull);

      // Enter "confirm"
      await tester.enterText(find.byKey(const Key('confirm_live_delete_text_field')), 'confirm');
      await tester.pumpAndSettle();

      expect(tester.widget<ElevatedButton>(confirmBtn).onPressed, isNotNull);

      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(mockCourseRepo.lessons.isEmpty, isTrue);
    });
  });
}
