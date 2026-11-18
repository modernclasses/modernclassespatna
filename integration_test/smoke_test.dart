import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:modern_classes_patna/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('End-to-End Flutter Android Smoke Test', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Sign out if already logged in (to ensure a fresh state)
    final profileTab = find.text('Profile');
    if (profileTab.evaluate().isNotEmpty) {
      await tester.tap(profileTab);
      await tester.pumpAndSettle();
      final logoutButton = find.text('Logout');
      if (logoutButton.evaluate().isNotEmpty) {
          await tester.tap(logoutButton);
          await tester.pumpAndSettle(const Duration(seconds: 3));
      } else {
          final logoutIcon = find.byIcon(Icons.logout);
          if (logoutIcon.evaluate().isNotEmpty) {
              await tester.tap(logoutIcon);
              await tester.pumpAndSettle(const Duration(seconds: 3));
          }
      }
    }

    // Now we should be on Login or Gateway screen
    // If on Gateway, tap Student Learning App
    final studentPortalBtn = find.textContaining('Student Learning App');
    if (studentPortalBtn.evaluate().isNotEmpty) {
      await tester.tap(studentPortalBtn);
      await tester.pumpAndSettle();
    }

    // 1. Fresh student registration
    final registerLink = find.text('Register Now');
    expect(registerLink, findsOneWidget, reason: 'Should see Register Now link');
    await tester.tap(registerLink);
    await tester.pumpAndSettle();

    final testEmail = 'student_${DateTime.now().millisecondsSinceEpoch}@example.com';
    
    // Fill Registration form
    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.at(0), 'TempName'); // Ignored by DB trigger
    await tester.enterText(textFields.at(1), '1234567890');
    await tester.enterText(textFields.at(2), testEmail);
    await tester.enterText(textFields.at(3), 'securepassword123');
    
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    
    await tester.enterText(textFields.at(4), 'Patna');
    await tester.pumpAndSettle();
    
    final createAccountBtn = find.byKey(const Key('register_submit_button'));
    await tester.tap(createAccountBtn);
    
    // Wait for the state transition to NameSelectionScreen
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Should be forced to NameSelectionScreen
    final nameScreenRoot = find.byKey(const Key('name_selection_root'));
    expect(nameScreenRoot, findsOneWidget, reason: 'Should route to NameSelectionScreen after signup');

    // 2. First name submission
    final nameField = find.byKey(const Key('name_input_field'));
    await tester.enterText(nameField, 'ValidName123');
    await tester.pumpAndSettle();

    final saveButton = find.byKey(const Key('name_submit_button'));
    await tester.tap(saveButton);
    
    // Wait for the submission and transition
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Confirm the app leaves NameSelectionScreen
    expect(nameScreenRoot, findsNothing, reason: 'Should leave NameSelectionScreen');
    
    // Check Profile Screen to confirm name
    final profileTabAgain = find.text('Profile');
    expect(profileTabAgain, findsOneWidget, reason: 'Should be logged in and see bottom nav');
    await tester.tap(profileTabAgain);
    await tester.pumpAndSettle();
    
    final profileNameDisplay = find.byKey(const Key('profile_name_display'));
    expect(profileNameDisplay, findsOneWidget, reason: 'Profile screen should load');
    
    final nameTextWidget = tester.widget<Text>(profileNameDisplay);
    expect(nameTextWidget.data, 'ValidName123', reason: 'Profile should display the established name');
    
    // 4. Immutability
    final editButton = find.byIcon(Icons.edit);
    expect(editButton, findsNothing, reason: 'Edit button should not be present for student profile');

    // 6. Cold-relaunch test (simulate process termination and relaunch)
    // We clear the widget tree and rerun main to simulate cold launch
    await tester.pumpWidget(Container()); // Clear tree
    await tester.pumpAndSettle();
    
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    
    expect(find.byKey(const Key('name_selection_root')), findsNothing, reason: 'Should not route to NameSelectionScreen on cold restart');
    
    final profileTabRestart = find.text('Profile');
    expect(profileTabRestart, findsOneWidget, reason: 'Should automatically log in on cold restart');
    await tester.tap(profileTabRestart);
    await tester.pumpAndSettle();
    
    final profileNameDisplayRestart = find.byKey(const Key('profile_name_display'));
    expect(profileNameDisplayRestart, findsOneWidget);
    
    final nameTextWidgetRestart = tester.widget<Text>(profileNameDisplayRestart);
    expect(nameTextWidgetRestart.data, 'ValidName123', reason: 'Profile should still display the established name after cold restart');

    print("DISPLAY NAME FEATURE: PASS");
  });
}
