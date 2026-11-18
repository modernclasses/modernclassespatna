import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_error_view.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_button.dart';
import '../../core/widgets/modern_card.dart';
import '../../features/courses/data/models/batch_model.dart';
import '../../features/courses/data/models/course_model.dart';
import '../../providers/course_provider.dart';
import '../../providers/live_class_provider.dart';
import '../../models/live_class_model.dart';
import 'live_classroom_screen.dart';

class LiveClassesScreen extends StatefulWidget {
  final int initialTabIndex;

  const LiveClassesScreen({super.key, this.initialTabIndex = 0});

  @override
  State<LiveClassesScreen> createState() => _LiveClassesScreenState();
}

class _LiveClassesScreenState extends State<LiveClassesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedLectureFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<LiveClassProvider>().fetchLiveClasses();
      }
    });
  }

  final Set<String> _reminderClassIds = {};

  void _toggleReminder(LiveClassModel live) {
    final isReminded = _reminderClassIds.contains(live.id);
    setState(() {
      if (isReminded) {
        _reminderClassIds.remove(live.id);
      } else {
        _reminderClassIds.add(live.id);
      }
    });

    if (!isReminded) {
      final now = DateTime.now();
      final scheduled = live.scheduledStartTime.toLocal();
      final diff = scheduled.difference(now);

      if (diff.isNegative) {
        final elapsed = now.difference(scheduled);
        if (elapsed < live.estimatedDuration) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("🔴 '${live.title}' is currently LIVE! Join the classroom now."),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "ℹ️ This session was scheduled for ${Formatters.formatDateTime(scheduled)} and has concluded.",
              ),
              backgroundColor: AppColors.deepInk,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      final totalMinutes = diff.inMinutes;
      final days = diff.inDays;
      final hours = diff.inHours % 24;
      final minutes = totalMinutes % 60;

      String timeStr;
      if (days > 0) {
        timeStr = hours > 0 ? "$days d $hours h" : "$days days";
      } else if (diff.inHours > 0) {
        timeStr = minutes > 0 ? "${diff.inHours}h ${minutes}m" : "${diff.inHours} hours";
      } else if (totalMinutes > 0) {
        timeStr = "$totalMinutes mins";
      } else {
        timeStr = "starting momentarily";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "⏰ Reminder active! You will be alerted 15 minutes before '${live.title}' starts ($timeStr away).",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.deepInk,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Reminder removed for '${live.title}'."),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final liveProvider = context.watch<LiveClassProvider>();
    final courseProvider = context.watch<CourseProvider>();
    final activeLive = liveProvider.currentActiveLiveClass;
    final upcoming = liveProvider.upcomingClasses;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Live Academic Hub"),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                indicatorColor: isDark ? AppColors.primary : AppColors.saffronDark,
                indicatorWeight: 3,
                labelColor: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                labelStyle: AppTypography.subtitle2.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: AppTypography.subtitle2.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                tabs: const [
                  Tab(text: "Live & Upcoming"),
                  Tab(text: "Lectures"),
                ],
              ),
              Container(color: isDark ? AppColors.darkBorder : AppColors.border, height: 1),
            ],
          ),
        ),
      ),
      body: liveProvider.isLoading
          ? const AppLoadingIndicator()
          : liveProvider.errorMessage != null
          ? AppErrorView(
              message: "Failed to load live classes.",
              onRetry: () => liveProvider.fetchLiveClasses(),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Live & Upcoming
                RefreshIndicator(
                  onRefresh: () => liveProvider.fetchLiveClasses(),
                  color: AppColors.primary,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                    // Highlighted LIVE NOW Card
                    if (activeLive != null) ...[
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "BROADCAST IN PROGRESS",
                            style: AppTypography.caption.copyWith(
                              color: AppColors.error,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ModernCard(
                        padding: const EdgeInsets.all(18),
                        backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                        accentSpineColor: AppColors.error,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (activeLive.thumbnailUrl != null &&
                                activeLive.thumbnailUrl!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: Image.network(
                                      activeLive.thumbnailUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const SizedBox.shrink(),
                                    ),
                                  ),
                                ),
                              ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const CustomBadge(
                                  text: "LIVE STREAM",
                                  variant: BadgeVariant.error,
                                  isLivePulse: true,
                                ),
                                CustomBadge(
                                  text:
                                      "${activeLive.activeViewersCount} In Classroom",
                                  variant: BadgeVariant.outline,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              activeLive.title,
                              style: AppTypography.titleLarge.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "${activeLive.subject} • ${activeLive.batchName}",
                              style: AppTypography.bodySmall.copyWith(
                                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: isDark ? AppColors.primary.withValues(alpha: 0.18) : AppColors.saffronMuted,
                                  child: Text(
                                    activeLive.teacherName.isNotEmpty
                                        ? activeLive.teacherName.substring(0, 1)
                                        : 'F',
                                    style: AppTypography.subtitle2.copyWith(
                                      color: AppColors.saffronDark,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  activeLive.teacherName,
                                  style: AppTypography.subtitle2.copyWith(
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ModernButton(
                              text: "Enter Live Classroom",
                              width: double.infinity,
                              icon: Icons.play_arrow_rounded,
                              variant: ButtonVariant.danger,
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => LiveClassroomScreen(
                                      liveClass: activeLive,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Upcoming Live Sessions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Scheduled Lectures",
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                          ),
                        ),
                        Text(
                          "${upcoming.length} upcoming",
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (upcoming.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: AppEmptyState(
                          icon: Icons.schedule_outlined,
                          title: "No Live Lectures Scheduled",
                          subtitle:
                              "Check back later or review recorded lectures from your enrolled batches.",
                        ),
                      )
                    else
                      ...upcoming.map((live) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ModernCard(
                            padding: const EdgeInsets.all(14),
                            backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                            accentSpineColor: AppColors.saffron,
                            child: Row(
                              children: [
                                if (live.thumbnailUrl != null &&
                                    live.thumbnailUrl!.isNotEmpty)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      live.thumbnailUrl!,
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? AppColors.primary
                                                  .withValues(alpha: 0.18)
                                              : AppColors.saffronMuted,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.alarm_rounded,
                                          color: AppColors.saffronDark,
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.primary.withValues(alpha: 0.18) : AppColors.saffronMuted,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.alarm_rounded,
                                      color: AppColors.saffronDark,
                                      size: 22,
                                    ),
                                  ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        live.title,
                                        style: AppTypography.subtitle2.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        "${live.subject} • Faculty: ${live.teacherName}",
                                        style: AppTypography.caption.copyWith(
                                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Starts at ${Formatters.formatDateTime(live.scheduledStartTime)}",
                                        style: AppTypography.caption.copyWith(
                                          color: isDark ? AppColors.primaryLight : AppColors.saffronDark,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Builder(
                                  builder: (context) {
                                    final isReminded = _reminderClassIds.contains(live.id);
                                    if (isReminded) {
                                      return ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.success,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          minimumSize: const Size(0, 32),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                        ),
                                        onPressed: () => _toggleReminder(live),
                                        icon: const Icon(Icons.check_rounded, size: 14),
                                        label: const Text(
                                          "Reminder Set",
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      );
                                    }
                                    return OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                          color: isDark ? AppColors.darkBorder : AppColors.border,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        minimumSize: const Size(0, 32),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                      ),
                                      onPressed: () => _toggleReminder(live),
                                      icon: Icon(
                                        Icons.alarm_add_rounded,
                                        size: 14,
                                        color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                                      ),
                                      label: Text(
                                        "Remind Me",
                                        style: AppTypography.caption.copyWith(
                                          color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),

                // Tab 2: Unified Lectures (Pre-recorded Lessons & Live Broadcast Recordings)
                _buildLecturesTab(
                  isDark: isDark,
                  liveProvider: liveProvider,
                  courseProvider: courseProvider,
                ),
              ],
            ),
    );
  }

  Widget _buildLecturesTab({
    required bool isDark,
    required LiveClassProvider liveProvider,
    required CourseProvider courseProvider,
  }) {
    final pastRecordings = liveProvider.pastRecordings;
    final videoLessons = courseProvider.videoLessons;

    final List<UnifiedLectureItem> allLectures = [];

    // 1. Add all completed live broadcast recordings
    for (final live in pastRecordings) {
      allLectures.add(
        UnifiedLectureItem(
          id: live.id,
          title: live.title,
          subject: live.subject,
          batchName: live.batchName,
          teacherName: live.teacherName,
          videoUrl: live.recordingUrl ?? live.streamUrl,
          thumbnailUrl: live.thumbnailUrl,
          date: live.actualStartTime ?? live.scheduledStartTime,
          duration: live.effectiveDuration > Duration.zero
              ? live.effectiveDuration
              : (live.actualDurationSeconds > 0
                  ? Duration(seconds: live.actualDurationSeconds)
                  : Duration.zero),
          isLiveRecording: true,
          liveModel: live,
        ),
      );
    }

    // 2. Add all pre-recorded course video lessons
    for (final lesson in videoLessons) {
      if (allLectures.any((item) =>
          item.id == lesson.id ||
          (lesson.videoUrl.isNotEmpty && item.videoUrl == lesson.videoUrl))) {
        continue;
      }

      final batch = courseProvider.batches
          .cast<BatchModel?>()
          .firstWhere((b) => b?.id == lesson.batchId, orElse: () => null);

      allLectures.add(
        UnifiedLectureItem(
          id: lesson.id,
          title: lesson.title,
          subject: lesson.chapter,
          batchName: batch?.name ?? 'Course Batch',
          teacherName: 'Faculty',
          videoUrl: lesson.videoUrl,
          thumbnailUrl: lesson.thumbnailUrl,
          date: lesson.uploadedAt,
          duration: lesson.duration,
          isLiveRecording: false,
          lessonModel: lesson,
        ),
      );
    }

    // Sort newest first
    allLectures.sort((a, b) => b.date.compareTo(a.date));

    // Filter based on selected filter
    final filteredLectures = allLectures.where((l) {
      if (_selectedLectureFilter == 'live') return l.isLiveRecording;
      if (_selectedLectureFilter == 'prerecorded') return !l.isLiveRecording;
      return true;
    }).toList();

    if (allLectures.isEmpty) {
      return AppEmptyState(
        icon: Icons.video_collection_outlined,
        title: "No Lectures Available Yet",
        subtitle:
            "Course video lessons and completed live lectures will appear here for your batch.",
        actionLabel: "Refresh",
        onAction: () {
          liveProvider.fetchLiveClasses();
          courseProvider.fetchMyEnrollments();
          courseProvider.fetchCatalog();
        },
      );
    }

    final liveCount = allLectures.where((l) => l.isLiveRecording).length;
    final lessonCount = allLectures.where((l) => !l.isLiveRecording).length;

    return Column(
      children: [
        // Filter Tabs Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: isDark ? AppColors.darkSurface : AppColors.surface,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip("All (${allLectures.length})", 'all', isDark),
                const SizedBox(width: 8),
                _buildFilterChip("Live Recordings ($liveCount)", 'live', isDark),
                const SizedBox(width: 8),
                _buildFilterChip("Video Lessons ($lessonCount)", 'prerecorded', isDark),
              ],
            ),
          ),
        ),
        Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.border),

        // List of unified lectures
        Expanded(
          child: filteredLectures.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      "No lectures found for the selected filter.",
                      style: TextStyle(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredLectures.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final lecture = filteredLectures[index];
                    return ModernCard(
                      onTap: () {
                        final LiveClassModel targetModel;
                        if (lecture.liveModel != null) {
                          targetModel = lecture.liveModel!;
                        } else {
                          targetModel = LiveClassModel(
                            id: lecture.id,
                            courseId: lecture.lessonModel?.courseId ?? '',
                            batchId: lecture.lessonModel?.batchId ?? '',
                            courseName: lecture.batchName,
                            batchName: lecture.batchName,
                            title: lecture.title,
                            subject: lecture.subject,
                            teacherName: lecture.teacherName,
                            teacherAvatar: '',
                            scheduledStartTime: lecture.date,
                            estimatedDuration: lecture.duration,
                            status: LiveStatus.ended,
                            streamUrl: lecture.videoUrl,
                            thumbnailUrl: lecture.thumbnailUrl,
                            recordingStatus: 'ready',
                          );
                        }

                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                LiveClassroomScreen(liveClass: targetModel),
                          ),
                        );
                      },
                      padding: const EdgeInsets.all(14),
                      backgroundColor: isDark
                          ? AppColors.darkSurfaceCard
                          : AppColors.surface,
                      child: Row(
                        children: [
                          // Thumbnail / Visual Icon
                          if (lecture.thumbnailUrl != null &&
                              lecture.thumbnailUrl!.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 54,
                                height: 54,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Image.network(
                                      lecture.thumbnailUrl!,
                                      width: 54,
                                      height: 54,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Container(
                                        color: isDark
                                            ? AppColors.secondary
                                                .withValues(alpha: 0.22)
                                            : AppColors.secondaryMuted,
                                        child: const Icon(
                                          Icons.play_circle_filled_rounded,
                                          color: AppColors.secondary,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.45),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.secondary.withValues(alpha: 0.22)
                                    : AppColors.secondaryMuted,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                lecture.isLiveRecording
                                    ? Icons.history_edu_rounded
                                    : Icons.play_lesson_outlined,
                                color: AppColors.secondary,
                                size: 26,
                              ),
                            ),
                          const SizedBox(width: 14),

                          // Lecture info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lecture.title,
                                  style: AppTypography.subtitle2.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.deepInk,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  "${lecture.subject} • ${lecture.teacherName}",
                                  style: AppTypography.caption.copyWith(
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    CustomBadge(
                                      text: lecture.isLiveRecording
                                          ? (lecture.liveModel?.recordingStatus == 'processing'
                                              ? "Processing (~60s)"
                                              : "Live Recording")
                                          : "Lesson",
                                      variant: lecture.isLiveRecording
                                          ? (lecture.liveModel?.recordingStatus == 'processing'
                                              ? BadgeVariant.warning
                                              : BadgeVariant.success)
                                          : BadgeVariant.secondary,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      fontSize: 9.5,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _formatLectureMeta(
                                          lecture.duration,
                                          lecture.date,
                                          lecture.isLiveRecording,
                                          recordingStatus: lecture.liveModel?.recordingStatus,
                                        ),
                                        style: AppTypography.caption.copyWith(
                                          color: isDark
                                              ? AppColors.darkTextMuted
                                              : AppColors.textMuted,
                                          fontSize: 10.5,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value, bool isDark) {
    final isSelected = _selectedLectureFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedLectureFilter = value;
        });
      },
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected
            ? Colors.white
            : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
      ),
      selectedColor: AppColors.primary,
      backgroundColor:
          isDark ? AppColors.darkSurfaceCard : AppColors.surfaceSubtle,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? AppColors.primary
              : (isDark ? AppColors.darkBorder : AppColors.border),
        ),
      ),
    );
  }

  String _formatLectureMeta(Duration d, DateTime date, bool isLive, {String? recordingStatus}) {
    final dSec = d.inSeconds;
    String durStr = "";
    if (dSec > 0) {
      final h = dSec ~/ 3600;
      final m = (dSec % 3600) ~/ 60;
      final s = dSec % 60;
      durStr = h > 0 ? '${h}h ${m}m' : (m > 0 ? '${m}m' : '${s}s');
    } else if (isLive && recordingStatus == 'processing') {
      durStr = "Finalizing (~60s)";
    }
    final dateStr = Formatters.formatDate(date);
    if (durStr.isNotEmpty) {
      return "$dateStr • $durStr";
    }
    return dateStr;
  }
}

/// Helper model for unified lecture representation (Live Recording + Pre-recorded Lesson)
class UnifiedLectureItem {
  final String id;
  final String title;
  final String subject;
  final String batchName;
  final String teacherName;
  final String videoUrl;
  final String? thumbnailUrl;
  final DateTime date;
  final Duration duration;
  final bool isLiveRecording;
  final LiveClassModel? liveModel;
  final VideoLessonModel? lessonModel;

  const UnifiedLectureItem({
    required this.id,
    required this.title,
    required this.subject,
    required this.batchName,
    required this.teacherName,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.date,
    required this.duration,
    required this.isLiveRecording,
    this.liveModel,
    this.lessonModel,
  });
}
