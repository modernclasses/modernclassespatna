enum PaymentStatus { success, pending, failed }

class PaymentTransactionModel {
  final String id;
  final String transactionReference;
  final String studentId;
  final String studentName;
  final String courseId;
  final String courseTitle;
  final String batchId;
  final String batchName;
  final double originalAmount;
  final double discountAmount;
  final double amountPaid;
  final String? couponApplied;
  final String paymentMethod; // "UPI / Google Pay", "Debit Card", "Net Banking"
  final PaymentStatus status;
  final DateTime timestamp;
  final String invoiceNumber;

  const PaymentTransactionModel({
    required this.id,
    required this.transactionReference,
    required this.studentId,
    required this.studentName,
    required this.courseId,
    required this.courseTitle,
    required this.batchId,
    required this.batchName,
    required this.originalAmount,
    this.discountAmount = 0.0,
    required this.amountPaid,
    this.couponApplied,
    this.paymentMethod = "UPI / PhonePe",
    required this.status,
    required this.timestamp,
    required this.invoiceNumber,
  });

  factory PaymentTransactionModel.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String? ?? 'success';
    final status = PaymentStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => PaymentStatus.pending,
    );
    final amountPaid = (json['amount_paid'] as num?)?.toDouble() ?? 0.0;

    return PaymentTransactionModel(
      id: json['id'] ?? '',
      invoiceNumber: json['invoice_number'] ?? '',
      transactionReference: json['transaction_reference'] ?? '',
      studentId: json['student_id'] ?? '',
      studentName: json['student_name'] ?? 'Unknown Student',
      courseId: json['course_id'] ?? '',
      courseTitle: json['course_title'] ?? 'Unknown Course',
      // DB doesn't have batch, discount, etc. Providing safe fallback defaults:
      batchId: '',
      batchName: 'N/A',
      originalAmount: amountPaid,
      discountAmount: 0.0,
      amountPaid: amountPaid,
      couponApplied: null,
      paymentMethod: json['payment_method'] ?? 'Unknown',
      status: status,
      timestamp: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}

enum CouponValidationStatus {
  valid,
  notFound,
  inactive,
  minOrderNotMet,
  courseNotEligible,
}

class CouponValidationResult {
  final CouponValidationStatus status;
  final CouponModel? coupon;
  final String? errorMessage;

  const CouponValidationResult({
    required this.status,
    this.coupon,
    this.errorMessage,
  });

  bool get isValid => status == CouponValidationStatus.valid;
}

class CouponModel {
  final String? id;
  final String code; // e.g. "PATNA50", "FREE100"
  final double discountAmount; // e.g. 200 or 100 for 100%
  final String discountType; // 'flat' or 'percentage'
  final double minOrderValue; // e.g. 500 or 0
  final String description;
  final bool isActive;
  /// If empty, coupon is eligible for ALL courses.
  /// If non-empty, contains the list of course IDs this coupon can be redeemed for.
  final List<String> applicableCourseIds;

  const CouponModel({
    this.id,
    required this.code,
    required this.discountAmount,
    this.discountType = 'flat',
    this.minOrderValue = 0,
    required this.description,
    this.isActive = true,
    this.applicableCourseIds = const [],
  });

  /// True if the discount is percentage-based (e.g. 100% off)
  bool get isPercentage => discountType.toLowerCase() == 'percentage';

  /// True if this coupon makes the course 100% Free
  bool get isFreeCourse => (isPercentage && discountAmount >= 100) || (discountAmount >= 99999);

  /// Computes the exact rupee discount applied for a given order amount
  double calculateDiscount(double orderAmount) {
    if (isFreeCourse) return orderAmount;
    if (isPercentage) {
      return (orderAmount * discountAmount / 100.0);
    }
    return discountAmount;
  }

  /// Check whether this coupon is eligible for a particular course.
  /// If [applicableCourseIds] is empty, returns true (eligible for all courses).
  bool isEligibleForCourse(String? courseId) {
    if (applicableCourseIds.isEmpty) return true;
    if (courseId == null) return false;
    return applicableCourseIds.contains(courseId);
  }

  CouponModel copyWith({
    String? id,
    String? code,
    double? discountAmount,
    String? discountType,
    double? minOrderValue,
    String? description,
    bool? isActive,
    List<String>? applicableCourseIds,
  }) {
    return CouponModel(
      id: id ?? this.id,
      code: code ?? this.code,
      discountAmount: discountAmount ?? this.discountAmount,
      discountType: discountType ?? this.discountType,
      minOrderValue: minOrderValue ?? this.minOrderValue,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      applicableCourseIds: applicableCourseIds ?? this.applicableCourseIds,
    );
  }

  factory CouponModel.fromJson(Map<String, dynamic> json) {
    List<String> courseIds = [];
    if (json['applicable_course_ids'] != null) {
      if (json['applicable_course_ids'] is List) {
        courseIds = (json['applicable_course_ids'] as List)
            .map((e) => e.toString())
            .toList();
      }
    }
    return CouponModel(
      id: json['id']?.toString(),
      code: json['code'] ?? '',
      discountAmount: (json['discount_amount'] is num)
          ? (json['discount_amount'] as num).toDouble()
          : 0.0,
      discountType: json['discount_type']?.toString().toLowerCase() ?? 'flat',
      minOrderValue: (json['min_order_value'] is num)
          ? (json['min_order_value'] as num).toDouble()
          : 0.0,
      description: json['description'] ?? '',
      isActive: json['is_active'] ?? true,
      applicableCourseIds: courseIds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'code': code.trim().toUpperCase(),
      'discount_amount': discountAmount,
      'discount_type': discountType,
      'min_order_value': minOrderValue,
      if (description.isNotEmpty) 'description': description,
      'is_active': isActive,
      'applicable_course_ids': applicableCourseIds.isNotEmpty ? applicableCourseIds : null,
    };
  }
}
