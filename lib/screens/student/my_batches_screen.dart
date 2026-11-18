import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_card.dart';
import '../../providers/course_provider.dart';
import '../../features/live_classes/logic/live_class_provider.dart';
import 'study_materials_screen.dart';
import 'tests_screen.dart';
import 'live_classes_screen.dart';
import 'course_store_screen.dart';

class MyBatchesScreen extends StatefulWidget {
  const MyBatchesScreen({super.key});

  @override
  State<MyBatchesScreen> createState() => _MyBatchesScreenState();
}

class _MyBatchesScreenState extends State<MyBatchesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CourseProvider>().fetchMyEnrollments();
    });
  }

  @override
  Widget build(BuildContext context) {
    final courseProvider = context.watch<CourseProvider>();
    final enrolledBatches = courseProvider.myEnrolledBatches;
    final isLoading = courseProvider.isLoadingEnrollments;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text("My Enrolled Batches")),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
              ),
            )
          : enrolledBatches.isEmpty
          ? AppEmptyState(
              icon: Icons.school_outlined,
              title: "No Batch Enrollments Yet",
              description:
                  "You have not enrolled in any batches yet. Browse our active crash courses to unlock video lectures, live classes, notes, and tests.",
              actionLabel: "Explore Course Catalog",
              onAction: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CourseStoreScreen()),
                );
              },
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: enrolledBatches.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final batch = enrolledBatches[index];
                final course = courseProvider.getCourseById(batch.courseId);

                if (course == null) return const SizedBox.shrink();

                final lessons = courseProvider.getLessonsForBatch(batch.id);
                final liveProvider = context.watch<LiveClassProvider>();
                final batchRecordings = liveProvider.pastRecordings
                    .where((r) => r.batchId == batch.id)
                    .toList();

                final totalAvailable = (lessons.length + batchRecordings.length) > 0
                    ? (lessons.length + batchRecordings.length)
                    : course.totalLessons;

                int completedLessons = 0;
                double accumulatedWatchFraction = 0.0;

                for (final lesson in lessons) {
                  final p = lesson.progressPercent.clamp(0.0, 1.0);
                  accumulatedWatchFraction += p;
                  if (lesson.isCompleted || p >= 0.75) {
                    completedLessons++;
                  }
                }

                for (final rec in batchRecordings) {
                  final playback = courseProvider.recentPlaybacks
                      .where((p) => p.lectureId == rec.id)
                      .firstOrNull;
                  final p = (playback?.progressPercent ?? 0.0).clamp(0.0, 1.0);
                  accumulatedWatchFraction += p;
                  if (p >= 0.75) {
                    completedLessons++;
                  }
                }

                final rawProgress = totalAvailable > 0
                    ? (accumulatedWatchFraction / totalAvailable).clamp(0.0, 1.0)
                    : 0.0;
                final progressPercent = (totalAvailable > 0 && completedLessons >= totalAvailable)
                    ? 1.0
                    : rawProgress;

                return ModernCard(
                  accentSpineColor: AppColors.primary,
                  padding: const EdgeInsets.all(14),
                  backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                  borderColor: isDark ? AppColors.darkBorder : AppColors.border,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              course.coverImageUrl,
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                width: 64,
                                height: 64,
                                color: isDark ? AppColors.darkSurface : AppColors.surfaceSubtle,
                                child: const Icon(
                                  Icons.school_outlined,
                                  color: AppColors.primaryDark,
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CustomBadge(
                                  text: batch.name,
                                  variant: BadgeVariant.primary,
                                  fontSize: 9.5,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  course.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                                    height: 1.25,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Timing: ${batch.timing}",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Progress Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              totalAvailable > 0
                                  ? "Curriculum: $completedLessons of $totalAvailable Lessons"
                                  : "Curriculum: Starting Soon",
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "${(progressPercent * 100).toInt()}%",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progressPercent,
                          backgroundColor: isDark ? AppColors.darkSurface : AppColors.surfaceSubtle,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primaryDark,
                          ),
                          minHeight: 5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Divider(color: isDark ? AppColors.darkBorder : AppColors.border),
                      const SizedBox(height: 10),

                      // Quick Action Grid for Enrolled Course
                      Row(
                        children: [
                          Expanded(
                            child: _buildBatchActionBtn(
                              context: context,
                              label: "Lectures",
                              icon: Icons.video_collection_outlined,
                              color: AppColors.deepInk,
                              bg: AppColors.surfaceSubtle,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const LiveClassesScreen(
                                      initialTabIndex: 1,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildBatchActionBtn(
                              context: context,
                              label: "Live Class",
                              icon: Icons.live_tv_rounded,
                              color: AppColors.error,
                              bg: AppColors.errorBg,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const LiveClassesScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildBatchActionBtn(
                              context: context,
                              label: "Notes",
                              icon: Icons.description_outlined,
                              color: AppColors.secondary,
                              bg: AppColors.secondaryMuted,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const StudyMaterialsScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildBatchActionBtn(
                              context: context,
                              label: "Tests",
                              icon: Icons.quiz_outlined,
                              color: AppColors.purple,
                              bg: AppColors.purpleBg,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const TestsScreen(),
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

  Widget _buildBatchActionBtn({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    required Color bg,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveBg = isDark
        ? (color == AppColors.deepInk
            ? AppColors.darkSurface
            : color.withValues(alpha: 0.18))
        : bg;
    final effectiveColor = isDark
        ? (color == AppColors.deepInk
            ? AppColors.primaryLight
            : (color == AppColors.secondary ? const Color(0xFF93C5FD) : color))
        : color;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: effectiveBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: effectiveColor.withValues(alpha: isDark ? 0.4 : 0.2),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 17, color: effectiveColor),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: effectiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
