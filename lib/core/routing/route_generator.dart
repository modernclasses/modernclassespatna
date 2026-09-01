import 'package:flutter/material.dart';
import 'app_routes.dart';
import '../theme/app_theme.dart';
import '../../screens/auth/portal_gateway_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/student_register_screen.dart';
import '../../screens/auth/staff_login_screen.dart';
import '../../screens/student/student_main_navigation.dart';
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
