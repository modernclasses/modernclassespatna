import '../../../core/errors/error_handler.dart';
import '../../../core/services/device_session_service.dart';
import '../../../core/services/push_notification_service.dart';
import 'package:flutter/material.dart';
import '../data/models/user_model.dart';
import '../data/repositories/auth_repository.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository _repository;

  UserModel? _currentUser;
  bool _isAuthenticated = false;
  bool _requiresEmailConfirmation = false;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel get currentUser => _currentUser ?? UserModel.guest;
  bool get isAuthenticated => _isAuthenticated && _currentUser != null;
  bool get requiresEmailConfirmation => _requiresEmailConfirmation;
  bool get hasSessionWithoutProfile => _isAuthenticated && _currentUser == null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  UserRole get currentRole => _currentUser?.role ?? UserRole.student;
  bool get isStudent => _currentUser?.role == UserRole.student;
  bool get isTeacher => _currentUser?.role == UserRole.teacher;
  bool get isAdmin => _currentUser?.role == UserRole.admin;

  AuthProvider({AuthRepository? repository})
    : _repository = repository ?? AuthRepositoryImpl() {
    _initializeSession();
  }

  void _syncPushToken() {
    final token = PushNotificationService.currentFcmToken;
    if (token != null) {
      PushNotificationService.syncTokenWithBackend(token);
    }
  }

  /// Check active session on app startup.
  Future<void> _initializeSession() async {
    if (!_repository.isConnected) return;

    _isLoading = true;
    notifyListeners();

    try {
      final profile = await _repository.getInitialSession();
      if (profile != null) {
        if (profile.role == UserRole.student) {
          final isDeviceValid =
              await DeviceSessionService.validateDeviceSession(profile.id);
          if (!isDeviceValid) {
            await _repository.logout();
            _currentUser = null;
            _isAuthenticated = false;
            _errorMessage =
                "Multiple Device Login: Your account was accessed from another device.";
            return;
          }
        }
        _currentUser = profile;
        _syncPushToken();
        _isAuthenticated = true;
      } else {
        _currentUser = null;
        _isAuthenticated = false;
      }
    } catch (_) {
      _currentUser = null;
      _isAuthenticated = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Student Registration via Supabase Auth
  Future<bool> registerStudent({
    String phone = '',
    required String email,
    String? password,
    String targetExam = '',
    String medium = '',
    bool termsAgreed = true,
    String? termsAgreedAt,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _repository.registerStudent(
        phone: phone,
        email: email,
        password: password,
        targetExam: targetExam,
        medium: medium,
        termsAgreed: termsAgreed,
        termsAgreedAt: termsAgreedAt,
      );

      _currentUser = user;
      _syncPushToken();
      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      final rawMsg = e.toString().replaceAll('Exception:', '').trim();
      if (rawMsg.contains('email_confirmation_required')) {
        _requiresEmailConfirmation = true;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _errorMessage = _formatAuthError(e);
      _currentUser = null;
      _isAuthenticated = false;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Student Sign In
  Future<bool> loginStudent({
    required String phoneOrEmail,
    String? password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _repository.loginStudent(
        phoneOrEmail: phoneOrEmail,
        password: password,
      );

      _currentUser = user;
      _syncPushToken();
      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();
      try {
        await DeviceSessionService.registerDeviceSession(user.id);
        _syncPushToken();
      } catch (_) {}
      return true;
    } catch (e) {
      final rawMsg = e.toString().replaceAll('Exception:', '').trim();
      if (rawMsg.contains('email_confirmation_required')) {
        _requiresEmailConfirmation = true;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _errorMessage = _formatAuthError(e);
      _currentUser = null;
      _isAuthenticated = false;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Staff (Faculty / Administrator) Sign In with Server-Enforced Role Check
  Future<bool> loginStaff({
    required String email,
    required String password,
    required UserRole expectedRole,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _repository.loginStaff(
        email: email,
        password: password,
      );

      // Verify that user possesses the required staff role on the backend
      if (expectedRole == UserRole.admin && user.role != UserRole.admin) {
        await _repository.logout();
        _currentUser = null;
        _isAuthenticated = false;
        _errorMessage =
            "Access Denied: This account does not possess Administrator privileges.";
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (expectedRole == UserRole.teacher &&
          user.role != UserRole.teacher &&
          user.role != UserRole.admin) {
        await _repository.logout();
        _currentUser = null;
        _isAuthenticated = false;
        _errorMessage =
            "Access Denied: This account is not registered as Faculty.";
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _currentUser = user;
      _syncPushToken();
      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      final rawMsg = e.toString().replaceAll('Exception:', '').trim();
      if (rawMsg.contains('email_confirmation_required')) {
        _requiresEmailConfirmation = true;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _errorMessage = _formatAuthError(e);
      _currentUser = null;
      _isAuthenticated = false;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  String _formatAuthError(dynamic e) {
    final msg = e.toString().replaceAll('Exception:', '').trim();
    if (msg.contains('Failed host lookup') ||
        msg.contains('SocketException') ||
        msg.contains('errno = 7') ||
        msg.contains('ClientException with Socket') ||
        msg.contains('Network is unreachable') ||
        msg.contains('Connection refused')) {
      return "No internet connection. Please check your Wi-Fi or mobile data and try again.";
    }
    if (msg.contains('Invalid login credentials')) {
      return "Invalid email or password. Please verify your credentials.";
    }
    if (msg.contains('Email not confirmed')) {
      return "Please confirm your email address before logging in.";
    }
    return msg;
  }

  /// Administrator Role Assignment RPC
  Future<bool> adminSetUserRole({
    required String targetUserId,
    required UserRole newRole,
  }) async {
    if (!isAdmin) {
      _errorMessage = "Unauthorized: Only administrators can assign roles.";
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.adminSetUserRole(
        targetUserId: targetUserId,
        newRole: newRole.name,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      await _repository.logout();
    } catch (_) {}
    _isAuthenticated = false;
    _currentUser = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Update Profile Details
  Future<void> updateProfile({
    required String name,
    required String phone,
    String? bio,
  }) async {
    if (_currentUser == null) return;

    final updated = _currentUser!.copyWith(name: name, phone: phone, bio: bio);
    _currentUser = updated;
    try {
      await _repository.updateProfile(updated);
    } catch (_) {}
    notifyListeners();
  }

  /// Enroll in Batch (updates local session lists for active UI)
  void enrollInBatch(String courseId, String batchId) {
    if (_currentUser == null) return;

    final updatedCourses = List<String>.from(_currentUser!.enrolledCourseIds);
    if (!updatedCourses.contains(courseId)) {
      updatedCourses.add(courseId);
    }
    final updatedBatches = List<String>.from(_currentUser!.enrolledBatchIds);
    if (!updatedBatches.contains(batchId)) {
      updatedBatches.add(batchId);
    }

    _currentUser = _currentUser!.copyWith(
      enrolledCourseIds: updatedCourses,
      enrolledBatchIds: updatedBatches,
    );
    notifyListeners();
  }

  Future<void> retryProfileLoad() async {
    await _initializeSession();
  }

  Future<bool> resendConfirmationEmail(String email) async {
    try {
      await _repository.resendConfirmation(email);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Sends a password reset email to a registered student.
  Future<bool> sendPasswordResetEmail(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.sendPasswordResetEmail(email.trim());
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _formatAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Updates user password when an active recovery session is present (e.g. from deep link).
  Future<bool> updateUserPassword(String newPassword) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.updateUserPassword(newPassword.trim());
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _formatAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Verifies recovery code and sets a new password.
  Future<bool> verifyRecoveryOtpAndSetNewPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.verifyRecoveryOtpAndSetNewPassword(
        email: email.trim(),
        token: token.trim(),
        newPassword: newPassword.trim(),
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _formatAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<List<UserModel>> getAllProfiles() async {
    try {
      return await _repository.getAllProfiles();
    } catch (e) {
      throw Exception('Failed to fetch profiles');
    }
  }

  Future<String> adminCreateTeacher({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      return await _repository.adminCreateTeacher(
        email: email,
        password: password,
        fullName: fullName,
      );
    } catch (e) {
      throw Exception(ErrorHandler.handle(e).message);
    }
  }

  Future<void> processDeepLinkCode(String code) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.exchangeCode(code);
      await _initializeSession();
    } catch (e) {
      _errorMessage = ErrorHandler.handle(e).message;
      _isLoading = false;
      notifyListeners();
      throw Exception(_errorMessage);
    }
  }

  Future<bool> updateDisplayName(String name) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final user = await _repository.updateDisplayName(name);
      _currentUser = user;
      _syncPushToken();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = ErrorHandler.handle(e).message;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<List<UserModel>> getBatchStudents(String batchId) async {
    try {
      return await _repository.getBatchStudents(batchId);
    } catch (e) {
      throw Exception('Failed to fetch batch roster');
    }
  }

  Future<List<UserModel>> getAllStudents() async {
    try {
      return await _repository.getAllStudents();
    } catch (e) {
      _errorMessage = ErrorHandler.handle(e).message;
      throw Exception(_errorMessage);
    }
  }

  Future<void> adminUpdateStudentProfile(
    String targetId,
    String newName,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.adminUpdateStudentProfile(targetId, newName.trim());
    } catch (e) {
      _errorMessage = ErrorHandler.handle(e).message;
      throw Exception(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
