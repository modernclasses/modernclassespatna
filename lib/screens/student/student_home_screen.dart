import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_card.dart';
import '../../core/widgets/section_header.dart';
import '../../providers/auth_provider.dart';
import '../../features/auth/data/models/user_model.dart';
import '../../providers/course_provider.dart';
import '../../models/course_model.dart';
import '../../models/live_class_model.dart';
import '../../providers/live_class_provider.dart';
import 'course_detail_screen.dart';
import 'course_store_screen.dart';
import 'live_classes_screen.dart';
import 'live_classroom_screen.dart';
import 'study_materials_screen.dart';
import 'tests_screen.dart';
import 'doubts_screen.dart';
import 'attendance_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;

  const StudentHomeScreen({super.key, this.onNavigateTab});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final courseProvider = context.read<CourseProvider>();
      courseProvider.fetchMyEnrollments();
      courseProvider.loadRecentPlaybacks(auth.currentUser.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final courseProvider = context.watch<CourseProvider>();
    final liveProvider = context.watch<LiveClassProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (courseProvider.isLoading && courseProvider.courses.isEmpty) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
          ),
        ),
      );
    }

    if (courseProvider.errorMessage != null && courseProvider.courses.isEmpty) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.error.withValues(alpha: 0.18)
                        : AppColors.errorBg,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? AppColors.error.withValues(alpha: 0.4)
                          : AppColors.errorBorder,
                    ),
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.error,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Connection to Modern Classes Server Failed",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.deepInk,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  courseProvider.errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? AppColors.primary
                        : AppColors.deepInk,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () => courseProvider.fetchCatalog(),
                  child: const Text(
                    "Retry Connection",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final user = auth.currentUser;
    final activeLive = liveProvider.currentActiveLiveClass;
    final isEnrolledInActiveLive = activeLive == null ||
        user.role != UserRole.student ||
        courseProvider.myEnrolledBatchIds.contains(activeLive.batchId) ||
        courseProvider.myEnrolledCourseIds.contains(activeLive.courseId);
    final featuredCourses = courseProvider.courses
        .where((c) => c.isFeatured)
        .toList();
    final enrolledBatches = courseProvider.batches
        .where((b) => courseProvider.myEnrolledBatchIds.contains(b.id))
        .toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Academic Student Masthead
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: isDark
                        ? AppColors.primary.withValues(alpha: 0.2)
                        : AppColors.deepInk,
                    child: Text(
                      user.name.isNotEmpty
                          ? user.name.substring(0, 1).toUpperCase()
                          : "S",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: isDark ? AppColors.primaryLight : Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              "Namaste, ${user.name.split(' ').first}!",
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.deepInk,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const CustomBadge(
                              text: "STUDENT",
                              variant: BadgeVariant.primary,
                              fontSize: 9,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.targetExam.isNotEmpty
                              ? "Target Exam: ${user.targetExam}"
                              : "Modern Classes Patna • Dedicated Exam Prep",
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // LIVE NOW Focus Banner (Active Lecture in Session)
            if (activeLive != null && isEnrolledInActiveLive) ...[
              ModernCard(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          LiveClassroomScreen(liveClass: activeLive),
                    ),
                  );
                },
                accentSpineColor: AppColors.error,
                padding: const EdgeInsets.all(14),
                backgroundColor: AppColors.surface,
                borderColor: AppColors.errorBorder,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.error.withValues(alpha: 0.18)
                            : AppColors.errorBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.live_tv_rounded,
                        color: AppColors.error,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const CustomBadge(
                                text: "LIVE NOW",
                                variant: BadgeVariant.error,
                                isLivePulse: true,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "${activeLive.activeViewersCount} attending",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppColors.darkTextMuted
                                      : AppColors.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            activeLive.title,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.deepInk,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Faculty: ${activeLive.teacherName} • ${activeLive.subject}",
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        "JOIN",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Continue Studying (Resume Learning Section)
            if (enrolledBatches.isNotEmpty || courseProvider.recentPlaybacks.isNotEmpty) ...[
              const SectionHeader(
                eyebrow: "ACADEMIC PROGRESS",
                title: "Resume Learning",
                subtitle: "Pick up right where you left off",
              ),
              if (courseProvider.recentPlaybacks.isNotEmpty)
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: courseProvider.recentPlaybacks.take(2).length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final playback = courseProvider.recentPlaybacks[index];
                    final progress = playback.progressPercent;
                    final formattedPos = Formatters.formatDuration(Duration(seconds: playback.positionSeconds));

                    return ModernCard(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LiveClassroomScreen(
                              liveClass: playback.toLiveClassModel(),
                            ),
                          ),
                        );
                      },
                      accentSpineColor: AppColors.primary,
                      padding: const EdgeInsets.all(12),
                      backgroundColor: AppColors.surface,
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.primary.withValues(alpha: 0.18)
                                  : AppColors.saffronMuted,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.primary.withValues(alpha: 0.4)
                                    : AppColors.saffronBorder,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              progress > 0 ? Icons.replay_rounded : Icons.play_arrow_rounded,
                              color: isDark
                                  ? AppColors.primaryLight
                                  : AppColors.primaryDark,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      progress > 0
                                          ? "RESUME LECTURE • ${(progress * 100).toInt()}% WATCHED"
                                          : "RECENTLY PLAYED",
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                        color: isDark
                                            ? AppColors.primaryLight
                                            : AppColors.primaryDark,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  playback.title,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.deepInk,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "${playback.subject} • ${playback.batchName}${playback.positionSeconds > 0 ? ' • Resumes at $formattedPos' : ''}",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (progress > 0) ...[
                                  const SizedBox(height: 5),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 3,
                                      backgroundColor: isDark
                                          ? AppColors.darkSurface
                                          : AppColors.surfaceSubtle,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        isDark
                                            ? AppColors.primaryLight
                                            : AppColors.primaryDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 12,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.textMuted,
                          ),
                        ],
                      ),
                    );
                  },
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: enrolledBatches.take(2).length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final batch = enrolledBatches[index];
                    final parentCourseIndex = courseProvider.courses.indexWhere(
                      (c) => c.id == batch.courseId,
                    );
                    if (parentCourseIndex == -1) return const SizedBox.shrink();
                    final parentCourse =
                        courseProvider.courses[parentCourseIndex];

                    final batchLessons = courseProvider.getLessonsForBatch(
                      batch.id,
                    );
                    VideoLessonModel? activeLesson;
                    if (batchLessons.isNotEmpty) {
                      activeLesson = batchLessons.firstWhere(
                        (l) => l.progressPercent > 0 && l.progressPercent < 1.0,
                        orElse: () => batchLessons.firstWhere(
                          (l) => !l.isCompleted,
                          orElse: () => batchLessons.first,
                        ),
                      );
                    }

                    final lessonToPlay = activeLesson;
                    final double progress = lessonToPlay?.progressPercent ?? 0.0;

                    return ModernCard(
                      onTap: () {
                        if (lessonToPlay != null) {
                          final matchingLive = liveProvider.pastRecordings
                              .cast<LiveClassModel?>()
                              .firstWhere(
                                (l) =>
                                    l?.id == lessonToPlay.id ||
                                    (lessonToPlay.videoUrl.isNotEmpty &&
                                        (l?.streamUrl == lessonToPlay.videoUrl ||
                                            l?.recordingUrl == lessonToPlay.videoUrl)),
                                orElse: () => null,
                              );

                          final targetModel = matchingLive ??
                              LiveClassModel(
                                id: lessonToPlay.id,
                                courseId: lessonToPlay.courseId.isNotEmpty
                                    ? lessonToPlay.courseId
                                    : parentCourse.id,
                                batchId: lessonToPlay.batchId.isNotEmpty
                                    ? lessonToPlay.batchId
                                    : batch.id,
                                courseName: parentCourse.title,
                                batchName: batch.name,
                                title: lessonToPlay.title,
                                subject: lessonToPlay.chapter,
                                teacherName: batch.teacherName.isNotEmpty
                                    ? batch.teacherName
                                    : 'Faculty',
                                teacherAvatar: '',
                                scheduledStartTime: lessonToPlay.uploadedAt,
                                estimatedDuration: lessonToPlay.duration,
                                status: LiveStatus.ended,
                                streamUrl: lessonToPlay.videoUrl,
                                recordingUrl: lessonToPlay.videoUrl,
                                thumbnailUrl: lessonToPlay.thumbnailUrl,
                                recordingStatus: 'ready',
                              );

                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => LiveClassroomScreen(
                                liveClass: targetModel,
                              ),
                            ),
                          );
                        } else {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  CourseDetailScreen(course: parentCourse),
                            ),
                          );
                        }
                      },
                      accentSpineColor: AppColors.primary,
                      padding: const EdgeInsets.all(12),
                      backgroundColor: AppColors.surface,
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.primary.withValues(alpha: 0.18)
                                  : AppColors.saffronMuted,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.primary.withValues(alpha: 0.4)
                                    : AppColors.saffronBorder,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              lessonToPlay != null
                                  ? (progress > 0 ? Icons.replay_rounded : Icons.play_arrow_rounded)
                                  : Icons.school_outlined,
                              color: isDark
                                  ? AppColors.primaryLight
                                  : AppColors.primaryDark,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      lessonToPlay != null
                                          ? (progress > 0
                                              ? "RESUME LECTURE • ${(progress * 100).toInt()}% WATCHED"
                                              : "UP NEXT IN BATCH")
                                          : "ENROLLED BATCH",
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                        color: isDark
                                            ? AppColors.primaryLight
                                            : AppColors.primaryDark,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  lessonToPlay != null
                                      ? lessonToPlay.title
                                      : batch.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.deepInk,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  lessonToPlay != null
                                      ? "${lessonToPlay.chapter} • ${Formatters.formatDuration(lessonToPlay.duration)}"
                                      : "${parentCourse.title} • Timing: ${batch.timing}",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (lessonToPlay != null && progress > 0) ...[
                                  const SizedBox(height: 5),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 3,
                                      backgroundColor: isDark
                                          ? AppColors.darkSurface
                                          : AppColors.surfaceSubtle,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        isDark
                                            ? AppColors.primaryLight
                                            : AppColors.primaryDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 12,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.textMuted,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox(height: 16),
            ],

            // Quick Learning Workspaces (Asymmetric Editorial Grid)
            const SectionHeader(
              eyebrow: "STUDY PORTAL",
              title: "Academic Workspaces",
              subtitle: "Classroom tools, exams, doubt clearing & materials",
            ),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.05,
              children: [
                _buildWorkspaceTile(
                  context: context,
                  icon: Icons.live_tv_rounded,
                  title: "Live Classes",
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
                _buildWorkspaceTile(
                  context: context,
                  icon: Icons.quiz_outlined,
                  title: "Mock Tests",
                  color: AppColors.purple,
                  bg: AppColors.purpleBg,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TestsScreen()),
                    );
                  },
                ),
                _buildWorkspaceTile(
                  context: context,
                  icon: Icons.description_outlined,
                  title: "PDF Notes",
                  color: AppColors.secondary,
                  bg: AppColors.secondaryMuted,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const StudyMaterialsScreen(),
                      ),
                    );
                  },
                ),
                _buildWorkspaceTile(
                  context: context,
                  icon: Icons.chat_bubble_outline_rounded,
                  title: "Ask Doubts",
                  color: AppColors.primaryDark,
                  bg: AppColors.saffronMuted,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DoubtsScreen()),
                    );
                  },
                ),
                _buildWorkspaceTile(
                  context: context,
                  icon: Icons.event_available_outlined,
                  title: "Attendance",
                  color: AppColors.success,
                  bg: AppColors.successBg,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AttendanceScreen(),
                      ),
                    );
                  },
                ),
                _buildWorkspaceTile(
                  context: context,
                  icon: Icons.storefront_outlined,
                  title: "Course Store",
                  color: AppColors.deepInk,
                  bg: AppColors.surfaceSubtle,
                  onTap: () {
                    if (widget.onNavigateTab != null) {
                      widget.onNavigateTab!(1);
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CourseStoreScreen(),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),



            // Featured Crash Courses Section
            SectionHeader(
              eyebrow: "ACADEMIC CATALOG",
              title: "Featured Batches & Courses",
              subtitle:
                  "Curated crash courses for state and central competitive exams",
              actionText: "See All",
              onActionTap: () {
                if (widget.onNavigateTab != null) {
                  widget.onNavigateTab!(1);
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CourseStoreScreen(),
                    ),
                  );
                }
              },
            ),

            if (featuredCourses.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                  ),
                ),
                child: Text(
                  "New exam crash courses are currently being finalized by Patna faculty.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              )
            else
              SizedBox(
                height: 240,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: featuredCourses.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final course = featuredCourses[index];
                    return SizedBox(
                      width: 230,
                      child: ModernCard(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  CourseDetailScreen(course: course),
                            ),
                          );
                        },
                        padding: EdgeInsets.zero,
                        backgroundColor:
                            isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(10),
                              ),
                              child: Image.network(
                                course.coverImageUrl,
                                height: 96,
                                width: 230,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  height: 96,
                                  color: isDark
                                      ? AppColors.darkSurface
                                      : AppColors.surfaceSubtle,
                                  child: Center(
                                    child: Icon(
                                      Icons.menu_book_outlined,
                                      color: isDark
                                          ? AppColors.primaryLight
                                          : AppColors.primaryDark,
                                      size: 30,
                                    ),
                                  ),
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
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.deepInk,
                                      height: 1.3,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Faculty: ${course.teacherName}",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        Formatters.formatCurrency(course.price),
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: isDark
                                              ? AppColors.primaryLight
                                              : AppColors.primaryDark,
                                        ),
                                      ),
                                      if (course.discountPercentage > 0)
                                        CustomBadge(
                                          text:
                                              "${course.discountPercentage}% OFF",
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

  Widget _buildWorkspaceTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Color color,
    required Color bg,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveBg = isDark ? color.withValues(alpha: 0.18) : bg;
    final effectiveColor = isDark
        ? (color == AppColors.deepInk
            ? AppColors.primaryLight
            : (color == AppColors.primaryDark ? AppColors.primaryLight : color))
        : color;

    return ModernCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
      borderColor: isDark ? AppColors.darkBorder : AppColors.border,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: effectiveBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 20, color: effectiveColor),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
