import 'package:flutter/material.dart';
import 'app_routes.dart';
import '../theme/app_theme.dart';
import '../../models/course_model.dart';
import '../../models/batch_model.dart';
import '../../models/live_class_model.dart';
import '../../models/test_model.dart';
import '../../models/study_material_model.dart';

import '../../screens/auth/portal_gateway_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/student_register_screen.dart';
import '../../screens/auth/staff_login_screen.dart';

import '../../screens/student/student_main_navigation.dart';
import '../../screens/student/course_detail_screen.dart';
import '../../screens/student/checkout_screen.dart';
import '../../screens/student/video_player_screen.dart';
import '../../screens/student/document_reader_screen.dart';
import '../../screens/student/live_classroom_screen.dart';
import '../../screens/student/test_taking_screen.dart';
import '../../screens/student/test_result_screen.dart';
import '../../screens/student/notifications_screen.dart';

import '../../screens/teacher/teacher_main_navigation.dart';
import '../../screens/admin/admin_main_navigation.dart';

/// Centralized Navigator Route Generator.
class RouteGenerator {
  RouteGenerator._();

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.gateway:
        return _buildRoute(const PortalGatewayScreen(), settings);

      case AppRoutes.studentLogin:
        return _buildRoute(const LoginScreen(), settings);

      case AppRoutes.studentRegister:
        return _buildRoute(const StudentRegisterScreen(), settings);

      case AppRoutes.staffLogin:
        return _buildRoute(const StaffLoginScreen(), settings);

      case AppRoutes.studentMain:
        return _buildRoute(const StudentMainNavigation(), settings);

      case AppRoutes.teacherMain:
        return _buildRoute(const TeacherMainNavigation(), settings);

      case AppRoutes.adminMain:
        return _buildRoute(const AdminMainNavigation(), settings);

      case AppRoutes.notifications:
        return _buildRoute(const NotificationsScreen(), settings);

      case AppRoutes.courseDetail:
        if (settings.arguments is CourseModel) {
          return _buildRoute(
            CourseDetailScreen(course: settings.arguments as CourseModel),
            settings,
          );
        }
        return _errorRoute('Invalid arguments for Course Detail');

      case AppRoutes.checkout:
        if (settings.arguments is Map<String, dynamic>) {
          final args = settings.arguments as Map<String, dynamic>;
          final course = args['course'] as CourseModel;
          final batch = args['batch'] as BatchModel;
          return _buildRoute(
            CheckoutScreen(course: course, batch: batch),
            settings,
          );
        }
        return _errorRoute('Invalid arguments for Checkout');

      case AppRoutes.videoPlayer:
        if (settings.arguments is Map<String, dynamic>) {
          final args = settings.arguments as Map<String, dynamic>;
          return _buildRoute(
            VideoPlayerScreen(
              lesson: args['lesson'] as VideoLessonModel,
              course: args['course'] as CourseModel,
            ),
            settings,
          );
        }
        return _errorRoute('Invalid arguments for Video Player');

      case AppRoutes.documentReader:
        if (settings.arguments is StudyMaterialModel) {
          return _buildRoute(
            DocumentReaderScreen(material: settings.arguments as StudyMaterialModel),
            settings,
          );
        }
        return _errorRoute('Invalid arguments for Document Reader');

      case AppRoutes.liveClassroom:
        if (settings.arguments is LiveClassModel) {
          return _buildRoute(
            LiveClassroomScreen(liveClass: settings.arguments as LiveClassModel),
            settings,
          );
        }
        return _errorRoute('Invalid arguments for Live Classroom');

      case AppRoutes.testTaking:
        if (settings.arguments is TestModel) {
          return _buildRoute(
            TestTakingScreen(test: settings.arguments as TestModel),
            settings,
          );
        }
        return _errorRoute('Invalid arguments for Test Taking');

      case AppRoutes.testResult:
        if (settings.arguments is Map<String, dynamic>) {
          final args = settings.arguments as Map<String, dynamic>;
          return _buildRoute(
            TestResultScreen(
              result: args['result'] as TestResultModel,
              test: args['test'] as TestModel,
            ),
            settings,
          );
        }
        return _errorRoute('Invalid arguments for Test Result');

      default:
        return _errorRoute(settings.name);
    }
  }

  static PageRoute _buildRoute(Widget screen, RouteSettings settings) {
    return MaterialPageRoute(
      builder: (_) => screen,
      settings: settings,
    );
  }

  static Route<dynamic> _errorRoute(String? routeName) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: const Text('Page Not Found')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.warning),
              const SizedBox(height: 16),
              Text(
                'No route defined for: $routeName',
                style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
