import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/routing/route_generator.dart';
import 'models/user_model.dart';
import 'providers/auth_provider.dart';
import 'providers/course_provider.dart';
import 'providers/live_class_provider.dart';
import 'providers/test_provider.dart';
import 'providers/study_material_provider.dart';
import 'providers/doubt_provider.dart';
import 'providers/attendance_provider.dart';
import 'providers/notification_provider.dart';
import 'screens/auth/portal_gateway_screen.dart';
import 'screens/student/student_main_navigation.dart';
import 'screens/teacher/teacher_main_navigation.dart';
import 'screens/admin/admin_main_navigation.dart';

/// Root Application Widget wiring Global Providers, Theme, and Routing.
class ModernClassesPatnaApp extends StatelessWidget {
  const ModernClassesPatnaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CourseProvider()),
        ChangeNotifierProvider(create: (_) => LiveClassProvider()),
        ChangeNotifierProvider(create: (_) => TestProvider()),
        ChangeNotifierProvider(create: (_) => StudyMaterialProvider()),
        ChangeNotifierProvider(create: (_) => DoubtProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: MaterialApp(
        title: 'Modern Classes Patna',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        onGenerateRoute: RouteGenerator.generateRoute,
        home: const RootGateScreen(),
      ),
    );
  }
}

/// Authentication & Role-Based Navigation Gateway.
class RootGateScreen extends StatelessWidget {
  const RootGateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isAuthenticated) {
      return const PortalGatewayScreen();
    }

    switch (auth.currentUser.role) {
      case UserRole.student:
        return const StudentMainNavigation();
      case UserRole.teacher:
        return const TeacherMainNavigation();
      case UserRole.admin:
        return const AdminMainNavigation();
    }
  }
}
