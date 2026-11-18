import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:modern_classes_patna/core/widgets/app_scaffold.dart';
import 'package:modern_classes_patna/screens/admin/admin_main_navigation.dart';
import 'package:modern_classes_patna/providers/auth_provider.dart';
import 'package:modern_classes_patna/providers/course_provider.dart';
import 'package:modern_classes_patna/providers/theme_provider.dart';
import 'package:modern_classes_patna/providers/notification_provider.dart';
import 'package:modern_classes_patna/providers/organization_provider.dart';
import 'package:modern_classes_patna/features/doubts/logic/doubt_provider.dart';
import 'package:modern_classes_patna/features/tests/logic/test_provider.dart';
import 'package:modern_classes_patna/features/auth/data/models/user_model.dart';
import 'verification_audit_pass_test.dart';
import 'content_management_and_teacher_results_test.dart';

void main() {
  group('Revenue, Sales & Reports and ModernAppScaffold Navigation Bar Tests', () {
    testWidgets('1. Bottom navigation bar cannot get stuck hidden on Revenue page when content fits viewport', (tester) async {
      // Standard Android phone viewport
      tester.view.physicalSize = const Size(360.0, 800.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final authRepo = FakeTestAuthRepo(
        user: const UserModel(
          id: 'admin_1',
          name: 'Executive Admin',
          email: 'admin@modernclassespatna.org',
          phone: '+91 9999999999',
          role: UserRole.admin,
        ),
      );
      final authProvider = AuthProvider(repository: authRepo);
      final courseRepo = MockFollowUpCourseRepo(courses: [], batches: []);
      final courseProvider = CourseProvider(repository: courseRepo);
      final testRepo = InMemoryAuditTestRepo();
      final testProvider = TestProvider(repository: testRepo);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authProvider),
            ChangeNotifierProvider.value(value: courseProvider),
            ChangeNotifierProvider.value(value: testProvider),
            ChangeNotifierProvider(create: (_) => ThemeProvider(autoLoad: false)),
            ChangeNotifierProvider(create: (_) => NotificationProvider()),
            ChangeNotifierProvider(create: (_) => OrganizationProvider()),
            ChangeNotifierProvider(create: (_) => DoubtProvider()),
          ],
          child: const MaterialApp(
            home: AdminMainNavigation(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the "Revenue" tab in AdminMainNavigation
      final revenueTabFinder = find.text('Revenue');
      expect(revenueTabFinder, findsOneWidget);
      await tester.tap(revenueTabFinder);
      await tester.pumpAndSettle();

      // Verify Revenue Reports title is visible
      expect(find.text('Revenue, Sales & Reports'), findsOneWidget);

      // Verify NavigationBar is rendered and visible at the bottom
      final navBarFinder = find.byType(NavigationBar);
      expect(navBarFinder, findsOneWidget);
      final initialNavBarPos = tester.getTopLeft(navBarFinder);
      expect(initialNavBarPos.dy, greaterThan(700.0)); // rendered in bottom portion of screen

      // Attempt to drag upward (scroll downward) on the Revenue screen
      await tester.drag(find.text('Revenue, Sales & Reports'), const Offset(0, -60));
      await tester.pumpAndSettle();

      // The bottom navigation bar MUST NOT be hidden when content fits within viewport!
      expect(find.byType(NavigationBar), findsOneWidget);
      final postDragNavBarPos = tester.getTopLeft(navBarFinder);
      expect(postDragNavBarPos.dy, equals(initialNavBarPos.dy),
          reason: 'Navigation bar must remain pinned and visible on non-scrollable / short pages');

      // Tabs remain tappable and accessible
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('2. Bar hides on scroll down and reappears on scroll up on genuinely scrollable content', (tester) async {
      tester.view.physicalSize = const Size(360.0, 640.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      int selectedTab = 0;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => NotificationProvider()),
            ChangeNotifierProvider(create: (_) => ThemeProvider(autoLoad: false)),
          ],
          child: MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                return ModernAppScaffold(
                  title: 'Scrollable Catalog',
                  selectedNavIndex: selectedTab,
                  onNavIndexChanged: (i) => setState(() => selectedTab = i),
                  bottomNavigationBar: NavigationBar(
                    selectedIndex: selectedTab,
                    destinations: const [
                      NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
                      NavigationDestination(icon: Icon(Icons.school), label: 'Courses'),
                    ],
                  ),
                  body: ListView.builder(
                    itemCount: 80,
                    itemBuilder: (ctx, idx) => ListTile(
                      title: Text('Module Item #$idx'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final titleFinder = find.text('Scrollable Catalog');
      expect(titleFinder, findsOneWidget);
      final initialTitleDy = tester.getTopLeft(titleFinder).dy;

      // Verify bottom bar is initially present
      expect(find.byType(NavigationBar), findsOneWidget);

      // 1. Scroll DOWN with significant delta (drag up)
      await tester.drag(find.byType(Scrollable), const Offset(0, -350));
      await tester.pumpAndSettle();

      // Top bar title has animated away / moved upward
      expect(tester.getTopLeft(titleFinder).dy, lessThan(initialTitleDy));
      // Bottom navigation bar has animated off screen
      expect(find.byType(NavigationBar), findsNothing);

      // 2. Scroll UP (drag down)
      await tester.drag(find.byType(Scrollable), const Offset(0, 350));
      await tester.pumpAndSettle();

      // Top bar and bottom bar restored
      expect(tester.getTopLeft(titleFinder).dy, equals(initialTitleDy));
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('3. Recovery mechanism: downward drag anywhere restores hidden navigation bar', (tester) async {
      tester.view.physicalSize = const Size(360.0, 640.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      int selectedTab = 0;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => NotificationProvider()),
            ChangeNotifierProvider(create: (_) => ThemeProvider(autoLoad: false)),
          ],
          child: MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                return ModernAppScaffold(
                  title: 'Recovery Test',
                  selectedNavIndex: selectedTab,
                  onNavIndexChanged: (i) => setState(() => selectedTab = i),
                  bottomNavigationBar: NavigationBar(
                    selectedIndex: selectedTab,
                    destinations: const [
                      NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
                      NavigationDestination(icon: Icon(Icons.school), label: 'Courses'),
                    ],
                  ),
                  body: ListView.builder(
                    itemCount: 80,
                    itemBuilder: (ctx, idx) => ListTile(
                      title: Text('Course Row #$idx'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down to hide bars
      await tester.drag(find.byType(Scrollable), const Offset(0, -350));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing);

      // Perform downward drag via pointer event anywhere on the screen
      await tester.drag(find.byType(ModernAppScaffold), const Offset(0, 40));
      await tester.pumpAndSettle();

      // Navigation bar must be restored and rendered
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('4. Recovery mechanism: tap in bottom navigation area restores hidden navigation bar', (tester) async {
      tester.view.physicalSize = const Size(360.0, 640.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      int selectedTab = 0;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => NotificationProvider()),
            ChangeNotifierProvider(create: (_) => ThemeProvider(autoLoad: false)),
          ],
          child: MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                return ModernAppScaffold(
                  title: 'Bottom Tap Recovery Test',
                  selectedNavIndex: selectedTab,
                  onNavIndexChanged: (i) => setState(() => selectedTab = i),
                  bottomNavigationBar: NavigationBar(
                    selectedIndex: selectedTab,
                    destinations: const [
                      NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
                      NavigationDestination(icon: Icon(Icons.school), label: 'Courses'),
                    ],
                  ),
                  body: ListView.builder(
                    itemCount: 80,
                    itemBuilder: (ctx, idx) => ListTile(
                      title: Text('Topic Item #$idx'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down to hide bars
      await tester.drag(find.byType(Scrollable), const Offset(0, -350));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing);

      // Tap in the bottom recovery zone (y = 610 in a 640 high screen)
      await tester.tapAt(const Offset(180.0, 610.0));
      await tester.pumpAndSettle();

      // Navigation bar must be restored immediately
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('5. Tab switching immediately restores both bars', (tester) async {
      tester.view.physicalSize = const Size(360.0, 640.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      Widget buildApp({required int tab}) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => NotificationProvider()),
            ChangeNotifierProvider(create: (_) => ThemeProvider(autoLoad: false)),
          ],
          child: MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                return ModernAppScaffold(
                  title: 'Tab Reset Test',
                  selectedNavIndex: tab,
                  onNavIndexChanged: (_) {},
                  bottomNavigationBar: NavigationBar(
                    selectedIndex: tab,
                    destinations: const [
                      NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
                      NavigationDestination(icon: Icon(Icons.school), label: 'Courses'),
                    ],
                  ),
                  body: ListView.builder(
                    itemCount: 80,
                    itemBuilder: (ctx, idx) => ListTile(
                      title: Text('Module Item #$idx'),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }

      await tester.pumpWidget(buildApp(tab: 0));
      await tester.pumpAndSettle();

      final titleFinder = find.text('Tab Reset Test');
      final initialTitleDy = tester.getTopLeft(titleFinder).dy;

      // Scroll down to hide
      await tester.drag(find.byType(Scrollable), const Offset(0, -350));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(titleFinder).dy, lessThan(initialTitleDy));
      expect(find.byType(NavigationBar), findsNothing);

      // Switch tab
      await tester.pumpWidget(buildApp(tab: 1));
      await tester.pumpAndSettle();

      // Both bars must be restored
      expect(tester.getTopLeft(titleFinder).dy, equals(initialTitleDy));
      expect(find.byType(NavigationBar), findsOneWidget);
    });
  });
}
