import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_card.dart';
import '../../providers/auth_provider.dart';
import '../../providers/doubt_provider.dart';

class TeacherDoubtsScreen extends StatefulWidget {
  const TeacherDoubtsScreen({super.key});

  @override
  State<TeacherDoubtsScreen> createState() => _TeacherDoubtsScreenState();
}

class _TeacherDoubtsScreenState extends State<TeacherDoubtsScreen> {
  final Map<String, TextEditingController> _controllers = {};

  // Track which doubt is currently being resolved
  String? _resolvingDoubtId;

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _postTeacherAnswer(
    DoubtProvider doubtProvider,
    AuthProvider auth,
    String doubtId,
  ) async {
    final controller = _controllers[doubtId];
    if (controller == null || controller.text.trim().isEmpty) return;

    setState(() {
      _resolvingDoubtId = doubtId;
    });

    await doubtProvider.resolveDoubt(
      doubtId: doubtId,
      facultyReply: controller.text.trim(),
      facultyName: auth.currentUser.name,
      resolvedBy: auth.currentUser.id,
    );

    if (mounted) {
      setState(() {
        _resolvingDoubtId = null;
      });

      if (doubtProvider.errorMessage == null) {
        controller.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Official Teacher Answer posted! Student notified.'),
            backgroundColor: AppTheme.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(doubtProvider.errorMessage!),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final doubtProvider = context.watch<DoubtProvider>();
    final doubts = doubtProvider.doubts;

    final unresolvedCount = doubts.where((d) => !d.isResolved).length;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Student Doubt Resolution Desk')),
      body: Column(
        children: [
          // Banner summary
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: isDark ? AppColors.darkSurfaceCard : AppTheme.surface,
            child: Row(
              children: [
                CustomBadge(
                  text: "$unresolvedCount Pending Questions",
                  variant: unresolvedCount > 0
                      ? BadgeVariant.warning
                      : BadgeVariant.success,
                ),
                const Spacer(),
                Text(
                  "Total Doubts: ${doubts.length}",
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? AppColors.darkBorder : AppTheme.border),

          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: doubts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final doubt = doubts[index];
                _controllers.putIfAbsent(
                  doubt.id,
                  () => TextEditingController(),
                );
                final isResolving = _resolvingDoubtId == doubt.id;

                return ModernCard(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: isDark ? AppColors.darkSurfaceCard : AppTheme.surface,
                  borderColor: doubt.isResolved
                      ? (isDark ? AppColors.darkBorder : AppTheme.border)
                      : AppTheme.warning.withValues(alpha: 0.4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (doubt.batchName != null)
                                  CustomBadge(
                                    text: doubt.batchName!,
                                    variant: BadgeVariant.secondary,
                                  ),
                                CustomBadge(
                                  text: doubt.subject,
                                  variant: BadgeVariant.primary,
                                ),
                                CustomBadge(
                                  text: doubt.isResolved
                                      ? 'RESOLVED'
                                      : 'NEEDS ANSWER',
                                  variant: doubt.isResolved
                                      ? BadgeVariant.success
                                      : BadgeVariant.warning,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            Formatters.timeAgo(doubt.createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextMuted : AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Student: ${doubt.studentName}",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondaryLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        doubt.questionText,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),

                      // Existing faculty reply
                      if (doubt.facultyReply != null &&
                          doubt.facultyReply!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.primary.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            "${doubt.facultyName ?? 'Faculty'}: ${doubt.facultyReply}",
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],

                      // Teacher Official Reply Input (only if unresolved, or allow updating)
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controllers[doubt.id],
                              style: const TextStyle(fontSize: 13),
                              enabled: !isResolving,
                              decoration: InputDecoration(
                                hintText: doubt.isResolved
                                    ? 'Update official solution...'
                                    : 'Provide official faculty solution...',
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              minimumSize: const Size(0, 38),
                            ),
                            onPressed: isResolving
                                ? null
                                : () => _postTeacherAnswer(
                                    doubtProvider,
                                    auth,
                                    doubt.id,
                                  ),
                            child: isResolving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black54,
                                    ),
                                  )
                                : Text(
                                    doubt.isResolved
                                        ? 'Update'
                                        : 'Post Solution',
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
