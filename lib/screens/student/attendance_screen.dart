import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
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
    final percentage = attProvider.calculateAttendancePercentage(auth.currentUser.id);

    final presentCount = records.where((r) => r.status == AttendanceStatus.present).length;
    final absentCount = records.where((r) => r.status == AttendanceStatus.absent).length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Attendance & Engagement"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Attendance Summary Card
            ModernCard(
              padding: const EdgeInsets.all(20),
              backgroundColor: AppTheme.surfaceCard,
              hasGlow: true,
              glowColor: percentage >= 75
                  ? AppTheme.success.withValues(alpha: 0.2)
                  : AppTheme.warning.withValues(alpha: 0.2),
              child: Row(
                children: [
                  // Circular Percentage Display
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.surfaceLight,
                      border: Border.all(
                        color: percentage >= 75 ? AppTheme.success : AppTheme.warning,
                        width: 4,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "${percentage.toInt()}%",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: percentage >= 75 ? AppTheme.success : AppTheme.warning,
                          ),
                        ),
                        const Text(
                          "Present",
                          style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          percentage >= 75 ? "Excellent Attendance!" : "Attention Needed",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Minimum 75% attendance recommended for test series eligibility.",
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildCountBadge("Present: $presentCount", AppTheme.success),
                            const SizedBox(width: 8),
                            _buildCountBadge("Absent: $absentCount", AppTheme.error),
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
            const Text(
              "Recent Session Attendance Logs",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Attendance Records List
            if (records.isEmpty)
              const Center(
                child: Text(
                  "No attendance records logged yet.",
                  style: TextStyle(color: AppTheme.textMuted),
                ),
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
                    backgroundColor: AppTheme.surface,
                    borderColor: isPresent
                        ? AppTheme.border
                        : AppTheme.error.withValues(alpha: 0.3),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isPresent
                                ? AppTheme.success.withValues(alpha: 0.15)
                                : AppTheme.error.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isPresent ? Icons.check : Icons.close,
                            size: 18,
                            color: isPresent ? AppTheme.success : AppTheme.error,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rec.batchName,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Date: ${Formatters.formatDate(rec.date)} • Marked by ${rec.markedByTeacherName ?? 'Faculty'}",
                                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                              ),
                              if (rec.remarks != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  rec.remarks!,
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                ),
                              ],
                            ],
                          ),
                        ),
                        CustomBadge(
                          text: isPresent ? "PRESENT" : "ABSENT",
                          variant: isPresent ? BadgeVariant.success : BadgeVariant.error,
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

  Widget _buildCountBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
