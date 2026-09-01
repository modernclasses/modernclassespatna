import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_button.dart';
import '../../core/widgets/modern_card.dart';
import '../../models/course_model.dart';
import '../../models/batch_model.dart';
import '../../models/payment_model.dart';
import '../../models/notification_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/notification_provider.dart';

class CheckoutScreen extends StatefulWidget {
  final CourseModel course;
  final BatchModel batch;

  const CheckoutScreen({
    super.key,
    required this.course,
    required this.batch,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final TextEditingController _couponController = TextEditingController();
  CouponModel? _appliedCoupon;
  String _selectedPaymentMethod = "UPI (Google Pay / PhonePe)";
  bool _isProcessing = false;
  String? _couponError;

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  void _applyCoupon(CourseProvider courseProvider) {
    setState(() {
      _couponError = null;
    });

    final code = _couponController.text.trim();
    if (code.isEmpty) return;

    final coupon = courseProvider.validateCoupon(code, widget.batch.batchPrice);
    if (coupon != null) {
      setState(() {
        _appliedCoupon = coupon;
        _couponError = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("🎉 Coupon '${coupon.code}' applied successfully! Saved ₹${coupon.discountAmount.toInt()}"),
          backgroundColor: AppTheme.success,
        ),
      );
    } else {
      setState(() {
        _couponError = "Invalid or expired coupon code for this amount.";
      });
    }
  }

  void _completePurchase() async {
    setState(() {
      _isProcessing = true;
    });

    final auth = context.read<AuthProvider>();
    final courseProvider = context.read<CourseProvider>();
    final notifProvider = context.read<NotificationProvider>();

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final txn = courseProvider.processPayment(
      studentId: auth.currentUser.id,
      studentName: auth.currentUser.name,
      course: widget.course,
      batch: widget.batch,
      appliedCoupon: _appliedCoupon,
      paymentMethod: _selectedPaymentMethod,
    );

    // Auto enroll student
    auth.enrollInBatch(widget.course.id, widget.batch.id);

    // Send confirmation notification
    notifProvider.broadcastAnnouncement(
      title: "🎉 Enrollment Successful: ${widget.course.title}",
      message: "You have been enrolled in ${widget.batch.name}. Invoice #${txn.invoiceNumber} has been generated.",
      category: NotificationCategory.payment,
    );

    setState(() {
      _isProcessing = false;
    });

    _showSuccessDialog(context, txn);
  }

  void _showSuccessDialog(BuildContext context, PaymentTransactionModel txn) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppTheme.success,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text(
              "Enrollment Confirmed!",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Welcome to Modern Classes Patna. You now have full access to ${widget.batch.name}.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  _buildReceiptRow("Invoice No", txn.invoiceNumber),
                  const SizedBox(height: 6),
                  _buildReceiptRow("Amount Paid", Formatters.formatCurrency(txn.amountPaid)),
                  const SizedBox(height: 6),
                  _buildReceiptRow("Payment Ref", txn.transactionReference),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ModernButton(
              text: "Start Learning Now",
              width: double.infinity,
              onPressed: () {
                Navigator.pop(dialogCtx); // close dialog
                Navigator.pop(context); // close checkout
                Navigator.pop(context); // back to catalog or batch
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final courseProvider = context.watch<CourseProvider>();
    final double discount = _appliedCoupon?.discountAmount ?? 0.0;
    final double finalAmount = (widget.batch.batchPrice - discount).clamp(0.0, double.infinity);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Batch Enrollment & Checkout"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selected Course & Batch Card
            ModernCard(
              padding: const EdgeInsets.all(16),
              backgroundColor: AppTheme.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomBadge(text: widget.course.category, variant: BadgeVariant.primary),
                  const SizedBox(height: 10),
                  Text(
                    widget.course.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 14, color: AppTheme.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "${widget.batch.name} (${widget.batch.timing})",
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Coupon Code Section
            const Text(
              "Have a Discount Coupon?",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _couponController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: "Enter Code (e.g. PATNA50)",
                      errorText: _couponError,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ModernButton(
                  text: _appliedCoupon != null ? "Applied" : "Apply",
                  height: 48,
                  onPressed: () => _applyCoupon(courseProvider),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              "💡 Tip: Use 'PATNA50' to get ₹200 OFF on any Patna Crash Course",
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 24),

            // Payment Method Selection
            const Text(
              "Select Payment Method",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildPaymentMethodOption(
              "UPI (Google Pay / PhonePe / Paytm)",
              Icons.account_balance_wallet_outlined,
            ),
            const SizedBox(height: 8),
            _buildPaymentMethodOption(
              "Debit / Credit Card (Visa, RuPay, MasterCard)",
              Icons.credit_card_outlined,
            ),
            const SizedBox(height: 8),
            _buildPaymentMethodOption(
              "Net Banking (SBI, PNB, HDFC, ICICI)",
              Icons.account_balance_outlined,
            ),
            const SizedBox(height: 24),

            // Order Price Breakdown
            ModernCard(
              padding: const EdgeInsets.all(16),
              backgroundColor: AppTheme.surfaceCard,
              child: Column(
                children: [
                  _buildPriceRow("Batch Price", Formatters.formatCurrency(widget.batch.batchPrice)),
                  if (_appliedCoupon != null) ...[
                    const SizedBox(height: 8),
                    _buildPriceRow(
                      "Coupon Discount (${_appliedCoupon!.code})",
                      "- ${Formatters.formatCurrency(discount)}",
                      isDiscount: true,
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Divider(color: AppTheme.border),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Total Payable Amount",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        Formatters.formatCurrency(finalAmount),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Pay & Enroll Button
            ModernButton(
              text: "Pay ${Formatters.formatCurrency(finalAmount)} & Enroll Now",
              width: double.infinity,
              height: 52,
              isLoading: _isProcessing,
              icon: Icons.lock_outline,
              onPressed: () => _completePurchase(),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_user, size: 14, color: AppTheme.success),
                  SizedBox(width: 6),
                  Text(
                    "256-Bit SSL Encrypted Razorpay Ready Gateway",
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDiscount ? AppTheme.success : AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodOption(String label, IconData icon) {
    final isSelected = _selectedPaymentMethod == label;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = label;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withValues(alpha: 0.12) : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isSelected ? AppTheme.primary : AppTheme.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.radio_button_checked, size: 18, color: AppTheme.primary)
            else
              const Icon(Icons.radio_button_off, size: 18, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}
