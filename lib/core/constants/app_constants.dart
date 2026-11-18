/// Global Application-Level Constants.
class AppConstants {
  AppConstants._();

  // Network Timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);

  // Storage Bucket Identifiers
  static const String bucketStudyMaterials = 'study-materials';
  static const String bucketCourseThumbnails = 'course-thumbnails';
  static const String bucketDoubtAttachments = 'doubt-attachments';
  static const String bucketLectureVideos = 'lecture-videos';

  // Pagination Defaults
  static const int defaultPageSize = 20;

  // Cache & SharedPreferences Keys
  static const String keyAuthToken = 'auth_session_token';
  static const String keySelectedRole = 'user_selected_role';
  static const String keyAppTheme = 'app_theme_mode';
}
