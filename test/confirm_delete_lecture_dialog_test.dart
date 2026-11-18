import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_classes_patna/widgets/confirm_delete_lecture_dialog.dart';

void main() {
  group('ConfirmDeleteLectureDialog Tests', () {
    testWidgets('Delete button is disabled until user types "confirm"',
        (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                key: const Key('trigger_dialog_btn'),
                onPressed: () async {
                  result = await showDialog<bool>(
                    context: context,
                    builder: (_) => const ConfirmDeleteLectureDialog(
                      lectureTitle: 'Indian Polity - Chapter 4',
                      batchName: 'UPSC Foundation 2026',
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.byKey(const Key('trigger_dialog_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Delete Lecture?'), findsOneWidget);
      expect(
        find.text(
          'Are you sure you want to permanently delete "Indian Polity - Chapter 4"?',
        ),
        findsOneWidget,
      );
      expect(find.text('Batch: UPSC Foundation 2026'), findsOneWidget);

      final deleteBtnFinder =
          find.byKey(const Key('confirm_delete_lecture_btn'));
      expect(deleteBtnFinder, findsOneWidget);

      // Initially disabled
      final initialBtn = tester.widget<ElevatedButton>(deleteBtnFinder);
      expect(initialBtn.onPressed, isNull);

      // Type wrong text
      final textFieldFinder =
          find.byKey(const Key('confirm_delete_text_field'));
      await tester.enterText(textFieldFinder, 'delete');
      await tester.pumpAndSettle();

      expect(tester.widget<ElevatedButton>(deleteBtnFinder).onPressed, isNull);

      // Type "confirm" (case-insensitive)
      await tester.enterText(textFieldFinder, 'Confirm');
      await tester.pumpAndSettle();

      expect(
        tester.widget<ElevatedButton>(deleteBtnFinder).onPressed,
        isNotNull,
      );

      // Tap Delete Lecture
      await tester.tap(deleteBtnFinder);
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(find.text('Delete Lecture?'), findsNothing);
    });

    testWidgets('Cancel button dismisses dialog and returns false',
        (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                key: const Key('trigger_dialog_btn'),
                onPressed: () async {
                  result = await showDialog<bool>(
                    context: context,
                    builder: (_) => const ConfirmDeleteLectureDialog(
                      lectureTitle: 'Modern History - 1857 Revolt',
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('trigger_dialog_btn')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(find.text('Delete Lecture?'), findsNothing);
    });
  });
}
