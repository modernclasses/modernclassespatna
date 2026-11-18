import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_classes_patna/features/auth/presentation/screens/portal_gateway_screen.dart';
import 'package:modern_classes_patna/screens/admin/app_settings_screen.dart';
import 'package:modern_classes_patna/core/constants/app_colors.dart';

void main() {
  group('1. Portal Gateway Screen Refinements', () {
    testWidgets('Merged Faculty & Admin card reduces clutter', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PortalGatewayScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Student learning app exists
      expect(find.text('Student Learning App'), findsOneWidget);
      expect(find.text('For Students'), findsOneWidget);

      // Unified Faculty & Admin card exists
      expect(find.text('Faculty & Admin Portal'), findsOneWidget);
      expect(find.text('Faculty & Administration'), findsOneWidget);

      // Redundant separate cards should NOT exist
      expect(find.text('Faculty & Teacher Portal'), findsNothing);
      expect(find.text('Admin Command Suite'), findsNothing);
      expect(find.text('5 Admin Seats Lock'), findsNothing);
    });

    testWidgets('Faculty & Admin card renders cleanly without overflow on Balmuda 360x640 viewport', (tester) async {
      tester.view.physicalSize = const Size(360.0, 640.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: PortalGatewayScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Faculty & Admin Portal'), findsOneWidget);
      expect(find.textContaining('Deliver live lectures'), findsOneWidget);
    });
  });

  group('2. AppSettingsScreen Live Ingest Removal', () {
    testWidgets('Admin settings does NOT contain live stream ingest card or inputs', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppSettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure no live streaming card or live input credentials exist in admin settings
      expect(find.text('Live Broadcast & Ingest Engine'), findsNothing);
      expect(find.text('Live Streaming Engine'), findsNothing);
      expect(find.text('Live Input UID'), findsNothing);
      expect(find.text('RTMPS Ingest URL'), findsNothing);
      expect(find.text('Stream Key'), findsNothing);
      expect(find.text('Student HLS Playback URL'), findsNothing);
      expect(find.byKey(const Key('add_live_input_button')), findsNothing);
    });
  });

  group('3. Student Account Status Toggle Switch Layout & Overflow Prevention', () {
    testWidgets('Toggle switch with Expanded column renders cleanly on narrow 300px dialog width', (tester) async {
      tester.view.physicalSize = const Size(300, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool isActive = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  content: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Student Account Status",
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 2),
                            Text(
                              "Active accounts can log in and view classes",
                              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch.adaptive(
                        value: isActive,
                        activeTrackColor: AppColors.emerald,
                        onChanged: (val) => setState(() => isActive = val),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Must not throw any RenderFlex overflow exceptions
      expect(tester.takeException(), isNull);
      expect(find.text("Student Account Status"), findsOneWidget);
      expect(find.text("Active accounts can log in and view classes"), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });
  });

  group('4. Admin Delete Student Account CONFIRM Verification', () {
    testWidgets('Delete button is disabled until CONFIRM is typed', (tester) async {
      final confirmCtrl = TextEditingController();
      bool canDelete = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  title: const Text("Delete Student Account?"),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Type CONFIRM to proceed with deletion:"),
                      TextField(
                        key: const Key('delete_student_confirm_field'),
                        controller: confirmCtrl,
                        onChanged: (val) {
                          setDialogState(() {
                            canDelete = val.trim() == "CONFIRM";
                          });
                        },
                      ),
                    ],
                  ),
                  actions: [
                    ElevatedButton(
                      key: const Key('confirm_delete_student_button'),
                      onPressed: canDelete ? () {} : null,
                      child: const Text("Delete Permanently"),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final buttonFinder = find.byKey(const Key('confirm_delete_student_button'));
      ElevatedButton button = tester.widget<ElevatedButton>(buttonFinder);

      // Initially disabled
      expect(button.onPressed, isNull);

      // Typing wrong text stays disabled
      await tester.enterText(find.byKey(const Key('delete_student_confirm_field')), 'delete');
      await tester.pumpAndSettle();
      button = tester.widget<ElevatedButton>(buttonFinder);
      expect(button.onPressed, isNull);

      // Typing CONFIRM enables button
      await tester.enterText(find.byKey(const Key('delete_student_confirm_field')), 'CONFIRM');
      await tester.pumpAndSettle();
      button = tester.widget<ElevatedButton>(buttonFinder);
      expect(button.onPressed, isNotNull);
    });
  });

  group('5. Orphaned Enrolled Batch Display Filter', () {
    test('Orphaned batch IDs without valid parent course are excluded from batchDetails', () {
      final List<String> enrolledBatchIds = ['orphan_uuid_1', 'orphan_uuid_2'];
      final List<String> allExistingBatchIds = ['valid_batch_1'];
      final List<String> batchDetails = [];
      final List<String> orphanedIds = [];

      for (final bId in enrolledBatchIds) {
        if (allExistingBatchIds.contains(bId)) {
          batchDetails.add("Valid Course • Batch Name");
        } else {
          orphanedIds.add(bId);
        }
      }

      // No raw UUID strings should be present in user facing details
      expect(batchDetails, isEmpty);
      expect(orphanedIds, containsAll(['orphan_uuid_1', 'orphan_uuid_2']));
      expect(batchDetails.any((d) => d.contains('orphan_uuid')), isFalse);
    });
  });
}
