class CourseModel {
  final String id;
  final String title;
  final String category;
  final String description;
  final String coverImageUrl;
  final double price; // e.g. 799
  final double originalPrice; // e.g. 1999
  final String teacherName;
  final String teacherId;
  final int totalLessons;
  final int totalHours;
  final int totalTests;
  final int totalNotes;
  final double rating;
  final int reviewsCount;
  final List<String> highlights;
  final List<String> batchIds;
  final bool isFeatured;
  final bool isCrashCourse;

  const CourseModel({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.coverImageUrl,
    required this.price,
    required this.originalPrice,
    required this.teacherName,
    required this.teacherId,
    required this.totalLessons,
    required this.totalHours,
    required this.totalTests,
    required this.totalNotes,
    this.rating = 4.9,
    this.reviewsCount = 1420,
    required this.highlights,
    required this.batchIds,
    this.isFeatured = false,
    this.isCrashCourse = true,
  });

  int get discountPercentage =>
      (((originalPrice - price) / originalPrice) * 100).round();
}

class VideoLessonModel {
  final String id;
  final String courseId;
  final String batchId;
  final String title;
  final String chapter;
  final Duration duration;
  final String videoUrl;
  final String? notesPdfUrl;
  final bool isCompleted;
  final double progressPercent; // 0.0 to 1.0
  final DateTime uploadedAt;

  const VideoLessonModel({
    required this.id,
    required this.courseId,
    required this.batchId,
    required this.title,
    required this.chapter,
    required this.duration,
    required this.videoUrl,
    this.notesPdfUrl,
    this.isCompleted = false,
    this.progressPercent = 0.0,
    required this.uploadedAt,
  });

  VideoLessonModel copyWith({
    bool? isCompleted,
    double? progressPercent,
  }) {
    return VideoLessonModel(
      id: id,
      courseId: courseId,
      batchId: batchId,
      title: title,
      chapter: chapter,
      duration: duration,
      videoUrl: videoUrl,
      notesPdfUrl: notesPdfUrl,
      isCompleted: isCompleted ?? this.isCompleted,
      progressPercent: progressPercent ?? this.progressPercent,
      uploadedAt: uploadedAt,
    );
  }
}
