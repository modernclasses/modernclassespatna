import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_scaffold.dart';
import 'student_home_screen.dart';
import 'course_store_screen.dart';
import 'my_batches_screen.dart';
import 'tests_screen.dart';
import 'student_profile_screen.dart';

class StudentMainNavigation extends StatefulWidget {
  const StudentMainNavigation({super.key});

  @override
  State<StudentMainNavigation> createState() => _StudentMainNavigationState();
}

class _StudentMainNavigationState extends State<StudentMainNavigation> {
  int _currentIndex = 0;

  void _onTabChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      StudentHomeScreen(onNavigateTab: _onTabChanged),
      const CourseStoreScreen(),
      const MyBatchesScreen(),
      const TestsScreen(),
      const StudentProfileScreen(),
    ];

    const destinations = [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home, color: AppTheme.primary),
        label: "Home",
      ),
      NavigationDestination(
        icon: Icon(Icons.storefront_outlined),
        selectedIcon: Icon(Icons.storefront, color: AppTheme.primary),
        label: "Courses",
      ),
      NavigationDestination(
        icon: Icon(Icons.school_outlined),
        selectedIcon: Icon(Icons.school, color: AppTheme.primary),
        label: "My Batches",
      ),
      NavigationDestination(
        icon: Icon(Icons.quiz_outlined),
        selectedIcon: Icon(Icons.quiz, color: AppTheme.primary),
        label: "Tests",
      ),
      NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person, color: AppTheme.primary),
        label: "Profile",
      ),
    ];

    return ModernAppScaffold(
      title: "Modern Classes Patna",
      selectedNavIndex: _currentIndex,
      onNavIndexChanged: _onTabChanged,
      navDestinations: destinations,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabChanged,
        destinations: destinations,
      ),
      body: IndexedStack(index: _currentIndex, children: screens),
    );
  }
}
