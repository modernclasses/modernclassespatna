import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_classes_patna/core/config/app_config.dart';
import 'package:modern_classes_patna/core/routing/app_routes.dart';
import 'package:modern_classes_patna/core/routing/route_generator.dart';
import 'package:modern_classes_patna/models/user_model.dart';
import 'package:modern_classes_patna/providers/auth_provider.dart';
import 'package:modern_classes_patna/providers/course_provider.dart';
import 'package:modern_classes_patna/providers/live_class_provider.dart';
import 'package:modern_classes_patna/providers/test_provider.dart';
import 'package:modern_classes_patna/providers/study_material_provider.dart';
import 'package:modern_classes_patna/providers/doubt_provider.dart';
import 'package:modern_classes_patna/providers/attendance_provider.dart';
import 'package:modern_classes_patna/providers/notification_provider.dart';
import 'package:modern_classes_patna/data/mock_data.dart';

void main() {
  group('Modern Classes Patna - Full Platform Domain Suite', () {
    test('AppConfig initializes with default safe fallback values', () {
      expect(AppConfig.appName, "Modern Classes Patna");
      expect(AppConfig.appVersion, "1.0.0");
      expect(AppConfig.supportEmail, "support@modernclassespatna.com");
    });

    test('AuthProvider enforces role-isolated authentication and master admin PIN', () async {
      final auth = AuthProvider();
      expect(auth.isAuthenticated, isFalse);

      // Student login
      await auth.loginStudent(phoneOrEmail: "9876543210");
      expect(auth.isAuthenticated, isTrue);
      expect(auth.isStudent, isTrue);
      expect(auth.currentUser.name, "Rohan Kumar");

      // Logout
      await auth.logout();
      expect(auth.isAuthenticated, isFalse);

      // Student registration
      await auth.registerStudent(
        name: "Pooja Kumari",
        phone: "9876500001",
        email: "pooja@gmail.com",
        targetExam: "BPSC 71st",
        medium: "Hindi",
      );
      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentUser.name, "Pooja Kumari");
      expect(auth.currentUser.role, UserRole.student);

      // Logout
      await auth.logout();
      expect(auth.isAuthenticated, isFalse);

      // Faculty login
      final teacherSuccess = await auth.loginTeacher(staffId: "tch_001", password: "password123");
      expect(teacherSuccess, isTrue);
      expect(auth.isTeacher, isTrue);
      expect(auth.currentUser.name, "Madhurendra Kumar Yadav");

      // Logout
      await auth.logout();
      expect(auth.isAuthenticated, isFalse);

      // Admin login with invalid PIN fails
      final adminFail = auth.loginAdmin(adminId: "admin@modernclasses.com", securityPin: "0000");
      expect(adminFail, isFalse);
      expect(auth.isAuthenticated, isFalse);

      // Admin login with valid 6-digit Master PIN succeeds
      final adminSuccess = auth.loginAdmin(adminId: "admin@modernclasses.com", securityPin: "123456");
      expect(adminSuccess, isTrue);
      expect(auth.isAdmin, isTrue);
      expect(auth.currentUser.name, "Modern Classes Admin");
    });

    test('CourseProvider applies coupon discount correctly and generates invoice', () {
      final courseProvider = CourseProvider();
      final course = courseProvider.courses.first;
      final batch = courseProvider.batches.first;

      // Validate PATNA50 coupon (₹200 discount)
      final coupon = courseProvider.validateCoupon("PATNA50", batch.batchPrice);
      expect(coupon, isNotNull);
      expect(coupon!.discountAmount, 200.0);

      // Process payment
      final txn = courseProvider.processPayment(
        studentId: "std_001",
        studentName: "Rohan Kumar",
        course: course,
        batch: batch,
        appliedCoupon: coupon,
        paymentMethod: "UPI (Google Pay)",
      );

      expect(txn.amountPaid, batch.batchPrice - 200.0);
      expect(txn.invoiceNumber, startsWith("INV-2026-MCP-"));
      expect(courseProvider.transactions.first.id, txn.id);
    });

    test('LiveClassProvider handles live stream state and real-time chat messages', () {
      final liveProvider = LiveClassProvider();
      expect(liveProvider.classes, isNotEmpty);

      final liveClass = liveProvider.classes.first;
      final initialMessages = liveClass.chatMessages.length;

      liveProvider.sendLiveChatMessage(
        classId: liveClass.id,
        senderName: "Rohan Kumar",
        text: "Sir, will the recording be uploaded tonight?",
      );

      final updatedClass = liveProvider.getLiveClassById(liveClass.id);
      expect(updatedClass, isNotNull);
      expect(updatedClass!.chatMessages.length, initialMessages + 1);
      expect(updatedClass.chatMessages.last.text, "Sir, will the recording be uploaded tonight?");
    });

    test('TestProvider executes timed test, auto-grading, and calculates ranks', () {
      final testProvider = TestProvider();
      final test = MockData.tests.first;

      testProvider.startTest(test);
      expect(testProvider.activeTest, isNotNull);
      expect(testProvider.currentQuestionIndex, 0);

      // Question 1: option 1 (Veer Kunwar Singh) is correct
      testProvider.selectOptionForCurrentQuestion(1);

      // Jump to question 2 (multiple choice 0, 1, 2)
      testProvider.jumpToQuestion(1);
      testProvider.selectOptionForCurrentQuestion(0);
      testProvider.selectOptionForCurrentQuestion(1);
      testProvider.selectOptionForCurrentQuestion(2);

      // Submit test
      final result = testProvider.submitTest(
        studentId: "std_001",
        studentName: "Rohan Kumar",
      );

      expect(result.score, greaterThan(0));
      expect(result.rank, greaterThanOrEqualTo(1));
      expect(result.percentile, greaterThan(0));
      expect(testProvider.activeTest, isNull);
    });

    test('StudyMaterialProvider filters documents by subject and batch', () {
      final smProvider = StudyMaterialProvider();
      expect(smProvider.materials, isNotEmpty);

      smProvider.setSelectedSubject('History');
      for (var m in smProvider.filteredMaterials) {
        expect(m.subject, 'History');
      }

      smProvider.setSelectedSubject('All');
      expect(smProvider.filteredMaterials.length, smProvider.materials.length);
    });

    test('DoubtProvider supports student queries, filtering, and faculty answers', () {
      final doubtProvider = DoubtProvider();
      final initialCount = doubtProvider.doubts.length;

      doubtProvider.askNewDoubt(
        studentId: "std_001",
        studentName: "Rohan Kumar",
        subject: "Bihar Special GK",
        topic: "Champaran Satyagraha 1917",
        questionText: "Who invited Mahatma Gandhi to Champaran?",
      );

      expect(doubtProvider.doubts.length, initialCount + 1);
      final newDoubt = doubtProvider.doubts.first;
      expect(newDoubt.isResolved, isFalse);

      doubtProvider.replyToDoubt(
        doubtId: newDoubt.id,
        authorId: "tch_001",
        authorName: "Madhurendra Kumar Yadav",
        authorRole: "Teacher",
        message: "Pandit Raj Kumar Shukla invited Gandhiji.",
        isOfficialTeacherAnswer: true,
      );

      final answeredDoubt = doubtProvider.doubts.firstWhere((d) => d.id == newDoubt.id);
      expect(answeredDoubt.isResolved, isTrue);
      expect(answeredDoubt.replies.first.isOfficialTeacherAnswer, isTrue);
    });

    test('AttendanceProvider calculates attendance percentage accurately', () {
      final attProvider = AttendanceProvider();
      final percentage = attProvider.calculateAttendancePercentage("std_001");
      expect(percentage, greaterThan(0));
      expect(percentage, lessThanOrEqualTo(100));
    });

    test('NotificationProvider broadcasts announcement and marks as read', () {
      final notifProvider = NotificationProvider();
      final initialCount = notifProvider.notifications.length;

      notifProvider.broadcastAnnouncement(
        title: "Test Notice",
        message: "Exam schedule released",
      );

      expect(notifProvider.notifications.length, initialCount + 1);
      expect(notifProvider.notifications.first.title, "Test Notice");

      final firstId = notifProvider.notifications.first.id;
      notifProvider.markAsRead(firstId);
      expect(notifProvider.notifications.first.isRead, isTrue);
    });

    test('RouteGenerator generates valid routes for all top-level entrypoints', () {
      final gatewayRoute = RouteGenerator.generateRoute(
        const RouteSettings(name: AppRoutes.gateway),
      );
      expect(gatewayRoute, isA<MaterialPageRoute>());

      final studentMainRoute = RouteGenerator.generateRoute(
        const RouteSettings(name: AppRoutes.studentMain),
      );
      expect(studentMainRoute, isA<MaterialPageRoute>());

      final teacherMainRoute = RouteGenerator.generateRoute(
        const RouteSettings(name: AppRoutes.teacherMain),
      );
      expect(teacherMainRoute, isA<MaterialPageRoute>());

      final adminMainRoute = RouteGenerator.generateRoute(
        const RouteSettings(name: AppRoutes.adminMain),
      );
      expect(adminMainRoute, isA<MaterialPageRoute>());
    });
  });
}
