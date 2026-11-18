import 'package:flutter_test/flutter_test.dart';
import 'package:modern_classes_patna/features/auth/logic/auth_provider.dart';
import 'package:modern_classes_patna/features/auth/data/repositories/auth_repository.dart';
import 'package:modern_classes_patna/models/user_model.dart';
import 'package:modern_classes_patna/features/notifications/data/models/notification_model.dart';
import 'package:modern_classes_patna/features/tests/data/models/test_model.dart';
import 'package:modern_classes_patna/features/live_classes/data/models/live_class_model.dart';

class FakeAuthRepository implements AuthRepository {
  @override
  Future<void> adminSetUserRole({
    required String targetUserId,
    required String newRole,
  }) async {}
  bool simulateNullUser = false;
  bool simulateEmailUnconfirmed = false;

  bool adminUpdateCalled = false;
  String updatedTargetId = '';
  String updatedName = '';
  int resendCount = 0;

  @override
  bool get isConnected => true;

  @override
  Future<UserModel?> getInitialSession() async => null;

  int resetEmailSentCount = 0;
  bool simulateResetFailure = false;
  int otpVerifyCount = 0;

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
    if (simulateNullUser) throw Exception('email_confirmation_required');
    return UserModel(
      id: 'student_1',
      email: email,
      name: '',
      phone: phone,
      role: UserRole.student,
    );
  }

  @override
  Future<UserModel> loginStudent({
    required String phoneOrEmail,
    String? password,
  }) async {
    if (simulateEmailUnconfirmed) throw Exception('Email not confirmed');
    return UserModel(
      id: 'student_1',
      email: phoneOrEmail,
      phone: '',
      role: UserRole.student,
      name: '',
    );
  }

  @override
  Future<UserModel> loginStaff({
    required String email,
    required String password,
  }) async {
    return UserModel(
      id: 'staff_1',
      email: email,
      phone: '',
      role: UserRole.teacher,
      name: '',
    );
  }

  @override
  Future<void> logout() async {}

  @override
  Future<UserModel> updateProfile(UserModel user) async => user;

  @override
  Future<void> exchangeCode(String code) async {}
  @override
  @override
  Future<void> resendConfirmation(String email) async {
    resendCount++;
  }

  @override
  Future<void> updateUserPassword(String newPassword) async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    if (simulateResetFailure) throw Exception('User not found');
    resetEmailSentCount++;
  }

  @override
  Future<void> verifyRecoveryOtpAndSetNewPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    if (simulateResetFailure) throw Exception('Invalid or expired recovery code.');
    otpVerifyCount++;
  }

  @override
  Future<UserModel> updateDisplayName(String newName) async => UserModel(
    id: '1',
    email: 'e',
    name: newName,
    phone: 'p',
    role: UserRole.student,
  );
  @override
  Future<List<UserModel>> getAllProfiles() async => [];
  @override
  Future<String> adminCreateTeacher({
    required String email,
    required String password,
    required String fullName,
  }) async => '';
  @override
  Future<List<UserModel>> getBatchStudents(String batchId) async => [];
  @override
  Future<List<UserModel>> getAllStudents() async => [];
  @override
  @override
  Future<void> adminUpdateStudentProfile(
    String targetId,
    String newName,
  ) async {
    adminUpdateCalled = true;
    updatedTargetId = targetId;
    updatedName = newName;
  }
}

void main() {
  group('Auth & Schema Flow Tests', () {
    late AuthProvider authProvider;
    late FakeAuthRepository fakeRepo;

    setUp(() {
      fakeRepo = FakeAuthRepository();
      authProvider = AuthProvider(repository: fakeRepo);
    });

    test('signup session-null handling (Confirm Email ON)', () async {
      fakeRepo.simulateNullUser = true;
      final success = await authProvider.registerStudent(
        phone: '1234567890',
        email: 'test@test.com',
        password: 'password',
        targetExam: 'BPSC',
        medium: 'English',
      );

      expect(success, true);
      expect(authProvider.requiresEmailConfirmation, true);
      expect(authProvider.isAuthenticated, false);
      expect(authProvider.currentUser, UserModel.guest);
    });

    test('signup success returns session (Confirm Email OFF)', () async {
      fakeRepo.simulateNullUser = false;
      final success = await authProvider.registerStudent(
        phone: '1234567890',
        email: 'test@test.com',
        password: 'password',
        targetExam: 'BPSC',
        medium: 'English',
      );

      expect(success, true);
      expect(authProvider.requiresEmailConfirmation, false);
      expect(authProvider.isAuthenticated, true);
      expect(authProvider.currentUser.id, 'student_1');
    });

    test('admin student name correction', () async {
      await authProvider.adminUpdateStudentProfile('student_123', 'New Name');
      expect(fakeRepo.adminUpdateCalled, true);
      expect(fakeRepo.updatedTargetId, 'student_123');
      expect(fakeRepo.updatedName, 'New Name');
    });

    test('resend confirmation path', () async {
      await authProvider.resendConfirmationEmail('test@test.com');
      expect(fakeRepo.resendCount, 1);
    });

    test('Notifications fetch - schema mismatch fix', () {
      final json = {
        'id': '1',
        'title': 'Test',
        'message': 'msg',
        'category': 'general',
        'created_at': '2026-01-01T12:00:00Z',
        'is_read': false,
      };
      final notif = NotificationModel.fromMap(json);
      expect(notif.timestamp.year, 2026);
    });

    test('Tests fetch - schema mismatch fix', () {
      final json = {
        'id': '1',
        'title': 'Test',
        'subject': 'Math',
        'total_questions': 10,
        'created_at': '2026-01-01T12:00:00Z',
      };
      final t = TestModel.fromMap(json);
      expect(t.scheduledDate.year, 2026);
    });

    test('Live classes fetch - schema mismatch fix', () {
      final json = {
        'id': '1',
        'title': 'Class',
        'scheduled_at': '2026-01-01T12:00:00Z',
      };
      final l = LiveClassModel.fromMap(json);
      expect(l.scheduledStartTime.year, 2026);
    });

    test('Student registration succeeds without phone number (SMS disabled)', () async {
      final success = await authProvider.registerStudent(
        email: 'teststudent_nophone@example.com',
        password: 'Password123',
        targetExam: 'BPSC',
        medium: 'English',
      );
      expect(success, isTrue);
      expect(authProvider.currentUser.email, 'teststudent_nophone@example.com');
      expect(authProvider.currentUser.phone, '');
    });

    test('sendPasswordResetEmail triggers reset email successfully', () async {
      expect(fakeRepo.resetEmailSentCount, 0);
      final success = await authProvider.sendPasswordResetEmail('student@example.com');
      expect(success, isTrue);
      expect(fakeRepo.resetEmailSentCount, 1);
      expect(authProvider.errorMessage, isNull);
    });

    test('sendPasswordResetEmail handles error gracefully', () async {
      fakeRepo.simulateResetFailure = true;
      final success = await authProvider.sendPasswordResetEmail('unknown@example.com');
      expect(success, isFalse);
      expect(authProvider.errorMessage, isNotNull);
    });

    test('verifyRecoveryOtpAndSetNewPassword verifies code and sets password', () async {
      expect(fakeRepo.otpVerifyCount, 0);
      final success = await authProvider.verifyRecoveryOtpAndSetNewPassword(
        email: 'student@example.com',
        token: '123456',
        newPassword: 'BrandNewPassword123',
      );
      expect(success, isTrue);
      expect(fakeRepo.otpVerifyCount, 1);
    });
  });
}
