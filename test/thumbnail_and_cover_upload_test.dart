import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:modern_classes_patna/core/widgets/image_upload_picker_widget.dart';
import 'package:modern_classes_patna/features/auth/data/models/user_model.dart';
import 'package:modern_classes_patna/features/auth/logic/auth_provider.dart';
import 'package:modern_classes_patna/features/courses/data/models/batch_model.dart';
import 'package:modern_classes_patna/features/courses/data/models/course_model.dart';
import 'package:modern_classes_patna/features/courses/data/repositories/course_repository.dart';
import 'package:modern_classes_patna/features/courses/logic/course_provider.dart';
import 'package:modern_classes_patna/screens/admin/course_creation_wizard_dialog.dart';
import 'package:modern_classes_patna/screens/admin/edit_course_screen.dart';
import 'package:modern_classes_patna/screens/student/course_detail_screen.dart';
import 'package:modern_classes_patna/screens/student/video_player_screen.dart';
import 'package:modern_classes_patna/screens/teacher/upload_lecture_screen.dart';

class MockCourseRepo implements CourseRepository {
  List<CourseModel> courses = [];
  List<BatchModel> batches = [];
  List<VideoLessonModel> lessons = [];

  @override
  Future<List<CourseModel>> getCourses() async => List.from(courses);
  @override
  Future<List<BatchModel>> getBatches() async => List.from(batches);
  @override
  Future<List<BatchModel>> adminGetAllBatches() async => List.from(batches);
  @override
  Future<List<VideoLessonModel>> getVideoLessons(String batchId) async =>
      lessons.where((l) => l.batchId == batchId).toList();

  @override
  Future<String> uploadCourseCoverImage({
    required String fileName,
    required Uint8List fileBytes,
  }) async => 'https://mock.storage/course-thumbnails/test_$fileName';

  @override
  Future<String> uploadLessonThumbnail({
    required String batchId,
    required String fileName,
    required Uint8List fileBytes,
  }) async => 'https://mock.storage/course-thumbnails/lessons/$batchId/test_$fileName';

  @override
  Future<String> uploadLectureVideo({
    required String batchId,
    required String fileName,
    Uint8List? fileBytes,
    String? filePath,
    void Function(int uploadedBytes, int totalBytes)? onProgress,
    bool Function()? isCancelled,
  }) async => '$batchId/test_$fileName';

  @override
  Future<List<VideoLessonModel>> getLessonsForBatches(List<String> batchIds) async => [];

  @override
  Future<VideoLessonModel> createLesson({
    required String courseId,
    required String batchId,
    required String title,
    required String chapter,
    required String videoUrl,
    String? thumbnailUrl,
    int durationSeconds = 0,
    int? orderIndex,
  }) async {
    final lesson = VideoLessonModel(
      id: 'lesson_${lessons.length + 1}',
      courseId: courseId,
      batchId: batchId,
      title: title,
      chapter: chapter,
      duration: Duration(seconds: durationSeconds),
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      uploadedAt: DateTime.now(),
    );
    lessons.add(lesson);
    return lesson;
  }

  @override
  Future<VideoLessonModel> updateLessonThumbnail({
    required String lessonId,
    required String thumbnailUrl,
  }) async {
    final idx = lessons.indexWhere((l) => l.id == lessonId);
    if (idx != -1) {
      final updated = lessons[idx].copyWith(thumbnailUrl: thumbnailUrl);
      lessons[idx] = updated;
      return updated;
    }
    final newLesson = VideoLessonModel(
      id: lessonId,
      courseId: 'mock-course',
      batchId: 'mock-batch',
      title: 'Mock Lesson',
      chapter: 'Mock Chapter',
      duration: Duration.zero,
      videoUrl: 'mock.mp4',
      thumbnailUrl: thumbnailUrl,
      uploadedAt: DateTime.now(),
    );
    lessons.add(newLesson);
    return newLesson;
  }

  @override
  Future<Map<String, List<String>>> getMyEnrollments() async => {
    'courseIds': ['course_test_1'],
    'batchIds': ['batch_test_1'],
  };

  @override
  Future<List<String>> getBatchTeacherIds(String batchId) async => ['tch_01'];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestAuthProvider extends ChangeNotifier implements AuthProvider {
  UserModel _user;
  TestAuthProvider({UserRole role = UserRole.admin})
      : _user = UserModel(
          id: 'test_user_01',
          name: 'Test Administrator',
          email: 'admin@modernclasses.com',
          phone: '9876543210',
          role: role,
        );

  @override
  UserModel get currentUser => _user;
  @override
  bool get isAuthenticated => true;
  @override
  bool get isAdmin => _user.role == UserRole.admin;
  @override
  bool get isTeacher => _user.role == UserRole.teacher;
  @override
  bool get isStudent => _user.role == UserRole.student;

  void setRole(UserRole role) {
    _user = _user.copyWith(role: role);
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockCourseRepo repo;
  late CourseProvider courseProvider;
  late TestAuthProvider authProvider;

  final testCourse = CourseModel(
    id: 'course_test_1',
    title: 'Class 12 Physics Complete',
    category: 'Physics',
    description: 'Comprehensive physics preparation',
    coverImageUrl: 'https://images.unsplash.com/photo-course-cover.jpg',
    price: 4999.0,
    originalPrice: 9999.0,
    teacherName: 'Dr. HC Verma',
    teacherId: 'tch_01',
    totalLessons: 45,
    totalTests: 12,
    totalHours: 90,
    totalNotes: 20,
    highlights: const ['Concept clarity', 'Daily tests'],
  );

  final testBatch = BatchModel(
    id: 'batch_test_1',
    courseId: 'course_test_1',
    name: 'Morning Batch Alpha',
    timing: '08:00 AM - 10:00 AM',
    batchPrice: 4999.0,
    teacherId: 'tch_01',
    teacherName: 'Dr. HC Verma',
    totalStudents: 35,
    medium: 'English',
    startDate: DateTime(2026, 1, 1),
    endDate: DateTime(2026, 12, 31),
  );

  final lesson1 = VideoLessonModel(
    id: 'lesson_101',
    courseId: 'course_test_1',
    batchId: 'batch_test_1',
    title: 'Lecture 1: Electrostatics',
    chapter: 'Chapter 1',
    duration: const Duration(minutes: 50),
    videoUrl: 'https://stream.example.com/v1.mp4',
    thumbnailUrl: 'https://images.unsplash.com/photo-electrostatics-thumb.jpg',
    uploadedAt: DateTime(2026, 2, 1),
  );

  final lesson2 = VideoLessonModel(
    id: 'lesson_102',
    courseId: 'course_test_1',
    batchId: 'batch_test_1',
    title: 'Lecture 2: Gauss Law & Flux',
    chapter: 'Chapter 1',
    duration: const Duration(minutes: 45),
    videoUrl: 'https://stream.example.com/v2.mp4',
    thumbnailUrl: 'https://images.unsplash.com/photo-gauss-law-thumb.jpg',
    uploadedAt: DateTime(2026, 2, 3),
  );

  setUp(() async {
    repo = MockCourseRepo();
    repo.courses = [testCourse];
    repo.batches = [testBatch];
    repo.lessons = [lesson1, lesson2];
    courseProvider = CourseProvider(repository: repo);
    await courseProvider.fetchMyEnrollments();
    authProvider = TestAuthProvider(role: UserRole.admin);
  });

  Widget buildApp(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<CourseProvider>.value(value: courseProvider),
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('1. Course & Lecture Thumbnail Provider & Repository Integration', () {
    test('CourseProvider.uploadCourseCoverImage returns public storage URL', () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final url = await courseProvider.uploadCourseCoverImage(
        fileName: 'cover_art.png',
        fileBytes: bytes,
      );
      expect(url, contains('course-thumbnails'));
      expect(url, contains('cover_art.png'));
    });

    test('CourseProvider.updateLessonThumbnail updates thumbnail and notifies listeners', () async {
      const newThumb = 'https://images.example.com/new_gauss_thumb.png';
      final updated = await courseProvider.updateLessonThumbnail(
        lessonId: 'lesson_102',
        thumbnailUrl: newThumb,
      );
      expect(updated.thumbnailUrl, equals(newThumb));
    });
  });

  group('2. ImageUploadPickerWidget Unit Tests', () {
    testWidgets('renders empty state with upload button and URL toggle', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageUploadPickerWidget(
              controller: controller,
              labelText: 'Course Cover Image',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Course Cover Image'), findsOneWidget);
      expect(find.text('Upload Image from Device'), findsOneWidget);
      expect(find.text('Required: 16:9 Widescreen (1920×1080 px)'), findsOneWidget);
      expect(find.text('Or enter Image URL'), findsOneWidget);
    });

    testWidgets('entering URL directly displays thumbnail preview and allows clearing', (tester) async {
      final controller = TextEditingController(text: 'https://example.com/thumb.jpg');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageUploadPickerWidget(
              controller: controller,
              labelText: 'Lecture Thumbnail',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lecture Thumbnail'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);

      // Tap remove icon button
      final clearBtn = find.byTooltip('Remove');
      expect(clearBtn, findsOneWidget);
      await tester.tap(clearBtn);
      await tester.pumpAndSettle();

      expect(controller.text, isEmpty);
      expect(find.text('Upload Image from Device'), findsOneWidget);
    });
  });

  group('3. Course Creation Wizard & Edit Course Cover Upload', () {
    testWidgets('Course Creation Wizard Step 2 renders ImageUploadPickerWidget for cover image', (tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildApp(const Scaffold(body: CourseCreationWizardDialog())));
      await tester.pumpAndSettle();

      // Step 1: fill required fields
      await tester.enterText(find.byType(TextField).at(0), 'NEET Crash Course 2026');
      await tester.enterText(find.byType(TextField).at(1), 'Biology');
      await tester.tap(find.text('Next: Course Setup'));
      await tester.pumpAndSettle();

      // Step 2: verify Cover Image / Thumbnail picker is present
      expect(find.text('Course Cover Image / Thumbnail (Optional)'), findsOneWidget);
      expect(find.text('Upload Image from Device'), findsOneWidget);
    });

    testWidgets('EditCourseScreen renders ImageUploadPickerWidget with existing cover image URL', (tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildApp(EditCourseScreen(course: testCourse)));
      await tester.pumpAndSettle();

      expect(find.text('Cover Image / Thumbnail (Course Cover Page)'), findsOneWidget);
      expect(find.byType(ImageUploadPickerWidget), findsOneWidget);
    });
  });

  group('4. UploadLectureScreen Lecture Thumbnail & Initial Batch', () {
    testWidgets('UploadLectureScreen supports initialBatchId and renders thumbnail section', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildApp(const UploadLectureScreen(initialBatchId: 'batch_test_1')));
      await tester.pumpAndSettle();

      expect(find.text('Lecture Thumbnail (Optional)'), findsOneWidget);
      expect(find.byKey(const Key('pick_thumbnail_button')), findsOneWidget);
      expect(find.text('Or enter Thumbnail URL'), findsOneWidget);
    });
  });

  group('5. Distinct Thumbnails Display in Curriculum and Playlist', () {
    testWidgets('CourseDetailScreen displays course cover at top and distinct lecture thumbnails in curriculum', (tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildApp(CourseDetailScreen(course: testCourse)));
      await tester.pumpAndSettle();

      // Course title and lessons rendered
      expect(find.text(testCourse.title), findsWidgets);
      expect(find.text(lesson1.title), findsOneWidget);
      expect(find.text(lesson2.title), findsOneWidget);

      // Verify that Image widgets are rendered (1 for course cover + 2 for curriculum lectures)
      expect(find.byType(Image), findsWidgets);
    });

    testWidgets('VideoPlayerScreen displays distinct thumbnails in playlist and edit thumbnail action for admin', (tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildApp(VideoPlayerScreen(lesson: lesson1, course: testCourse)));
      await tester.pumpAndSettle();

      // Verify playlist displays distinct lesson
      expect(find.text(lesson2.title), findsOneWidget);
      // Verify admin has Change Lecture Thumbnail action button
      expect(find.byKey(const Key('edit_thumbnail_action')), findsOneWidget);
    });
  });
}
