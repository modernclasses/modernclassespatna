import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/app_config.dart';
import '../../models/user_model.dart';
import '../mock_data.dart';

/// Production Authentication & Profile Management Service using Supabase.
///
/// Automatically falls back to offline mock mode if Supabase is not yet configured,
/// ensuring a zero-crash developer experience.
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  SupabaseClient? get _supabase {
    if (!AppConfig.isSupabaseConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  bool get isConnectedToSupabase => _supabase != null;

  /// Stream of Supabase Auth state changes.
  Stream<AuthState>? get onAuthStateChange => _supabase?.auth.onAuthStateChange;

  /// Current raw Supabase Auth user.
  User? get currentAuthUser => _supabase?.auth.currentUser;

  /// Fetch full user profile from PostgreSQL `public.profiles` table.
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
      return null;
    }
  }

  /// Sign Up with Email & Password.
  Future<UserModel> signUpWithEmail({
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
      throw Exception('Failed to create student account. Please verify details.');
    }

    // Ensure profile row exists
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
  }

  /// Sign In with Email & Password.
  Future<UserModel> signInWithEmail({
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

    final authRes = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (authRes.user == null) {
      throw Exception('Invalid email or password.');
    }

    final profile = await getCurrentProfile();
    if (profile == null) {
      throw Exception('User profile not found. Please contact institute administration.');
    }

    return profile;
  }

  /// Sign Out of active session.
  Future<void> signOut() async {
    final client = _supabase;
    if (client != null) {
      await client.auth.signOut();
    }
  }

  /// Update Profile details in Supabase.
  Future<UserModel> updateProfile(UserModel updatedUser) async {
    final client = _supabase;
    if (client != null) {
      await client
          .from('profiles')
          .update(updatedUser.toMap())
          .eq('id', updatedUser.id);
    }
    return updatedUser;
  }
}
