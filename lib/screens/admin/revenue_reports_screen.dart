import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_card.dart';
import '../../providers/course_provider.dart';

class RevenueReportsScreen extends StatelessWidget {
  const RevenueReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final courseProvider = context.watch<CourseProvider>();
    final transactions = courseProvider.transactions;
    final coupons = courseProvider.coupons;

    final totalRevenue = transactions.fold<double>(0, (sum, t) => sum + t.amountPaid);
    final totalDiscounts = transactions.fold<double>(0, (sum, t) => sum + t.discountAmount);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Revenue, Sales & Reports"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Revenue Cards
            Row(
              children: [
                Expanded(
                  child: ModernCard(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: AppTheme.surfaceCard,
                    hasGlow: true,
                    glowColor: AppTheme.primary.withValues(alpha: 0.2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.currency_rupee, color: AppTheme.primary, size: 24),
                        const SizedBox(height: 10),
                        Text(
                          Formatters.formatCurrency(totalRevenue),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          "Total Course Sales Revenue",
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ModernCard(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: AppTheme.surface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.confirmation_number_outlined, color: AppTheme.success, size: 24),
                        const SizedBox(height: 10),
                        Text(
                          "${transactions.length}",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.success,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          "Total Invoices",
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ModernCard(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: AppTheme.surface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.discount_outlined, color: AppTheme.warning, size: 24),
                        const SizedBox(height: 10),
                        Text(
                          Formatters.formatCurrency(totalDiscounts),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.warning,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          "Coupons Redeemed",
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Active Discount Coupons
            const Text(
              "Active Promotional Coupons",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: coupons.map((c) {
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomBadge(text: c.code, variant: BadgeVariant.primary, fontSize: 10),
                        const SizedBox(height: 6),
                        Text(
                          "Save ₹${c.discountAmount.toInt()}",
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "Min Order: ₹${c.minOrderValue.toInt()}",
                          style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
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
                        child: const Icon(Icons.check, color: AppTheme.success, size: 18),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${txn.studentName} (${txn.invoiceNumber})",
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "${txn.courseTitle} • ${txn.batchName}",
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Method: ${txn.paymentMethod} • ${Formatters.formatDate(txn.timestamp)}",
                              style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        Formatters.formatCurrency(txn.amountPaid),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
