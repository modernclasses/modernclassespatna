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
import 'providers/organization_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/auth/portal_gateway_screen.dart';
import 'screens/auth/name_selection_screen.dart';
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
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CourseProvider()),
        ChangeNotifierProvider(create: (_) => LiveClassProvider()),
        ChangeNotifierProvider(create: (_) => TestProvider()),
        ChangeNotifierProvider(create: (_) => StudyMaterialProvider()),
        ChangeNotifierProvider(create: (_) => DoubtProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => OrganizationProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Modern Classes Patna',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.academicTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            onGenerateRoute: RouteGenerator.generateRoute,
            home: const RootGateScreen(),
          );
        },
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

    // State 1: No authenticated session -> Gateway (Login)
    if (!auth.isAuthenticated) {
      return const PortalGatewayScreen();
    }

    // State 2: Session exists, but profile failed to load
    if (auth.hasSessionWithoutProfile) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off, size: 64, color: AppTheme.error),
                const SizedBox(height: 24),
                Text(
                  "Profile Loading Failed",
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  auth.errorMessage ??
                      "An error occurred while loading your profile data. Please check your connection and try again.",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                if (auth.isLoading)
                  const CircularProgressIndicator(color: AppTheme.primary)
                else
                  ElevatedButton(
                    onPressed: auth.retryProfileLoad,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                    child: const Text("Retry Connection"),
                  ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: auth.logout,
                  child: const Text(
                    "Sign Out & Re-login",
                    style: TextStyle(
                      color: AppTheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // State 3: Session exists AND profile is loaded -> Route by valid role
    final role = auth.currentUser.role;
    switch (role) {
      case UserRole.student:
        if (auth.currentUser.name.isEmpty) {
          return const NameSelectionScreen();
        }
        return const StudentMainNavigation();
      case UserRole.teacher:
        return const TeacherMainNavigation();
      case UserRole.admin:
        return const AdminMainNavigation();
    }
  }
}
