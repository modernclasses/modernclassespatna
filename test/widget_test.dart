import 'package:flutter_test/flutter_test.dart';
import 'package:modern_classes_patna/app.dart';

void main() {
  testWidgets(
    'Modern Classes Patna App renders Portal Gateway with unified staff portal',
    (WidgetTester tester) async {
      await tester.pumpWidget(const ModernClassesPatnaApp());
      await tester.pump();

      // Verify brand and portal choices
      expect(find.text('MODERN CLASSES PATNA'), findsOneWidget);
      expect(find.text('Student Learning App'), findsOneWidget);
      expect(find.text('Faculty & Admin Portal'), findsOneWidget);
    },
  );
}
