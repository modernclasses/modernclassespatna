import 'package:flutter/material.dart';
import '../models/course_model.dart';
import '../models/batch_model.dart';
import '../models/payment_model.dart';
import '../data/mock_data.dart';

class CourseProvider extends ChangeNotifier {
  final List<CourseModel> _courses = List.from(MockData.courses);
  final List<BatchModel> _batches = List.from(MockData.batches);
  final List<VideoLessonModel> _videoLessons = List.from(MockData.videoLessons);
  final List<CouponModel> _coupons = List.from(MockData.availableCoupons);
  final List<PaymentTransactionModel> _transactions = List.from(MockData.transactions);

  String _searchQuery = '';
  String _selectedCategory = 'All';

  List<CourseModel> get courses => _courses;
  List<BatchModel> get batches => _batches;
  List<VideoLessonModel> get videoLessons => _videoLessons;
  List<CouponModel> get coupons => _coupons;
  List<PaymentTransactionModel> get transactions => _transactions;
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

  List<VideoLessonModel> getLessonsForBatch(String batchId) {
    return _videoLessons.where((v) => v.batchId == batchId).toList();
  }

  List<VideoLessonModel> getLessonsForCourse(String courseId) {
    return _videoLessons.where((v) => v.courseId == courseId).toList();
  }

  void updateLessonProgress(String lessonId, double progressPercent, bool isCompleted) {
    final index = _videoLessons.indexWhere((v) => v.id == lessonId);
    if (index != -1) {
      _videoLessons[index] = _videoLessons[index].copyWith(
        progressPercent: progressPercent,
        isCompleted: isCompleted,
      );
      notifyListeners();
    }
  }

  CouponModel? validateCoupon(String code, double orderAmount) {
    try {
      final coupon = _coupons.firstWhere(
        (c) => c.code.toUpperCase() == code.trim().toUpperCase() && c.isActive,
      );
      if (orderAmount >= coupon.minOrderValue) {
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
    final double discount = appliedCoupon?.discountAmount ?? 0.0;
    final double finalAmount = (batch.batchPrice - discount).clamp(0.0, double.infinity);

    final transaction = PaymentTransactionModel(
      id: "txn_${DateTime.now().millisecondsSinceEpoch}",
      transactionReference: "PAY_MCP_${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}",
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
      status: PaymentStatus.success,
      timestamp: DateTime.now(),
      invoiceNumber: "INV-2026-MCP-${_transactions.length + 201}",
    );

    _transactions.insert(0, transaction);
    notifyListeners();
    return transaction;
  }

  // Admin capabilities
  void addCourse(CourseModel course) {
    _courses.insert(0, course);
    notifyListeners();
  }

  void addBatch(BatchModel batch) {
    _batches.add(batch);
    notifyListeners();
  }

  void addVideoLesson(VideoLessonModel lesson) {
    _videoLessons.add(lesson);
    notifyListeners();
  }
}
