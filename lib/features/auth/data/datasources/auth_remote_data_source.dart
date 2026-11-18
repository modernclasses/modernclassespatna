import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import '../../../../core/config/app_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  bool get isConnected;
  Stream<AuthState>? get authStateChanges;
  User? get currentAuthUser;
  Future<UserModel?> getCurrentProfile();
  Future<UserModel> signUp({
    required String email,
    required String password,
    String? phone,
    String targetExam = "",
    String medium = "",
    bool termsAgreed = true,
    String? termsAgreedAt,
  });
  Future<UserModel> signIn({required String email, required String password});
  Future<void> signOut();
  Future<UserModel> updateProfile(UserModel updatedUser);
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

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  SupabaseClient? get _supabase {
    if (!AppConfig.isSupabaseConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  bool get isConnected => _supabase != null;

  @override
  Stream<AuthState>? get authStateChanges => _supabase?.auth.onAuthStateChange;

  @override
  User? get currentAuthUser => _supabase?.auth.currentUser;

  @override
  Future<UserModel?> getCurrentProfile() async {
    final client = _supabase;
    if (client == null) {
      throw const ServerException('Backend service is not configured.');
    }

    final authUser = client.auth.currentUser;
    if (authUser == null) {
      return null;
    }

    try {
      final response = await client
          .from('profiles')
          .select()
          .eq('id', authUser.id)
          .maybeSingle();

      if (response != null) {
        return UserModel.fromMap(response);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching user profile from Supabase: $e');
      throw ServerException('Failed to load user profile from database', e);
    }
  }

  @override
  Future<UserModel> signUp({
    required String email,
    required String password,
    String? phone,
    String targetExam = "",
    String medium = "",
    bool termsAgreed = true,
    String? termsAgreedAt,
  }) async {
    final client = _supabase;
    if (client == null) {
      throw const ServerException('Backend service is not configured.');
    }

    try {
      final authRes = await client.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        emailRedirectTo: 'modernclasses://login-callback',
        data: {
          'phone': phone?.trim(),
          'target_exam': targetExam,
          'medium': medium,
          'terms_agreed': termsAgreed,
          'terms_agreed_at': termsAgreedAt ?? DateTime.now().toUtc().toIso8601String(),
        },
      );

      if (authRes.user == null) {
        throw const AuthException(
          'Failed to create account. Please check your details.',
        );
      }
      if (authRes.session == null) {
        throw const AuthException('email_confirmation_required');
      }

      // Fetch the trigger-created profile from public.profiles
      // Retry up to 3 times to allow trigger execution
      UserModel? profile;
      for (int i = 0; i < 3; i++) {
        await Future.delayed(const Duration(milliseconds: 300));
        profile = await getCurrentProfile();
        if (profile != null) break;
      }

      return profile ??
          UserModel(
            id: authRes.user!.id,
            name: '',
            email: email.trim().toLowerCase(),
            phone: phone?.trim() ?? '',
            role: UserRole.student,
            targetExam: targetExam,
            medium: medium,
            joinedDate: DateTime.now(),
          );
    } catch (e) {
      if (e is AppException) rethrow;
      throw AuthException(e.toString().replaceAll('Exception:', '').trim());
    }
  }

  @override
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    final client = _supabase;
    if (client == null) {
      throw const ServerException('Backend service is not configured.');
    }

    try {
      final authRes = await client.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      if (authRes.user == null) {
        throw const AuthException('Invalid email or password.');
      }

      final profile = await getCurrentProfile();
      if (profile == null) {
        throw const AuthException(
          'User profile not found. Please contact institute administration.',
        );
      }

      if (!profile.isActive) {
        await client.auth.signOut();
        throw const AuthException(
          'Your account has been deactivated. Please contact administration.',
        );
      }

      return profile;
    } catch (e) {
      if (e is AppException) rethrow;
      throw AuthException(e.toString().replaceAll('Exception:', '').trim());
    }
  }

  @override
  Future<void> signOut() async {
    final client = _supabase;
    if (client != null) {
      try {
        await client.auth.signOut();
      } catch (e) {
        throw ServerException('Failed to sign out session', e);
      }
    }
  }

  @override
  Future<UserModel> updateProfile(UserModel updatedUser) async {
    final client = _supabase;
    if (client == null) {
      throw const ServerException('Backend service is not configured.');
    }

    try {
      // Send only safe, allowed fields to profiles table
      await client
          .from('profiles')
          .update({
            'full_name': updatedUser.name,
            'phone': updatedUser.phone,
            'bio': updatedUser.bio,
            'avatar_url': updatedUser.avatarUrl,
            'target_exam': updatedUser.targetExam,
            'medium': updatedUser.medium,
          })
          .eq('id', updatedUser.id);

      return updatedUser;
    } catch (e) {
      throw ServerException('Failed to update profile details', e);
    }
  }

  @override
  Future<void> adminSetUserRole({
    required String targetUserId,
    required String newRole,
  }) async {
    final client = _supabase;
    if (client == null) {
      throw const ServerException('Backend service is not configured.');
    }

    try {
      await client.rpc(
        'admin_set_user_role',
        params: {'target_user_id': targetUserId, 'new_role': newRole},
      );
    } catch (e) {
      throw ServerException('Failed to assign user role via server RPC', e);
    }
  }

  @override
  Future<void> exchangeCode(String code) async {
    final client = _supabase;
    if (client == null) throw const ServerException('Backend not configured');
    if (client.auth.currentSession != null) return;
    try {
      await client.auth.exchangeCodeForSession(code);
    } catch (e) {
      if (client.auth.currentSession != null) return;
      throw AuthException(e.toString().replaceAll('Exception:', '').trim());
    }
  }

  @override
  Future<void> resendConfirmation(String email) async {
    final client = _supabase;
    if (client == null) throw const ServerException('Backend not configured');
    try {
      await client.auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: 'modernclasses://login-callback',
      );
    } catch (e) {
      throw AuthException(e.toString().replaceAll('Exception:', '').trim());
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    final client = _supabase;
    if (client == null) throw const ServerException('Backend not configured');
    try {
      await client.auth.resetPasswordForEmail(
        email.trim().toLowerCase(),
        redirectTo: AppConfig.passwordResetRedirectUrl,
      );
    } catch (e) {
      throw AuthException(e.toString().replaceAll('Exception:', '').trim());
    }
  }

  @override
  Future<void> updateUserPassword(String newPassword) async {
    final client = _supabase;
    if (client == null) throw const ServerException('Backend not configured');
    try {
      await client.auth.updateUser(
        UserAttributes(password: newPassword.trim()),
      );
      try {
        await client.auth.signOut();
      } catch (_) {}
    } catch (e) {
      throw AuthException(e.toString().replaceAll('Exception:', '').trim());
    }
  }

  @override
  Future<void> verifyRecoveryOtpAndSetNewPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    final client = _supabase;
    if (client == null) throw const ServerException('Backend not configured');
    try {
      final res = await client.auth.verifyOTP(
        email: email.trim().toLowerCase(),
        token: token.trim(),
        type: OtpType.recovery,
      );
      if (res.user == null) {
        throw const AuthException('Invalid or expired verification code.');
      }
      await client.auth.updateUser(
        UserAttributes(password: newPassword.trim()),
      );
    } catch (e) {
      throw AuthException(e.toString().replaceAll('Exception:', '').trim());
    }
  }

  @override
  Future<UserModel> updateDisplayName(String newName) async {
    final client = _supabase;
    if (client == null) throw const ServerException('Backend not configured');
    try {
      await client.functions.invoke(
        'student_update_display_name',
        body: {'new_name': newName.trim()},
      );

      final userResponse = await client
          .from('profiles')
          .select()
          .eq('id', client.auth.currentUser!.id)
          .single();
      return UserModel.fromMap(userResponse);
    } catch (e) {
      throw AuthException(e.toString().replaceAll('Exception:', '').trim());
    }
  }

  @override
  Future<List<UserModel>> getAllProfiles() async {
    final client = _supabase;
    if (client == null) throw const ServerException('Backend not configured');
    try {
      final response = await client.from('profiles').select();
      return (response as List)
          .map((item) => UserModel.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ServerException('Failed to fetch profiles', e);
    }
  }

  @override
  Future<String> adminCreateTeacher({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final client = _supabase;
    if (client == null) throw const ServerException('Backend not configured');

    // Ensure session is active and fresh before invoking admin edge function
    final session = client.auth.currentSession;
    if (session == null) {
      throw const ServerException(
        'Your administrator session has expired. Please sign out and sign back in.',
      );
    }

    if (session.isExpired) {
      try {
        await client.auth.refreshSession();
      } catch (_) {
        throw const ServerException(
          'Your administrator session has expired. Please sign out and sign back in.',
        );
      }
    }

    final freshToken = client.auth.currentSession?.accessToken ?? session.accessToken;

    try {
      final response = await client.functions.invoke(
        'admin_create_teacher',
        headers: {
          'Authorization': 'Bearer $freshToken',
        },
        body: {
          'email': email.trim().toLowerCase(),
          'password': password,
          'fullName': fullName.trim(),
        },
      );
      if (response.status != 200) {
        final data = response.data;
        final errorMsg = data is Map ? (data['error'] ?? 'Failed to create teacher account') : 'Failed to create teacher account';
        throw ServerException(errorMsg.toString());
      }
      final data = response.data;
      if (data is Map && data['userId'] != null) {
        return data['userId'].toString();
      }
      return 'Teacher account created successfully';
    } catch (e) {
      if (e is ServerException) rethrow;
      if (e is FunctionException) {
        dynamic details = e.details;
        if (details is String && details.trim().isNotEmpty) {
          try {
            details = jsonDecode(details.trim());
          } catch (_) {}
        }
        if (details is Map && details['error'] != null) {
          final serverError = details['error'].toString();
          if (serverError.toLowerCase().contains('invalid format') ||
              serverError.toLowerCase().contains('email')) {
            throw const ServerException(
              'Invalid email format. Please provide a complete email with domain like faculty@gmail.com or faculty@modernclasses.in.',
            );
          }
          if (serverError.toLowerCase().contains('already') ||
              serverError.toLowerCase().contains('exists')) {
            throw const ServerException(
              'An account with this email address already exists. Please use a different email.',
            );
          }
          if (serverError.toLowerCase().contains('forbidden') ||
              serverError.toLowerCase().contains('admin')) {
            throw const ServerException(
              'Administrator privileges required. Please sign out and sign in again with your admin account.',
            );
          }
          throw ServerException(serverError);
        }
        if (details is String && details.trim().isNotEmpty) {
          throw ServerException(details.trim());
        }
        throw ServerException(
          'Teacher account creation failed (${e.status}): ${e.reasonPhrase ?? 'Server error'}',
        );
      }
      throw ServerException(
        e.toString().replaceAll('Exception:', '').replaceAll('ServerException:', '').trim(),
        e,
      );
    }
  }

  @override
  Future<List<UserModel>> getBatchStudents(String batchId) async {
    final client = _supabase;
    if (client == null) throw const ServerException('Backend not configured');
    try {
      final response = await client.from('profiles').select().contains(
        'enrolled_batch_ids',
        [batchId],
      );
      return (response as List)
          .map((item) => UserModel.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ServerException('Failed to fetch batch roster', e);
    }
  }

  @override
  Future<List<UserModel>> getAllStudents() async {
    final client = _supabase;
    if (client == null) throw const ServerException('Backend not configured');
    try {
      final response = await client
          .from('profiles')
          .select()
          .or('role.eq.student,role.is.null')
          .order('created_at', ascending: false);
      return (response as List)
          .map((item) => UserModel.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ServerException('Failed to fetch all students', e);
    }
  }

  @override
  Future<void> adminUpdateStudentProfile(
    String targetId,
    String newName,
  ) async {
    final client = _supabase;
    if (client == null) throw const ServerException('Backend not configured');
    try {
      final verify = await client
          .from('profiles')
          .select('role')
          .eq('id', targetId)
          .single();
      if (verify['role'] != 'student') {
        throw const ServerException('Target user is not a student');
      }
      await client
          .from('profiles')
          .update({'full_name': newName})
          .eq('id', targetId)
          .eq('role', 'student');
    } catch (e) {
      throw ServerException('Failed to update student profile', e);
    }
  }
}
