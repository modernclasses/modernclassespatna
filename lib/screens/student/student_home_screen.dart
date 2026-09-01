import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_card.dart';
import '../../core/widgets/section_header.dart';
import '../../providers/auth_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/live_class_provider.dart';
import 'course_detail_screen.dart';
import 'course_store_screen.dart';
import 'live_classes_screen.dart';
import 'live_classroom_screen.dart';
import 'study_materials_screen.dart';
import 'tests_screen.dart';
import 'doubts_screen.dart';
import 'attendance_screen.dart';
import 'video_player_screen.dart';

class StudentHomeScreen extends StatelessWidget {
  final ValueChanged<int>? onNavigateTab;

  const StudentHomeScreen({super.key, this.onNavigateTab});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final courseProvider = context.watch<CourseProvider>();
    final liveProvider = context.watch<LiveClassProvider>();

    final user = auth.currentUser;
    final activeLive = liveProvider.currentActiveLiveClass;
    final featuredCourses = courseProvider.courses.where((c) => c.isFeatured).toList();
    final firstLesson = courseProvider.videoLessons.isNotEmpty ? courseProvider.videoLessons.first : null;
    final enrolledCourse = courseProvider.courses.isNotEmpty ? courseProvider.courses.first : null;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student Welcome Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Namaste, ${user.name.split(' ').first}! 👋",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Target your Dream Exam with Modern Classes Patna",
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.primary,
                  child: Text(
                    user.name.substring(0, 1),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // LIVE NOW Banner (If there is an active class)
            if (activeLive != null) ...[
              ModernCard(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LiveClassroomScreen(liveClass: activeLive),
                    ),
                  );
                },
                padding: const EdgeInsets.all(16),
                backgroundColor: AppTheme.surfaceCard,
                borderColor: AppTheme.error.withValues(alpha: 0.5),
                hasGlow: true,
                glowColor: AppTheme.error.withValues(alpha: 0.2),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: AppTheme.error,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.live_tv, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CustomBadge(text: "LIVE NOW", variant: BadgeVariant.error, isLivePulse: true),
                              const SizedBox(width: 6),
                              Text(
                                "${activeLive.activeViewersCount} watching",
                                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            activeLive.title,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Faculty: ${activeLive.teacherName}",
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.error),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Continue Learning / Resume Video Card
            if (firstLesson != null && enrolledCourse != null) ...[
              ModernCard(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => VideoPlayerScreen(
                        lesson: firstLesson,
                        course: enrolledCourse,
                      ),
                    ),
                  );
                },
                padding: const EdgeInsets.all(14),
                backgroundColor: AppTheme.surfaceElevated,
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "CONTINUE WATCHING",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            firstLesson.title,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${firstLesson.chapter} • ${Formatters.formatDuration(firstLesson.duration)}",
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Quick Access Grid (Live, Tests, PDFs, Doubts, Attendance)
            SectionHeader(title: "Quick Learning Hub"),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.05,
              children: [
                _buildQuickTile(
                  icon: Icons.live_tv,
                  title: "Live Classes",
                  color: AppTheme.error,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LiveClassesScreen()),
                    );
                  },
                ),
                _buildQuickTile(
                  icon: Icons.quiz_outlined,
                  title: "Mock Tests",
                  color: AppTheme.purple,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TestsScreen()),
                    );
                  },
                ),
                _buildQuickTile(
                  icon: Icons.menu_book_outlined,
                  title: "PDFs & Notes",
                  color: AppTheme.secondaryLight,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const StudyMaterialsScreen()),
                    );
                  },
                ),
                _buildQuickTile(
                  icon: Icons.help_outline_rounded,
                  title: "Ask Doubts",
                  color: AppTheme.primary,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DoubtsScreen()),
                    );
                  },
                ),
                _buildQuickTile(
                  icon: Icons.fact_check_outlined,
                  title: "Attendance",
                  color: AppTheme.success,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AttendanceScreen()),
                    );
                  },
                ),
                _buildQuickTile(
                  icon: Icons.storefront_outlined,
                  title: "Store / Batches",
                  color: AppTheme.warning,
                  onTap: () {
                    if (onNavigateTab != null) {
                      onNavigateTab!(1);
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CourseStoreScreen()),
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Coupon Promo Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomBadge(text: "SPECIAL OFFER", variant: BadgeVariant.primary),
                        const SizedBox(height: 6),
                        const Text(
                          "Get ₹200 Flat Discount!",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Use coupon code 'PATNA50' on checkout for any Patna Crash Course.",
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "PATNA50",
                      style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Featured Crash Courses Section
            SectionHeader(
              title: "Featured Crash Courses",
              subtitle: "Special crash batches for upcoming exams",
              actionText: "See All",
              onActionTap: () {
                if (onNavigateTab != null) {
                  onNavigateTab!(1);
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CourseStoreScreen()),
                  );
                }
              },
            ),
            const SizedBox(height: 8),

            SizedBox(
              height: 240,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: featuredCourses.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final course = featuredCourses[index];
                  return SizedBox(
                    width: 240,
                    child: ModernCard(
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
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            child: Image.network(
                              course.coverImageUrl,
                              height: 100,
                              width: 240,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                height: 100,
                                color: AppTheme.surfaceLight,
                                child: const Center(child: Icon(Icons.school, color: AppTheme.primary)),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  course.title,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "By ${course.teacherName}",
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      Formatters.formatCurrency(course.price),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                    CustomBadge(
                                      text: "${course.discountPercentage}% OFF",
                                      variant: BadgeVariant.success,
                                      fontSize: 9,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickTile({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ModernCard(
      onTap: onTap,
      padding: const EdgeInsets.all(10),
      backgroundColor: AppTheme.surface,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
