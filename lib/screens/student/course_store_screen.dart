import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_card.dart';
import '../../providers/auth_provider.dart';
import '../../providers/course_provider.dart';
import 'course_detail_screen.dart';

class CourseStoreScreen extends StatelessWidget {
  const CourseStoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final courseProvider = context.watch<CourseProvider>();
    final auth = context.watch<AuthProvider>();
    final courses = courseProvider.filteredCourses;
    final categories = courseProvider.categories;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Course Catalog & Batches"),
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            color: AppTheme.surface,
            child: Column(
              children: [
                TextField(
                  onChanged: (val) => courseProvider.setSearchQuery(val),
                  decoration: InputDecoration(
                    hintText: "Search BPSC, SSC, Railway, 12th Board courses...",
                    prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.textMuted),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    isDense: true,
                    fillColor: AppTheme.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Category Pills
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      final isSelected = cat == courseProvider.selectedCategory;

                      return InkWell(
                        onTap: () => courseProvider.setSelectedCategory(cat),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primary : AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? AppTheme.primary : AppTheme.border,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            cat,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.black : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),

          // Courses List
          Expanded(
            child: courses.isEmpty
                ? const Center(
                    child: Text(
                      "No courses match your search criteria.",
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: courses.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final course = courses[index];
                      final isEnrolled = auth.currentUser.enrolledCourseIds.contains(course.id);

                      return ModernCard(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CourseDetailScreen(course: course),
                            ),
                          );
                        },
                        padding: EdgeInsets.zero,
                        backgroundColor: AppTheme.surface,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Cover Image with Badges
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                  child: Image.network(
                                    course.coverImageUrl,
                                    height: 150,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Container(
                                      height: 150,
                                      color: AppTheme.surfaceLight,
                                      child: const Center(
                                        child: Icon(Icons.school, size: 40, color: AppTheme.primary),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 10,
                                  left: 10,
                                  child: CustomBadge(text: course.category, variant: BadgeVariant.primary),
                                ),
                                if (isEnrolled)
                                  const Positioned(
                                    top: 10,
                                    right: 10,
                                    child: CustomBadge(
                                      text: "ENROLLED",
                                      variant: BadgeVariant.success,
                                    ),
                                  ),
                              ],
                            ),

                            // Content Details
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    course.title,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "Faculty: ${course.teacherName} • Modern Classes Patna",
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                  ),
                                  const SizedBox(height: 12),

                                  // Stats Row
                                  Row(
                                    children: [
                                      _buildQuickStat(Icons.video_library_outlined, "${course.totalLessons} Lessons"),
                                      const SizedBox(width: 14),
                                      _buildQuickStat(Icons.timer_outlined, "${course.totalHours} hrs"),
                                      const SizedBox(width: 14),
                                      _buildQuickStat(Icons.quiz_outlined, "${course.totalTests} Tests"),
                                      const Spacer(),
                                      Row(
                                        children: [
                                          const Icon(Icons.star, size: 14, color: AppTheme.primary),
                                          const SizedBox(width: 2),
                                          Text(
                                            "${course.rating}",
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  const Divider(color: AppTheme.border),
                                  const SizedBox(height: 12),

                                  // Price & CTA Row
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            Formatters.formatCurrency(course.price),
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w900,
                                              color: AppTheme.primary,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            Formatters.formatCurrency(course.originalPrice),
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AppTheme.textMuted,
                                              decoration: TextDecoration.lineThrough,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          CustomBadge(
                                            text: "${course.discountPercentage}% OFF",
                                            variant: BadgeVariant.success,
                                            fontSize: 9,
                                          ),
                                        ],
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isEnrolled ? AppTheme.surfaceElevated : AppTheme.primary,
                                          foregroundColor: isEnrolled ? Colors.white : Colors.black,
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          minimumSize: const Size(0, 36),
                                        ),
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => CourseDetailScreen(course: course),
                                            ),
                                          );
                                        },
                                        child: Text(isEnrolled ? "View Batch" : "Explore"),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
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

  Widget _buildQuickStat(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppTheme.textMuted),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}
