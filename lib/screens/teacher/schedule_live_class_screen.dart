import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/batch_timing_helper.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_button.dart';
import '../../features/courses/data/models/batch_model.dart';
import '../../models/notification_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/live_class_provider.dart';
import '../../providers/notification_provider.dart';
import '../../core/widgets/image_upload_picker_widget.dart';
import 'teacher_broadcast_prototype_screen.dart';

class ScheduleLiveClassScreen extends StatefulWidget {
  const ScheduleLiveClassScreen({super.key});

  @override
  State<ScheduleLiveClassScreen> createState() =>
      _ScheduleLiveClassScreenState();
}

class _ScheduleLiveClassScreenState extends State<ScheduleLiveClassScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _thumbnailUrlController = TextEditingController();
  final TextEditingController _durationMinutesController =
      TextEditingController(text: "90");

  String? _selectedCourseId;
  String? _selectedBatchId;
  final DateTime _scheduledDateTime = DateTime.now().add(const Duration(minutes: 30));

  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _thumbnailUrlController.dispose();
    _durationMinutesController.dispose();
    super.dispose();
  }


  Future<void> _scheduleClass() async {
    if (!_formKey.currentState!.validate()) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final auth = context.read<AuthProvider>();
    final courseProvider = context.read<CourseProvider>();
    final liveProvider = context.read<LiveClassProvider>();
    final notifProvider = context.read<NotificationProvider>();

    final courses = courseProvider.courses;
    final batches = courseProvider.batches;

    if (batches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "No batches available. Please create or assign a batch first.",
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final course =
        courseProvider.getCourseById(_selectedCourseId ?? courses.first.id) ??
        courses.first;
    final batch =
        courseProvider.getBatchById(_selectedBatchId ?? batches.first.id) ??
        batches.first;

    // Slot restriction check for teachers
    final isTeacher = auth.currentUser.role == UserRole.teacher;
    if (isTeacher) {
      final isImmediate =
          _scheduledDateTime.difference(DateTime.now()).inMinutes.abs() <= 30;
      if (isImmediate) {
        final slotCheck = BatchTimingHelper.validateCurrentTimeSlot(
          batch.timing,
        );
        if (!slotCheck.isValid) {
          final shouldProceed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border),
              ),
              title: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.amber,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Slot Restriction",
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                    ),
                  ),
                ],
              ),
              content: Text(
                "Your assigned slot for '${batch.name}' is:\n${batch.timing}\n\n${slotCheck.message}\n\nWould you like to schedule it for your next official slot instead or proceed?",
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(
                    "Adjust Timing",
                    style: AppTypography.button.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text("Schedule Anyway"),
                ),
              ],
            ),
          );

          if (shouldProceed != true) return;
        }
      }
    }

    final durationMins = int.tryParse(_durationMinutesController.text) ?? 90;
    final streamUrl =
        (batch.playbackUrl != null && batch.playbackUrl!.isNotEmpty)
        ? batch.playbackUrl!
        : (batch.streamKey != null && batch.streamKey!.isNotEmpty
              ? batch.streamKey!
              : "cloudflare-auto-stream");

    setState(() => _isSubmitting = true);

    try {
      final thumbnailUrl = _thumbnailUrlController.text.trim();
      final scheduled = await liveProvider.scheduleLiveClass(
        courseId: course.id,
        batchId: batch.id,
        courseName: course.title,
        batchName: batch.name,
        title: _titleController.text.trim(),
        subject: _subjectController.text.trim(),
        teacherName: auth.currentUser.name,
        teacherAvatar: auth.currentUser.avatarUrl ?? "",
        scheduledStartTime: _scheduledDateTime,
        duration: Duration(minutes: durationMins),
        streamUrl: streamUrl,
        teacherId: auth.currentUser.id,
        thumbnailUrl: thumbnailUrl.isNotEmpty ? thumbnailUrl : null,
      );

      final formattedDate = DateFormat(
        'EEE, dd MMM – hh:mm a',
      ).format(_scheduledDateTime);

      // 1. Immediate Broadcast Notification for Scheduled Class
      await notifProvider.broadcastAnnouncement(
        title: "🔴 New Live Class Scheduled: ${_titleController.text.trim()}",
        message:
            "${auth.currentUser.name} scheduled a lecture on '${_subjectController.text.trim()}' for ${batch.name} on $formattedDate.",
        category: NotificationCategory.liveClass,
      );

      // 2. Automated 15-Minute Advance Reminder Notification
      await notifProvider.broadcastAnnouncement(
        title: "⏰ 15-Min Class Reminder: ${_titleController.text.trim()}",
        message:
            "Your upcoming live class '${_titleController.text.trim()}' (${batch.name}) begins in 15 minutes! Please be ready.",
        category: NotificationCategory.liveClass,
      );

      if (mounted) {
        Navigator.pop(context, scheduled);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "✨ Class scheduled for $formattedDate! Students & Teachers notified.",
            ),
            backgroundColor: AppColors.emerald,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to schedule class: $e"),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final courseProvider = context.watch<CourseProvider>();
    final allCourses = courseProvider.courses;
    final allBatches = courseProvider.batches;

    final isTeacher = auth.currentUser.role == UserRole.teacher;
    final teacherBatches = isTeacher
        ? allBatches
              .where(
                (b) =>
                    b.teacherId == auth.currentUser.id ||
                    (b.teacherName.isNotEmpty &&
                        b.teacherName.toLowerCase() ==
                            auth.currentUser.name.toLowerCase()),
              )
              .toList()
        : allBatches;

    final availableBatches = teacherBatches.isNotEmpty
        ? teacherBatches
        : allBatches;
    final availableCourses = allCourses.where((c) {
      return availableBatches.any((b) => b.courseId == c.id);
    }).toList();

    final coursesToDisplay = availableCourses.isNotEmpty
        ? availableCourses
        : allCourses;

    if (_selectedCourseId == null ||
        !coursesToDisplay.any((c) => c.id == _selectedCourseId)) {
      _selectedCourseId = coursesToDisplay.isNotEmpty
          ? coursesToDisplay.first.id
          : null;
    }

    final courseBatches = availableBatches
        .where((b) => b.courseId == _selectedCourseId)
        .toList();
    final batchesToDisplay = courseBatches.isNotEmpty
        ? courseBatches
        : availableBatches;

    if (_selectedBatchId == null ||
        !batchesToDisplay.any((b) => b.id == _selectedBatchId)) {
      _selectedBatchId = batchesToDisplay.isNotEmpty
          ? batchesToDisplay.first.id
          : null;
    }

    final selectedBatch = batchesToDisplay.firstWhere(
      (b) => b.id == _selectedBatchId,
      orElse: () => batchesToDisplay.isNotEmpty
          ? batchesToDisplay.first
          : BatchModel(
              id: '',
              courseId: '',
              name: 'No Batch',
              timing: '08:00 AM - 10:00 AM (Mon-Sat)',
              startDate: DateTime.now(),
              endDate: DateTime.now(),
              teacherName: 'Unassigned',
              teacherId: '',
              totalStudents: 0,
              maxStudents: 500,
              batchPrice: 0,
              medium: 'Bilingual',
            ),
    );

    final slotValidation = BatchTimingHelper.validateCurrentTimeSlot(
      selectedBatch.timing,
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Schedule Live Lecture"),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: isDark ? AppColors.darkBorder : AppColors.border, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "TARGET COURSE & BATCH",
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),

              // Course Dropdown
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _selectedCourseId,
                dropdownColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                decoration: InputDecoration(
                  labelText: "Course Curriculum",
                  prefixIcon: Icon(
                    Icons.school_outlined,
                    size: 20,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                  ),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurface : AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                  ),
                ),
                items: coursesToDisplay
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(
                          c.title,
                          style: AppTypography.bodyMedium.copyWith(
                            color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedCourseId = val;
                    final newBatches = availableBatches
                        .where((b) => b.courseId == val)
                        .toList();
                    if (newBatches.isNotEmpty) {
                      _selectedBatchId = newBatches.first.id;
                    }
                  });
                },
              ),
              const SizedBox(height: 12),

              // Batch Dropdown
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _selectedBatchId,
                dropdownColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                decoration: InputDecoration(
                  labelText: "Assigned Batch",
                  prefixIcon: Icon(
                    Icons.groups_outlined,
                    size: 20,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                  ),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurface : AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                  ),
                ),
                items: batchesToDisplay
                    .map(
                      (b) => DropdownMenuItem(
                        value: b.id,
                        child: Text(
                          "${b.name} (${b.timing})",
                          style: AppTypography.bodyMedium.copyWith(
                            color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedBatchId = val;
                  });
                },
              ),
              const SizedBox(height: 14),

              // Admin Scheduled Slot Badge & Verification Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: slotValidation.isValid
                        ? AppColors.emeraldBorder
                        : AppColors.amberBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_month_rounded,
                              size: 16,
                              color: AppColors.saffronDark,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Admin Assigned Lecture Slot",
                              style: AppTypography.subtitle2.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        CustomBadge(
                          text: slotValidation.isValid
                              ? "Slot Active Now"
                              : "Scheduled Slot",
                          variant: slotValidation.isValid
                              ? BadgeVariant.success
                              : BadgeVariant.warning,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      selectedBatch.timing.isNotEmpty
                          ? selectedBatch.timing
                          : "Slot not configured by admin",
                      style: AppTypography.subtitle1.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.saffronDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      slotValidation.message,
                      style: AppTypography.caption.copyWith(
                        color: slotValidation.isValid
                            ? AppColors.emerald
                            : AppColors.textMuted,
                      ),
                    ),
                    if (selectedBatch.teacherName.isNotEmpty &&
                        selectedBatch.teacherName != "Unassigned")
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          "Assigned Faculty: ${selectedBatch.teacherName}",
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Title & Subject Information
              Text(
                "CLASS INFORMATION",
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: "Live Class Title *",
                  hintText: "e.g. Masterclass on Bihar Geography & Rivers",
                  prefixIcon: Icon(
                    Icons.title,
                    size: 20,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                  ),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurface : AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                  ),
                ),
                validator: (val) => (val == null || val.trim().isEmpty)
                    ? "Please enter class title"
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _subjectController,
                decoration: InputDecoration(
                  labelText: "Subject / Topic *",
                  hintText: "e.g. Geography / GS Paper 1",
                  prefixIcon: Icon(
                    Icons.book_outlined,
                    size: 20,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                  ),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurface : AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                  ),
                ),
                validator: (val) => (val == null || val.trim().isEmpty)
                    ? "Please enter subject"
                    : null,
              ),
              const SizedBox(height: 14),

              // Thumbnail Image (Poster)
              Text(
                "LECTURE THUMBNAIL (POSTER)",
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              ImageUploadPickerWidget(
                controller: _thumbnailUrlController,
                labelText: "Live Lecture Thumbnail Poster",
                hintText: "https://.../thumbnail.jpg",
                helperText: "Visual poster for live stream card & classroom screen",
                enabled: !_isSubmitting,
                onUpload: (fileName, bytes) async {
                  final liveProvider = context.read<LiveClassProvider>();
                  return await liveProvider.uploadLiveClassThumbnail(
                    fileName: fileName,
                    fileBytes: bytes,
                  );
                },
              ),
              const SizedBox(height: 14),

              // Admin Governed Schedule Information
              Text(
                "ADMIN SCHEDULED TIMING",
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      color: AppColors.saffronDark,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Fixed Batch Slot: ${selectedBatch.timing}",
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Today, ${DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now())}",
                            style: AppTypography.caption.copyWith(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Automated Streaming Pipeline
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppColors.saffronMuted,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.cell_tower,
                        color: AppColors.saffronDark,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Live Stream Pipeline",
                            style: AppTypography.subtitle2.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            (selectedBatch.playbackUrl != null &&
                                    selectedBatch.playbackUrl!.isNotEmpty)
                                ? "Dedicated Batch Stream Key & Playback URL configured."
                                : "Inherited from Institute Cloudflare Live Stream Settings.",
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.emerald,
                      size: 18,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Combined Go Live Button
              ModernButton(
                text: _isSubmitting
                    ? "Launching Broadcast..."
                    : (slotValidation.isValid
                        ? "🔴 Go Live Now in Studio"
                        : "Launch Live Studio Stream"),
                width: double.infinity,
                icon: Icons.cell_tower_rounded,
                isLoading: _isSubmitting,
                variant: slotValidation.isValid ? ButtonVariant.danger : ButtonVariant.primary,
                onPressed: _isSubmitting
                    ? null
                    : () async {
                        final nav = Navigator.of(context);
                        await _scheduleClass();
                        if (!mounted) return;
                        nav.pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const TeacherBroadcastPrototypeScreen(),
                          ),
                        );
                      },
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  "Enrolled students and teachers automatically receive live & 15-min reminder alerts.",
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
