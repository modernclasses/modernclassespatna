import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_card.dart';
import '../../models/payment_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/course_provider.dart';

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.currentUser.id.isNotEmpty) {
        context.read<CourseProvider>().fetchStudentTransactions(
          auth.currentUser.id,
        );
      }
    });
  }

  void _showInvoiceDialog(BuildContext context, PaymentTransactionModel txn) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text("Tax Invoice #${txn.invoiceNumber}", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "MODERN CLASSES PATNA",
              style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.primary, fontSize: 13),
            ),
            const Text("Director: Madhurendra Kumar Yadav", style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            const Text("Phone: +91 6209016951 • Patna, Bihar", style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            const SizedBox(height: 12),
            const Divider(color: AppTheme.border),
            const SizedBox(height: 12),
            _buildInvoiceItem("Student Name", txn.studentName),
            _buildInvoiceItem("Course Title", txn.courseTitle),
            _buildInvoiceItem("Batch Name", txn.batchName),
            _buildInvoiceItem("Transaction Ref", txn.transactionReference),
            _buildInvoiceItem("Date", Formatters.formatDateTime(txn.timestamp)),
            _buildInvoiceItem("Original Price", Formatters.formatCurrency(txn.originalAmount)),
            if (txn.discountAmount > 0)
              _buildInvoiceItem("Discount Applied", "- ${Formatters.formatCurrency(txn.discountAmount)}"),
            const SizedBox(height: 8),
            const Divider(color: AppTheme.border),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Total Paid", style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  Formatters.formatCurrency(txn.amountPaid),
                  style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.primary, fontSize: 16),
                ),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close Receipt"),
          ),
        ],
      ),
    );
  }

  static Widget _buildInvoiceItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final courseProvider = context.watch<CourseProvider>();
    final transactions = courseProvider.studentTransactions
        .where((t) => t.studentId == auth.currentUser.id)
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Payment History & Invoices"),
      ),
      body: courseProvider.isLoadingLedger
          ? const Center(child: CircularProgressIndicator())
          : courseProvider.ledgerError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                        const SizedBox(height: 12),
                        Text(
                          courseProvider.ledgerError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.error),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => courseProvider.fetchStudentTransactions(auth.currentUser.id),
                          child: const Text("Retry"),
                        ),
                      ],
                    ),
                  ),
                )
              : transactions.isEmpty
                  ? const Center(
                      child: Text(
                        "No payment transactions found.",
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: transactions.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final txn = transactions[index];
                        return ModernCard(
                          padding: const EdgeInsets.all(16),
                          backgroundColor: AppTheme.surface,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  CustomBadge(text: txn.invoiceNumber, variant: BadgeVariant.primary),
                                  const CustomBadge(
                                    text: "PAID",
                                    variant: BadgeVariant.success,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                txn.courseTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${txn.batchName} • ${txn.paymentMethod}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                              const SizedBox(height: 12),
                              const Divider(color: AppTheme.border),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Date: ${Formatters.formatDateTime(txn.timestamp)}",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                        ),
                                        Text(
                                          "Ref: ${txn.transactionReference}",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 120),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              Formatters.formatCurrency(txn.amountPaid),
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w900,
                                                color: AppTheme.primary,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          icon: const Icon(Icons.receipt_outlined, size: 18, color: AppTheme.primary),
                                          tooltip: "View Invoice",
                                          onPressed: () => _showInvoiceDialog(context, txn),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
