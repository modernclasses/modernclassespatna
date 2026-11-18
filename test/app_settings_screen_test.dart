import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_classes_patna/screens/admin/app_settings_screen.dart';

void main() {
  Widget buildTestWidget() {
    return const MaterialApp(home: AppSettingsScreen());
  }

  void testResolution(String description, double width, double height) {
    testWidgets(description, (WidgetTester tester) async {
      tester.view.physicalSize = Size(width, height);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Ensure no layout exceptions or RenderFlex overflow occurred
      expect(tester.takeException(), isNull);

      // Verify all confirmed organization content remains fully present and accessible
      expect(find.text('App Config & Security Settings'), findsOneWidget);
      expect(find.text('Modern Classes Patna Organization'), findsOneWidget);
      expect(find.text('Director / Owner'), findsOneWidget);
      expect(find.text('Madhurendra Kumar Yadav'), findsOneWidget);
      expect(find.text('Helpline Phone'), findsOneWidget);
      expect(find.text('+91 6209016951'), findsOneWidget);
      expect(find.text('Official Email'), findsOneWidget);
      expect(find.text('madhurendrayadav06@gmail.com'), findsOneWidget);
      expect(find.text('Campus Location'), findsOneWidget);
      expect(find.text('Musallahpur Hat / Boring Road, Patna'), findsOneWidget);
      expect(find.text('Platform Scalability'), findsOneWidget);
      expect(find.text('Status unverified'), findsOneWidget);

      // Verify Access Control & Security content
      expect(find.text('Master Admin Seats'), findsOneWidget);
      expect(
        find.text('Anti-Piracy Screen Recording Protection'),
        findsOneWidget,
      );
      expect(find.text('Single Device Student Session Lock'), findsOneWidget);
      expect(find.text('Watermarked Dynamic DRM Video Stream'), findsOneWidget);

      // Verify Gateway & Cloud Status content
      expect(find.text('Payment Gateway'), findsOneWidget);
      expect(find.text('Test Auto-Grader'), findsOneWidget);
      expect(find.text('Verification not implemented'), findsOneWidget);
      expect(find.text('Cloud Data Backup'), findsOneWidget);
      expect(find.text('Status unavailable'), findsOneWidget);

      // Verify active configured security features
      expect(find.text('Active (FLAG_SECURE)'), findsOneWidget);
      expect(find.text('Configured & Active'), findsNWidgets(2));

      // Verify that unconfigured items display 'Not configured'
      expect(find.text('Not configured'), findsNWidgets(2));

      // Explicitly verify Live Streaming Ingest is NOT present in admin settings
      expect(find.text('Live Streaming Engine'), findsNothing);
      expect(find.text('Live Broadcast & Ingest Engine'), findsNothing);

      // Explicitly verify unsupported operational claims and fake checkmarks are NOT present
      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.text('5 / 5 Seats Locked'), findsNothing);
      expect(find.text('100k Concurrent Students Ready'), findsNothing);
      expect(find.text('Razorpay / UPI Live'), findsNothing);
      expect(find.text('YouTube Live RTMP Integrated'), findsNothing);
      expect(find.text('Instant Rank Engine Active'), findsNothing);
      expect(find.text('Secured & Encrypted Daily'), findsNothing);
    });
  }

  group('AppSettingsScreen Responsive Layout & Overflow Tests', () {
    testResolution('Ultra-narrow mobile viewport (300px)', 300, 750);
    testResolution('Narrow mobile viewport (320px)', 320, 800);
    testResolution('Compact Android viewport (340px)', 340, 800);
    testResolution('Standard Android viewport (360px)', 360, 800);
    testResolution('Modern mid-tier mobile viewport (390px)', 390, 844);
    testResolution('Large Android viewport (412px)', 412, 915);
    testResolution('Tablet portrait viewport (600px)', 600, 1024);
    testResolution('Tablet landscape / Desktop viewport (800px)', 800, 1200);
  });
}
