import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Launch Legal & Compliance Audit (PDF Specification)', () {
    test('Item 1 & 2: Student Registration requires Terms & Privacy agreement', () {
      final registerFile = File('lib/features/auth/presentation/screens/student_register_screen.dart');
      expect(registerFile.existsSync(), isTrue);

      final content = registerFile.readAsStringSync();
      // Checkbox key & variable
      expect(content.contains('_agreedToTerms'), isTrue);
      expect(content.contains("key: const Key('register_terms_checkbox')"), isTrue);
      // Validation & error message
      expect(content.contains("Please accept the Terms of Use & Privacy Policy to register."), isTrue);
      // In-app viewer dialog
      expect(content.contains('_showPolicyDialog'), isTrue);
      // Passes terms agreement metadata
      expect(content.contains('termsAgreed: _agreedToTerms'), isTrue);
      expect(content.contains('termsAgreedAt:'), isTrue);
    });

    test('Item 1, 2 & 8: Student Profile contains Legal Policies & Account Deletion', () {
      final profileFile = File('lib/screens/student/student_profile_screen.dart');
      expect(profileFile.existsSync(), isTrue);

      final content = profileFile.readAsStringSync();
      // Legal policies tiles
      expect(content.contains("title: \"Terms of Use\""), isTrue);
      expect(content.contains("title: \"Privacy Policy\""), isTrue);
      expect(content.contains("title: \"Refund & Cancellation Policy\""), isTrue);
      // Google Play Account Deletion workflow
      expect(content.contains("title: \"Request Account Deletion\""), isTrue);
      expect(content.contains('_showAccountDeletionDialog'), isTrue);
      expect(content.contains("madhurendrayadav06@gmail.com"), isTrue);
    });

    test('Item 3: Terms of Service contains ALL-CAPS Disclaimer & Liability Limit', () {
      final termsFile = File('website/terms.html');
      expect(termsFile.existsSync(), isTrue);

      final content = termsFile.readAsStringSync();
      expect(content.contains("DISCLAIMER OF WARRANTIES"), isTrue);
      expect(content.contains("LIMITATION OF LIABILITY & DAMAGE CAP"), isTrue);
      expect(content.contains("TWELVE (12) MONTHS"), isTrue);
      expect(content.contains("Educational Content & AI Disclaimer"), isTrue);
    });

    test('Item 4: Checkout Screen links Refund Policy & Google Play Billing', () {
      final checkoutFile = File('lib/screens/student/checkout_screen.dart');
      expect(checkoutFile.existsSync(), isTrue);

      final content = checkoutFile.readAsStringSync();
      expect(content.contains("By enrolling, you agree that digital batch access begins immediately."), isTrue);
      expect(content.contains("key: const Key('checkout_refund_policy_link')"), isTrue);
      expect(content.contains('_showRefundPolicyDialog'), isTrue);
      expect(content.contains("Google Play In-App Billing"), isTrue);
      expect(content.contains("Razorpay"), isFalse); // Misleading gateway claim removed
    });

    test('Item 4, 5, 7, 8, 9: Website contains all required compliance HTML pages', () {
      final refundFile = File('website/refund-policy.html');
      final cookieFile = File('website/cookie-policy.html');
      final a11yFile = File('website/accessibility.html');
      final dmcaFile = File('website/dmca.html');
      final dpaFile = File('website/dpa.html');

      expect(refundFile.existsSync(), isTrue, reason: 'Refund & Cancellation Policy page missing');
      expect(cookieFile.existsSync(), isTrue, reason: 'Cookie & Tracking Policy page missing');
      expect(a11yFile.existsSync(), isTrue, reason: 'Accessibility Statement page missing');
      expect(dmcaFile.existsSync(), isTrue, reason: 'DMCA & Copyright Takedown Policy page missing');
      expect(dpaFile.existsSync(), isTrue, reason: 'Data Processing Agreement page missing');

      // Verify footers link to them
      final indexFile = File('website/index.html');
      final indexContent = indexFile.readAsStringSync();
      expect(indexContent.contains('href="refund-policy.html"'), isTrue);
      expect(indexContent.contains('href="cookie-policy.html"'), isTrue);
      expect(indexContent.contains('href="accessibility.html"'), isTrue);
      expect(indexContent.contains('href="dmca.html"'), isTrue);
      expect(indexContent.contains('href="dpa.html"'), isTrue);
    });

    test('Item 9 & 10: Legal repository contains DPA and Contractor IP Assignment', () {
      final dpaDoc = File('LEGAL/DATA_PROCESSING_AGREEMENT.md');
      final ipDoc = File('LEGAL/CONTRACTOR_IP_ASSIGNMENT_AGREEMENT.md');

      expect(dpaDoc.existsSync(), isTrue);
      expect(ipDoc.existsSync(), isTrue);

      final ipContent = ipDoc.readAsStringSync();
      expect(ipContent.contains("UNCONDITIONAL INTELLECTUAL PROPERTY ASSIGNMENT"), isTrue);
      expect(ipContent.contains("CONTRACTOR IP OWNERSHIP AUDIT CHECKLIST"), isTrue);
      expect(ipContent.contains("Madhurendra Kumar Yadav"), isTrue);
    });
  });
}
