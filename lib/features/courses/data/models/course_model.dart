/// Course Entity for Modern Classes Patna.
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
  final String? playProductId;

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
    this.playProductId,
  });

  int get discountPercentage => originalPrice > 0
      ? (((originalPrice - price) / originalPrice) * 100).round()
      : 0;

  /// Deserialize from Supabase `public.courses` row.
  factory CourseModel.fromMap(Map<String, dynamic> map) {
    return CourseModel(
      id: map['id']?.toString() ?? '',
      title: map['title'] ?? 'Modern Classes Course',
      category: map['category'] ?? 'General',
      description: map['description'] ?? '',
      coverImageUrl: map['cover_image_url'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      originalPrice: (map['original_price'] as num?)?.toDouble() ?? 0.0,
      teacherName: map['teacher_name'] ?? 'Faculty Member',
      teacherId: map['teacher_id']?.toString() ?? '',
      totalLessons: (map['total_lessons'] as num?)?.toInt() ?? 0,
      totalHours: (map['total_hours'] as num?)?.toInt() ?? 0,
      totalTests: (map['total_tests'] as num?)?.toInt() ?? 0,
      totalNotes: (map['total_notes'] as num?)?.toInt() ?? 0,
      rating: (map['rating'] as num?)?.toDouble() ?? 4.9,
      reviewsCount: (map['reviews_count'] as num?)?.toInt() ?? 0,
      highlights: map['highlights'] != null
          ? List<String>.from(map['highlights'])
          : const [],
      batchIds: map['batch_ids'] != null
          ? List<String>.from(map['batch_ids'])
          : const [],
      isFeatured: map['is_featured'] ?? false,
      isCrashCourse: map['is_crash_course'] ?? true,
      playProductId: map['play_product_id'],
    );
  }

  /// Serialize to Supabase `public.courses` format.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'description': description,
      'cover_image_url': coverImageUrl,
      'price': price,
      'original_price': originalPrice,
      'teacher_name': teacherName,
      'teacher_id': teacherId,
      'total_lessons': totalLessons,
      'total_hours': totalHours,
      'total_tests': totalTests,
      'total_notes': totalNotes,
      'rating': rating,
      'reviews_count': reviewsCount,
      'highlights': highlights,
      'batch_ids': batchIds,
      'is_featured': isFeatured,
      'is_crash_course': isCrashCourse,
      'play_product_id': playProductId,
    };
  }
}

/// Video Lesson Entity for Recorded Lectures.
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

  factory VideoLessonModel.fromMap(Map<String, dynamic> map) {
    return VideoLessonModel(
      id: map['id']?.toString() ?? '',
      courseId: map['course_id']?.toString() ?? '',
      batchId: map['batch_id']?.toString() ?? '',
      title: map['title'] ?? '',
      chapter: map['chapter'] ?? 'General Chapter',
      duration: Duration(seconds: (map['duration_seconds'] as num?)?.toInt() ?? 3600),
      videoUrl: map['video_url'] ?? '',
      notesPdfUrl: map['notes_pdf_url'],
      isCompleted: map['is_completed'] ?? false,
      progressPercent: (map['progress_percent'] as num?)?.toDouble() ?? 0.0,
      uploadedAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'course_id': courseId,
      'batch_id': batchId,
      'title': title,
      'chapter': chapter,
      'duration_seconds': duration.inSeconds,
      'video_url': videoUrl,
      'notes_pdf_url': notesPdfUrl,
      'is_completed': isCompleted,
      'progress_percent': progressPercent,
    };
  }

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
