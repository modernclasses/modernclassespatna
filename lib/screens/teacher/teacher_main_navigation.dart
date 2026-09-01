import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_scaffold.dart';
import 'teacher_dashboard_screen.dart';
import 'teacher_batches_screen.dart';
import 'teacher_doubts_screen.dart';
import '../student/tests_screen.dart';

class TeacherMainNavigation extends StatefulWidget {
  const TeacherMainNavigation({super.key});

  @override
  State<TeacherMainNavigation> createState() => _TeacherMainNavigationState();
}

class _TeacherMainNavigationState extends State<TeacherMainNavigation> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const TeacherDashboardScreen(),
      const TeacherBatchesScreen(),
      const TeacherDoubtsScreen(),
      const TestsScreen(),
    ];

    const destinations = [
      NavigationDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard, color: AppTheme.primary),
        label: "Dashboard",
      ),
      NavigationDestination(
        icon: Icon(Icons.school_outlined),
        selectedIcon: Icon(Icons.school, color: AppTheme.primary),
        label: "Batches",
      ),
      NavigationDestination(
        icon: Icon(Icons.help_outline),
        selectedIcon: Icon(Icons.help, color: AppTheme.primary),
        label: "Doubts Desk",
      ),
      NavigationDestination(
        icon: Icon(Icons.quiz_outlined),
        selectedIcon: Icon(Icons.quiz, color: AppTheme.primary),
        label: "Exams",
      ),
    ];

    return ModernAppScaffold(
      title: "Faculty Workspace",
      selectedNavIndex: _currentIndex,
      onNavIndexChanged: (i) => setState(() => _currentIndex = i),
      navDestinations: destinations,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: AppTheme.surface,
        indicatorColor: AppTheme.primary.withValues(alpha: 0.2),
        destinations: destinations,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
    );
  }
}
