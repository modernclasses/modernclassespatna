import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_scaffold.dart';
import 'admin_dashboard_screen.dart';
import 'manage_courses_screen.dart';
import 'manage_students_screen.dart';
import 'manage_teachers_screen.dart';
import 'revenue_reports_screen.dart';
import 'app_settings_screen.dart';

class AdminMainNavigation extends StatefulWidget {
  const AdminMainNavigation({super.key});

  @override
  State<AdminMainNavigation> createState() => _AdminMainNavigationState();
}

class _AdminMainNavigationState extends State<AdminMainNavigation> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const AdminDashboardScreen(),
      const ManageCoursesScreen(),
      const ManageStudentsScreen(),
      const ManageTeachersScreen(),
      const RevenueReportsScreen(),
      const AppSettingsScreen(),
    ];

    const destinations = [
      NavigationDestination(
        icon: Icon(Icons.analytics_outlined),
        selectedIcon: Icon(Icons.analytics, color: AppTheme.primary),
        label: "Overview",
      ),
      NavigationDestination(
        icon: Icon(Icons.school_outlined),
        selectedIcon: Icon(Icons.school, color: AppTheme.primary),
        label: "Courses",
      ),
      NavigationDestination(
        icon: Icon(Icons.people_outline),
        selectedIcon: Icon(Icons.people, color: AppTheme.primary),
        label: "Students",
      ),
      NavigationDestination(
        icon: Icon(Icons.badge_outlined),
        selectedIcon: Icon(Icons.badge, color: AppTheme.primary),
        label: "Teachers",
      ),
      NavigationDestination(
        icon: Icon(Icons.attach_money_outlined),
        selectedIcon: Icon(Icons.attach_money, color: AppTheme.primary),
        label: "Revenue",
      ),
      NavigationDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings, color: AppTheme.primary),
        label: "Settings",
      ),
    ];

    return ModernAppScaffold(
      title: "Admin Command Center",
      selectedNavIndex: _currentIndex,
      onNavIndexChanged: (i) => setState(() => _currentIndex = i),
      navDestinations: destinations,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: destinations,
      ),
      body: IndexedStack(index: _currentIndex, children: screens),
    );
  }
}
