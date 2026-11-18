import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:modern_classes_patna/features/auth/data/models/user_model.dart';
import 'package:modern_classes_patna/features/auth/data/repositories/auth_repository.dart';
import 'package:modern_classes_patna/features/auth/logic/auth_provider.dart';
import 'package:modern_classes_patna/features/auth/presentation/screens/login_screen.dart';
import 'package:modern_classes_patna/features/auth/presentation/screens/student_register_screen.dart';
import 'package:modern_classes_patna/features/courses/logic/course_provider.dart';
import 'package:modern_classes_patna/core/widgets/modern_button.dart';
import 'fake_course_repository.dart';

class MockStudentAuthRepo implements AuthRepository {
  @override
  bool get isConnected => true;
  int sendResetCount = 0;
  String? lastResetEmail;
  int verifyOtpCount = 0;
  String? lastNewPassword;
  bool simulateOtpFailure = false;
  bool registrationCalled = false;
  String? registeredEmail;
  String? registeredPhone;

  @override
  Future<UserModel?> getInitialSession() async => null;

  @override
  Future<UserModel> registerStudent({
    String phone = '',
    required String email,
    String? password,
    required String targetExam,
    required String medium,
    bool termsAgreed = true,
    String? termsAgreedAt,
  }) async {
    registrationCalled = true;
    registeredEmail = email;
    registeredPhone = phone;
    return UserModel(
      id: 'reg_student_1',
      email: email,
      name: 'Registered Student',
      phone: phone,
      role: UserRole.student,
    );
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    sendResetCount++;
    lastResetEmail = email;
  }

  @override
  Future<void> verifyRecoveryOtpAndSetNewPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    if (simulateOtpFailure) {
      throw Exception('Invalid or expired verification code.');
    }
    verifyOtpCount++;
    lastNewPassword = newPassword;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Student Forgot Password & Signup Without Phone Tests', () {
    testWidgets('LoginScreen displays Forgot Password button and opens recovery dialog', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockAuth = MockStudentAuthRepo();
      final authProvider = AuthProvider(repository: mockAuth);
      final courseProvider = CourseProvider(repository: FakeCourseRepository());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<CourseProvider>.value(value: courseProvider),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify "Forgot Password?" button is visible on student login
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.text('Need Help?'), findsOneWidget);

      // Pre-enter an email in the login box
      await tester.enterText(
        find.widgetWithText(TextField, 'Registered Email Address'),
        'student@modernclasses.com',
      );
      await tester.pump();

      // Tap "Forgot Password?"
      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();

      // Verify dialog opened with email pre-filled
      expect(find.text('Reset Password'), findsOneWidget);
      expect(find.text('student@modernclasses.com'), findsWidgets);

      // Tap "Send Reset Link"
      await tester.tap(find.widgetWithText(ModernButton, 'Send Reset Link'));
      await tester.pumpAndSettle();

      // Verify auth repo received the call
      expect(mockAuth.sendResetCount, equals(1));
      expect(mockAuth.lastResetEmail, equals('student@modernclasses.com'));

      // Verify success message banner is shown
      expect(
        find.textContaining('Password reset instructions have been sent'),
        findsOneWidget,
      );

      // Switch to Enter Code & New Password mode
      await tester.tap(
        find.text('Have a recovery code? Enter Code & New Password'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Recovery Code / Token'), findsOneWidget);
      expect(find.text('New Password'), findsOneWidget);
      expect(find.text('Confirm New Password'), findsOneWidget);

      // Enter OTP code and matching password
      await tester.enterText(
        find.widgetWithText(TextField, 'Recovery Code / Token'),
        '654321',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'New Password'),
        'ModernPass@2026',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Confirm New Password'),
        'ModernPass@2026',
      );
      await tester.pump();

      // Tap Set New Password button
      await tester.tap(find.widgetWithText(ModernButton, 'Set New Password'));
      await tester.pumpAndSettle();

      // Verify OTP verification was executed
      expect(mockAuth.verifyOtpCount, equals(1));
      expect(mockAuth.lastNewPassword, equals('ModernPass@2026'));

      // Verify dialog closed and snackbar appears on login screen
      expect(
        find.text('Password successfully updated! You can now sign in with your new password.'),
        findsOneWidget,
      );
    });

    testWidgets('StudentRegisterScreen has NO mobile number field or requirement', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockAuth = MockStudentAuthRepo();
      final authProvider = AuthProvider(repository: mockAuth);
      final courseProvider = CourseProvider(repository: FakeCourseRepository());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<CourseProvider>.value(value: courseProvider),
          ],
          child: const MaterialApp(
            home: StudentRegisterScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Mobile Number field is NOT present anywhere on the screen
      expect(find.textContaining('Mobile Number'), findsNothing);
      expect(find.textContaining('phone'), findsNothing);

      // Verify Email Address and Password fields ARE present
      expect(find.text('Email Address *'), findsOneWidget);
      expect(find.text('Password *'), findsOneWidget);

      // Fill in registration form without any phone number
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email Address *'),
        'newsmsfree@gmail.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password *'),
        'SecurePassword123',
      );
      await tester.pump();

      // Check terms checkbox
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      // Scroll to submit button and tap
      final submitFinder = find.byKey(const Key('register_submit_button'));
      await tester.ensureVisible(submitFinder);
      await tester.tap(submitFinder);
      await tester.pumpAndSettle();

      // Verify student was registered with empty phone string
      expect(mockAuth.registrationCalled, isTrue);
      expect(mockAuth.registeredEmail, equals('newsmsfree@gmail.com'));
      expect(mockAuth.registeredPhone, equals(''));
    });
  });
}
