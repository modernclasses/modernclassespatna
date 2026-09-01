import 'package:flutter_test/flutter_test.dart';
import 'package:modern_classes_patna/app.dart';

void main() {
  testWidgets('Modern Classes Patna App renders Portal Gateway with 3 isolated portals', (WidgetTester tester) async {
    await tester.pumpWidget(const ModernClassesPatnaApp());
    await tester.pump();

    // Verify brand and portal choices
    expect(find.text('MODERN CLASSES PATNA'), findsOneWidget);
    expect(find.text('Student Learning App'), findsOneWidget);
    expect(find.text('Faculty & Teacher Portal'), findsOneWidget);
    expect(find.text('Admin Command Suite'), findsOneWidget);
  });
}
