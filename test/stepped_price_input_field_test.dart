import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_classes_patna/core/widgets/stepped_price_input_field.dart';

void main() {
  group('SteppedPriceInputField - Course & Batch Prices (Ending in 9)', () {
    testWidgets('Empty field: tapping + sets value to 9', (tester) async {
      final ctrl = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SteppedPriceInputField(
              controller: ctrl,
              labelText: 'Batch Fee',
              isCoursePrice: true,
              minPrice: 9,
              maxPrice: 3199,
            ),
          ),
        ),
      );

      final plusBtn = find.byKey(const Key('btn_plus_Batch_Fee'));
      expect(plusBtn, findsOneWidget);

      await tester.tap(plusBtn);
      await tester.pump();

      expect(ctrl.text, '9');
    });

    testWidgets('Empty field: tapping - does nothing and remains empty', (tester) async {
      final ctrl = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SteppedPriceInputField(
              controller: ctrl,
              labelText: 'Batch Fee',
              isCoursePrice: true,
              minPrice: 9,
              maxPrice: 3199,
            ),
          ),
        ),
      );

      final minusBtn = find.byKey(const Key('btn_minus_Batch_Fee'));
      expect(minusBtn, findsOneWidget);

      await tester.tap(minusBtn);
      await tester.pump();

      expect(ctrl.text, '');
    });

    testWidgets('Field with value 9: + increments by 10 to 19, - stays at 9', (tester) async {
      final ctrl = TextEditingController(text: '9');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SteppedPriceInputField(
              controller: ctrl,
              labelText: 'Batch Fee',
              isCoursePrice: true,
              minPrice: 9,
              maxPrice: 3199,
            ),
          ),
        ),
      );

      final plusBtn = find.byKey(const Key('btn_plus_Batch_Fee'));
      final minusBtn = find.byKey(const Key('btn_minus_Batch_Fee'));

      // Minus at minPrice 9 should do nothing
      await tester.tap(minusBtn);
      await tester.pump();
      expect(ctrl.text, '9');

      // Plus should increment by 10
      await tester.tap(plusBtn);
      await tester.pump();
      expect(ctrl.text, '19');

      // Another plus
      await tester.tap(plusBtn);
      await tester.pump();
      expect(ctrl.text, '29');

      // Minus should decrement by 10
      await tester.tap(minusBtn);
      await tester.pump();
      expect(ctrl.text, '19');
    });

    testWidgets('Clamped at maxPrice 3199: cannot exceed 3199', (tester) async {
      final ctrl = TextEditingController(text: '3199');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SteppedPriceInputField(
              controller: ctrl,
              labelText: 'Batch Fee',
              isCoursePrice: true,
              minPrice: 9,
              maxPrice: 3199,
            ),
          ),
        ),
      );

      final plusBtn = find.byKey(const Key('btn_plus_Batch_Fee'));
      await tester.tap(plusBtn);
      await tester.pump();
      expect(ctrl.text, '3199');
    });

    testWidgets('Arbitrary typed values jump to valid stepped values ending in 9', (tester) async {
      final ctrl = TextEditingController(text: '25');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SteppedPriceInputField(
              controller: ctrl,
              labelText: 'Batch Fee',
              isCoursePrice: true,
              minPrice: 9,
              maxPrice: 3199,
            ),
          ),
        ),
      );

      final plusBtn = find.byKey(const Key('btn_plus_Batch_Fee'));
      final minusBtn = find.byKey(const Key('btn_minus_Batch_Fee'));

      // 25 + 1 step jumps to 29
      await tester.tap(plusBtn);
      await tester.pump();
      expect(ctrl.text, '29');

      // Set to 25 and test minus
      ctrl.text = '25';
      await tester.tap(minusBtn);
      await tester.pump();
      expect(ctrl.text, '19');
    });

    testWidgets('Validation enforces (value - 9) % 10 == 0 within range 9..3199', (tester) async {
      final formKey = GlobalKey<FormState>();
      final ctrl = TextEditingController(text: '599');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: SteppedPriceInputField(
                controller: ctrl,
                labelText: 'Batch Fee',
                isCoursePrice: true,
                minPrice: 9,
                maxPrice: 3199,
              ),
            ),
          ),
        ),
      );

      // 599 is valid
      expect(formKey.currentState!.validate(), isTrue);

      // 600 does not end in 9 -> invalid
      ctrl.text = '600';
      expect(formKey.currentState!.validate(), isFalse);

      // 5 is below minPrice 9 -> invalid
      ctrl.text = '5';
      expect(formKey.currentState!.validate(), isFalse);

      // 3209 is above maxPrice 3199 -> invalid
      ctrl.text = '3209';
      expect(formKey.currentState!.validate(), isFalse);
    });

    testWidgets('Optional field (isRequired: false) validates empty as valid, non-empty as stepped', (tester) async {
      final formKey = GlobalKey<FormState>();
      final ctrl = TextEditingController(text: '');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: SteppedPriceInputField(
                controller: ctrl,
                labelText: 'Original MRP',
                isCoursePrice: true,
                isRequired: false,
                minPrice: 9,
                maxPrice: 3199,
              ),
            ),
          ),
        ),
      );

      // Empty is valid when isRequired: false
      expect(formKey.currentState!.validate(), isTrue);

      // Valid price
      ctrl.text = '1999';
      expect(formKey.currentState!.validate(), isTrue);

      // Invalid price ending in 0
      ctrl.text = '2000';
      expect(formKey.currentState!.validate(), isFalse);
    });
  });

  group('SteppedPriceInputField - Coupon Discounts (Increments of 10, Capped at Course Price)', () {
    testWidgets('Empty field: + sets to 10, - does nothing', (tester) async {
      final ctrl = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SteppedPriceInputField(
              controller: ctrl,
              labelText: 'Discount',
              isCoursePrice: false,
              minPrice: 10,
              maxPrice: 599,
            ),
          ),
        ),
      );

      final plusBtn = find.byKey(const Key('btn_plus_Discount'));
      final minusBtn = find.byKey(const Key('btn_minus_Discount'));

      // Minus on empty does nothing
      await tester.tap(minusBtn);
      await tester.pump();
      expect(ctrl.text, '');

      // Plus on empty sets to 10
      await tester.tap(plusBtn);
      await tester.pump();
      expect(ctrl.text, '10');

      // Minus on 10 is clamped at 10
      await tester.tap(minusBtn);
      await tester.pump();
      expect(ctrl.text, '10');
    });

    testWidgets('Coupon discount increments by 10 and clamps at course price maxPrice', (tester) async {
      // Course price is 599. Discount cannot exceed 599.
      final ctrl = TextEditingController(text: '590');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SteppedPriceInputField(
              controller: ctrl,
              labelText: 'Discount',
              isCoursePrice: false,
              minPrice: 10,
              maxPrice: 599,
            ),
          ),
        ),
      );

      final plusBtn = find.byKey(const Key('btn_plus_Discount'));
      final minusBtn = find.byKey(const Key('btn_minus_Discount'));

      // 590 + 10 = 600, clamped to maxPrice 599
      await tester.tap(plusBtn);
      await tester.pump();
      expect(ctrl.text, '599');

      // Tapping + at 599 does nothing
      await tester.tap(plusBtn);
      await tester.pump();
      expect(ctrl.text, '599');

      // Tapping - at 599 steps down to 590
      await tester.tap(minusBtn);
      await tester.pump();
      expect(ctrl.text, '590');
    });

    testWidgets('Validation blocks coupon discounts exceeding course price', (tester) async {
      final formKey = GlobalKey<FormState>();
      final ctrl = TextEditingController(text: '200');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: SteppedPriceInputField(
                controller: ctrl,
                labelText: 'Discount',
                isCoursePrice: false,
                minPrice: 10,
                maxPrice: 599,
              ),
            ),
          ),
        ),
      );

      // 200 <= 599 -> valid
      expect(formKey.currentState!.validate(), isTrue);

      // 599 (100% discount equal to course price) -> valid
      ctrl.text = '599';
      expect(formKey.currentState!.validate(), isTrue);

      // 600 > 599 -> invalid
      ctrl.text = '600';
      expect(formKey.currentState!.validate(), isFalse);
    });
  });
}
