import 'package:flutter/material.dart';
import '../../../../data/mock_data.dart';
import '../data/models/user_model.dart';
import '../data/repositories/auth_repository.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository _repository;

  UserModel _currentUser = MockData.currentStudent;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  UserRole get currentRole => _currentUser.role;
  bool get isStudent => _currentUser.role == UserRole.student;
  bool get isTeacher => _currentUser.role == UserRole.teacher;
  bool get isAdmin => _currentUser.role == UserRole.admin;

  AuthProvider({AuthRepository? repository})
      : _repository = repository ?? AuthRepositoryImpl() {
    _initializeSession();
  }

  /// Check active session on app startup.
  Future<void> _initializeSession() async {
    if (!_repository.isConnected) return;

    final profile = await _repository.getInitialSession();
    if (profile != null) {
      _currentUser = profile;
      _isAuthenticated = true;
      notifyListeners();
    }
  }

  /// Student Registration via Supabase or Local Mock
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
      _errorMessage = e.toString();
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
      // Fallback to local mock if offline or credentials mismatch
      UserModel? matchedStudent;
      try {
        matchedStudent = MockData.allStudents.firstWhere(
          (s) => s.phone == phoneOrEmail || s.email.toLowerCase() == phoneOrEmail.toLowerCase(),
        );
      } catch (_) {
        matchedStudent = MockData.currentStudent;
      }

      _currentUser = matchedStudent;
      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();
      return true;
    }
  }

  /// Faculty Login
  Future<bool> loginTeacher({
    required String staffId,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _repository.loginTeacher(
        staffId: staffId,
        password: password,
      );

      _currentUser = user.copyWith(role: UserRole.teacher);
      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (_) {
      // Fallback demo faculty login
      _currentUser = MockData.teacherUser;
      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();
      return true;
    }
  }

  /// Master Admin PIN Login
  bool loginAdmin({required String adminId, required String securityPin}) {
    if (securityPin.trim() == "123456" || securityPin.trim() == "000000") {
      _currentUser = MockData.adminUser;
      _isAuthenticated = true;
      _errorMessage = null;
      notifyListeners();
      return true;
    }
    _errorMessage = "Invalid Master Security PIN. Please enter the authorized 6-digit PIN.";
    notifyListeners();
    return false;
  }

  /// Switch user role (demo & testing utility)
  void switchRole(UserRole role) {
    switch (role) {
      case UserRole.student:
        _currentUser = MockData.currentStudent;
        break;
      case UserRole.teacher:
        _currentUser = MockData.teacherUser;
        break;
      case UserRole.admin:
        _currentUser = MockData.adminUser;
        break;
    }
    _isAuthenticated = true;
    notifyListeners();
  }

  /// Logout
  Future<void> logout() async {
    try {
      await _repository.logout();
    } catch (_) {
      // Ignore logout errors
    }
    _isAuthenticated = false;
    _currentUser = MockData.currentStudent;
    _errorMessage = null;
    notifyListeners();
  }

  /// Update Profile Details
  Future<void> updateProfile({required String name, required String phone, String? bio}) async {
    final updated = _currentUser.copyWith(
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

  /// Enroll in Batch
  void enrollInBatch(String courseId, String batchId) {
    final updatedCourses = List<String>.from(_currentUser.enrolledCourseIds);
    if (!updatedCourses.contains(courseId)) {
      updatedCourses.add(courseId);
    }
    final updatedBatches = List<String>.from(_currentUser.enrolledBatchIds);
    if (!updatedBatches.contains(batchId)) {
      updatedBatches.add(batchId);
    }

    _currentUser = _currentUser.copyWith(
      enrolledCourseIds: updatedCourses,
      enrolledBatchIds: updatedBatches,
    );
    notifyListeners();
  }
}
