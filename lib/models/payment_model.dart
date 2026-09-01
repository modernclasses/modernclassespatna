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
}

class CouponModel {
  final String code; // e.g. "PATNA50"
  final double discountAmount; // e.g. 200
  final double minOrderValue; // e.g. 500
  final String description;
  final bool isActive;

  const CouponModel({
    required this.code,
    required this.discountAmount,
    this.minOrderValue = 500,
    required this.description,
    this.isActive = true,
  });
}
