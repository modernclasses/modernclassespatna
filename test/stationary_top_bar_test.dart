import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_classes_patna/app.dart';
import 'package:modern_classes_patna/core/widgets/app_scaffold.dart';
import 'package:modern_classes_patna/providers/auth_provider.dart';
import 'package:modern_classes_patna/providers/notification_provider.dart';
import 'package:modern_classes_patna/providers/organization_provider.dart';
import 'package:modern_classes_patna/providers/theme_provider.dart';
import 'package:provider/provider.dart';

void main() {
  group('Stationary Top Bar Tests', () {
    testWidgets('Top bar on PortalGatewayScreen remains stationary during scroll', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const ModernClassesPatnaApp());
      await tester.pumpAndSettle();

      final brandFinder = find.text('MODERN CLASSES PATNA');
      expect(brandFinder, findsOneWidget);

      final initialPosition = tester.getTopLeft(brandFinder);

      // Perform a long upward drag (scroll down)
      final scrollableFinder = find.byType(Scrollable);
      expect(scrollableFinder, findsWidgets);

      await tester.drag(scrollableFinder.first, const Offset(0, -300));
      await tester.pumpAndSettle();

      // Top bar must remain at the exact same vertical position
      final postScrollPosition = tester.getTopLeft(brandFinder);
      expect(postScrollPosition.dy, equals(initialPosition.dy));
    });

    testWidgets('Top bar in ModernAppScaffold smoothly hides on scroll down and reappears on scroll up', (
      WidgetTester tester,
    ) async {
      final orgProvider = OrganizationProvider();
      final authProvider = AuthProvider();
      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: orgProvider),
            ChangeNotifierProvider.value(value: authProvider),
            ChangeNotifierProvider.value(value: themeProvider),
            ChangeNotifierProvider(create: (_) => NotificationProvider()),
          ],
          child: MaterialApp(
            home: ModernAppScaffold(
              title: "Modern Classes Patna",
              body: ListView.builder(
                itemCount: 50,
                itemBuilder: (context, index) => ListTile(
                  title: Text("Course Item #$index"),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final titleFinder = find.text("Modern Classes Patna");
      expect(titleFinder, findsOneWidget);

      final initialTitleOffset = tester.getTopLeft(titleFinder);

      // Scroll content down (finger drags up, negative dy)
      await tester.drag(find.byType(Scrollable), const Offset(0, -500));
      await tester.pumpAndSettle();

      // Top bar title has animated away / moved upward
      final postScrollTitleOffset = tester.getTopLeft(titleFinder);
      expect(postScrollTitleOffset.dy, lessThan(initialTitleOffset.dy));

      // Scroll back up (finger drags down, positive dy)
      await tester.drag(find.byType(Scrollable), const Offset(0, 500));
      await tester.pumpAndSettle();

      // Top bar title has restored to initial position
      final restoredTitleOffset = tester.getTopLeft(titleFinder);
      expect(restoredTitleOffset.dy, equals(initialTitleOffset.dy));
    });
  });
}
