import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_card.dart';
import '../../models/attendance_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/attendance_provider.dart';

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final attProvider = context.watch<AttendanceProvider>();
    final records = attProvider.getRecordsForStudent(auth.currentUser.id);
    final percentage = attProvider.calculateAttendancePercentage(
      auth.currentUser.id,
    );

    final presentCount = records
        .where((r) => r.status == AttendanceStatus.present)
        .length;
    final absentCount = records
        .where((r) => r.status == AttendanceStatus.absent)
        .length;
    final isGoodStanding = percentage >= 75;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Attendance & Engagement",
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Academic Attendance Standing Card
            ModernCard(
              padding: const EdgeInsets.all(20),
              backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
              accentSpineColor: isGoodStanding
                  ? AppColors.emerald
                  : AppColors.amber,
              child: Row(
                children: [
                  // Circular Metric Badge
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isGoodStanding
                          ? (isDark ? AppColors.emerald.withValues(alpha: 0.18) : AppColors.emeraldBg)
                          : (isDark ? AppColors.amber.withValues(alpha: 0.18) : AppColors.amberBg),
                      border: Border.all(
                        color: isGoodStanding
                            ? (isDark ? const Color(0xFF86EFAC) : AppColors.emerald)
                            : (isDark ? const Color(0xFFFCD34D) : AppColors.amber),
                        width: 3,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "${percentage.toInt()}%",
                          style: AppTypography.statLarge.copyWith(
                            fontSize: 22,
                            color: isGoodStanding
                                ? (isDark ? const Color(0xFF86EFAC) : AppColors.emerald)
                                : (isDark ? const Color(0xFFFCD34D) : AppColors.amber),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          "Regularity",
                          style: AppTypography.caption.copyWith(
                            fontSize: 10,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isGoodStanding
                              ? "Eligible Standing"
                              : "Attendance Warning",
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "75% minimum batch attendance required for state mock test series qualification.",
                          style: AppTypography.bodySmall.copyWith(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildCountBadge(
                              context,
                              "Present: $presentCount",
                              AppColors.emerald,
                              AppColors.emeraldBg,
                            ),
                            const SizedBox(width: 8),
                            _buildCountBadge(
                              context,
                              "Absent: $absentCount",
                              AppColors.error,
                              AppColors.errorBg,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Attendance Logs Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Session Roll Call Records",
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                  ),
                ),
                Text(
                  "${records.length} logged",
                  style: AppTypography.caption.copyWith(
                    color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Attendance Records List
            if (records.isEmpty)
              const AppEmptyState(
                icon: Icons.event_available_outlined,
                title: "No Attendance Records Yet",
                subtitle:
                    "Your class attendance will appear here once faculty conducts roll call for your batch.",
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: records.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final rec = records[index];
                  final isPresent = rec.status == AttendanceStatus.present;

                  return ModernCard(
                    padding: const EdgeInsets.all(14),
                    backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                    accentSpineColor: isPresent
                        ? AppColors.emerald
                        : AppColors.error,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isPresent
                                ? (isDark ? AppColors.emerald.withValues(alpha: 0.18) : AppColors.emeraldBg)
                                : (isDark ? AppColors.error.withValues(alpha: 0.18) : AppColors.errorBg),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isPresent
                                ? Icons.check_rounded
                                : Icons.close_rounded,
                            size: 18,
                            color: isPresent
                                ? (isDark ? const Color(0xFF86EFAC) : AppColors.emerald)
                                : (isDark ? const Color(0xFFFDA4AF) : AppColors.error),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rec.batchName,
                                style: AppTypography.subtitle2.copyWith(
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                "Date: ${Formatters.formatDate(rec.date)} • Marked by ${rec.markedByTeacherName ?? 'Faculty'}",
                                style: AppTypography.caption.copyWith(
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                              if (rec.remarks != null &&
                                  rec.remarks!.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  rec.remarks!,
                                  style: AppTypography.caption.copyWith(
                                    color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                    fontStyle: FontStyle.italic,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        CustomBadge(
                          text: isPresent ? "PRESENT" : "ABSENT",
                          variant: isPresent
                              ? BadgeVariant.success
                              : BadgeVariant.error,
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

  Widget _buildCountBadge(BuildContext context, String text, Color textColor, Color bgColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveBg = isDark ? textColor.withValues(alpha: 0.18) : bgColor;
    final effectiveText = isDark
        ? (textColor == AppColors.emerald
            ? const Color(0xFF86EFAC)
            : const Color(0xFFFDA4AF))
        : textColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: effectiveText.withValues(alpha: isDark ? 0.4 : 0.3),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: effectiveText,
        ),
      ),
    );
  }
}
