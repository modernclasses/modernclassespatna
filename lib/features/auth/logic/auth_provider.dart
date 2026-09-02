import 'package:flutter/material.dart';
import '../data/models/user_model.dart';
import '../data/repositories/auth_repository.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository _repository;

  UserModel? _currentUser;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel get currentUser => _currentUser ?? UserModel.guest;
  bool get isAuthenticated => _isAuthenticated && _currentUser != null;
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

  /// Check active session on app startup.
  Future<void> _initializeSession() async {
    if (!_repository.isConnected) return;

    _isLoading = true;
    notifyListeners();

    try {
      final profile = await _repository.getInitialSession();
      if (profile != null) {
        _currentUser = profile;
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
    required String name,
    required String phone,
    required String email,
    String? password,
    required String targetExam,
    required String medium,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _repository.registerStudent(
        name: name,
        phone: phone,
        email: email,
        password: password,
        targetExam: targetExam,
        medium: medium,
      );

      _currentUser = user;
      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
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
      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
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
        _errorMessage = "Access Denied: This account does not possess Administrator privileges.";
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
        _errorMessage = "Access Denied: This account is not registered as Faculty.";
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _currentUser = user;
      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      _currentUser = null;
      _isAuthenticated = false;
      _isLoading = false;
      notifyListeners();
      return false;
    }
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
  Future<void> updateProfile({required String name, required String phone, String? bio}) async {
    if (_currentUser == null) return;

    final updated = _currentUser!.copyWith(
      name: name,
      phone: phone,
      bio: bio,
    );
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
}
