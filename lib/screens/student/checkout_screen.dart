import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_button.dart';
import '../../core/widgets/modern_card.dart';
import '../../models/course_model.dart';
import '../../models/batch_model.dart';
import '../../models/payment_model.dart';
import '../../providers/course_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/utils/google_play_tier_helper.dart';

class CheckoutScreen extends StatefulWidget {
  final CourseModel course;
  final BatchModel batch;

  const CheckoutScreen({super.key, required this.course, required this.batch});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final TextEditingController _couponController = TextEditingController();
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  CouponModel? _appliedCoupon;
  String _selectedPaymentMethod = "Google Play Billing (UPI, Cards, Net Banking)";
  bool _isProcessing = false;
  String? _couponError;

  @override
  void initState() {
    super.initState();
    final purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _handlePurchaseUpdates,
      onDone: () => _subscription?.cancel(),
      onError: (dynamic error) {
        if (mounted) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Purchase stream error: $error"),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _couponController.dispose();
    super.dispose();
  }

  void _applyCoupon(CourseProvider courseProvider) {
    setState(() {
      _couponError = null;
    });

    final code = _couponController.text.trim();
    if (code.isEmpty) return;

    final result = courseProvider.validateCouponDetailed(
      code,
      widget.batch.batchPrice,
      courseId: widget.course.id,
    );
    if (result.isValid && result.coupon != null) {
      final coupon = result.coupon!;
      setState(() {
        _appliedCoupon = coupon;
        _couponError = null;
      });
      final discountMsg = coupon.isFreeCourse
          ? "100% Free Enrollment applied!"
          : "Saved ₹${coupon.calculateDiscount(widget.batch.batchPrice).toInt()}";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "🎉 Coupon '${coupon.code}' applied successfully! $discountMsg",
          ),
          backgroundColor: AppTheme.success,
        ),
      );
    } else {
      setState(() {
        _couponError = result.errorMessage ?? "Invalid or expired coupon code for this course.";
      });
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        if (mounted) {
          setState(() => _isProcessing = true);
        }
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          if (mounted) {
            setState(() => _isProcessing = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  purchaseDetails.error?.message ?? "Purchase failed or was canceled in Google Play.",
                ),
                backgroundColor: AppTheme.error,
              ),
            );
          }
        } else if (purchaseDetails.status == PurchaseStatus.canceled) {
          if (mounted) {
            setState(() => _isProcessing = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Payment was cancelled."),
                backgroundColor: AppTheme.warning,
              ),
            );
          }
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          await _verifyAndEnrollPurchased(purchaseDetails);
        }

        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<void> _verifyAndEnrollPurchased(PurchaseDetails purchaseDetails) async {
    try {
      final courseProvider = context.read<CourseProvider>();
      final realToken = purchaseDetails.verificationData.serverVerificationData;

      final double discount = _appliedCoupon?.calculateDiscount(widget.batch.batchPrice) ?? 0.0;
      final double finalAmount = (widget.batch.batchPrice - discount).clamp(
        0.0,
        double.infinity,
      );

      await courseProvider.processPayment(
        purchaseToken: realToken,
        batchId: widget.batch.id,
        couponCode: _appliedCoupon?.code,
        amountPaid: finalAmount,
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Payment Verified & Enrollment Successful! Welcome to the batch."),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      String friendlyMsg = e.toString().replaceAll("ServerException: ", "").replaceAll("Exception: ", "");
      if (friendlyMsg.contains("pending in console") || friendlyMsg.contains("500")) {
        friendlyMsg = "Google Play purchase verification failed. Ensure billing setup is active in Google Play Console.";
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyMsg),
          backgroundColor: AppTheme.error,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _completePurchase() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });

    try {
      if (!mounted) return;
      final authProvider = context.read<AuthProvider>();
      final courseProvider = context.read<CourseProvider>();

      final user = authProvider.currentUser;
      if (user.id.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Authentication error. Please log in again to purchase.",
            ),
          ),
        );
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      final double discount = _appliedCoupon?.calculateDiscount(widget.batch.batchPrice) ?? 0.0;
      final double finalAmount = (widget.batch.batchPrice - discount).clamp(
        0.0,
        double.infinity,
      );
      if (!mounted) return;

      // SCENARIO 1: Free / 100% Scholarship Bypass
      if (GooglePlayTierHelper.isFreeEnrollment(finalAmount)) {
        await courseProvider.enrollFreeBatch(
          batchId: widget.batch.id,
          couponCode: _appliedCoupon?.code,
        );

        if (!mounted) return;
        setState(() => _isProcessing = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("100% Scholarship / Discount Applied! Free Enrollment Successful."),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.pop(context, true);
        return;
      }

      // SCENARIO 2: Google Play In-App Product Tier
      final storeProductId = GooglePlayTierHelper.resolveProductTier(
        originalPrice: widget.batch.batchPrice,
        finalPayable: finalAmount,
        batchProductId: widget.batch.playProductId,
      );

      final bool isAvailable = await _iap.isAvailable();
      if (!isAvailable) {
        setState(() => _isProcessing = false);
        if (!mounted) return;

        // In debug mode, offer mock fallback for testing without Google Play Services
        if (kDebugMode) {
          _showDebugMockFallbackDialog(storeProductId, finalAmount);
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Google Play Billing is not available on this device."),
            backgroundColor: AppTheme.error,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      final ProductDetailsResponse response = await _iap.queryProductDetails({storeProductId});
      if (response.error != null) {
        setState(() => _isProcessing = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Google Play error: ${response.error!.message}"),
            backgroundColor: AppTheme.error,
          ),
        );
        return;
      }

      if (response.productDetails.isEmpty) {
        setState(() => _isProcessing = false);
        if (!mounted) return;

        if (kDebugMode) {
          _showDebugMockFallbackDialog(storeProductId, finalAmount);
          return;
        }

        _showProductNotFoundDialog(storeProductId);
        return;
      }

      final ProductDetails productDetails = response.productDetails.first;
      final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);

      // Launch genuine Google Play payment sheet
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        String friendlyMsg = e.toString().replaceAll("ServerException: ", "").replaceAll("Exception: ", "");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Payment failed: $friendlyMsg"),
            backgroundColor: AppTheme.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _showProductNotFoundDialog(String productId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceCard : AppTheme.surface,
        title: Text(
          "Product Pending in Google Play Console",
          style: TextStyle(
            color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          "The Google Play in-app product '$productId' was not found.\n\n"
          "To test real money payments:\n"
          "1. Go to Google Play Console > Monetize > In-app products.\n"
          "2. Ensure in-app product '$productId' is created and active.\n"
          "3. Publish an app build (AAB) to an internal or closed testing track.\n"
          "4. Join the testing track with your Google Play tester account.",
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.darkTextSecondary : AppTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK", style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  void _showDebugMockFallbackDialog(String productId, double finalAmount) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceCard : AppTheme.surface,
        title: Text(
          "Debug Mode: Google Play Inactive",
          style: TextStyle(
            color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          "Google Play product '$productId' was not found or Google Play Services is unavailable on this test environment.\n\n"
          "Would you like to simulate payment with a sandbox test token for local development?",
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.darkTextSecondary : AppTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isProcessing = true);
              try {
                final courseProvider = context.read<CourseProvider>();
                final dummyToken = "mockpurchase:$productId:${DateTime.now().millisecondsSinceEpoch}";
                await courseProvider.processPayment(
                  purchaseToken: dummyToken,
                  batchId: widget.batch.id,
                  couponCode: _appliedCoupon?.code,
                  amountPaid: finalAmount,
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Sandbox Enrollment Successful!"),
                    backgroundColor: AppTheme.success,
                  ),
                );
                Navigator.pop(context, true);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Sandbox verification error: $e"),
                    backgroundColor: AppTheme.error,
                  ),
                );
              } finally {
                if (mounted) setState(() => _isProcessing = false);
              }
            },
            child: const Text("Use Sandbox Mock"),
          ),
        ],
      ),
    );
  }


  void _showRefundPolicyDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceCard : AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: isDark ? AppColors.darkBorder : AppTheme.border),
        ),
        title: Text(
          "Refund & Cancellation Policy",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(
              "Modern Classes Patna Refund Guidelines:\n\n"
              "• Digital Access: Batch enrollment grants immediate digital delivery of video lectures, study materials, and tests.\n\n"
              "• Google Play Billing: In-app purchases are subject to Google Play refund policies. Purchases made by mistake can be refunded via Google Play within 48 hours.\n\n"
              "• Technical Failures: For duplicate payments or persistent technical lockouts, contact madhurendrayadav06@gmail.com with your Google Play GPA order ID for resolution within 24-48 hours.\n\n"
              "• Non-Recurring: Single batch enrollments do not auto-renew or charge recurring fees.",
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: isDark ? AppColors.darkTextSecondary : AppTheme.textSecondary,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Understood",
              style: TextStyle(color: AppTheme.primaryDark, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final courseProvider = context.watch<CourseProvider>();
    final double discount = _appliedCoupon?.calculateDiscount(widget.batch.batchPrice) ?? 0.0;
    final double finalAmount = (widget.batch.batchPrice - discount).clamp(
      0.0,
      double.infinity,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text("Batch Enrollment & Checkout")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selected Course & Batch Card
            ModernCard(
              padding: const EdgeInsets.all(16),
              backgroundColor: isDark ? AppColors.darkSurfaceCard : AppTheme.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomBadge(
                    text: widget.course.category,
                    variant: BadgeVariant.primary,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.course.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "${widget.batch.name} (${widget.batch.timing})",
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Coupon Code Section
            Text(
              "Have a Discount Coupon?",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
              ),
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
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
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
            Text(
              "Select Payment Method",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
              ),
            ),
            const SizedBox(height: 10),
            _buildPaymentMethodOption(isDark: isDark, 
              "UPI (Google Pay / PhonePe / Paytm)",
              Icons.account_balance_wallet_outlined,
            ),
            const SizedBox(height: 8),
            _buildPaymentMethodOption(isDark: isDark, 
              "Debit / Credit Card (Visa, RuPay, MasterCard)",
              Icons.credit_card_outlined,
            ),
            const SizedBox(height: 8),
            _buildPaymentMethodOption(isDark: isDark, 
              "Net Banking (SBI, PNB, HDFC, ICICI)",
              Icons.account_balance_outlined,
            ),
            const SizedBox(height: 24),

            // Order Price Breakdown
            ModernCard(
              padding: const EdgeInsets.all(16),
              backgroundColor: isDark ? AppColors.darkSurfaceCard : AppTheme.surfaceCard,
              child: Column(
                children: [
                  _buildPriceRow(isDark: isDark, 
                    "Batch Price",
                    Formatters.formatCurrency(widget.batch.batchPrice),
                  ),
                  if (_appliedCoupon != null) ...[
                    const SizedBox(height: 8),
                    _buildPriceRow(isDark: isDark, 
                      "Coupon Discount (${_appliedCoupon!.code})",
                      _appliedCoupon!.isFreeCourse
                          ? "- ${Formatters.formatCurrency(discount)} (100% Free)"
                          : "- ${Formatters.formatCurrency(discount)}",
                      isDiscount: true,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Divider(color: isDark ? AppColors.darkBorder : AppTheme.border),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Total Payable Amount",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                        ),
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
            const SizedBox(height: 18),

            // Pre-Purchase Instant Delivery & Refund Consent Disclosure
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
              child: Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      "By enrolling, you agree that digital batch access begins immediately. ",
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? AppColors.darkTextSecondary : AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    InkWell(
                      key: const Key('checkout_refund_policy_link'),
                      onTap: () => _showRefundPolicyDialog(context),
                      child: const Text(
                        "Refund Policy",
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryDark,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Pay & Enroll Button (Dynamic Free / Paid Label)
            ModernButton(
              text: finalAmount == 0
                  ? "Claim Free Enrollment Now"
                  : "Pay ${Formatters.formatCurrency(finalAmount)} & Enroll Now",
              width: double.infinity,
              height: 52,
              isLoading: _isProcessing,
              icon: finalAmount == 0 ? Icons.check_circle_outline : Icons.lock_outline,
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
                    "Google Play In-App Billing • 256-Bit Encrypted Database",
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

  Widget _buildPriceRow(String label, String value, {bool isDiscount = false, bool isDark = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.darkTextSecondary : AppTheme.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDiscount ? AppTheme.success : (isDark ? AppColors.darkTextPrimary : AppColors.deepInk),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodOption(String label, IconData icon, {bool isDark = false}) {
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
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.18)
              : (isDark ? AppColors.darkSurfaceCard : AppTheme.surface),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primary : (isDark ? AppColors.darkBorder : AppTheme.border),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppTheme.primary : (isDark ? AppColors.darkTextMuted : AppTheme.textMuted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? AppColors.darkTextPrimary : AppColors.deepInk)
                      : (isDark ? AppColors.darkTextSecondary : AppTheme.textSecondary),
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.radio_button_checked,
                size: 18,
                color: AppTheme.primary,
              )
            else
              Icon(
                Icons.radio_button_off,
                size: 18,
                color: isDark ? AppColors.darkTextMuted : AppTheme.textMuted,
              ),
          ],
        ),
      ),
    );
  }
}
