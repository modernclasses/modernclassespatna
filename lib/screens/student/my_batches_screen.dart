import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_card.dart';
import '../../providers/auth_provider.dart';
import '../../providers/course_provider.dart';
import 'video_player_screen.dart';
import 'study_materials_screen.dart';
import 'tests_screen.dart';
import 'live_classes_screen.dart';
import 'course_store_screen.dart';

class MyBatchesScreen extends StatelessWidget {
  const MyBatchesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final courseProvider = context.watch<CourseProvider>();

    final enrolledCourses = courseProvider.courses
        .where((c) => auth.currentUser.enrolledCourseIds.contains(c.id))
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("My Enrolled Batches"),
      ),
      body: enrolledCourses.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.school_outlined, size: 64, color: AppTheme.textMuted),
                  const SizedBox(height: 16),
                  const Text(
                    "You are not enrolled in any batches yet.",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Explore Modern Classes Patna crash courses & start learning.",
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CourseStoreScreen()),
                      );
                    },
                    child: const Text("Browse Courses"),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: enrolledCourses.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final course = enrolledCourses[index];
                final lessons = courseProvider.getLessonsForCourse(course.id);
                final completedLessons = lessons.where((l) => l.isCompleted).length;
                final progressPercent = lessons.isEmpty ? 0.0 : (completedLessons / lessons.length);

                return ModernCard(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: AppTheme.surface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              course.coverImageUrl,
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                width: 70,
                                height: 70,
                                color: AppTheme.surfaceLight,
                                child: const Icon(Icons.school, color: AppTheme.primary),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CustomBadge(text: course.category, variant: BadgeVariant.primary),
                                const SizedBox(height: 4),
                                Text(
                                  course.title,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Progress Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Course Progress: $completedLessons / ${lessons.length} Lessons",
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                          Text(
                            "${(progressPercent * 100).toInt()}%",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progressPercent,
                          backgroundColor: AppTheme.surfaceLight,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: AppTheme.border),
                      const SizedBox(height: 12),

                      // Quick Action Grid for Enrolled Course
                      Row(
                        children: [
                          Expanded(
                            child: _buildBatchActionBtn(
                              context: context,
                              label: "Lectures",
                              icon: Icons.video_collection_outlined,
                              color: AppTheme.primary,
                              onTap: () {
                                if (lessons.isNotEmpty) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => VideoPlayerScreen(
                                        lesson: lessons.first,
                                        course: course,
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildBatchActionBtn(
                              context: context,
                              label: "Live Class",
                              icon: Icons.live_tv,
                              color: AppTheme.error,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const LiveClassesScreen()),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildBatchActionBtn(
                              context: context,
                              label: "Notes",
                              icon: Icons.menu_book,
                              color: AppTheme.secondaryLight,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const StudyMaterialsScreen()),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildBatchActionBtn(
                              context: context,
                              label: "Tests",
                              icon: Icons.quiz_outlined,
                              color: AppTheme.purple,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const TestsScreen()),
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
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
