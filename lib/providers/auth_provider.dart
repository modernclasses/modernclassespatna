import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../data/mock_data.dart';

class AuthProvider extends ChangeNotifier {
  UserModel _currentUser = MockData.currentStudent;
  bool _isAuthenticated = false; // Initially at Portal Gateway

  UserModel get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  UserRole get currentRole => _currentUser.role;

  bool get isStudent => _currentUser.role == UserRole.student;
  bool get isTeacher => _currentUser.role == UserRole.teacher;
  bool get isAdmin => _currentUser.role == UserRole.admin;

  void loginStudent({required String phone, String? password}) {
    // Match existing student or default to Rohan Kumar
    UserModel? matchedStudent;
    try {
      matchedStudent = MockData.allStudents.firstWhere(
        (s) => s.phone == phone || s.email.toLowerCase() == phone.toLowerCase(),
      );
    } catch (_) {
      matchedStudent = MockData.currentStudent;
    }

    _currentUser = matchedStudent;
    _isAuthenticated = true;
    notifyListeners();
  }

  void registerStudent({
    required String name,
    required String phone,
    required String email,
    required String targetExam,
    required String medium,
  }) {
    final newStudent = UserModel(
      id: "std_${DateTime.now().millisecondsSinceEpoch}",
      name: name,
      email: email,
      phone: phone,
      role: UserRole.student,
      enrolledBatchIds: ["batch_101"],
      enrolledCourseIds: ["crs_001"],
      joinedDate: DateTime.now(),
      bio: "Target: $targetExam • Medium: $medium",
    );

    MockData.allStudents.insert(0, newStudent);
    _currentUser = newStudent;
    _isAuthenticated = true;
    notifyListeners();
  }

  bool loginTeacher({required String staffId, required String password}) {
    // Verify faculty credentials
    _currentUser = MockData.teacherUser;
    _isAuthenticated = true;
    notifyListeners();
    return true;
  }

  bool loginAdmin({required String adminId, required String securityPin}) {
    // Verify 6-digit master security PIN (123456)
    if (securityPin.trim() == "123456") {
      _currentUser = MockData.adminUser;
      _isAuthenticated = true;
      notifyListeners();
      return true;
    }
    return false;
  }

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

  void logout() {
    _isAuthenticated = false;
    _currentUser = MockData.currentStudent;
    notifyListeners();
  }

  void updateProfile({required String name, required String phone, String? bio}) {
    _currentUser = _currentUser.copyWith(
      name: name,
      phone: phone,
      bio: bio,
    );
    notifyListeners();
  }

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
