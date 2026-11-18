import 'package:flutter/material.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../features/courses/data/models/batch_model.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/utils/batch_timing_helper.dart';
import '../../core/widgets/batch_timing_picker_dialog.dart';
import '../../core/widgets/modern_card.dart';
import '../../core/widgets/multi_teacher_selector.dart';
import '../../models/course_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/course_provider.dart';
import 'course_creation_wizard_dialog.dart';
import '../../core/widgets/image_upload_picker_widget.dart';
import '../../core/widgets/stepped_price_input_field.dart';

String _sanitizeForLog(dynamic err) {
  if (err == null) return '';
  String s = err.toString();
  s = s.replaceAllMapped(
    RegExp(r'(https?|rtmps?)://([^:@\s]+):([^@\s]+)@', caseSensitive: false),
    (m) => '${m[1]}://***:***@',
  );
  s = s.replaceAllMapped(
    RegExp(r'([?&](?:token|key|secret|apiKey|api_key|auth)=)[^&\s]+', caseSensitive: false),
    (m) => '${m[1]}***masked***',
  );
  return s;
}

class ManageCoursesScreen extends StatefulWidget {
  const ManageCoursesScreen({super.key});

  @override
  State<ManageCoursesScreen> createState() => _ManageCoursesScreenState();
}

class _ManageCoursesScreenState extends State<ManageCoursesScreen> {
  static bool _checkStreamKeyCollisionStatic({
    required BuildContext parentContext,
    required String? currentBatchId,
    required String streamKey,
    required String playbackUrl,
  }) {
    if (streamKey.isEmpty && playbackUrl.isEmpty) return false;
    final batches = parentContext.read<CourseProvider>().batches;
    for (final other in batches) {
      if (currentBatchId != null && other.id == currentBatchId) continue;
      final matchKey = streamKey.isNotEmpty && other.streamKey != null && other.streamKey!.trim() == streamKey;
      final matchPlayback = playbackUrl.isNotEmpty && other.playbackUrl != null && other.playbackUrl!.trim() == playbackUrl;
      if (matchKey || matchPlayback) {
        final isDark = Theme.of(parentContext).brightness == Brightness.dark;
        showDialog(
          context: parentContext,
          builder: (c) => AlertDialog(
            backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
            ),
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Live Stream Collision Warning",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "This Cloudflare Stream Key or Playback URL is already assigned to another batch:",
                  style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.amberBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.amberBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        other.name,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Schedule: ${other.timing}",
                        style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "If two batches broadcast at the same time using identical stream keys, the streams will collide and disconnect students.",
                  style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  "Action Required:\n"
                  "1. Assign a distinct Cloudflare Stream Key & Playback URL for this batch, OR\n"
                  "2. Change class timings so that the two classes never run at the same time.",
                  style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.primary : AppColors.deepInk,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () => Navigator.pop(c),
                child: const Text("Adjust Details"),
              ),
            ],
          ),
        );
        return true;
      }
    }
    return false;
  }

  void _showAddCourseDialog(BuildContext context) {
    CourseCreationWizardDialog.show(context);
  }

  Future<void> _confirmDeleteCourse(BuildContext context, CourseModel course) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final batches = context.read<CourseProvider>().getBatchesForCourse(course.id);
    final confirmCtrl = TextEditingController();
    bool canDelete = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor:
              isDark ? AppColors.darkSurfaceCard : AppColors.surface,
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
              SizedBox(width: 8),
              Text('Delete Course?'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to permanently delete "${course.title}"?',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Text(
                  'Warning: Deleting this course will permanently remove all associated batches (${batches.length}), recorded lessons, study material PDFs, tests, scheduled live streams, and student enrollments.\n\nThis action cannot be undone.',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 16),
                Text(
                  'Type CONFIRM to proceed with deletion:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: "CONFIRM",
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.error, width: 2),
                    ),
                  ),
                  onChanged: (val) {
                    setDialogState(() {
                      canDelete = val.trim() == "CONFIRM";
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.error.withValues(alpha: 0.3),
                disabledForegroundColor: Colors.white70,
              ),
              onPressed: canDelete ? () => Navigator.of(dialogCtx).pop(true) : null,
              child: const Text('Delete Course'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await context.read<CourseProvider>().deleteCourse(course.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Course "${course.title}" deleted successfully.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete course: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _confirmDeleteBatch(
    BuildContext context,
    BatchModel batch,
    String courseTitle,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (batch.totalStudents > 0) {
      await showDialog<void>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, color: AppColors.error, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Cannot Delete Timing Slot",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This timing slot currently has ${batch.totalStudents} enrolled student(s):',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      batch.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      batch.timing,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Deleting a slot with active enrollments causes student data loss and orphaned records. To safely remove this slot, transfer enrolled students to another slot or resolve enrollments first.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text("Understood"),
            ),
          ],
        ),
      );
      return;
    }

    final confirmCtrl = TextEditingController();
    bool canDelete = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.delete_outline, color: AppColors.error, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Delete Batch?",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to permanently delete the batch "${batch.name}" (${batch.timing}) for "$courseTitle"?\n\nNo students are enrolled in this batch.',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                Text(
                  'Type CONFIRM to proceed with deletion:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: "CONFIRM",
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.error, width: 2),
                    ),
                  ),
                  onChanged: (val) {
                    setDialogState(() {
                      canDelete = val.trim() == "CONFIRM";
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.error.withValues(alpha: 0.3),
                disabledForegroundColor: Colors.white70,
              ),
              onPressed: canDelete ? () => Navigator.of(dialogCtx).pop(true) : null,
              child: const Text("Delete Batch"),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await context.read<CourseProvider>().deleteBatch(batch.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Batch "${batch.name}" deleted successfully!'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete batch: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _createDefaultBatchForCourse(
    BuildContext context,
    CourseModel course,
  ) async {
    final courseProvider = context.read<CourseProvider>();
    final newBatch = BatchModel(
      id: "",
      courseId: course.id,
      name: "${course.title} - Batch 1",
      timing: "08:00 AM - 10:00 AM (Mon-Sat)",
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 90)),
      teacherName: "Unassigned",
      teacherId: "",
      totalStudents: 0,
      maxStudents: 500,
      batchPrice: course.price,
      medium: "Bilingual (Hindi + English)",
    );

    try {
      await courseProvider.addBatch(newBatch);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✅ Batch 1 created for ${course.title}!"),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to create batch: $e"),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _handleAddScheduleDirectly(
    BuildContext context,
    CourseModel course,
  ) async {
    final courseProvider = context.read<CourseProvider>();
    final batches = courseProvider.getBatchesForCourse(course.id);

    final existingTimings = batches.map((b) => b.timing).toList();
    final picked = await BatchTimingPickerDialog.show(
      context,
      initialTiming: "04:00 PM - 06:00 PM (Mon-Sat)",
      existingTimings: existingTimings,
    );
    if (picked == null || !context.mounted) return;

    final overlap = BatchTimingHelper.findOverlappingTiming(picked, existingTimings);
    if (overlap != null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text("Timing overlaps with existing course slot: $overlap. Two slots cannot have overlapping class hours."),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    final slotNumber = batches.length + 1;
    final newBatch = BatchModel(
      id: "",
      courseId: course.id,
      name: "${course.title} - Batch $slotNumber",
      timing: picked,
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 90)),
      teacherName: course.teacherName.isNotEmpty ? course.teacherName : "Faculty Member",
      teacherId: course.teacherId,
      totalStudents: 0,
      maxStudents: 500,
      batchPrice: course.price,
      medium: "Bilingual (Hindi + English)",
    );

    try {
      await courseProvider.addBatch(newBatch);
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text("✅ Added schedule: $picked for ${course.title}!"),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text("Failed to add schedule: $e"),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  void _showAddBatchDialog(
    BuildContext context,
    String courseId,
    String courseTitle, [
    double? coursePrice,
    List<UserModel>? preloadedTeachers,
  ]) async {
    if (!context.mounted) return;

    List<UserModel> teachers = preloadedTeachers ?? [];
    if (teachers.isEmpty) {
      try {
        final authProvider = context.read<AuthProvider>();
        final all = await authProvider.getAllProfiles();
        teachers = all.where((u) => u.role == UserRole.teacher).toList();
      } catch (_) {}
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AddBatchDialog(
        courseId: courseId,
        courseTitle: courseTitle,
        coursePrice: coursePrice,
        teachers: teachers,
      ),
    );
  }

  void _showEditCourseAndBatchDialog(
    BuildContext context,
    CourseModel course, {
    BatchModel? batch,
  }) async {
    final authProvider = context.read<AuthProvider>();
    final courseProvider = context.read<CourseProvider>();

    List<UserModel> teachers = [];
    try {
      final all = await authProvider.getAllProfiles();
      teachers = all.where((u) => u.role == UserRole.teacher).toList();
    } catch (_) {}

    final batches = courseProvider.getBatchesForCourse(course.id);
    final targetBatch = batch ??
        (batches.isNotEmpty
            ? batches.first
            : BatchModel(
                id: '',
                courseId: course.id,
                name: '${course.title} - Batch 1',
                timing: '10:00 AM - 12:00 PM (Mon-Sat)',
                startDate: DateTime.now(),
                endDate: DateTime.now().add(const Duration(days: 90)),
                teacherName: 'Unassigned',
                teacherId: '',
                totalStudents: 0,
                batchPrice: course.price,
                medium: 'Bilingual (Hindi + English)',
              ));

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _EditBatchDialog(
        course: course,
        batch: targetBatch,
        courseTitle: course.title,
        teachers: teachers,
        onAddBatch: (c, cId, cTitle, cPrice) => _showAddBatchDialog(c, cId, cTitle, cPrice),
      ),
    );
  }

  void _showEditSubjectsDialog(BuildContext context, CourseModel course) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subjectsList = List<String>.from(course.subjects);
    final textCtrl = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.menu_book_rounded, color: AppColors.saffronDark, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Course Subjects",
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.primaryLight : AppColors.saffronDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Add or remove academic subjects for this course. These subjects directly populate 'Ask Doubts' for enrolled students.",
                      style: AppTypography.caption.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: textCtrl,
                            decoration: InputDecoration(
                              hintText: "Add subject (e.g. History, Polity)",
                              isDense: true,
                              prefixIcon: const Icon(Icons.menu_book_rounded, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            enabled: !isSaving,
                            onSubmitted: (val) {
                              final trimmed = val.trim();
                              if (trimmed.isNotEmpty && !subjectsList.contains(trimmed)) {
                                setDialogState(() {
                                  subjectsList.add(trimmed);
                                  textCtrl.clear();
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.deepInk,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: isSaving
                              ? null
                              : () {
                                  final trimmed = textCtrl.text.trim();
                                  if (trimmed.isNotEmpty && !subjectsList.contains(trimmed)) {
                                    setDialogState(() {
                                      subjectsList.add(trimmed);
                                      textCtrl.clear();
                                    });
                                  }
                                },
                          child: const Text("Add"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Current Subjects (${subjectsList.length}):",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (subjectsList.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                        ),
                        child: Text(
                          "No subjects configured yet. Add custom subjects above or select from presets below.",
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: subjectsList.map((sub) {
                          return Chip(
                            label: Text(sub, style: const TextStyle(fontSize: 12)),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: isSaving
                                ? null
                                : () {
                                    setDialogState(() {
                                      subjectsList.remove(sub);
                                    });
                                  },
                            backgroundColor: isDark ? AppColors.darkSurface : AppColors.warmIvory,
                            side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 14),
                    Text(
                      "Quick Preset Suggestions:",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        "History",
                        "Geography",
                        "Polity",
                        "Economy",
                        "General Science",
                        "Current Affairs",
                        "Mathematics",
                        "Reasoning",
                        "Bihar Special",
                        "Hindi",
                        "English",
                      ].where((s) => !subjectsList.contains(s)).map((preset) {
                        return ActionChip(
                          avatar: const Icon(Icons.add, size: 14, color: AppColors.saffronDark),
                          label: Text(preset, style: const TextStyle(fontSize: 11)),
                          backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
                          onPressed: isSaving
                              ? null
                              : () {
                                  setDialogState(() {
                                    subjectsList.add(preset);
                                  });
                                },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.saffronDark,
                  foregroundColor: Colors.white,
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        setDialogState(() => isSaving = true);
                        try {
                          final updatedCourse = course.copyWith(subjects: subjectsList);
                          await context.read<CourseProvider>().updateCourse(updatedCourse);
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Course subjects updated successfully!"),
                              backgroundColor: AppColors.emerald,
                            ),
                          );
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text("Failed to update subjects: $e"),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text("Save Subjects"),
              ),
            ],
          );
        },
      ),
    );
  }

void _showCourseCouponsDialog(BuildContext context, CourseModel course) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final courseProvider = context.read<CourseProvider>();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final coupons = courseProvider.coupons;

          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.discount_rounded, color: AppTheme.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Coupons for Course",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width > 600 ? 500 : double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.school, size: 16, color: AppColors.saffronDark),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              course.title,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      "Coupons Available (${coupons.length}):",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Toggle coupons on or off to make them eligible for this course.",
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 10),
                    if (coupons.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text("No coupons created yet in the system.", style: TextStyle(fontSize: 12)),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: coupons.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final c = coupons[idx];
                          final isUniversal = c.applicableCourseIds.isEmpty;
                          final isLinked = c.applicableCourseIds.contains(course.id);

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurface : AppColors.warmIvory,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: (isUniversal || isLinked)
                                    ? AppTheme.primary.withValues(alpha: 0.3)
                                    : (isDark ? AppColors.darkBorder : AppColors.border),
                              ),
                            ),
                            child: Row(
                              children: [
                                CustomBadge(
                                  text: c.code,
                                  variant: BadgeVariant.primary,
                                  fontSize: 11,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Save ₹${c.discountAmount.toInt()} (Min: ₹${c.minOrderValue.toInt()})",
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        isUniversal
                                            ? "Universal: Active on ALL courses"
                                            : (isLinked
                                                ? "Active on this course"
                                                : "Restricted (Not active on this course)"),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: isUniversal
                                              ? AppTheme.success
                                              : (isLinked ? AppTheme.primary : AppTheme.textMuted),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isUniversal)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppTheme.success.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      "All Courses",
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.success,
                                      ),
                                    ),
                                  )
                                else
                                  Switch(
                                    value: isLinked,
                                    activeThumbColor: AppTheme.primary,
                                    onChanged: (val) {
                                      setDialogState(() {
                                        courseProvider.toggleCouponCourseEligibility(c.code, course.id);
                                      });
                                    },
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Done"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditBatchDialog(
    BuildContext context,
    BatchModel batch,
    String courseTitle,
  ) async {
    final courseProvider = context.read<CourseProvider>();
    CourseModel? course;
    try {
      course = courseProvider.courses.firstWhere((c) => c.id == batch.courseId);
    } catch (_) {
      course = CourseModel(
        id: batch.courseId,
        title: courseTitle,
        category: 'General',
        description: '',
        coverImageUrl: '',
        price: batch.batchPrice,
        originalPrice: batch.batchPrice,
        teacherName: batch.teacherName,
        teacherId: batch.teacherId,
        totalLessons: 10,
        totalHours: 20,
        totalTests: 0,
        totalNotes: 0,
        highlights: const [],
        isFeatured: false,
      );
    }

    _showEditCourseAndBatchDialog(context, course, batch: batch);
  }
  @override
  Widget build(BuildContext context) {
    final courseProvider = context.watch<CourseProvider>();
    final courses = courseProvider.courses;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Curriculum & Batch Directory"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: isDark ? AppColors.darkBorder : AppColors.border, height: 1),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.saffron,
        foregroundColor: isDark ? Colors.black : AppColors.deepInk,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text(
          "Add Course",
          style: AppTypography.button.copyWith(fontWeight: FontWeight.w700),
        ),
        onPressed: () => _showAddCourseDialog(context),
      ),
      body: courseProvider.isLoading && courses.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.saffronDark),
            )
          : (courseProvider.errorMessage != null && courses.isEmpty)
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    courseProvider.errorMessage!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => courseProvider.fetchCatalog(),
                    child: const Text("Retry"),
                  ),
                ],
              ),
            )
          : courses.isEmpty
          ? const Center(
              child: AppEmptyState(
                icon: Icons.school_outlined,
                title: "No Courses Created",
                description:
                    "Tap '+ Add Course' to initialize the institute curriculum and batch offerings.",
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              itemCount: courses.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final course = courses[index];
                final batches = courseProvider.getBatchesForCourse(course.id);

                return ModernCard(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                  accentSpineColor: AppColors.saffron,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CustomBadge(
                                  text: course.category,
                                  variant: BadgeVariant.primary,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  course.title,
                                  style: AppTypography.titleMedium.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            Formatters.formatCurrency(course.price),
                            style: AppTypography.titleLarge.copyWith(
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppColors.primaryLight : AppColors.saffronDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${course.totalLessons} Lessons • ${course.totalTests} Tests • ${batches.length} active batches",
                        style: AppTypography.caption.copyWith(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Course Subjects Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.menu_book_rounded, size: 14, color: AppColors.saffronDark),
                              const SizedBox(width: 5),
                              Text(
                                "Subjects (${course.subjects.length}):",
                                style: AppTypography.caption.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            key: Key('edit_subjects_${course.id}'),
                            onTap: () => _showEditSubjectsDialog(context, course),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.edit, size: 12, color: AppColors.saffronDark),
                                  const SizedBox(width: 3),
                                  Text(
                                    "Edit Subjects",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? AppColors.primaryLight : AppColors.saffronDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Course Management Actions (Coupons & Delete)
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          InkWell(
                            key: Key('course_coupons_${course.id}'),
                            onTap: () => _showCourseCouponsDialog(context, course),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.primary.withValues(alpha: 0.15) : AppColors.saffronMuted,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isDark
                                      ? AppColors.primaryLight.withValues(alpha: 0.3)
                                      : AppColors.saffron.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.discount_outlined, size: 13, color: AppTheme.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Coupons (${courseProvider.getCouponsForCourse(course.id).length})",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? AppColors.primaryLight : AppTheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          InkWell(
                            key: Key('delete_course_${course.id}'),
                            onTap: () => _confirmDeleteCourse(context, course),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.errorBg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.errorBorder),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.delete_outline, size: 13, color: AppColors.error),
                                  SizedBox(width: 4),
                                  Text(
                                    "Delete Course",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (course.subjects.isNotEmpty)
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: course.subjects.map((sub) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkSurface : AppColors.warmIvory,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                              ),
                              child: Text(
                                sub,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                                ),
                              ),
                            );
                          }).toList(),
                        )
                      else
                        InkWell(
                          key: Key('add_subjects_placeholder_${course.id}'),
                          onTap: () => _showEditSubjectsDialog(context, course),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurface : AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_circle_outline, size: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                                const SizedBox(width: 5),
                                Text(
                                  "No subjects configured. Tap here to add subjects.",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 14),
                      Container(height: 1, color: isDark ? AppColors.darkBorder : AppColors.border),
                      const SizedBox(height: 10),

                      // Batches Header
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            "Class Timings & Batches (${batches.length})",
                            style: AppTypography.subtitle2.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            ),
                            icon: const Icon(Icons.add, size: 15, color: AppTheme.primary),
                            label: const Text(
                              "Add Schedule / Timing",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                            ),
                            onPressed: () => _handleAddScheduleDirectly(context, course),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (batches.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  "No batches created yet.",
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textMuted,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.saffronMuted,
                                  foregroundColor: AppColors.saffronDark,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  minimumSize: const Size(0, 28),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                onPressed: () => _createDefaultBatchForCourse(
                                  context,
                                  course,
                                ),
                                icon: const Icon(
                                  Icons.flash_on_rounded,
                                  size: 14,
                                ),
                                label: Text(
                                  "Create Default Batch",
                                  style: AppTypography.button.copyWith(
                                    fontSize: 11,
                                    color: AppColors.saffronDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Column(
                          children: batches
                              .map(
                                (b) => InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => _showEditBatchDialog(
                                    context,
                                    b,
                                    course.title,
                                  ),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.darkSurface : AppColors.warmIvory,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isDark ? AppColors.darkBorder : AppColors.border,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                b.name,
                                                style: AppTypography.subtitle2
                                                    .copyWith(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                                                    ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                "${b.timing} • ${b.medium}",
                                                style: AppTypography.caption
                                                    .copyWith(
                                                      color: AppColors
                                                          .textSecondary,
                                                    ),
                                              ),
                                              if (b.teacherName.isNotEmpty &&
                                                  b.teacherName !=
                                                      "Faculty Member")
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 2,
                                                      ),
                                                  child: Text(
                                                    "Teacher: ${b.teacherName}",
                                                    style: AppTypography.caption
                                                        .copyWith(
                                                          color: AppColors
                                                              .saffronDark,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  Formatters.formatCurrency(
                                                    b.batchPrice,
                                                  ),
                                                  style: AppTypography.subtitle2
                                                      .copyWith(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: AppColors
                                                            .saffronDark,
                                                      ),
                                                ),
                                                Text(
                                                  "${b.totalStudents} Enrolled",
                                                  style: AppTypography.caption
                                                      .copyWith(
                                                        color:
                                                            AppColors.textMuted,
                                                        fontSize: 10,
                                                      ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(width: 8),

                                            IconButton(
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                                size: 18,
                                                color: AppColors.saffronDark,
                                              ),
                                              tooltip: "Edit Batch",
                                              constraints:
                                                  const BoxConstraints(),
                                              padding: const EdgeInsets.all(4),
                                              onPressed: () =>
                                                  _showEditBatchDialog(
                                                    context,
                                                    b,
                                                    course.title,
                                                  ),
                                            ),
                                            const SizedBox(width: 4),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                size: 18,
                                                color: AppColors.error,
                                              ),
                                              tooltip: "Delete Timing Slot",
                                              constraints:
                                                  const BoxConstraints(),
                                              padding: const EdgeInsets.all(4),
                                              onPressed: () =>
                                                  _confirmDeleteBatch(
                                                    context,
                                                    b,
                                                    course.title,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}


class _AddBatchDialog extends StatefulWidget {
  final String courseId;
  final String courseTitle;
  final double? coursePrice;
  final List<UserModel> teachers;

  const _AddBatchDialog({
    required this.courseId,
    required this.courseTitle,
    this.coursePrice,
    required this.teachers,
  });

  @override
  State<_AddBatchDialog> createState() => _AddBatchDialogState();
}

class _AddBatchDialogState extends State<_AddBatchDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _timingCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _streamKeyCtrl;
  late final TextEditingController _playbackUrlCtrl;
  late final TextEditingController _rtmpsUrlCtrl;

  late final FocusNode _nameFocus;
  late final FocusNode _timingFocus;
  late final FocusNode _priceFocus;
  late final FocusNode _streamKeyFocus;
  late final FocusNode _playbackUrlFocus;
  late final FocusNode _rtmpsUrlFocus;
  late final TextEditingController _maxStudentsCtrl;
  late final FocusNode _maxStudentsFocus;

  String _selectedMedium = "Bilingual (Hindi + English)";
  List<String> _selectedTeacherIds = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _timingCtrl = TextEditingController();
    _priceCtrl = TextEditingController(
      text: widget.coursePrice != null && widget.coursePrice! > 0
          ? widget.coursePrice!.toInt().toString()
          : "",
    );
    _streamKeyCtrl = TextEditingController();
    _playbackUrlCtrl = TextEditingController();
    _rtmpsUrlCtrl = TextEditingController();
    _maxStudentsCtrl = TextEditingController(text: "500");

    _nameFocus = FocusNode();
    _timingFocus = FocusNode();
    _streamKeyFocus = FocusNode();
    _playbackUrlFocus = FocusNode();
    _rtmpsUrlFocus = FocusNode();
    _maxStudentsFocus = FocusNode();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _timingCtrl.dispose();
    _priceCtrl.dispose();
    _streamKeyCtrl.dispose();
    _playbackUrlCtrl.dispose();
    _rtmpsUrlCtrl.dispose();
    _maxStudentsCtrl.dispose();

    _nameFocus.dispose();
    _timingFocus.dispose();
    _priceFocus.dispose();
    _streamKeyFocus.dispose();
    _playbackUrlFocus.dispose();
    _rtmpsUrlFocus.dispose();
    _maxStudentsFocus.dispose();
    super.dispose();
  }

  Future<void> _handleCreateBatch() async {
    if (_nameCtrl.text.trim().isEmpty || _timingCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Batch name and timing are required"),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    final existingBatches = context.read<CourseProvider>().getBatchesForCourse(widget.courseId);
    final existingTimings = existingBatches.map((b) => b.timing).toList();
    final overlap = BatchTimingHelper.findOverlappingTiming(_timingCtrl.text.trim(), existingTimings);
    if (overlap != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Timing overlaps with existing course slot: $overlap. Two slots cannot have overlapping class hours."),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    final ef = int.tryParse(_priceCtrl.text.replaceAll('₹', '').trim());
    if (ef == null || ef < 9 || ef > 3199 || (ef - 9) % 10 != 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Batch Fee must be in steps of 10 ending in 9 (₹9 to ₹3199)"),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    final enteredFee = ef.toDouble();

    final rtmpsUrl = _rtmpsUrlCtrl.text.trim();
    if (rtmpsUrl.isNotEmpty) {
      final rtmpsErr = BatchTimingHelper.validateRtmpsUrl(rtmpsUrl);
      if (rtmpsErr != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(rtmpsErr),
            backgroundColor: AppTheme.error,
          ),
        );
        return;
      }
    }

    final collision = _ManageCoursesScreenState._checkStreamKeyCollisionStatic(
      parentContext: context,
      currentBatchId: null,
      streamKey: _streamKeyCtrl.text.trim(),
      playbackUrl: _playbackUrlCtrl.text.trim(),
    );
    if (collision) return;

    setState(() => _isSubmitting = true);

    final courseProvider = context.read<CourseProvider>();
    final teacherNames = _selectedTeacherIds
        .map((id) => widget.teachers.firstWhere(
              (t) => t.id == id,
              orElse: () => UserModel(
                id: id,
                email: '',
                phone: '',
                name: 'Faculty',
                role: UserRole.teacher,
              ),
            ).name)
        .join(', ');

    final newBatch = BatchModel(
      id: "", // Stripped by DB
      courseId: widget.courseId,
      name: _nameCtrl.text.trim(),
      timing: _timingCtrl.text.trim(),
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 90)),
      teacherName: teacherNames.isNotEmpty ? teacherNames : "Unassigned",
      teacherId: _selectedTeacherIds.isNotEmpty ? _selectedTeacherIds.first : "",
      totalStudents: 0,
      maxStudents: int.tryParse(_maxStudentsCtrl.text) ?? 500,
      batchPrice: enteredFee,
      medium: _selectedMedium,
      streamKey: _streamKeyCtrl.text.trim().isNotEmpty
          ? _streamKeyCtrl.text.trim()
          : null,
      playbackUrl: _playbackUrlCtrl.text.trim().isNotEmpty
          ? _playbackUrlCtrl.text.trim()
          : null,
      rtmpsUrl: rtmpsUrl.isNotEmpty ? rtmpsUrl : null,
      teacherIds: _selectedTeacherIds,
    );

    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await courseProvider.addBatch(newBatch, teacherIds: _selectedTeacherIds);
      if (mounted) {
        nav.pop(true);
        messenger.showSnackBar(
          const SnackBar(
            content: Text("✅ Batch created successfully!"),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.fixed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text("Failed to create batch: $e"),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final isCompact = keyboardHeight > 60 || isLandscape || mediaQuery.size.height < 500;
    final verticalInset = isLandscape ? 4.0 : (isCompact ? 8.0 : 20.0);
    final availableHeight = mediaQuery.size.height - keyboardHeight - (verticalInset * 2);

    return Dialog(
      backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isLandscape ? 32 : (mediaQuery.size.width < 360 ? 12 : 20),
        vertical: verticalInset,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: availableHeight > 50 ? availableHeight : 300.0,
        ),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.symmetric(
            horizontal: isLandscape ? 20 : 16,
            vertical: isCompact ? 10 : 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.add_circle_outline, color: AppTheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Create Batch for ${widget.courseTitle}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 12),
              TextField(
                controller: _nameCtrl,
                focusNode: _nameFocus,
                scrollPadding: const EdgeInsets.only(bottom: 80),
                decoration: const InputDecoration(
                  labelText: "Batch Name *",
                  hintText: "e.g. Morning Target Batch A",
                ),
                enabled: !_isSubmitting,
              ),
              const SizedBox(height: 10),
              InkWell(
                focusNode: _timingFocus,
                onTap: _isSubmitting
                    ? null
                    : () async {
                        final existingTimings = context.read<CourseProvider>()
                            .getBatchesForCourse(widget.courseId)
                            .map((b) => b.timing)
                            .toList();
                        final picked = await BatchTimingPickerDialog.show(
                          context,
                          initialTiming: _timingCtrl.text.isNotEmpty
                              ? _timingCtrl.text
                              : "08:00 AM - 10:00 AM (Mon-Sat)",
                          existingTimings: existingTimings,
                        );
                        if (picked != null && mounted) {
                          setState(() => _timingCtrl.text = picked);
                        }
                      },
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: "Batch Schedule (Hours & Days) *",
                    hintText: "Tap to configure class hours & days",
                    prefixIcon: Icon(
                      Icons.calendar_month,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                    suffixIcon: Icon(
                      Icons.edit_calendar,
                      color: AppTheme.primary,
                      size: 18,
                    ),
                  ),
                  child: Text(
                    _timingCtrl.text.isNotEmpty
                        ? _timingCtrl.text
                        : "Tap to configure hours & days",
                    style: TextStyle(
                      color: _timingCtrl.text.isNotEmpty
                          ? (isDark ? Colors.white : Colors.black87)
                          : AppTheme.textMuted,
                      fontWeight: _timingCtrl.text.isNotEmpty
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SteppedPriceInputField(
                controller: _priceCtrl,
                focusNode: _priceFocus,
                scrollPadding: const EdgeInsets.only(bottom: 80),
                labelText: "Batch Fee (₹) *",
                hintText: "e.g. 1999",
                isCoursePrice: true,
                minPrice: 9,
                maxPrice: 3199,
                enabled: !_isSubmitting,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedMedium,
                      decoration: const InputDecoration(
                        labelText: "Medium",
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: "Bilingual (Hindi + English)",
                          child: Text(
                            "Bilingual",
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: "Hindi",
                          child: Text("Hindi", overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: "English",
                          child: Text("English", overflow: TextOverflow.ellipsis),
                        ),
                      ],
                      onChanged: _isSubmitting
                          ? null
                          : (val) {
                              if (val != null) {
                                setState(() => _selectedMedium = val);
                              }
                            },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _maxStudentsCtrl,
                      focusNode: _maxStudentsFocus,
                      scrollPadding: const EdgeInsets.only(bottom: 80),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Max Students",
                        hintText: "500",
                      ),
                      enabled: !_isSubmitting,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              MultiTeacherSelector(
                allTeachers: widget.teachers,
                selectedTeacherIds: _selectedTeacherIds,
                enabled: !_isSubmitting,
                onChanged: (ids) => setState(() => _selectedTeacherIds = ids),
              ),
              const SizedBox(height: 14),
              Divider(color: isDark ? AppColors.darkBorder : AppColors.border),
              const SizedBox(height: 6),
              const Text(
                "Dedicated Live Stream (Optional)",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                "Dedicated Cloudflare Stream credentials for this batch schedule.",
                style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _streamKeyCtrl,
                focusNode: _streamKeyFocus,
                scrollPadding: const EdgeInsets.only(bottom: 80),
                decoration: const InputDecoration(
                  labelText: "Custom Stream Key (Optional)",
                  hintText: "e.g. 64-char key for concurrent class",
                  isDense: true,
                ),
                enabled: !_isSubmitting,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _playbackUrlCtrl,
                focusNode: _playbackUrlFocus,
                scrollPadding: const EdgeInsets.only(bottom: 80),
                decoration: const InputDecoration(
                  labelText: "Custom Playback HLS URL (Optional)",
                  hintText: "https://.../manifest/video.m3u8",
                  isDense: true,
                ),
                enabled: !_isSubmitting,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _rtmpsUrlCtrl,
                focusNode: _rtmpsUrlFocus,
                scrollPadding: const EdgeInsets.only(bottom: 80),
                decoration: const InputDecoration(
                  labelText: "RTMPS URL",
                  hintText: "Enter RTMPS streaming URL",
                  isDense: true,
                ),
                enabled: !_isSubmitting,
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    ),
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.black,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                    onPressed: _isSubmitting ? null : _handleCreateBatch,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Text(
                            "Create Batch",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditBatchDialog extends StatefulWidget {
  final CourseModel? course;
  final BatchModel batch;
  final String courseTitle;
  final List<UserModel> teachers;
  final void Function(BuildContext context, String courseId, String courseTitle, double? coursePrice)? onAddBatch;

  const _EditBatchDialog({
    this.course,
    required this.batch,
    required this.courseTitle,
    required this.teachers,
    this.onAddBatch,
  });

  @override
  State<_EditBatchDialog> createState() => _EditBatchDialogState();
}

class _EditBatchDialogState extends State<_EditBatchDialog> {
  late BatchModel _currentBatch;

  // Course form controllers & focus nodes
  late final TextEditingController _titleCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _coursePriceCtrl;
  late final TextEditingController _originalPriceCtrl;
  late final TextEditingController _highlightsCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _coverImageUrlCtrl;
  late final TextEditingController _totalHoursCtrl;
  late final TextEditingController _totalLessonsCtrl;
  late final TextEditingController _totalTestsCtrl;

  late final FocusNode _titleFocus;
  late final FocusNode _categoryFocus;
  late final FocusNode _coursePriceFocus;
  late final FocusNode _originalPriceFocus;
  late final FocusNode _highlightsFocus;
  late final FocusNode _descFocus;
  late final FocusNode _coverImageUrlFocus;
  late final FocusNode _totalHoursFocus;
  late final FocusNode _totalLessonsFocus;
  late final FocusNode _totalTestsFocus;

  late bool _isFeatured;
  late bool _isCrashCourse;

  // Batch form controllers & focus nodes
  late final TextEditingController _nameCtrl;
  late final TextEditingController _timingCtrl;
  late final TextEditingController _streamKeyCtrl;
  late final TextEditingController _playbackUrlCtrl;
  late final TextEditingController _rtmpsUrlCtrl;

  late final FocusNode _nameFocus;
  late final FocusNode _timingFocus;
  late final FocusNode _streamKeyFocus;
  late final FocusNode _playbackUrlFocus;
  late final FocusNode _rtmpsUrlFocus;

  late String _selectedMedium;
  late List<String> _selectedTeacherIds;
  bool _isSubmitting = false;

  String? _saveErrorMessage;
  String? _titleError;
  String? _categoryError;
  String? _coursePriceError;
  String? _nameError;
  String? _timingError;
  String? _rtmpsUrlError;
  String? _streamKeyError;

  void _loadBatchData(BatchModel batch) {
    _nameCtrl.text = batch.name;
    _timingCtrl.text = batch.timing;
    if (batch.batchPrice > 0) {
      _coursePriceCtrl.text = batch.batchPrice.toInt().toString();
    }
    _streamKeyCtrl.text = batch.streamKey ?? "";
    _playbackUrlCtrl.text = batch.playbackUrl ?? "";
    _rtmpsUrlCtrl.text = batch.rtmpsUrl ?? "";
    _selectedMedium = batch.medium.isNotEmpty ? batch.medium : "Bilingual (Hindi + English)";
    const standardMediums = ["Bilingual (Hindi + English)", "Hindi", "English"];
    if (!standardMediums.contains(_selectedMedium)) {
      _selectedMedium = "Bilingual (Hindi + English)";
    }
    _selectedTeacherIds = List.from(batch.teacherIds);
    if (_selectedTeacherIds.isEmpty && batch.teacherId.isNotEmpty) {
      _selectedTeacherIds = [batch.teacherId];
    }
    _syncTeachers();
  }

  @override
  void initState() {
    super.initState();
    _currentBatch = widget.batch;
    final batch = _currentBatch;
    final c = widget.course;

    _titleCtrl = TextEditingController(text: c?.title ?? widget.courseTitle);
    _categoryCtrl = TextEditingController(text: c?.category ?? "General");
    _coursePriceCtrl = TextEditingController(
      text: c != null && c.price > 0
          ? c.price.toInt().toString()
          : (batch.batchPrice > 0 ? batch.batchPrice.toInt().toString() : ""),
    );
    _originalPriceCtrl = TextEditingController(
      text: c != null && c.originalPrice > 0 ? c.originalPrice.toInt().toString() : "",
    );
    _highlightsCtrl = TextEditingController(
      text: c != null ? c.highlights.join(", ") : "",
    );
    _descCtrl = TextEditingController(text: c?.description ?? "");
    _coverImageUrlCtrl = TextEditingController(text: c?.coverImageUrl ?? "");
    _totalHoursCtrl = TextEditingController(text: (c?.totalHours ?? 60).toString());
    _totalLessonsCtrl = TextEditingController(text: (c?.totalLessons ?? 30).toString());
    _totalTestsCtrl = TextEditingController(text: (c?.totalTests ?? 10).toString());
    _isFeatured = c?.isFeatured ?? false;
    _isCrashCourse = c?.isCrashCourse ?? false;

    _titleFocus = FocusNode();
    _categoryFocus = FocusNode();
    _coursePriceFocus = FocusNode();
    _originalPriceFocus = FocusNode();
    _highlightsFocus = FocusNode();
    _descFocus = FocusNode();
    _coverImageUrlFocus = FocusNode();
    _totalHoursFocus = FocusNode();
    _totalLessonsFocus = FocusNode();
    _totalTestsFocus = FocusNode();

    _nameCtrl = TextEditingController(text: batch.name);
    _timingCtrl = TextEditingController(text: batch.timing);
    _streamKeyCtrl = TextEditingController(text: batch.streamKey ?? "");
    _playbackUrlCtrl = TextEditingController(text: batch.playbackUrl ?? "");
    _rtmpsUrlCtrl = TextEditingController(text: batch.rtmpsUrl ?? "");

    _nameFocus = FocusNode();
    _timingFocus = FocusNode();
    _streamKeyFocus = FocusNode();
    _playbackUrlFocus = FocusNode();
    _rtmpsUrlFocus = FocusNode();

    _selectedMedium = batch.medium.isNotEmpty
        ? batch.medium
        : "Bilingual (Hindi + English)";
    const standardMediums = ["Bilingual (Hindi + English)", "Hindi", "English"];
    if (!standardMediums.contains(_selectedMedium)) {
      _selectedMedium = "Bilingual (Hindi + English)";
    }

    _selectedTeacherIds = List.from(batch.teacherIds);
    if (_selectedTeacherIds.isEmpty && batch.teacherId.isNotEmpty) {
      _selectedTeacherIds = [batch.teacherId];
    }

    _syncTeachers();
  }

  Future<void> _syncTeachers() async {
    if (_selectedTeacherIds.isEmpty && _currentBatch.id.isNotEmpty) {
      try {
        final syncedIds = await context.read<CourseProvider>().getBatchTeacherIds(_currentBatch.id);
        if (mounted && syncedIds.isNotEmpty) {
          setState(() {
            _selectedTeacherIds = syncedIds;
          });
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _categoryCtrl.dispose();
    _coursePriceCtrl.dispose();
    _originalPriceCtrl.dispose();
    _highlightsCtrl.dispose();
    _descCtrl.dispose();
    _coverImageUrlCtrl.dispose();
    _totalHoursCtrl.dispose();
    _totalLessonsCtrl.dispose();
    _totalTestsCtrl.dispose();

    _titleFocus.dispose();
    _categoryFocus.dispose();
    _coursePriceFocus.dispose();
    _originalPriceFocus.dispose();
    _highlightsFocus.dispose();
    _descFocus.dispose();
    _coverImageUrlFocus.dispose();
    _totalHoursFocus.dispose();
    _totalLessonsFocus.dispose();
    _totalTestsFocus.dispose();

    _nameCtrl.dispose();
    _timingCtrl.dispose();
    _streamKeyCtrl.dispose();
    _playbackUrlCtrl.dispose();
    _rtmpsUrlCtrl.dispose();

    _nameFocus.dispose();
    _timingFocus.dispose();
    _streamKeyFocus.dispose();
    _playbackUrlFocus.dispose();
    _rtmpsUrlFocus.dispose();
    super.dispose();
  }

  Future<void> _handleAddScheduleAndTiming() async {
    final courseId = widget.course?.id ?? _currentBatch.courseId;
    final courseProvider = context.read<CourseProvider>();
    final courseBatches = courseProvider.getBatchesForCourse(courseId);

    final existingTimings = courseBatches.map((b) => b.timing).toList();
    final picked = await BatchTimingPickerDialog.show(
      context,
      initialTiming: "04:00 PM - 06:00 PM (Mon-Sat)",
      existingTimings: existingTimings,
    );
    if (picked == null || !mounted) return;

    final overlap = BatchTimingHelper.findOverlappingTiming(picked, existingTimings);
    if (overlap != null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text("Timing overlaps with existing course slot: $overlap. Two slots cannot have overlapping class hours."),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    final slotNumber = courseBatches.length + 1;
    final courseTitle = widget.course?.title ?? widget.courseTitle;
    final coursePrice = widget.course?.price ?? _currentBatch.batchPrice;

    setState(() => _isSubmitting = true);

    try {
      final newBatch = BatchModel(
        id: "",
        courseId: courseId,
        name: "$courseTitle - Batch $slotNumber",
        timing: picked,
        startDate: _currentBatch.startDate,
        endDate: _currentBatch.endDate,
        teacherName: _currentBatch.teacherName,
        teacherId: _currentBatch.teacherId,
        teacherIds: List.from(_selectedTeacherIds),
        totalStudents: 0,
        maxStudents: 500,
        batchPrice: coursePrice,
        medium: _selectedMedium,
      );

      await courseProvider.addBatch(newBatch);

      final updatedBatches = courseProvider.getBatchesForCourse(courseId);
      final createdBatch = updatedBatches.firstWhere(
        (b) => b.timing == picked,
        orElse: () => updatedBatches.isNotEmpty ? updatedBatches.last : newBatch,
      );

      if (_selectedTeacherIds.isNotEmpty && createdBatch.id.isNotEmpty) {
        try {
          await courseProvider.updateBatchTeachers(createdBatch.id, _selectedTeacherIds);
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _currentBatch = createdBatch;
        _loadBatchData(createdBatch);
        _isSubmitting = false;
        _saveErrorMessage = null;
      });

      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text("✅ Added schedule: $picked"),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _saveErrorMessage = "Failed to add schedule: $e";
      });
    }
  }

  Future<void> _handleEditScheduleTiming(BatchModel batch) async {
    final courseId = widget.course?.id ?? _currentBatch.courseId;
    final courseBatches = context.read<CourseProvider>().getBatchesForCourse(courseId);
    final otherTimings = courseBatches
        .where((b) => b.id != batch.id)
        .map((b) => b.timing)
        .toList();

    final picked = await BatchTimingPickerDialog.show(
      context,
      initialTiming: batch.timing,
      existingTimings: otherTimings,
    );
    if (picked == null || !mounted) return;

    final overlap = BatchTimingHelper.findOverlappingTiming(picked, otherTimings);
    if (overlap != null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text("Timing overlaps with another course schedule: $overlap. Two slots cannot have overlapping class hours."),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final updatedBatch = batch.copyWith(timing: picked);
      await context.read<CourseProvider>().updateBatch(updatedBatch);
      if (mounted) {
        if (_currentBatch.id == batch.id) {
          setState(() {
            _currentBatch = updatedBatch;
            _timingCtrl.text = picked;
            _isSubmitting = false;
          });
        } else {
          setState(() => _isSubmitting = false);
        }
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text("✅ Updated schedule: $picked"),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text("Failed to update schedule: $e"),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleDeleteSchedule(BatchModel batch) async {
    final courseId = widget.course?.id ?? _currentBatch.courseId;
    final courseBatches = context.read<CourseProvider>().getBatchesForCourse(courseId);

    if (courseBatches.length <= 1) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text("A course must have at least one active schedule timing."),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Schedule?"),
        content: Text("Are you sure you want to delete the schedule '${batch.name}' (${batch.timing})?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      final courseProvider = context.read<CourseProvider>();
      await courseProvider.deleteBatch(batch.id);
      if (!mounted) return;
      final remaining = courseProvider.getBatchesForCourse(courseId);
      if (mounted) {
        if (_currentBatch.id == batch.id && remaining.isNotEmpty) {
          setState(() {
            _currentBatch = remaining.first;
            _loadBatchData(remaining.first);
            _isSubmitting = false;
          });
        } else {
          setState(() => _isSubmitting = false);
        }
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text("Deleted schedule '${batch.name}'"),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text("Failed to delete schedule: $e"),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleSaveBatch() async {
    setState(() {
      _saveErrorMessage = null;
      _titleError = null;
      _categoryError = null;
      _coursePriceError = null;
      _nameError = null;
      _timingError = null;
      _rtmpsUrlError = null;
      _streamKeyError = null;
    });

    bool hasError = false;

    // Validate Course fields
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      _titleError = "Course title is required";
      hasError = true;
    }

    final cp = int.tryParse(_coursePriceCtrl.text.replaceAll('₹', '').trim());
    if (cp == null || cp < 9 || cp > 3199 || (cp - 9) % 10 != 0) {
      _coursePriceError = "Selling Price must be in steps of 10 ending in 9 (₹9 to ₹3199)";
      hasError = true;
    }
    final coursePrice = cp?.toDouble();

    // Validate Batch fields
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _nameError = "Batch name is required";
      hasError = true;
    }

    final timing = _timingCtrl.text.trim();
    if (timing.isEmpty) {
      _timingError = "Batch schedule timing is required";
      hasError = true;
    } else {
      final existingBatches = context.read<CourseProvider>().getBatchesForCourse(_currentBatch.courseId);
      final existingTimings = existingBatches.where((b) => b.id != _currentBatch.id).map((b) => b.timing);
      if (BatchTimingHelper.isDuplicateTiming(timing, existingTimings)) {
        _timingError = "Another timing slot with this schedule already exists for this course.";
        hasError = true;
      }
    }

    final rtmpsUrl = _rtmpsUrlCtrl.text.trim();
    if (rtmpsUrl.isNotEmpty) {
      final rtmpsErr = BatchTimingHelper.validateRtmpsUrl(rtmpsUrl);
      if (rtmpsErr != null) {
        _rtmpsUrlError = rtmpsErr;
        hasError = true;
      }
    }

    final collision = _ManageCoursesScreenState._checkStreamKeyCollisionStatic(
      parentContext: context,
      currentBatchId: _currentBatch.id,
      streamKey: _streamKeyCtrl.text.trim(),
      playbackUrl: _playbackUrlCtrl.text.trim(),
    );
    if (collision) return;

    if (hasError) {
      setState(() {});
      return;
    }

    setState(() => _isSubmitting = true);

    final courseProvider = context.read<CourseProvider>();

    try {
      // 1. Update Course if model is available
      CourseModel? courseToUpdate = widget.course;
      if (courseToUpdate == null) {
        try {
          courseToUpdate = courseProvider.courses.firstWhere((c) => c.id == _currentBatch.courseId);
        } catch (_) {}
      }

      if (courseToUpdate != null) {
        final originalPrice = double.tryParse(_originalPriceCtrl.text.trim()) ?? coursePrice!;
        final highlights = _highlightsCtrl.text
            .split(",")
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

        final updatedCourse = courseToUpdate.copyWith(
          title: title,
          category: _categoryCtrl.text.trim().isNotEmpty ? _categoryCtrl.text.trim() : "General",
          description: _descCtrl.text.trim(),
          highlights: highlights.isNotEmpty
              ? highlights
              : [
                  "Live interactive video lectures",
                  "Complete digital PDF study material",
                  "Weekly mock test series with ranks",
                ],
          price: coursePrice!,
          originalPrice: originalPrice,
          coverImageUrl: _coverImageUrlCtrl.text.trim(),
          totalHours: int.tryParse(_totalHoursCtrl.text.trim()) ?? courseToUpdate.totalHours,
          totalLessons: int.tryParse(_totalLessonsCtrl.text.trim()) ?? courseToUpdate.totalLessons,
          totalTests: int.tryParse(_totalTestsCtrl.text.trim()) ?? courseToUpdate.totalTests,
          isFeatured: _isFeatured,
          isCrashCourse: _isCrashCourse,
        );

        await courseProvider.updateCourse(updatedCourse);
      }

      // 2. Validate timing overlap against other slots of this course
      final otherBatches = courseProvider.getBatchesForCourse(_currentBatch.courseId)
          .where((b) => b.id != _currentBatch.id);
      final timingOverlap = BatchTimingHelper.findOverlappingTiming(timing, otherBatches.map((b) => b.timing));
      if (timingOverlap != null) {
        setState(() {
          _isSubmitting = false;
          _saveErrorMessage = "Timing overlaps with existing course slot: $timingOverlap. Two slots cannot have overlapping class hours.";
        });
        return;
      }

      // 3. Update or Create Batch
      final teacherNames = _selectedTeacherIds
          .map((id) => widget.teachers.firstWhere(
                (t) => t.id == id,
                orElse: () => UserModel(
                  id: id,
                  email: '',
                  phone: '',
                  name: 'Faculty',
                  role: UserRole.teacher,
                ),
              ).name)
          .join(', ');

      final updatedBatch = BatchModel(
        id: _currentBatch.id,
        courseId: _currentBatch.courseId,
        name: name,
        timing: timing,
        startDate: _currentBatch.startDate,
        endDate: _currentBatch.endDate,
        teacherName: teacherNames.isNotEmpty
            ? teacherNames
            : (_currentBatch.teacherName.isNotEmpty ? _currentBatch.teacherName : "Faculty Member"),
        teacherId: _selectedTeacherIds.isNotEmpty ? _selectedTeacherIds.first : "",
        totalStudents: _currentBatch.totalStudents,
        maxStudents: _currentBatch.maxStudents,
        batchPrice: coursePrice!,
        medium: _selectedMedium,
        isActive: _currentBatch.isActive,
        playProductId: _currentBatch.playProductId,
        streamKey: _streamKeyCtrl.text.trim().isNotEmpty
            ? _streamKeyCtrl.text.trim()
            : null,
        playbackUrl: _playbackUrlCtrl.text.trim().isNotEmpty
            ? _playbackUrlCtrl.text.trim()
            : null,
        rtmpsUrl: rtmpsUrl.isNotEmpty ? rtmpsUrl : null,
        teacherIds: _selectedTeacherIds,
      );

      if (_currentBatch.id.isEmpty) {
        await courseProvider.addBatch(updatedBatch, teacherIds: _selectedTeacherIds);
      } else {
        await courseProvider.updateBatch(updatedBatch, teacherIds: _selectedTeacherIds);
      }

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop(true);
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              "✅ Course & Batch updated successfully!",
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.fixed,
          ),
        );
      }
    } catch (e) {
      final sanitized = _sanitizeForLog(e);
      debugPrint('[EditBatchDialog] Failed to save changes: $sanitized');
      if (mounted) {
        final cleanMsg = e.toString()
            .replaceAll('Exception:', '')
            .replaceAll('ServerFailure:', '')
            .replaceAll('ServerException:', '')
            .trim();
        setState(() {
          _isSubmitting = false;
          _saveErrorMessage = cleanMsg.isNotEmpty
              ? cleanMsg
              : "Failed to update changes. Please check your network and settings.";
        });
      }
    } finally {
      if (mounted && _saveErrorMessage == null) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final isCompact = keyboardHeight > 60 || isLandscape || mediaQuery.size.height < 500;
    final verticalInset = isLandscape ? 4.0 : (isCompact ? 8.0 : 20.0);
    final availableHeight = mediaQuery.size.height - keyboardHeight - (verticalInset * 2);

    return Dialog(
      backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isLandscape ? 32 : (mediaQuery.size.width < 360 ? 12 : 20),
        vertical: verticalInset,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 580,
          maxHeight: availableHeight > 50 ? availableHeight : 300.0,
        ),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.symmetric(
            horizontal: isLandscape ? 20 : 16,
            vertical: isCompact ? 10 : 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Combined Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.edit_note, color: AppTheme.primary, size: 22),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Edit Course: ${widget.course?.title ?? widget.courseTitle}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Edit Batch: ${widget.batch.name}",
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: AppTheme.primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              if (_saveErrorMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.error.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _saveErrorMessage!,
                          style: const TextStyle(
                            color: AppTheme.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // -------------------------------------------------------------
              // SECTION 1: Course Information & Pricing
              // -------------------------------------------------------------
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.school, size: 18, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    "Course Information",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _titleCtrl,
                focusNode: _titleFocus,
                scrollPadding: const EdgeInsets.only(bottom: 80),
                decoration: InputDecoration(
                  labelText: "Course Title *",
                  hintText: "e.g. BPSC 72nd Target Batch",
                  errorText: _titleError,
                  isDense: true,
                ),
                enabled: !_isSubmitting,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _categoryCtrl,
                focusNode: _categoryFocus,
                scrollPadding: const EdgeInsets.only(bottom: 80),
                decoration: InputDecoration(
                  labelText: "Category *",
                  hintText: "e.g. BPSC / SSC / State Exams",
                  errorText: _categoryError,
                  isDense: true,
                ),
                enabled: !_isSubmitting,
              ),
              const SizedBox(height: 8),
              SteppedPriceInputField(
                controller: _coursePriceCtrl,
                focusNode: _coursePriceFocus,
                scrollPadding: const EdgeInsets.only(bottom: 80),
                labelText: "Selling Price (₹) *",
                hintText: "e.g. 1499",
                helperText: "Student enrollment fee for this course and batch",
                errorText: _coursePriceError,
                isCoursePrice: true,
                minPrice: 9,
                maxPrice: 3199,
                enabled: !_isSubmitting,
              ),
              const SizedBox(height: 8),
              SteppedPriceInputField(
                controller: _originalPriceCtrl,
                focusNode: _originalPriceFocus,
                scrollPadding: const EdgeInsets.only(bottom: 80),
                labelText: "Offer / Original MRP (₹)",
                hintText: "e.g. 2999",
                isCoursePrice: true,
                isRequired: false,
                minPrice: 9,
                maxPrice: 3199,
                enabled: !_isSubmitting,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _highlightsCtrl,
                focusNode: _highlightsFocus,
                scrollPadding: const EdgeInsets.only(bottom: 80),
                decoration: const InputDecoration(
                  labelText: "Course Highlights (comma separated)",
                  hintText: "Live classes, Notes, Mock Tests",
                  isDense: true,
                ),
                enabled: !_isSubmitting,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descCtrl,
                focusNode: _descFocus,
                maxLines: 2,
                scrollPadding: const EdgeInsets.only(bottom: 80),
                decoration: const InputDecoration(
                  labelText: "Course Description",
                  hintText: "Enter comprehensive course curriculum details...",
                  isDense: true,
                ),
                enabled: !_isSubmitting,
              ),
              const SizedBox(height: 8),
              ImageUploadPickerWidget(
                controller: _coverImageUrlCtrl,
                labelText: "Cover Image / Thumbnail (Course Cover Page)",
                hintText: "https://.../thumbnail.jpg",
                helperText: "Cover page & cards",
                enabled: !_isSubmitting,
                onUpload: (fileName, bytes) async {
                  final courseProvider = context.read<CourseProvider>();
                  return await courseProvider.uploadCourseCoverImage(
                    fileName: fileName,
                    fileBytes: bytes,
                  );
                },
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.warmIvory,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, size: 20, color: AppColors.saffronDark),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Curriculum Statistics (Auto-Tracked)",
                            style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${widget.course?.totalLessons ?? 0} Lessons • ${widget.course?.totalHours ?? 0} Hours • ${widget.course?.totalTests ?? 0} Tests",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.primaryLight : AppColors.saffronDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Automatically counted as faculty uploads lectures and creates tests.",
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Material(
                color: Colors.transparent,
                child: Column(
                  children: [
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        "Featured Course on Store",
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      subtitle: const Text(
                        "Highlighted on student home and store banners",
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                      value: _isFeatured,
                      activeThumbColor: AppTheme.primary,
                      onChanged: _isSubmitting ? null : (v) => setState(() => _isFeatured = v),
                    ),
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        "Crash Course Badge",
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      subtitle: const Text(
                        "Tags this course as an intensive fast-track program",
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                      value: _isCrashCourse,
                      activeThumbColor: AppTheme.primary,
                      onChanged: _isSubmitting ? null : (v) => setState(() => _isCrashCourse = v),
                    ),
                  ],
                ),
              ),

              // -------------------------------------------------------------
              // SECTION 2: Batch Schedule & Faculty (Multiple Schedules Support)
              // -------------------------------------------------------------
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month, size: 18, color: AppTheme.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Builder(
                            builder: (ctx) {
                              final count = ctx.watch<CourseProvider>().getBatchesForCourse(widget.course?.id ?? _currentBatch.courseId).length;
                              return Text(
                                "Course Schedules & Timings ($count)",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                                ),
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text(
                      "Add Schedule / Timing",
                      style: TextStyle(fontSize: 12),
                    ),
                    onPressed: _isSubmitting ? null : _handleAddScheduleAndTiming,
                  ),
                ],
              ),
              Builder(
                builder: (context) {
                  final courseBatches = context
                      .watch<CourseProvider>()
                      .getBatchesForCourse(widget.course?.id ?? _currentBatch.courseId);

                  if (courseBatches.isEmpty) {
                    return Container(
                      margin: const EdgeInsets.only(top: 6, bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.warmIvory,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          "No class schedules configured yet. Tap '+ Add Schedule / Timing' above to add one.",
                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Choice chips for quick switching
                      if (courseBatches.length > 1)
                        Container(
                          margin: const EdgeInsets.only(top: 4, bottom: 6),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: courseBatches.map((b) {
                                final isSelected = b.id == _currentBatch.id;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ChoiceChip(
                                    label: Text(
                                      b.name.isNotEmpty ? b.name : b.timing,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        color: isSelected
                                          ? (isDark ? Colors.white : Colors.black87)
                                          : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                                      ),
                                    ),
                                    selected: isSelected,
                                    selectedColor: isDark
                                        ? AppColors.primary.withValues(alpha: 0.35)
                                        : AppTheme.primary.withValues(alpha: 0.25),
                                    backgroundColor: isDark ? AppColors.darkSurface : AppColors.warmIvory,
                                    onSelected: _isSubmitting
                                        ? null
                                        : (selected) {
                                            if (selected && b.id != _currentBatch.id) {
                                              setState(() {
                                                _currentBatch = b;
                                                _loadBatchData(b);
                                              });
                                            }
                                          },
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),

                      // Multiple Schedules Detailed Cards List
                      ...courseBatches.asMap().entries.map((entry) {
                        final index = entry.key;
                        final batch = entry.value;
                        final isSelected = batch.id == _currentBatch.id;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : AppColors.warmIvory,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primary
                                  : (isDark ? AppColors.darkBorder : AppColors.border),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppTheme.primary : AppColors.saffronMuted,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      "Schedule ${index + 1}",
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? Colors.black : AppColors.saffronDark,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      batch.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (courseBatches.length > 1)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                      tooltip: "Delete Schedule",
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: _isSubmitting ? null : () => _handleDeleteSchedule(batch),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              // Interactive Timing Tile
                              InkWell(
                                onTap: _isSubmitting ? null : () => _handleEditScheduleTiming(batch),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isDark ? AppColors.darkBorder : AppColors.border,
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.access_time_filled, size: 15, color: AppTheme.primary),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          batch.timing,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const Icon(Icons.edit_calendar, size: 15, color: AppTheme.primary),
                                    ],
                                  ),
                                ),
                              ),
                              if (batch.teacherName.isNotEmpty && batch.teacherName != "Faculty Member") ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.person_outline, size: 12, color: AppTheme.textMuted),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        batch.teacherName,
                                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                focusNode: _nameFocus,
                scrollPadding: const EdgeInsets.only(bottom: 80),
                decoration: InputDecoration(
                  labelText: "Batch Name *",
                  hintText: "e.g. Morning Target Batch A",
                  errorText: _nameError,
                  isDense: true,
                ),
                enabled: !_isSubmitting,
              ),
              const SizedBox(height: 8),
              InkWell(
                focusNode: _timingFocus,
                onTap: _isSubmitting
                    ? null
                    : () async {
                        final courseId = widget.course?.id ?? _currentBatch.courseId;
                        final otherTimings = context.read<CourseProvider>()
                            .getBatchesForCourse(courseId)
                            .where((b) => b.id != _currentBatch.id)
                            .map((b) => b.timing)
                            .toList();
                        final picked = await BatchTimingPickerDialog.show(
                          context,
                          initialTiming: _timingCtrl.text.isNotEmpty
                              ? _timingCtrl.text
                              : "08:00 AM - 10:00 AM (Mon-Sat)",
                          existingTimings: otherTimings,
                        );
                        if (picked != null && mounted) {
                          final overlap = BatchTimingHelper.findOverlappingTiming(picked, otherTimings);
                          if (overlap != null) {
                            setState(() {
                              _timingError = "Overlaps with another schedule ($overlap)";
                            });
                            return;
                          }
                          setState(() {
                            _timingCtrl.text = picked;
                            _timingError = null;
                          });
                        }
                      },
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: "Batch Schedule (Hours & Days) *",
                    hintText: "Tap to configure class hours & days",
                    errorText: _timingError,
                    isDense: true,
                    prefixIcon: const Icon(
                      Icons.calendar_month,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                    suffixIcon: const Icon(
                      Icons.edit_calendar,
                      color: AppTheme.primary,
                      size: 18,
                    ),
                  ),
                  child: Text(
                    _timingCtrl.text.isNotEmpty
                        ? _timingCtrl.text
                        : "Tap to configure hours & days",
                    style: TextStyle(
                      color: _timingCtrl.text.isNotEmpty
                          ? (isDark ? Colors.white : Colors.black87)
                          : AppTheme.textMuted,
                      fontWeight: _timingCtrl.text.isNotEmpty
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _selectedMedium,
                decoration: const InputDecoration(
                  labelText: "Course Medium",
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(
                    value: "Bilingual (Hindi + English)",
                    child: Text(
                      "Bilingual (Hindi + English)",
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: "Hindi",
                    child: Text("Hindi", overflow: TextOverflow.ellipsis),
                  ),
                  DropdownMenuItem(
                    value: "English",
                    child: Text("English", overflow: TextOverflow.ellipsis),
                  ),
                ],
                onChanged: _isSubmitting
                    ? null
                    : (val) {
                        if (val != null) {
                          setState(() => _selectedMedium = val);
                        }
                      },
              ),
              const SizedBox(height: 10),
              MultiTeacherSelector(
                allTeachers: widget.teachers,
                selectedTeacherIds: _selectedTeacherIds,
                enabled: !_isSubmitting,
                onChanged: (ids) => setState(() => _selectedTeacherIds = ids),
              ),

              // -------------------------------------------------------------
              // SECTION 3: Dedicated Live Stream Engine (Optional)
              // -------------------------------------------------------------
              const Divider(height: 16),
              const Text(
                "Dedicated Live Stream (Optional)",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                "Leave empty to use institute default from Admin Settings.",
                style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _streamKeyCtrl,
                focusNode: _streamKeyFocus,
                scrollPadding: const EdgeInsets.only(bottom: 80),
                decoration: InputDecoration(
                  labelText: "Custom Stream Key (Optional)",
                  hintText: "e.g. 64-char key for concurrent class",
                  isDense: true,
                  errorText: _streamKeyError,
                ),
                enabled: !_isSubmitting,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _playbackUrlCtrl,
                focusNode: _playbackUrlFocus,
                scrollPadding: const EdgeInsets.only(bottom: 80),
                decoration: const InputDecoration(
                  labelText: "Custom Playback HLS URL (Optional)",
                  hintText: "https://.../manifest/video.m3u8",
                  isDense: true,
                ),
                enabled: !_isSubmitting,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _rtmpsUrlCtrl,
                focusNode: _rtmpsUrlFocus,
                scrollPadding: const EdgeInsets.only(bottom: 80),
                decoration: InputDecoration(
                  labelText: "RTMPS URL",
                  hintText: "Enter RTMPS streaming URL",
                  isDense: true,
                  errorText: _rtmpsUrlError,
                ),
                enabled: !_isSubmitting,
              ),

              // -------------------------------------------------------------
              // Actions: Cancel & Save Changes
              // -------------------------------------------------------------
              const Divider(height: 20),
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    ),
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.black,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                    onPressed: _isSubmitting ? null : _handleSaveBatch,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Text(
                            "Save Changes",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
