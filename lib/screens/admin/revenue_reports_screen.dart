import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_card.dart';
import '../../providers/course_provider.dart';
import '../../models/payment_model.dart';
import '../../features/courses/data/models/course_model.dart';
import '../../core/widgets/stepped_price_input_field.dart';

class RevenueReportsScreen extends StatefulWidget {
  const RevenueReportsScreen({super.key});

  @override
  State<RevenueReportsScreen> createState() => _RevenueReportsScreenState();
}

class _RevenueReportsScreenState extends State<RevenueReportsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<CourseProvider>();
      provider.fetchAdminManualCollectionsTotal();
      provider.fetchAdminLedger(refresh: true);
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<CourseProvider>().fetchAdminLedger();
    }
  }

  @override
  Widget build(BuildContext context) {
    final courseProvider = context.watch<CourseProvider>();
    final transactions = courseProvider.adminLedger;
    final coupons = courseProvider.coupons;

    final totalCollections = courseProvider.adminManualCollectionsTotal;
    final netCollections = courseProvider.adminNetCollectionsTotal;
    final googleCommission = courseProvider.adminGoogleCommissionTotal;
    final totalDiscounts = transactions.fold<double>(
      0,
      (sum, t) => sum + t.discountAmount,
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text("Revenue, Sales & Reports")),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (courseProvider.ledgerError != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                color: AppTheme.error.withValues(alpha: 0.1),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: AppTheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        courseProvider.ledgerError!,
                        style: const TextStyle(color: AppTheme.error),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          courseProvider.fetchAdminLedger(refresh: true),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            // Revenue Cards
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ModernCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                      hasGlow: true,
                      glowColor: AppTheme.primary.withValues(alpha: 0.2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.currency_rupee,
                            color: AppTheme.primary,
                            size: 18,
                          ),
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              netCollections != null
                                  ? Formatters.formatCurrencyWithDecimals(netCollections)
                                  : "--",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Net Collections (-15%)",
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                              ),
                            ),
                          ),
                          if (totalCollections != null && totalCollections > 0) ...[
                            const SizedBox(height: 1),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Gross: ${Formatters.formatCurrency(totalCollections)}",
                                style: TextStyle(
                                  fontSize: 9.0,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ModernCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.confirmation_number_outlined,
                            color: AppTheme.success,
                            size: 18,
                          ),
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "${transactions.length}",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.success,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Total Invoices",
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ModernCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.discount_outlined,
                            color: AppTheme.warning,
                            size: 18,
                          ),
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              Formatters.formatCurrency(totalDiscounts),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.warning,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Coupons Redeemed",
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (totalCollections != null && totalCollections > 0) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? AppColors.primary.withValues(alpha: 0.3)
                        : const Color(0xFFBBF7D0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(Icons.verified_outlined, size: 16, color: AppTheme.success),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Google Play Billing Payout Breakdown (15% Tier)",
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : const Color(0xFF14532D),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          "Gross: ${Formatters.formatCurrency(totalCollections)}",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF166534),
                          ),
                        ),
                        Text(
                          "• Fee (15%): -${Formatters.formatCurrencyWithDecimals(googleCommission ?? 0.0)}",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppColors.darkTextMuted : const Color(0xFF15803D),
                          ),
                        ),
                        Text(
                          "• Net Payout: ${Formatters.formatCurrencyWithDecimals(netCollections ?? 0.0)}",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.primaryLight : const Color(0xFF166534),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Active Discount Coupons Header & Action
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Text(
                  "Active Promotional Coupons",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showCreateCouponDialog(context, courseProvider),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text(
                    "Create Coupon",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (coupons.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                ),
                child: Column(
                  children: [
                    Icon(Icons.discount_outlined, size: 36, color: AppTheme.textMuted),
                    const SizedBox(height: 8),
                    const Text(
                      "No active promotional coupons",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Tap '+ Create Coupon' above to add custom discounts for students.",
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: coupons.map((c) {
                  final isUniversal = c.applicableCourseIds.isEmpty;
                  final eligibleCourses = isUniversal
                      ? <CourseModel>[]
                      : courseProvider.courses
                          .where((crs) => c.applicableCourseIds.contains(crs.id))
                          .toList();

                  return Container(
                    width: MediaQuery.of(context).size.width > 700
                        ? 340
                        : double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: CustomBadge(
                                text: c.code,
                                variant: BadgeVariant.primary,
                                fontSize: 12,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  key: Key('edit_coupon_${c.code}'),
                                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primary),
                                  tooltip: "Edit Coupon & Eligible Courses",
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _showEditCouponDialog(context, courseProvider, c),
                                ),
                                IconButton(
                                  key: Key('delete_coupon_${c.code}'),
                                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.error),
                                  tooltip: "Delete Coupon",
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _confirmDeleteCoupon(context, courseProvider, c.code),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              c.isFreeCourse
                                  ? "100% FREE"
                                  : (c.isPercentage
                                      ? "Save ${c.discountAmount.toInt()}%"
                                      : "Save ₹${c.discountAmount.toInt()}"),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: c.isFreeCourse
                                    ? AppTheme.success
                                    : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkSurface : AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                c.isFreeCourse
                                    ? "Full Scholarship (₹0)"
                                    : "Min Order: ₹${c.minOrderValue.toInt()}",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: c.isFreeCourse
                                      ? AppTheme.success
                                      : (isDark ? AppColors.darkTextMuted : AppTheme.textMuted),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Course Eligibility Display
                        Row(
                          children: [
                            Icon(
                              isUniversal ? Icons.public : Icons.school_outlined,
                              size: 14,
                              color: isUniversal ? AppTheme.success : AppTheme.primary,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                isUniversal
                                    ? "Eligible for: All Courses"
                                    : "Eligible for (${c.applicableCourseIds.length} ${c.applicableCourseIds.length == 1 ? 'course' : 'courses'}):",
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: isUniversal ? AppTheme.success : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!isUniversal) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: eligibleCourses.isNotEmpty
                                ? eligibleCourses.map((crs) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                                      ),
                                      child: Text(
                                        crs.title,
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                    );
                                  }).toList()
                                : [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppTheme.error.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        "No courses currently linked",
                                        style: TextStyle(fontSize: 10, color: AppTheme.error),
                                      ),
                                    ),
                                  ],
                          ),
                        ],
                        if (c.description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            c.description,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 24),

            // Transaction Ledger
            const Text(
              "Recent Student Transactions Ledger",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: transactions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final txn = transactions[index];
                return ModernCard(
                  padding: const EdgeInsets.all(14),
                  backgroundColor: AppTheme.surface,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: AppTheme.success,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${txn.studentName} (${txn.invoiceNumber})",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "${txn.courseTitle} • ${txn.batchName}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Method: ${txn.paymentMethod} • ${Formatters.formatDate(txn.timestamp)}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 100),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            Formatters.formatCurrencyWithDecimals(txn.amountPaid),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (courseProvider.isLoadingLedger)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  void _showCreateCouponDialog(
    BuildContext context,
    CourseProvider courseProvider,
  ) {
    _showCouponEditorDialog(
      context: context,
      courseProvider: courseProvider,
      existingCoupon: null,
    );
  }

  void _showEditCouponDialog(
    BuildContext context,
    CourseProvider courseProvider,
    CouponModel coupon,
  ) {
    _showCouponEditorDialog(
      context: context,
      courseProvider: courseProvider,
      existingCoupon: coupon,
    );
  }

  void _showCouponEditorDialog({
    required BuildContext context,
    required CourseProvider courseProvider,
    CouponModel? existingCoupon,
  }) {
    final formKey = GlobalKey<FormState>();
    final isEditing = existingCoupon != null;
    final codeController = TextEditingController(text: existingCoupon?.code ?? '');
    final discountController = TextEditingController(
      text: existingCoupon != null ? existingCoupon.discountAmount.toInt().toString() : '',
    );
    final minOrderController = TextEditingController(
      text: existingCoupon != null ? existingCoupon.minOrderValue.toInt().toString() : '500',
    );
    final descController = TextEditingController(text: existingCoupon?.description ?? '');

    bool allCoursesSelected = existingCoupon == null ? true : existingCoupon.applicableCourseIds.isEmpty;
    bool is100PercentFree = existingCoupon?.isFreeCourse ?? false;
    final List<String> selectedCourseIds = existingCoupon != null
        ? List<String>.from(existingCoupon.applicableCourseIds)
        : <String>[];
    String? courseSelectionError;

    showDialog(
      context: context,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            int getMaxAllowedDiscount() {
              if (!allCoursesSelected && selectedCourseIds.isNotEmpty) {
                final selectedCourses = courseProvider.courses
                    .where((c) => selectedCourseIds.contains(c.id))
                    .toList();
                if (selectedCourses.isNotEmpty) {
                  final minP = selectedCourses.map((c) => c.price).reduce((a, b) => a < b ? a : b);
                  return minP.toInt().clamp(10, 3199);
                }
              }
              return 3199;
            }

            final maxDiscount = getMaxAllowedDiscount();

            // Auto-clamp discount if selected course limit is lower
            final currentDiscount = int.tryParse(discountController.text.replaceAll('₹', '').trim());
            if (currentDiscount != null && currentDiscount > maxDiscount) {
              discountController.text = maxDiscount.toString();
            }

            return AlertDialog(
              backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isEditing ? Icons.edit_note_rounded : Icons.discount_rounded,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEditing ? "Edit Coupon (${existingCoupon.code})" : "Create Coupon",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width > 600 ? 500 : double.maxFinite,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Coupon Code",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: codeController,
                          enabled: !isEditing, // Code is immutable once created
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            hintText: "e.g. DIWALI300, NEET2026",
                            isDense: true,
                            border: const OutlineInputBorder(),
                            helperText: isEditing ? "Coupon code cannot be renamed" : null,
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return "Please enter a coupon code";
                            }
                            if (val.trim().length < 3) {
                              return "Code must be at least 3 characters";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        // 100% Free / Full Scholarship Switch
                        Container(
                          decoration: BoxDecoration(
                            color: is100PercentFree
                                ? AppTheme.success.withValues(alpha: 0.12)
                                : (isDark ? AppColors.darkSurface : AppColors.surfaceMuted),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: is100PercentFree ? AppTheme.success : (isDark ? AppColors.darkBorder : AppColors.border),
                              width: 1.5,
                            ),
                          ),
                          child: SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            value: is100PercentFree,
                            activeThumbColor: AppTheme.success,
                            title: Row(
                              children: [
                                Icon(
                                  Icons.card_giftcard_rounded,
                                  size: 20,
                                  color: is100PercentFree ? AppTheme.success : AppTheme.primary,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  "100% Free / Full Scholarship",
                                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              is100PercentFree
                                  ? "Selected course(s) will be completely ₹0 (FREE) for students."
                                  : "Toggle to grant 100% free enrollment.",
                              style: TextStyle(
                                fontSize: 11,
                                color: is100PercentFree
                                    ? AppTheme.success
                                    : (isDark ? AppColors.darkTextSecondary : AppTheme.textSecondary),
                              ),
                            ),
                            onChanged: (val) {
                              setDialogState(() {
                                is100PercentFree = val;
                                if (is100PercentFree) {
                                  discountController.text = "100";
                                  minOrderController.text = "0";
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (is100PercentFree) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.success.withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 20),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "100% Discount Active: Students using this coupon pay ₹0.00 and enroll instantly without payment.",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.success,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          SteppedPriceInputField(
                            controller: discountController,
                            labelText: "Discount (₹) *",
                            isCoursePrice: false,
                            minPrice: 10,
                            maxPrice: maxDiscount,
                            step: 10,
                            helperText: !allCoursesSelected && selectedCourseIds.isNotEmpty
                                ? "Max limit for selected course(s): ₹$maxDiscount"
                                : "Universal coupon (Max: ₹$maxDiscount)",
                            validator: (val) {
                              if (is100PercentFree) return null;
                              if (val == null || val.trim().isEmpty) {
                                return "Required";
                              }
                              final clean = val.replaceAll('₹', '').trim();
                              final n = int.tryParse(clean);
                              if (n == null) return "Enter whole number";
                              if (n < 10) return "Min is ₹10";
                              if (n > maxDiscount) {
                                return "Cannot exceed course price (₹$maxDiscount)";
                              }
                              if (n % 10 != 0 && n != maxDiscount) {
                                return "Must be in steps of 10 (e.g. 50, 100)";
                              }
                              return null;
                            },
                            onChanged: (_) => setDialogState(() {}),
                          ),
                          const SizedBox(height: 12),
                          SteppedPriceInputField(
                            controller: minOrderController,
                            labelText: "Min Order (₹) *",
                            isCoursePrice: false,
                            minPrice: 0,
                            maxPrice: 3199,
                            step: 10,
                            helperText: "Minimum order value required to apply coupon",
                            validator: (val) {
                              if (is100PercentFree) return null;
                              if (val == null || val.trim().isEmpty) {
                                return "Required";
                              }
                              final clean = val.replaceAll('₹', '').trim();
                              final n = int.tryParse(clean);
                              if (n == null || n < 0) return "Must be >= 0";
                              return null;
                            },
                          ),
                        ],
                        const SizedBox(height: 14),
                        // Course Eligibility Selection
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Course Eligibility",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            if (!allCoursesSelected && courseProvider.courses.isNotEmpty)
                              Row(
                                children: [
                                  InkWell(
                                    onTap: () {
                                      setDialogState(() {
                                        selectedCourseIds.clear();
                                        selectedCourseIds.addAll(
                                          courseProvider.courses.map((c) => c.id),
                                        );
                                        courseSelectionError = null;
                                      });
                                    },
                                    child: const Text(
                                      "Select All",
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  InkWell(
                                    onTap: () {
                                      setDialogState(() {
                                        selectedCourseIds.clear();
                                      });
                                    },
                                    child: const Text(
                                      "Clear All",
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.error,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.public, size: 14),
                                  SizedBox(width: 4),
                                  Text("All Courses"),
                                ],
                              ),
                              selected: allCoursesSelected,
                              onSelected: (val) {
                                setDialogState(() {
                                  allCoursesSelected = true;
                                  courseSelectionError = null;
                                });
                              },
                            ),
                            ChoiceChip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.school_outlined, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    selectedCourseIds.isEmpty
                                        ? "Specific Courses"
                                        : "Specific (${selectedCourseIds.length})",
                                  ),
                                ],
                              ),
                              selected: !allCoursesSelected,
                              onSelected: (val) {
                                setDialogState(() {
                                  allCoursesSelected = false;
                                });
                              },
                            ),
                          ],
                        ),
                        if (!allCoursesSelected) ...[
                          const SizedBox(height: 10),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 180),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurface : AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: courseSelectionError != null
                                    ? AppTheme.error
                                    : (isDark ? AppColors.darkBorder : AppColors.border),
                              ),
                            ),
                            child: courseProvider.courses.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(
                                      child: Text(
                                        "No courses created yet. Select 'All Courses'.",
                                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: courseProvider.courses.length,
                                    itemBuilder: (context, idx) {
                                      final crs = courseProvider.courses[idx];
                                      final isChecked = selectedCourseIds.contains(crs.id);
                                      return CheckboxListTile(
                                        dense: true,
                                        value: isChecked,
                                        activeColor: AppTheme.primary,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                        title: Text(
                                          crs.title,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: isChecked ? FontWeight.w700 : FontWeight.w500,
                                          ),
                                        ),
                                        subtitle: Text(
                                          "${crs.category.toUpperCase()} • ${crs.teacherName.isNotEmpty ? crs.teacherName : 'Faculty'}",
                                          style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                        ),
                                        onChanged: (val) {
                                          setDialogState(() {
                                            if (val == true) {
                                              selectedCourseIds.add(crs.id);
                                            } else {
                                              selectedCourseIds.remove(crs.id);
                                            }
                                            if (selectedCourseIds.isNotEmpty) {
                                              courseSelectionError = null;
                                            }
                                          });
                                        },
                                      );
                                    },
                                  ),
                          ),
                          if (courseSelectionError != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              courseSelectionError!,
                              style: const TextStyle(fontSize: 11, color: AppTheme.error),
                            ),
                          ],
                        ],
                        const SizedBox(height: 14),
                        const Text(
                          "Description / Notes",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: descController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            hintText: "e.g. Special promotional discount for select course batches",
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    if (!allCoursesSelected && selectedCourseIds.isEmpty) {
                      setDialogState(() {
                        courseSelectionError = "Please select at least one course, or choose 'All Courses'.";
                      });
                      return;
                    }

                    if (formKey.currentState?.validate() ?? false) {
                      final code = codeController.text.trim().toUpperCase();
                      final double discount;
                      final double minOrder;
                      final String discountType;

                      if (is100PercentFree) {
                        discount = 100.0;
                        discountType = 'percentage';
                        minOrder = 0.0;
                      } else {
                        discount = double.tryParse(discountController.text.replaceAll('₹', '').trim()) ?? 0.0;
                        discountType = 'flat';
                        minOrder = double.tryParse(minOrderController.text.replaceAll('₹', '').trim()) ?? 0.0;

                        if (discount > maxDiscount) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Coupon discount (₹${discount.toInt()}) cannot exceed the course price of ₹$maxDiscount for the selected course(s)."),
                              backgroundColor: AppTheme.error,
                            ),
                          );
                          return;
                        }
                      }

                      final desc = descController.text.trim().isEmpty
                          ? (is100PercentFree ? "100% Free Full Scholarship" : "Special Promotional Discount")
                          : descController.text.trim();

                      final updatedCoupon = CouponModel(
                        id: existingCoupon?.id,
                        code: code,
                        discountAmount: discount,
                        discountType: discountType,
                        minOrderValue: minOrder,
                        description: desc,
                        isActive: true,
                        applicableCourseIds: allCoursesSelected ? [] : List<String>.from(selectedCourseIds),
                      );

                      if (isEditing) {
                        await courseProvider.updateCoupon(updatedCoupon);
                      } else {
                        await courseProvider.addCustomCoupon(updatedCoupon);
                      }

                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }

                      if (!context.mounted) return;

                      final scopeMsg = allCoursesSelected
                          ? "All Courses"
                          : "${selectedCourseIds.length} eligible course(s)";

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            is100PercentFree
                                ? "🎉 100% Free Scholarship Coupon '$code' ${isEditing ? 'updated' : 'created'}! Eligible for: $scopeMsg."
                                : (isEditing
                                    ? "🎉 Coupon '$code' updated! Eligible for: $scopeMsg."
                                    : "🎉 Coupon '$code' created! Eligible for: $scopeMsg."),
                          ),
                          backgroundColor: AppTheme.success,
                        ),
                      );
                    }
                  },
                  child: Text(isEditing ? "Save Changes" : "Create Coupon"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteCoupon(
    BuildContext context,
    CourseProvider courseProvider,
    String code,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
          ),
          title: const Text("Delete Coupon"),
          content: Text("Are you sure you want to deactivate and remove coupon '$code'?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                courseProvider.removeCustomCoupon(code);
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Coupon '$code' has been removed."),
                  ),
                );
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }
}
