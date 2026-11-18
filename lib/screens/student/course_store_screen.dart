import '../../providers/live_class_provider.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_card.dart';
import '../../providers/course_provider.dart';
import 'course_detail_screen.dart';

class CourseStoreScreen extends StatelessWidget {
  const CourseStoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final courseProvider = context.watch<CourseProvider>();
    final courses = courseProvider.filteredCourses;
    final categories = courseProvider.categories;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text("Academic Courses & Batches")),
      body: CustomScrollView(
        slivers: [
          // Search & Filter Header (scrolls naturally with list in landscape)
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.surface,
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  TextField(
                    onChanged: (val) => courseProvider.setSearchQuery(val),
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                    ),
                    decoration: InputDecoration(
                      hintText: "Search BPSC, Bihar SSC, Railway, Board exams...",
                      hintStyle: TextStyle(
                        color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 19,
                        color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      isDense: true,
                      fillColor: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceSubtle,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Category Pills
                  SizedBox(
                    height: 32,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        final isSelected = cat == courseProvider.selectedCategory;

                        return InkWell(
                          onTap: () => courseProvider.setSelectedCategory(cat),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark ? AppColors.primary : AppColors.deepInk)
                                  : (isDark ? AppColors.darkSurfaceCard : AppColors.surfaceSubtle),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSelected
                                    ? (isDark ? AppColors.primary : AppColors.deepInk)
                                    : (isDark ? AppColors.darkBorder : AppColors.border),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              cat,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isSelected
                                    ? (isDark ? Colors.black : Colors.white)
                                    : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
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
          ),

          // Courses List
          if (courses.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    "No courses match your search criteria.",
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index.isOdd) return const SizedBox(height: 14);
                    final courseIndex = index ~/ 2;
                    final course = courses[courseIndex];
                    final isEnrolled = courseProvider.myEnrolledCourseIds.contains(course.id);
                    final hasValidImage = course.coverImageUrl.trim().isNotEmpty &&
                        course.coverImageUrl.startsWith('http');
                    final liveProvider = Provider.of<LiveClassProvider?>(context);
                    final batchIds = courseProvider.batches.where((b) => b.courseId == course.id).map((b) => b.id).toSet();
                    final courseRecordings = (liveProvider?.pastRecordings ?? []).where(
                      (c) => (c.courseId.isNotEmpty && c.courseId == course.id) || batchIds.contains(c.batchId),
                    ).toList();
                    final preLessons = courseProvider.videoLessons.where((l) => batchIds.contains(l.batchId)).toList();
                    final effectiveLessons = math.max(
                      course.totalLessons,
                      preLessons.length + courseRecordings.length,
                    );
                    int totalSec = courseRecordings.fold<int>(0, (sum, r) => sum + r.effectiveDuration.inSeconds) +
                        preLessons.fold<int>(0, (sum, l) => sum + l.duration.inSeconds);
                    int computedHours = (totalSec / 3600).round();
                    if (computedHours <= 0 && (totalSec > 0 || effectiveLessons > 0)) {
                      computedHours = 1;
                    }
                    final effectiveHours = math.max(course.totalHours, computedHours);

                    return ModernCard(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CourseDetailScreen(course: course),
                          ),
                        );
                      },
                      padding: EdgeInsets.zero,
                      backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Cover Image or Dignified Academic Gradient Box
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(10),
                                ),
                                child: hasValidImage
                                    ? Image.network(
                                        course.coverImageUrl,
                                        height: 130,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => _buildAcademicPlaceholder(isDark),
                                      )
                                    : _buildAcademicPlaceholder(isDark),
                              ),
                              Positioned(
                                top: 10,
                                left: 10,
                                child: CustomBadge(
                                  text: course.category,
                                  variant: BadgeVariant.primary,
                                ),
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
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  course.title,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Stats Row
                                Row(
                                  children: [
                                    _buildQuickStat(
                                      context,
                                      Icons.video_library_outlined,
                                      "$effectiveLessons Lessons",
                                    ),
                                    const SizedBox(width: 12),
                                    _buildQuickStat(
                                      context,
                                      Icons.schedule_outlined,
                                      "$effectiveHours hrs",
                                    ),
                                    const SizedBox(width: 12),
                                    _buildQuickStat(
                                      context,
                                      Icons.quiz_outlined,
                                      "${course.totalTests} Tests",
                                    ),
                                    const Spacer(),
                                    if (course.rating > 0 && course.reviewsCount > 0)
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.star_rounded,
                                            size: 15,
                                            color: AppColors.primaryDark,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            "${course.rating}",
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                                Builder(
                                  builder: (context) {
                                    final courseBatches = courseProvider.getBatchesForCourse(course.id);
                                    if (courseBatches.isEmpty) return const SizedBox.shrink();
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isDark ? AppColors.darkSurface : AppColors.warmIvory,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: isDark ? AppColors.darkBorder : AppColors.border,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.access_time_filled, size: 12, color: AppColors.primary),
                                            const SizedBox(width: 4),
                                            Text(
                                              courseBatches.length > 1
                                                  ? "${courseBatches.length} Class Timings Available"
                                                  : courseBatches.first.timing,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                Divider(color: isDark ? AppColors.darkBorder : AppColors.border),
                                const SizedBox(height: 10),

                                // Price & CTA Row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          Formatters.formatCurrency(course.price),
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
                                          ),
                                        ),
                                        if (course.originalPrice > course.price) ...[
                                          const SizedBox(width: 6),
                                          Text(
                                            Formatters.formatCurrency(course.originalPrice),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                              decoration: TextDecoration.lineThrough,
                                            ),
                                          ),
                                        ],
                                        if (course.discountPercentage > 0) ...[
                                          const SizedBox(width: 6),
                                          CustomBadge(
                                            text: "${course.discountPercentage}% OFF",
                                            variant: BadgeVariant.success,
                                            fontSize: 9,
                                          ),
                                        ],
                                      ],
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isEnrolled
                                            ? (isDark ? AppColors.darkSurface : AppColors.surfaceSubtle)
                                            : (isDark ? AppColors.primary : AppColors.deepInk),
                                        foregroundColor: isEnrolled
                                            ? (isDark ? AppColors.darkTextPrimary : AppColors.deepInk)
                                            : (isDark ? Colors.black : Colors.white),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 8,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        minimumSize: const Size(0, 34),
                                      ),
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => CourseDetailScreen(course: course),
                                          ),
                                        );
                                      },
                                      child: Text(
                                        isEnrolled ? "Access Batch" : "Explore Batch",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
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
                  childCount: courses.length * 2 - 1,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAcademicPlaceholder(bool isDark) {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [AppColors.darkSurfaceCard, AppColors.deepInk]
              : [AppColors.surfaceSubtle, AppColors.saffronMuted],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.menu_book_rounded,
          size: 40,
          color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
        ),
      ),
    );
  }

  Widget _buildQuickStat(BuildContext context, IconData icon, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
