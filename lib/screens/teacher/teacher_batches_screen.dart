import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_card.dart';
import '../../providers/course_provider.dart';
import 'teacher_broadcast_prototype_screen.dart';
import 'upload_material_screen.dart';

class TeacherBatchesScreen extends StatelessWidget {
  const TeacherBatchesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final courseProvider = context.watch<CourseProvider>();
    final batches = courseProvider.batches
        .where((b) => courseProvider.myAssignedBatchIds.contains(b.id))
        .toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text("My Assigned Batches")),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: batches.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final batch = batches[index];
          final course = courseProvider.getCourseById(batch.courseId);

          return ModernCard(
            padding: const EdgeInsets.all(16),
            backgroundColor: isDark ? AppColors.darkSurfaceCard : AppTheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CustomBadge(
                      text: course?.category ?? "Crash Course",
                      variant: BadgeVariant.primary,
                    ),
                    CustomBadge(
                      text: "${batch.totalStudents} Students",
                      variant: BadgeVariant.success,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  batch.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Course: ${course?.title ?? 'General Course'}",
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "⏰ Schedule: ${batch.timing} • ${batch.medium}",
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Divider(color: isDark ? AppColors.darkBorder : AppTheme.border),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.cell_tower_rounded, size: 16),
                        label: const Text(
                          "Go Live",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const TeacherBroadcastPrototypeScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.upload_file, size: 16),
                        label: const Text(
                          "Upload Notes",
                          style: TextStyle(fontSize: 12),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const UploadMaterialScreen(),
                            ),
                          );
                        },
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
