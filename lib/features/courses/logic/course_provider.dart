import 'package:flutter/material.dart';
import '../../../../data/mock_data.dart';
import '../../../../models/payment_model.dart';
import '../data/models/course_model.dart';
import '../data/models/batch_model.dart';
import '../data/repositories/course_repository.dart';

class CourseProvider extends ChangeNotifier {
  final CourseRepository _repository;

  List<CourseModel> _courses = List.from(MockData.courses);
  List<BatchModel> _batches = List.from(MockData.batches);
  final List<VideoLessonModel> _videoLessons = List.from(MockData.videoLessons);
  final List<CouponModel> _coupons = List.from(MockData.availableCoupons);
  final List<PaymentTransactionModel> _transactions = List.from(MockData.transactions);

  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  String _selectedCategory = 'All';

  List<CourseModel> get courses => _courses;
  List<BatchModel> get batches => _batches;
  List<VideoLessonModel> get videoLessons => _videoLessons;
  List<CouponModel> get coupons => _coupons;
  List<PaymentTransactionModel> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;

  List<String> get categories {
    final set = {'All'};
    for (var c in _courses) {
      set.add(c.category);
    }
    return set.toList();
  }

  List<CourseModel> get filteredCourses {
    return _courses.where((course) {
      final matchesSearch = course.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          course.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          course.category.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'All' || course.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  CourseProvider({CourseRepository? repository})
      : _repository = repository ?? CourseRepositoryImpl() {
    fetchCatalog();
  }

  /// Asynchronously fetch courses and batches from repository.
  Future<void> fetchCatalog() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetchedCourses = await _repository.getCourses();
      final fetchedBatches = await _repository.getBatches();

      if (fetchedCourses.isNotEmpty) _courses = fetchedCourses;
      if (fetchedBatches.isNotEmpty) _batches = fetchedBatches;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  CourseModel? getCourseById(String id) {
    try {
      return _courses.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  BatchModel? getBatchById(String id) {
    try {
      return _batches.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  List<BatchModel> getBatchesForCourse(String courseId) {
    return _batches.where((b) => b.courseId == courseId).toList();
  }

  List<VideoLessonModel> getVideoLessonsForCourse(String courseId) {
    return _videoLessons.where((l) => l.courseId == courseId).toList();
  }

  List<VideoLessonModel> getLessonsForCourse(String courseId) {
    return getVideoLessonsForCourse(courseId);
  }

  void updateLessonProgress(String lessonId, double progress, [bool? isCompleted]) {
    final index = _videoLessons.indexWhere((l) => l.id == lessonId);
    if (index != -1) {
      final lesson = _videoLessons[index];
      _videoLessons[index] = lesson.copyWith(
        progressPercent: progress,
        isCompleted: isCompleted ?? (progress >= 0.9),
      );
      notifyListeners();
    }
  }

  void addCourse(CourseModel course) {
    _courses.insert(0, course);
    notifyListeners();
  }

  CouponModel? validateCoupon(String code, double amount) {
    final cleanCode = code.trim().toUpperCase();
    try {
      final coupon = _coupons.firstWhere(
        (c) => c.code.toUpperCase() == cleanCode && c.isActive,
      );
      if (amount >= coupon.minOrderValue) {
        return coupon;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  PaymentTransactionModel processPayment({
    required String studentId,
    required String studentName,
    required CourseModel course,
    required BatchModel batch,
    CouponModel? appliedCoupon,
    required String paymentMethod,
  }) {
    double discount = 0.0;
    if (appliedCoupon != null) {
      discount = appliedCoupon.discountAmount;
    }
    final finalAmount = (batch.batchPrice - discount).clamp(0.0, 99999.0);

    final transaction = PaymentTransactionModel(
      id: "txn_${DateTime.now().millisecondsSinceEpoch}",
      transactionReference: "MCP-TXN-${DateTime.now().millisecondsSinceEpoch}",
      studentId: studentId,
      studentName: studentName,
      courseId: course.id,
      courseTitle: course.title,
      batchId: batch.id,
      batchName: batch.name,
      originalAmount: batch.batchPrice,
      discountAmount: discount,
      amountPaid: finalAmount,
      couponApplied: appliedCoupon?.code,
      paymentMethod: paymentMethod,
      timestamp: DateTime.now(),
      status: PaymentStatus.success,
      invoiceNumber: "INV-2026-MCP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}",
    );

    _transactions.insert(0, transaction);
    _repository.enrollInBatch(
      studentId: studentId,
      courseId: course.id,
      batchId: batch.id,
      transactionId: transaction.id,
    );
    notifyListeners();
    return transaction;
  }
}
