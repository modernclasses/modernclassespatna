import 'package:flutter/foundation.dart';
import '../../../../core/errors/error_handler.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/user_model.dart';

abstract class AuthRepository {
  bool get isConnected;
  Future<UserModel?> getInitialSession();
  Future<UserModel> registerStudent({
    required String name,
    required String phone,
    required String email,
    String? password,
    required String targetExam,
    required String medium,
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
    required String name,
    required String phone,
    required String email,
    String? password,
    required String targetExam,
    required String medium,
  }) async {
    try {
      final formattedEmail = email.isNotEmpty
          ? email.trim()
          : "${phone.trim()}@student.modernclasses.com";

      return await _remoteDataSource.signUp(
        email: formattedEmail,
        password: password ?? "Modern@123",
        fullName: name,
        phone: phone,
        targetExam: targetExam,
        medium: medium,
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
}
