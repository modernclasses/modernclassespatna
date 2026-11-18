import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_card.dart';
import '../../providers/auth_provider.dart';
import '../../providers/doubt_provider.dart';
import 'ask_doubt_dialog.dart';

class DoubtsScreen extends StatefulWidget {
  const DoubtsScreen({super.key});

  @override
  State<DoubtsScreen> createState() => _DoubtsScreenState();
}

class _DoubtsScreenState extends State<DoubtsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DoubtProvider>().fetchDoubts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final doubtProvider = context.watch<DoubtProvider>();
    final doubts = doubtProvider.getFilteredDoubts(auth.currentUser.id);
    final filters = ['All', 'Resolved', 'Unresolved'];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Academic Doubts & Inquiries',
          style: TextStyle(
            color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
          ),
        ),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: isDark ? AppColors.darkBorder : AppColors.border,
            height: 1,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.saffron,
        foregroundColor: Colors.black,
        elevation: 2,
        icon: const Icon(Icons.help_outline_rounded, size: 20),
        label: Text(
          'Ask Doubt',
          style: AppTypography.button.copyWith(
            color: AppColors.deepInk,
            fontWeight: FontWeight.w700,
          ),
        ),
        onPressed: () {
          showDialog(context: context, builder: (_) => const AskDoubtDialog());
        },
      ),
      body: Column(
        children: [
          // Filter Chips Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: isDark ? AppColors.darkSurface : AppColors.surface,
            child: Row(
              children: filters.map((f) {
                final isSelected =
                    f == doubtProvider.selectedFilter ||
                    (f == 'All' && doubtProvider.selectedFilter == 'My Doubts');
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f),
                    selected: isSelected,
                    onSelected: (_) => doubtProvider.setFilter(f),
                    backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceMuted,
                    selectedColor: isDark ? AppColors.primary.withValues(alpha: 0.25) : AppColors.saffronMuted,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? (isDark ? AppColors.primaryLight : AppColors.saffronDark)
                          : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected
                            ? (isDark ? AppColors.primaryLight : AppColors.saffron)
                            : (isDark ? AppColors.darkBorder : AppColors.border),
                        width: 1,
                      ),
                    ),
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Container(height: 1, color: isDark ? AppColors.darkBorder : AppColors.border),

          // Doubts List
          Expanded(
            child: doubts.isEmpty
                ? AppEmptyState(
                    icon: Icons.quiz_outlined,
                    title: 'No Doubts in This View',
                    subtitle:
                        'Ask a question from your enrolled batch to get direct guidance from faculty.',
                    actionText: 'Ask Your First Doubt',
                    onAction: () {
                      showDialog(
                        context: context,
                        builder: (_) => const AskDoubtDialog(),
                      );
                    },
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                    itemCount: doubts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final doubt = doubts[index];

                      return ModernCard(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                        accentSpineColor: doubt.isResolved
                            ? AppColors.emerald
                            : AppColors.amber,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Doubt Header
                            Row(
                              children: [
                                CustomBadge(
                                  text: doubt.subject.toUpperCase(),
                                  variant: BadgeVariant.primary,
                                ),
                                const SizedBox(width: 8),
                                CustomBadge(
                                  text: doubt.isResolved
                                      ? 'RESOLVED'
                                      : 'PENDING REVIEW',
                                  variant: doubt.isResolved
                                      ? BadgeVariant.success
                                      : BadgeVariant.warning,
                                ),
                                const Spacer(),
                                Text(
                                  Formatters.timeAgo(doubt.createdAt),
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Question
                            Text(
                              doubt.questionText,
                              style: AppTypography.titleMedium.copyWith(
                                color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.person_outline_rounded,
                                  size: 14,
                                  color: AppColors.textMuted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "Asked by ${doubt.studentName}",
                                  style: AppTypography.caption.copyWith(
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),

                            // Official Faculty Reply Section
                            if (doubt.facultyReply != null &&
                                doubt.facultyReply!.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Container(height: 1, color: isDark ? AppColors.darkBorder : AppColors.border),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkSurface : AppColors.warmIvory,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isDark
                                        ? AppColors.success.withValues(alpha: 0.4)
                                        : AppColors.emeraldBorder,
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? AppColors.success.withValues(alpha: 0.2)
                                                : AppColors.emeraldBg,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.verified_rounded,
                                            size: 14,
                                            color: AppColors.emerald,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          doubt.facultyName ??
                                              'Faculty Response',
                                          style: AppTypography.subtitle2
                                              .copyWith(
                                                color: isDark
                                                    ? AppColors.darkTextPrimary
                                                    : AppColors.deepInk,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                              ),
                                        ),
                                        if (doubt.resolvedAt != null) ...[
                                          const Spacer(),
                                          Text(
                                            Formatters.timeAgo(
                                              doubt.resolvedAt!,
                                            ),
                                            style: AppTypography.caption
                                                .copyWith(
                                                  color: AppColors.textMuted,
                                                  fontSize: 10,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      doubt.facultyReply!,
                                      style: AppTypography.bodySmall.copyWith(
                                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
