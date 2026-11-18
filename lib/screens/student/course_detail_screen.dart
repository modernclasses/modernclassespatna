import '../../providers/live_class_provider.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_card.dart';
import '../../models/course_model.dart';
import '../../models/batch_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/course_provider.dart';
import 'checkout_screen.dart';
import '../../models/live_class_model.dart';
import 'live_classroom_screen.dart';

class CourseDetailScreen extends StatefulWidget {
  final CourseModel course;

  const CourseDetailScreen({super.key, required this.course});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  BatchModel? _selectedBatch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final courseProvider = context.read<CourseProvider>();
      final batches = courseProvider.getBatchesForCourse(widget.course.id);
      if (batches.isNotEmpty) {
        try {
          final enrolledBatch = batches.firstWhere(
            (b) => courseProvider.myEnrolledBatchIds.contains(b.id),
          );
          setState(() {
            _selectedBatch = enrolledBatch;
          });
        } catch (_) {
          setState(() {
            _selectedBatch = batches.isNotEmpty ? batches.first : null;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final courseProvider = context.watch<CourseProvider>();
    final auth = context.watch<AuthProvider>();
    final bool canManage = auth.isTeacher || auth.isAdmin;
    final liveProvider = Provider.of<LiveClassProvider?>(context);
    final batches = courseProvider.getBatchesForCourse(widget.course.id);
    final batchIds = batches.map((b) => b.id).toSet();
    final courseRecordings = (liveProvider?.pastRecordings ?? []).where(
      (c) => (c.courseId.isNotEmpty && c.courseId == widget.course.id) || batchIds.contains(c.batchId),
    ).toList();
    final lessons = _selectedBatch != null
        ? courseProvider.getLessonsForBatch(_selectedBatch!.id)
        : [];
    final batchRecordings = _selectedBatch != null
        ? courseRecordings.where((c) => c.batchId == _selectedBatch!.id).toList()
        : courseRecordings;

    final totalPreRecorded = batches.fold<int>(
      0,
      (sum, b) => sum + courseProvider.getLessonsForBatch(b.id).length,
    );
    final effectiveTotalLessons = math.max(
      widget.course.totalLessons,
      math.max(totalPreRecorded + courseRecordings.length, lessons.length + batchRecordings.length),
    );

    int totalRecordedSec = courseRecordings.fold<int>(
      0,
      (sum, r) => sum + r.effectiveDuration.inSeconds,
    );
    int totalPreRecordedSec = batches.fold<int>(
      0,
      (sum, b) => sum + courseProvider.getLessonsForBatch(b.id).fold<int>(0, (s, l) => s + l.duration.inSeconds),
    );
    int totalDurationSec = totalRecordedSec + totalPreRecordedSec;
    int computedHours = (totalDurationSec / 3600).round();
    if (computedHours <= 0 && (totalDurationSec > 0 || effectiveTotalLessons > 0)) {
      computedHours = 1;
    }
    final effectiveTotalHours = math.max(widget.course.totalHours, computedHours);
    final bool isEnrolled =
        _selectedBatch != null &&
        courseProvider.myEnrolledBatchIds.contains(_selectedBatch!.id);
    final bool canWatch = isEnrolled || canManage;
    final isAnySlotEnrolled =
        batches.any((b) => courseProvider.myEnrolledBatchIds.contains(b.id));
    final BatchModel? enrolledBatch = isAnySlotEnrolled
        ? batches.firstWhere((b) => courseProvider.myEnrolledBatchIds.contains(b.id))
        : null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.course.title, style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(icon: const Icon(Icons.share_outlined), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image
            Stack(
              children: [
                (widget.course.coverImageUrl.trim().isNotEmpty &&
                        widget.course.coverImageUrl.startsWith('http'))
                    ? Image.network(
                        widget.course.coverImageUrl,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: double.infinity,
                          height: 200,
                          color: AppTheme.surfaceLight,
                          child: const Icon(
                            Icons.school,
                            size: 80,
                            color: AppTheme.primary,
                          ),
                        ),
                      )
                    : Container(
                        width: double.infinity,
                        height: 200,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppColors.deepInk, Color(0xFF1E3A8A)],
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.school,
                            size: 72,
                            color: AppColors.primaryLight,
                          ),
                        ),
                      ),
                if (widget.course.isFeatured)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: CustomBadge(
                      text: "FEATURED",
                      variant: BadgeVariant.primary,
                    ),
                  ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CustomBadge(
                        text: widget.course.category,
                        variant: BadgeVariant.secondary,
                      ),
                      if (widget.course.rating > 0 && widget.course.reviewsCount > 0)
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: AppTheme.warning,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "${widget.course.rating}",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              " (${widget.course.reviewsCount})",
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.course.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  if (widget.course.teacherName.trim().isNotEmpty &&
                      widget.course.teacherName != 'Faculty Member' &&
                      widget.course.teacherName != 'Faculty Team') ...[
                    const SizedBox(height: 8),
                    Text(
                      "Faculty: ${widget.course.teacherName}",
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn(isDark: isDark, 
                        Icons.play_circle_outline,
                        "$effectiveTotalLessons Lessons",
                      ),
                      _buildStatColumn(isDark: isDark, 
                        Icons.access_time,
                        "$effectiveTotalHours+ Hours",
                      ),
                      _buildStatColumn(isDark: isDark, 
                        Icons.quiz_outlined,
                        "${widget.course.totalTests} Tests",
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Description
                  const Text(
                    "About Course",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.course.description,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Class Timings / Batches Selection
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Available Class Timings",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (batches.isNotEmpty)
                        CustomBadge(
                          text: "${batches.length} Timing${batches.length > 1 ? 's' : ''}",
                          variant: BadgeVariant.primary,
                          fontSize: 11,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Select your preferred lecture schedule. All slots cover the complete course curriculum.",
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (batches.isEmpty)
                    const Text(
                      "No class timings scheduled yet.",
                      style: TextStyle(color: AppTheme.textMuted),
                    )
                  else
                    ...batches.map((batch) {
                      final isSelected = _selectedBatch?.id == batch.id;
                      final isThisSlotEnrolled =
                          courseProvider.myEnrolledBatchIds.contains(batch.id);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ModernCard(
                          onTap: () {
                            setState(() {
                              _selectedBatch = batch;
                            });
                          },
                          padding: const EdgeInsets.all(14),
                          backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceSubtle,
                          borderColor: isThisSlotEnrolled
                              ? AppTheme.success
                              : (isSelected ? AppTheme.primary : Colors.transparent),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isSelected
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_unchecked,
                                    color: isSelected
                                        ? AppTheme.primary
                                        : AppTheme.textMuted,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      batch.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                                      ),
                                    ),
                                  ),
                                  if (isThisSlotEnrolled)
                                    const CustomBadge(
                                      text: "ENROLLED",
                                      variant: BadgeVariant.success,
                                      fontSize: 10,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Timing & Days Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.primary.withValues(alpha: 0.15)
                                      : AppTheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isDark
                                        ? AppColors.primary.withValues(alpha: 0.3)
                                        : AppTheme.primary.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.access_time_filled,
                                      size: 14,
                                      color: AppTheme.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        batch.timing,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Faculty, Medium & Capacity
                              Wrap(
                                spacing: 12,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (batch.teacherName.isNotEmpty &&
                                      batch.teacherName != "Faculty Member")
                                    ...batch.teacherName.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).map(
                                      (tName) => Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.person_outline,
                                            size: 13,
                                            color: isDark ? AppColors.darkTextSecondary : AppTheme.textSecondary,
                                          ),
                                          const SizedBox(width: 4),
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(maxWidth: 160),
                                            child: Text(
                                              tName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark ? AppColors.darkTextSecondary : AppTheme.textSecondary,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.translate,
                                        size: 13,
                                        color: isDark ? AppColors.darkTextSecondary : AppTheme.textSecondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        batch.medium,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? AppColors.darkTextSecondary : AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: 24),

                  // Curriculum (Lessons & Recorded Lectures)
                  const Text(
                    "Curriculum",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (lessons.isEmpty && batchRecordings.isEmpty)
                    const Text(
                      "No lessons available yet.",
                      style: TextStyle(color: AppTheme.textMuted),
                    )
                  else ...[
                    if (batchRecordings.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.videocam_rounded, size: 16, color: AppColors.secondary),
                            const SizedBox(width: 6),
                            Text(
                              "Recorded Live Lectures (${batchRecordings.length})",
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...batchRecordings.map((recording) {
                        final durStr = recording.effectiveDuration > Duration.zero
                            ? Formatters.formatDuration(recording.effectiveDuration)
                            : (recording.recordingStatus == 'processing' ? "Finalizing (~60s)" : "Recorded");
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 56,
                              height: 42,
                              child: Container(
                                color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceSubtle,
                                alignment: Alignment.center,
                                child: const Icon(Icons.history_edu_rounded, color: AppColors.secondary, size: 24),
                              ),
                            ),
                          ),
                          title: Text(
                            recording.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Text(
                            "${recording.subject} • $durStr",
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                          ),
                          trailing: canWatch
                              ? const Icon(Icons.play_circle_fill_rounded, color: AppColors.secondary, size: 24)
                              : const Icon(Icons.lock_outline, color: AppTheme.textMuted, size: 20),
                          onTap: () {
                            if (canWatch) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => LiveClassroomScreen(liveClass: recording),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Please enroll to watch this recorded lecture")),
                              );
                            }
                          },
                        );
                      }),
                      if (lessons.isNotEmpty) const Divider(height: 24),
                    ],
                    ...lessons.map((lesson) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: (lesson.thumbnailUrl != null &&
                                lesson.thumbnailUrl!.trim().isNotEmpty &&
                                lesson.thumbnailUrl!.startsWith('http'))
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 56,
                                  height: 42,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.network(
                                        lesson.thumbnailUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => Container(
                                          color: isDark
                                              ? AppColors.darkSurfaceCard
                                              : AppColors.surfaceSubtle,
                                          alignment: Alignment.center,
                                          child: const Icon(
                                            Icons.play_arrow,
                                            size: 20,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        color: Colors.black.withValues(alpha: 0.25),
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.play_circle_fill,
                                          size: 20,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceSubtle,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.play_arrow,
                                  color: AppTheme.primary,
                                ),
                              ),
                        title: Text(
                          lesson.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          "${lesson.chapter} • ${Formatters.formatDuration(lesson.duration)}",
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        trailing: canManage
                            ? const Tooltip(
                                message: "Edit / Watch Lecture",
                                child: Icon(
                                  Icons.edit_note_rounded,
                                  color: AppTheme.primary,
                                  size: 24,
                                ),
                              )
                            : isEnrolled
                            ? const Icon(
                                Icons.check_circle,
                                color: AppTheme.success,
                                size: 20,
                              )
                            : const Icon(
                                Icons.lock_outline,
                                color: AppTheme.textMuted,
                                size: 20,
                              ),
                        onTap: () {
                          if (canWatch) {
                            final targetModel = LiveClassModel(
                              id: lesson.id,
                              courseId: lesson.courseId.isNotEmpty ? lesson.courseId : widget.course.id,
                              batchId: lesson.batchId.isNotEmpty ? lesson.batchId : (_selectedBatch?.id ?? ''),
                              courseName: widget.course.title,
                              batchName: _selectedBatch?.name ?? widget.course.title,
                              title: lesson.title,
                              subject: lesson.chapter,
                              teacherName: _selectedBatch?.teacherName.isNotEmpty == true ? _selectedBatch!.teacherName : 'Faculty',
                              teacherAvatar: '',
                              scheduledStartTime: lesson.uploadedAt,
                              estimatedDuration: lesson.duration,
                              status: LiveStatus.ended,
                              streamUrl: lesson.videoUrl,
                              recordingUrl: lesson.videoUrl,
                              thumbnailUrl: lesson.thumbnailUrl,
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Please enroll to watch this lesson",
                                ),
                              ),
                            );
                          }
                        },
                      );
                    }),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.surfaceCard,
          border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.course.originalPrice > widget.course.price)
                    Text(
                      Formatters.formatCurrency(widget.course.originalPrice),
                      style: const TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  Text(
                    Formatters.formatCurrency(
                      _selectedBatch != null && _selectedBatch!.batchPrice > 0
                          ? _selectedBatch!.batchPrice
                          : widget.course.price,
                    ),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final String buttonLabel;
                    final VoidCallback? buttonOnPressed;
                    final Color buttonColor;

                    if (isEnrolled) {
                      buttonLabel = "ENROLLED";
                      buttonColor = AppTheme.success;
                      buttonOnPressed = () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "You are enrolled in ${_selectedBatch?.name ?? 'this slot'} (${_selectedBatch?.timing ?? ''}). Select a lesson above to start learning.",
                            ),
                          ),
                        );
                      };
                    } else if (isAnySlotEnrolled) {
                      buttonLabel = "ENROLLED IN OTHER SLOT";
                      buttonColor = AppTheme.primary.withValues(alpha: 0.6);
                      buttonOnPressed = () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "You are already enrolled in ${enrolledBatch?.name ?? 'another slot'} (${enrolledBatch?.timing ?? ''}) of this course.",
                            ),
                          ),
                        );
                      };
                    } else {
                      buttonLabel = "ENROLL NOW";
                      buttonColor = AppTheme.primary;
                      buttonOnPressed = () async {
                        if (_selectedBatch == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Please select a class timing slot first"),
                            ),
                          );
                          return;
                        }
                        final result = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CheckoutScreen(
                              course: widget.course,
                              batch: _selectedBatch!,
                            ),
                          ),
                        );

                        if (result == true && context.mounted) {
                          await context
                              .read<CourseProvider>()
                              .fetchMyEnrollments();
                        }
                      };
                    }

                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: buttonOnPressed,
                      child: Text(
                        buttonLabel,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(IconData icon, String text, {bool isDark = false}) {
    return Column(
      children: [
        Icon(icon, color: isDark ? AppColors.darkTextSecondary : AppTheme.textSecondary),
        const SizedBox(height: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
          ),
        ),
      ],
    );
  }
}
