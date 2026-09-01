import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import '../../../../core/config/app_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/user_model.dart';
import '../../../../data/mock_data.dart';

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
    final authUser = client?.auth.currentUser;

    if (client == null || authUser == null) {
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
      } else {
        // Fallback: Create initial profile record if trigger didn't fire
        final newProfile = UserModel(
          id: authUser.id,
          name: authUser.userMetadata?['full_name'] ?? 'Student Aspirant',
          email: authUser.email ?? '',
          phone: authUser.userMetadata?['phone'] ?? '',
          role: UserRole.student,
          joinedDate: DateTime.now(),
        );
        await client.from('profiles').upsert(newProfile.toMap());
        return newProfile;
      }
    } catch (e) {
      debugPrint('Error fetching Supabase user profile: $e');
      throw ServerException('Failed to fetch profile from cloud database', e);
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
      // Mock Fallback
      return UserModel(
        id: "mock-${DateTime.now().millisecondsSinceEpoch}",
        name: fullName,
        email: email,
        phone: phone ?? "9876543210",
        role: UserRole.student,
        targetExam: targetExam,
        medium: medium,
        joinedDate: DateTime.now(),
      );
    }

    try {
      final authRes = await client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'phone': phone,
          'role': 'student',
          'target_exam': targetExam,
          'medium': medium,
        },
      );

      if (authRes.user == null) {
        throw const AuthException('Failed to create account. Please check credentials.');
      }

      final profile = UserModel(
        id: authRes.user!.id,
        name: fullName,
        email: email,
        phone: phone ?? '',
        role: UserRole.student,
        targetExam: targetExam,
        medium: medium,
        joinedDate: DateTime.now(),
      );

      await client.from('profiles').upsert(profile.toMap());
      return profile;
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
      // Mock Fallback if Supabase not configured
      if (email.contains('admin')) return MockData.adminUser;
      if (email.contains('teacher') || email.contains('faculty') || email.contains('tch')) return MockData.teacherUser;
      return MockData.currentStudent;
    }

    try {
      final authRes = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (authRes.user == null) {
        throw const AuthException('Invalid login credentials.');
      }

      final profile = await getCurrentProfile();
      if (profile == null) {
        throw const AuthException('User profile not found. Please contact administration.');
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
    if (client != null) {
      try {
        await client
            .from('profiles')
            .update(updatedUser.toMap())
            .eq('id', updatedUser.id);
      } catch (e) {
        throw ServerException('Failed to update profile details', e);
      }
    }
    return updatedUser;
  }
}
