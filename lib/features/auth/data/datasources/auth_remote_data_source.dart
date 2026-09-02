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
    required String fullName,
    String? phone,
    String targetExam = "BPSC 71st Civil Services",
    String medium = "Bilingual (Hindi + English)",
  });
  Future<UserModel> signIn({
    required String email,
    required String password,
  });
  Future<void> signOut();
  Future<UserModel> updateProfile(UserModel updatedUser);
  Future<void> adminSetUserRole({
    required String targetUserId,
    required String newRole,
  });
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
    required String fullName,
    String? phone,
    String targetExam = "BPSC 71st Civil Services",
    String medium = "Bilingual (Hindi + English)",
  }) async {
    final client = _supabase;
    if (client == null) {
      throw const ServerException('Backend service is not configured.');
    }

    try {
      final authRes = await client.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        data: {
          'full_name': fullName.trim(),
          'phone': phone?.trim(),
          'target_exam': targetExam,
          'medium': medium,
        },
      );

      if (authRes.user == null) {
        throw const AuthException('Failed to create account. Please check your details.');
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
            name: fullName.trim(),
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
        throw const AuthException('User profile not found. Please contact institute administration.');
      }

      if (!profile.isActive) {
        await client.auth.signOut();
        throw const AuthException('Your account has been deactivated. Please contact administration.');
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
      await client.from('profiles').update({
        'full_name': updatedUser.name,
        'phone': updatedUser.phone,
        'bio': updatedUser.bio,
        'avatar_url': updatedUser.avatarUrl,
        'target_exam': updatedUser.targetExam,
        'medium': updatedUser.medium,
      }).eq('id', updatedUser.id);

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
      await client.rpc('admin_set_user_role', params: {
        'target_user_id': targetUserId,
        'new_role': newRole,
      });
    } catch (e) {
      throw ServerException('Failed to assign user role via server RPC', e);
    }
  }
}
