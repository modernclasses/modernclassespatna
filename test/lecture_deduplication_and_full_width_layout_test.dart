import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:modern_classes_patna/features/courses/data/models/course_model.dart';
import 'package:modern_classes_patna/features/courses/logic/course_provider.dart';
import 'package:modern_classes_patna/features/auth/data/models/user_model.dart';
import 'package:modern_classes_patna/providers/auth_provider.dart';
import 'package:modern_classes_patna/screens/student/video_player_screen.dart';
import 'fake_course_repository.dart';

class FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  final UserModel _user = const UserModel(
    id: 'std_001',
    name: 'Anand',
    email: 'anand@example.com',
    phone: '9876543210',
    role: UserRole.student,
  );

  @override
  UserModel get currentUser => _user;

  @override
  bool get isAuthenticated => true;

  @override
  bool get isTeacher => false;

  @override
  bool get isAdmin => false;

  @override
  bool get isStudent => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockDuplicateCourseRepository extends FakeCourseRepository {
  final List<VideoLessonModel> duplicateLessons;

  MockDuplicateCourseRepository(this.duplicateLessons);

  @override
  Future<List<VideoLessonModel>> getVideoLessons(String batchId) async {
    return duplicateLessons;
  }

  @override
  Future<Map<String, List<String>>> getMyEnrollments() async {
    return {
      'courseIds': ['crs_rangdari'],
      'batchIds': ['batch_rangdari_2', 'batch_rangdari_2'], // simulated duplicate enrollment
    };
  }
}

void main() {
  group('Lecture Deduplication & VideoPlayerScreen Full-Width Layout Tests', () {
    late CourseModel testCourse;
    late VideoLessonModel validRecording;
    late VideoLessonModel zeroDurationRecording;

    setUp(() {
      testCourse = CourseModel(
        id: 'crs_rangdari',
        title: 'Rangdari batch',
        category: 'BPSC',
        description: 'Test description',
        coverImageUrl: 'https://example.com/cover.jpg',
        price: 999,
        originalPrice: 1999,
        teacherId: 'tch_01',
        teacherName: 'Dr. Teacher',
        totalLessons: 1,
        totalHours: 1,
        totalTests: 1,
        totalNotes: 1,
        rating: 4.8,
        reviewsCount: 12,
        highlights: [],
        isFeatured: false,
        isCrashCourse: false,
      );

      validRecording = VideoLessonModel(
        id: 'rec_valid_14s',
        courseId: 'crs_rangdari',
        batchId: 'batch_rangdari_2',
        title: 'Live Concept Lecture',
        chapter: 'Live Lecture Recording',
        duration: const Duration(seconds: 14),
        videoUrl: 'https://customer.cloudflarestream.com/246a406974ce065a6fcdf02f7d7e0602/manifest/video.m3u8',
        uploadedAt: DateTime.now(),
      );

      zeroDurationRecording = VideoLessonModel(
        id: 'rec_placeholder_0s',
        courseId: 'crs_rangdari',
        batchId: 'batch_rangdari_2',
        title: 'Live Concept Lecture',
        chapter: 'Live Lecture Recording',
        duration: Duration.zero,
        videoUrl: 'https://customer.cloudflarestream.com/650bef2c1e64e84d5d9461d8f25b749d/manifest/video.m3u8',
        uploadedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
    });

    test('CourseProvider.getLessonsForBatch deduplicates repeated lectures and excludes 0-duration copy', () {
      final repo = MockDuplicateCourseRepository([
        validRecording,
        zeroDurationRecording,
        validRecording, // duplicate
        zeroDurationRecording, // duplicate
      ]);

      final provider = CourseProvider(repository: repo);
      // Simulate raw populated lessons containing 4 items (2 duplicates each)
      provider.videoLessons.addAll([
        validRecording,
        zeroDurationRecording,
        validRecording,
        zeroDurationRecording,
      ]);

      final deduplicated = provider.getLessonsForBatch('batch_rangdari_2');

      // Must have exactly 1 lecture: the valid 14-second recording
      expect(deduplicated.length, 1);
      expect(deduplicated.first.id, 'rec_valid_14s');
      expect(deduplicated.first.duration, const Duration(seconds: 14));
      expect(deduplicated.first.title, 'Live Concept Lecture');
    });

    testWidgets('VideoPlayerScreen title container spans 100% full width and shows non-duplicated playlist', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400); // 360x800 dp
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = MockDuplicateCourseRepository([
        validRecording,
        zeroDurationRecording,
        validRecording,
        zeroDurationRecording,
      ]);
      final provider = CourseProvider(repository: repo);
      provider.videoLessons.addAll([
        validRecording,
        zeroDurationRecording,
        validRecording,
        zeroDurationRecording,
      ]);

      final authProvider = FakeAuthProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CourseProvider>.value(value: provider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: MaterialApp(
            home: VideoPlayerScreen(
              lesson: validRecording,
              course: testCourse,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify "Course Lectures" header shows exactly "Course Lectures (1 Video)"
      expect(find.text('Course Lectures (1 Video)'), findsOneWidget);
      expect(find.text('Course Lectures (4 Videos)'), findsNothing);

      // 2. Playlist only contains one item for Live Concept Lecture (3 occurrences total: 1 in AppBar, 1 in title card, 1 in playlist)
      expect(find.text('Live Concept Lecture'), findsNWidgets(3));

      // 3. Find the title Container widget and verify it spans full width
      final containerFinder = find.byWidgetPredicate((widget) {
        if (widget is Container && widget.constraints != null) {
          return widget.constraints!.minWidth == double.infinity;
        }
        return false;
      });
      expect(containerFinder, findsWidgets);

      // 4. Verify the width of the rendered title card matches the screen width (360 dp)
      final titleCardRenderBox = tester.renderObject(
        find.ancestor(
          of: find.text('Live Lecture Recording').first,
          matching: find.byType(Container),
        ).first,
      ) as RenderBox;

      expect(titleCardRenderBox.size.width, 360.0);
    });
  });
}
