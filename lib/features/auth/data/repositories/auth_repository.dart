import 'package:flutter/foundation.dart';
import '../../../../core/errors/error_handler.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/user_model.dart';

abstract class AuthRepository {
  bool get isConnected;
  Future<UserModel?> getInitialSession();
  Future<UserModel> registerStudent({
    String phone = '',
    required String email,
    String? password,
    required String targetExam,
    required String medium,
    bool termsAgreed = true,
    String? termsAgreedAt,
  });
  Future<UserModel> loginStudent({
    required String phoneOrEmail,
    String? password,
  });
  Future<UserModel> loginStaff({
    required String email,
    required String password,
  });
  Future<void> logout();
  Future<UserModel> updateProfile(UserModel user);
  Future<void> adminSetUserRole({
    required String targetUserId,
    required String newRole,
  });
  Future<void> exchangeCode(String code);
  Future<void> resendConfirmation(String email);
  Future<void> sendPasswordResetEmail(String email);
  Future<void> updateUserPassword(String newPassword);
  Future<void> verifyRecoveryOtpAndSetNewPassword({
    required String email,
    required String token,
    required String newPassword,
  });
  Future<UserModel> updateDisplayName(String newName);
  Future<List<UserModel>> getAllProfiles();
  Future<String> adminCreateTeacher({
    required String email,
    required String password,
    required String fullName,
  });
  Future<List<UserModel>> getBatchStudents(String batchId);
  Future<List<UserModel>> getAllStudents();
  Future<void> adminUpdateStudentProfile(String targetId, String newName);
}

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;

  AuthRepositoryImpl({AuthRemoteDataSource? remoteDataSource})
    : _remoteDataSource = remoteDataSource ?? AuthRemoteDataSourceImpl();

  @override
  bool get isConnected => _remoteDataSource.isConnected;

  @override
  Future<UserModel?> getInitialSession() async {
    try {
      return await _remoteDataSource.getCurrentProfile();
    } catch (e) {
      debugPrint('Error getting initial session: $e');
      return null;
    }
  }

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
    try {
      final formattedEmail = email.isNotEmpty
          ? email.trim()
          : (phone.trim().isNotEmpty
              ? "${phone.trim()}@student.modernclasses.com"
              : "student_${DateTime.now().millisecondsSinceEpoch}@student.modernclasses.com");

      return await _remoteDataSource.signUp(
        email: formattedEmail,
        password: password ?? "Modern@123",
        phone: phone.isNotEmpty ? phone : null,
        targetExam: targetExam,
        medium: medium,
        termsAgreed: termsAgreed,
        termsAgreedAt: termsAgreedAt,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<UserModel> loginStudent({
    required String phoneOrEmail,
    String? password,
  }) async {
    try {
      final formattedEmail = phoneOrEmail.contains('@')
          ? phoneOrEmail.trim()
          : "${phoneOrEmail.trim()}@student.modernclasses.com";

      return await _remoteDataSource.signIn(
        email: formattedEmail,
        password: password ?? "Modern@123",
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<UserModel> loginStaff({
    required String email,
    required String password,
  }) async {
    try {
      return await _remoteDataSource.signIn(
        email: email.trim(),
        password: password,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _remoteDataSource.signOut();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<UserModel> updateProfile(UserModel user) async {
    try {
      return await _remoteDataSource.updateProfile(user);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> adminSetUserRole({
    required String targetUserId,
    required String newRole,
  }) async {
    try {
      await _remoteDataSource.adminSetUserRole(
        targetUserId: targetUserId,
        newRole: newRole,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> exchangeCode(String code) async {
    try {
      await _remoteDataSource.exchangeCode(code);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> resendConfirmation(String email) async {
    try {
      await _remoteDataSource.resendConfirmation(email);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _remoteDataSource.sendPasswordResetEmail(email);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> updateUserPassword(String newPassword) async {
    try {
      await _remoteDataSource.updateUserPassword(newPassword);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> verifyRecoveryOtpAndSetNewPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    try {
      await _remoteDataSource.verifyRecoveryOtpAndSetNewPassword(
        email: email,
        token: token,
        newPassword: newPassword,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<UserModel> updateDisplayName(String newName) async {
    try {
      return await _remoteDataSource.updateDisplayName(newName);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<List<UserModel>> getAllProfiles() async {
    try {
      return await _remoteDataSource.getAllProfiles();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<String> adminCreateTeacher({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      return await _remoteDataSource.adminCreateTeacher(
        email: email,
        password: password,
        fullName: fullName,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<List<UserModel>> getBatchStudents(String batchId) async {
    try {
      return await _remoteDataSource.getBatchStudents(batchId);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<List<UserModel>> getAllStudents() async {
    try {
      return await _remoteDataSource.getAllStudents();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> adminUpdateStudentProfile(
    String targetId,
    String newName,
  ) async {
    try {
      await _remoteDataSource.adminUpdateStudentProfile(targetId, newName);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
