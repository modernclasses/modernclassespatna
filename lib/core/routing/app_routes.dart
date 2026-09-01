/// Centralized Route Name Constants for Modern Classes Patna.
class AppRoutes {
  AppRoutes._();

  static const String root = '/';
  static const String gateway = '/gateway';

  // Auth Routes
  static const String studentLogin = '/auth/student-login';
  static const String studentRegister = '/auth/student-register';
  static const String staffLogin = '/auth/staff-login';

  // Student Main Portals
  static const String studentMain = '/student/main';
  static const String courseDetail = '/courses/detail';
  static const String checkout = '/checkout';
  static const String videoPlayer = '/learning/video-player';
  static const String documentReader = '/learning/document-reader';
  static const String liveClassroom = '/live/classroom';
  static const String testTaking = '/tests/take-exam';
  static const String testResult = '/tests/result';
  static const String notifications = '/notifications';

  // Staff Portals
  static const String teacherMain = '/teacher/main';
  static const String adminMain = '/admin/main';
}
