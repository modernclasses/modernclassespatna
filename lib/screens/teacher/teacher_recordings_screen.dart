import 'package:flutter/material.dart';
import '../../widgets/confirm_delete_lecture_dialog.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/image_upload_picker_widget.dart';
import '../../core/widgets/modern_card.dart';
import '../../features/courses/data/models/course_model.dart';
import '../../features/live_classes/data/models/lecture_recording_model.dart';
import '../../features/live_classes/data/models/live_class_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/live_class_provider.dart';
import '../student/live_classroom_screen.dart';

import 'upload_lecture_screen.dart';

class _UnifiedTeacherLecture {
  final String id;
  final String title;
  final String courseName;
  final String batchName;
  final String batchId;
  final String courseId;
  final int durationSeconds;
  final DateTime? date;
  final String? thumbnailUrl;
  final bool isPrerecorded;
  final String statusName; // ready, processing, failed
  final VideoLessonModel? lessonModel;
  final LectureRecordingModel? recordingModel;

  _UnifiedTeacherLecture({
    required this.id,
    required this.title,
    required this.courseName,
    required this.batchName,
    required this.batchId,
    required this.courseId,
    required this.durationSeconds,
    this.date,
    this.thumbnailUrl,
    required this.isPrerecorded,
    required this.statusName,
    this.lessonModel,
    this.recordingModel,
  });
}

/// Teacher My Lectures Hub.
/// Shows both uploaded prerecorded lectures and completed live broadcast recordings,
/// strictly restricted to batches assigned to the authenticated teacher.
class TeacherRecordingsScreen extends StatefulWidget {
  const TeacherRecordingsScreen({super.key});

  @override
  State<TeacherRecordingsScreen> createState() =>
      _TeacherRecordingsScreenState();
}

class _TeacherRecordingsScreenState extends State<TeacherRecordingsScreen> {
  String _selectedStatusFilter = 'all'; // all, prerecorded, live, ready, processing
  final Set<String> _refreshingUids = {};
  List<VideoLessonModel> _prerecordedLessons = [];
  bool _isLoadingLessons = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTeacherRecordings();
    });
  }

  Future<void> _loadTeacherRecordings() async {
    final auth = context.read<AuthProvider>();
    final teacherId = auth.currentUser.id;
    final liveProvider = context.read<LiveClassProvider>();
    final courseProvider = context.read<CourseProvider>();

    setState(() => _isLoadingLessons = true);

    await liveProvider.fetchLectureRecordings(teacherId: teacherId);

    try {
      if (courseProvider.batches.isEmpty) {
        await courseProvider.fetchCatalog();
      }
      if (courseProvider.myAssignedBatchIds.isEmpty && teacherId.isNotEmpty) {
        await courseProvider.fetchMyTeacherAssignments(teacherId);
      }
      final batchIds = courseProvider.myAssignedBatchIds;
      if (batchIds.isNotEmpty) {
        final lessons = await courseProvider.getLessonsForBatches(batchIds);
        if (mounted) {
          setState(() {
            _prerecordedLessons = lessons;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading prerecorded lessons for teacher: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingLessons = false);
      }
    }
  }

  Future<void> _refreshSingleRecording(LectureRecordingModel rec) async {
    setState(() {
      _refreshingUids.add(rec.videoUid);
    });

    final liveProvider = context.read<LiveClassProvider>();
    final updated = await liveProvider.refreshRecording(rec.videoUid);

    if (mounted) {
      setState(() {
        _refreshingUids.remove(rec.videoUid);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated != null && updated.isReady
                ? "Recording '${rec.title}' is now READY for students!"
                : "Encoding status: ${updated?.statusName ?? 'still processing'}",
          ),
          backgroundColor: updated != null && updated.isReady
              ? AppColors.success
              : AppColors.deepInk,
        ),
      );
    }
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return 'Duration pending';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

    void _playPrerecordedLesson(VideoLessonModel lesson) {
    final courseProvider = context.read<CourseProvider>();
    final course = courseProvider.getCourseById(lesson.courseId) ?? CourseModel.mock();
    final batch = courseProvider.batches.where((b) => b.id == lesson.batchId).firstOrNull;

    final targetModel = LiveClassModel(
      id: lesson.id,
      courseId: lesson.courseId.isNotEmpty ? lesson.courseId : course.id,
      batchId: lesson.batchId.isNotEmpty ? lesson.batchId : (batch?.id ?? ''),
      courseName: course.title.isNotEmpty ? course.title : lesson.chapter,
      batchName: batch?.name ?? 'Assigned Batch',
      title: lesson.title,
      subject: lesson.chapter,
      teacherName: batch?.teacherName.isNotEmpty == true ? batch!.teacherName : 'Faculty',
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
        builder: (_) => LiveClassroomScreen(liveClass: targetModel),
      ),
    );
  }

  Future<void> _confirmDeleteLecture(_UnifiedTeacherLecture item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => ConfirmDeleteLectureDialog(
        lectureTitle: item.title,
        batchName: item.batchName,
        textFieldKey: 'confirm_delete_text_field',
        confirmButtonKey: 'confirm_delete_lecture_btn',
      ),
    );

    if (confirmed == true && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        final courseProvider = context.read<CourseProvider>();
        final liveProvider = context.read<LiveClassProvider>();

        if (item.isPrerecorded && item.lessonModel != null) {
          await courseProvider.deleteLesson(
            item.lessonModel!.id,
            videoPath: item.lessonModel!.videoUrl,
            thumbnailPath: item.lessonModel!.thumbnailUrl,
          );
          if (mounted) {
            setState(() {
              _prerecordedLessons.removeWhere((l) => l.id == item.id);
            });
          }
        } else if (item.recordingModel != null) {
          await liveProvider.deleteRecording(item.recordingModel!.id);
        }

        courseProvider.removeRecentPlayback(item.id);

        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lecture "${item.title}" deleted successfully.'),
              backgroundColor: AppColors.success,
            ),
          );

          _loadTeacherRecordings();
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete lecture: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  void _playRecording(LectureRecordingModel rec) {
    if (!rec.isReady || rec.playbackUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            rec.isProcessing
                ? "Recording is still encoding on Cloudflare (~60s buffer). Tap Refresh Status to update."
                : "Recording playback is not yet available (${rec.statusName}).",
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final liveModel = LiveClassModel(
      id: rec.liveClassId ?? rec.id,
      courseId: rec.courseId,
      batchId: rec.batchId,
      courseName: rec.courseName,
      batchName: rec.batchName,
      title: rec.title,
      subject: rec.courseName,
      teacherName: rec.teacherName,
      teacherAvatar: '',
      scheduledStartTime: rec.startTime ?? rec.createdAt,
      estimatedDuration: Duration(seconds: rec.durationSeconds),
      status: LiveStatus.ended,
      streamUrl: rec.playbackUrl,
      thumbnailUrl: rec.thumbnailUrl,
      recordingStatus: rec.statusName,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LiveClassroomScreen(liveClass: liveModel),
      ),
    );
  }

  Future<void> _showEditPrerecordedDialog(VideoLessonModel lesson) async {
    final titleCtrl = TextEditingController(text: lesson.title);
    final chapterCtrl = TextEditingController(text: lesson.chapter);
    final thumbCtrl = TextEditingController(text: lesson.thumbnailUrl ?? '');
    final formKey = GlobalKey<FormState>();
    final courseProvider = context.read<CourseProvider>();
    bool isSaving = false;
    String? localError;

    await showDialog(
      context: context,
      barrierDismissible: !isSaving,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(
              children: [
                const Icon(Icons.edit_note, color: AppColors.primaryDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Edit Prerecorded Lecture",
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
              width: 400,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (localError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.error),
                          ),
                          child: Text(
                            localError!,
                            style: const TextStyle(color: AppColors.error, fontSize: 12),
                          ),
                        ),
                      ],
                      TextFormField(
                        controller: titleCtrl,
                        decoration: InputDecoration(
                          labelText: "Lecture Title",
                          prefixIcon: const Icon(Icons.title, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          isDense: true,
                        ),
                        validator: (val) =>
                            val == null || val.trim().isEmpty ? "Title required" : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: chapterCtrl,
                        decoration: InputDecoration(
                          labelText: "Chapter / Topic",
                          prefixIcon: const Icon(Icons.menu_book, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          isDense: true,
                        ),
                        validator: (val) =>
                            val == null || val.trim().isEmpty ? "Chapter required" : null,
                      ),
                      const SizedBox(height: 16),
                      ImageUploadPickerWidget(
                        controller: thumbCtrl,
                        labelText: "Lecture Thumbnail",
                        hintText: "https://.../thumbnail.jpg",
                        helperText: "Appears on recordings list and student dashboard",
                        isCompact: true,
                        enabled: !isSaving,
                        onUpload: (fileName, bytes) async {
                          return await courseProvider.uploadLessonThumbnail(
                            batchId: lesson.batchId,
                            fileName: fileName,
                            fileBytes: bytes,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.of(dialogCtx).pop(),
                child: const Text("Cancel"),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                icon: isSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save, size: 16),
                label: Text(isSaving ? "Saving..." : "Save Changes"),
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() {
                          isSaving = true;
                          localError = null;
                        });
                        try {
                          await courseProvider.updateLesson(
                            lessonId: lesson.id,
                            title: titleCtrl.text.trim(),
                            chapter: chapterCtrl.text.trim(),
                            thumbnailUrl: thumbCtrl.text.trim().isEmpty
                                ? null
                                : thumbCtrl.text.trim(),
                          );
                          if (dialogCtx.mounted) {
                            Navigator.of(dialogCtx).pop();
                          }
                          _loadTeacherRecordings();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Lecture updated successfully!"),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() {
                            isSaving = false;
                            localError = e.toString();
                          });
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showEditRecordingDialog(LectureRecordingModel rec) async {
    final titleCtrl = TextEditingController(text: rec.title);
    final thumbCtrl = TextEditingController(text: rec.thumbnailUrl ?? '');
    final formKey = GlobalKey<FormState>();
    final liveProvider = context.read<LiveClassProvider>();
    final courseProvider = context.read<CourseProvider>();
    bool isSaving = false;
    String? localError;

    await showDialog(
      context: context,
      barrierDismissible: !isSaving,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(
              children: [
                const Icon(Icons.edit_note, color: AppColors.primaryDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Edit Lecture Recording",
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
              width: 400,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (localError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.error),
                          ),
                          child: Text(
                            localError!,
                            style: const TextStyle(color: AppColors.error, fontSize: 12),
                          ),
                        ),
                      ],
                      TextFormField(
                        key: const Key('edit_recording_title_input'),
                        controller: titleCtrl,
                        decoration: InputDecoration(
                          labelText: "Lecture Title",
                          hintText: "Enter lecture title...",
                          prefixIcon: const Icon(Icons.title, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          isDense: true,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return "Title cannot be empty";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      ImageUploadPickerWidget(
                        controller: thumbCtrl,
                        labelText: "Lecture Thumbnail",
                        hintText: "https://.../thumbnail.jpg",
                        helperText: "Appears on recordings list and student dashboard",
                        isCompact: true,
                        enabled: !isSaving,
                        onUpload: (fileName, bytes) async {
                          return await courseProvider.uploadLessonThumbnail(
                            batchId: rec.batchId,
                            fileName: fileName,
                            fileBytes: bytes,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.of(dialogCtx).pop(),
                child: const Text("Cancel"),
              ),
              ElevatedButton.icon(
                key: const Key('save_recording_details_btn'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                icon: isSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save, size: 16),
                label: Text(isSaving ? "Saving..." : "Save Changes"),
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() {
                          isSaving = true;
                          localError = null;
                        });
                        try {
                          await liveProvider.updateRecordingDetails(
                            recordingId: rec.id,
                            title: titleCtrl.text.trim(),
                            thumbnailUrl: thumbCtrl.text.trim().isEmpty
                                ? null
                                : thumbCtrl.text.trim(),
                          );
                          if (dialogCtx.mounted) {
                            Navigator.of(dialogCtx).pop();
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Lecture details updated successfully!"),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() {
                            isSaving = false;
                            localError = e.toString();
                          });
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final liveProvider = context.watch<LiveClassProvider>();
    final courseProvider = context.watch<CourseProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final myAssignedBatchIds = courseProvider.myAssignedBatchIds;

    // Build unified lecture items
    final List<_UnifiedTeacherLecture> allLectures = [];
    final Set<String> addedIds = {};

    // 1. Add prerecorded uploads
    for (final l in _prerecordedLessons) {
      if (myAssignedBatchIds.isNotEmpty && !myAssignedBatchIds.contains(l.batchId)) {
        continue;
      }
      final course = courseProvider.getCourseById(l.courseId);
      final batch = courseProvider.batches.where((b) => b.id == l.batchId).firstOrNull;

      // Status logic: if uploaded within the last 5 minutes and duration is 0, Cloudflare is processing
      final isRecent = DateTime.now().difference(l.uploadedAt).inMinutes < 5;
      final statusName = (l.duration == Duration.zero && isRecent) ? 'processing' : 'ready';

      allLectures.add(
        _UnifiedTeacherLecture(
          id: l.id,
          title: l.title,
          courseName: course?.title ?? l.chapter,
          batchName: batch?.name ?? 'Assigned Batch',
          batchId: l.batchId,
          courseId: l.courseId,
          durationSeconds: l.duration.inSeconds,
          date: l.uploadedAt,
          thumbnailUrl: l.thumbnailUrl,
          isPrerecorded: true,
          statusName: statusName,
          lessonModel: l,
        ),
      );
      addedIds.add(l.id);
    }

    // 2. Add live lecture recordings
    for (final r in liveProvider.recordings) {
      if (myAssignedBatchIds.isNotEmpty && !myAssignedBatchIds.contains(r.batchId)) {
        continue;
      }
      if (addedIds.contains(r.id)) continue;

      allLectures.add(
        _UnifiedTeacherLecture(
          id: r.id,
          title: r.title,
          courseName: r.courseName,
          batchName: r.batchName,
          batchId: r.batchId,
          courseId: r.courseId,
          durationSeconds: r.durationSeconds,
          date: r.startTime ?? r.createdAt,
          thumbnailUrl: r.thumbnailUrl,
          isPrerecorded: false,
          statusName: r.statusName,
          recordingModel: r,
        ),
      );
    }

    // Sort descending by date
    allLectures.sort((a, b) {
      final da = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });

    // Filter
    final filteredLectures = allLectures.where((item) {
      if (_selectedStatusFilter == 'all') return true;
      if (_selectedStatusFilter == 'prerecorded') return item.isPrerecorded;
      if (_selectedStatusFilter == 'live') return !item.isPrerecorded;
      if (_selectedStatusFilter == 'ready') return item.statusName == 'ready';
      if (_selectedStatusFilter == 'processing') return item.statusName == 'processing';
      return item.statusName == _selectedStatusFilter;
    }).toList();

    final prerecordedCount = allLectures.where((l) => l.isPrerecorded).length;
    final liveCount = allLectures.where((l) => !l.isPrerecorded).length;

    final isLoading = liveProvider.isRecordingsLoading || _isLoadingLessons;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("My Lectures & Recordings"),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload_outlined),
            tooltip: "Upload Lecture Video",
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const UploadLectureScreen(),
                ),
              ).then((_) => _loadTeacherRecordings());
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Lectures",
            onPressed: _loadTeacherRecordings,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.surface,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                ),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip("All (${allLectures.length})", 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip("Prerecorded ($prerecordedCount)", 'prerecorded'),
                  const SizedBox(width: 8),
                  _buildFilterChip("Live ($liveCount)", 'live'),
                  const SizedBox(width: 8),
                  _buildFilterChip("Ready", 'ready'),
                  const SizedBox(width: 8),
                  _buildFilterChip("Processing", 'processing'),
                ],
              ),
            ),
          ),

          // Lectures List
          Expanded(
            child: isLoading && allLectures.isEmpty
                ? const AppLoadingIndicator()
                : filteredLectures.isEmpty
                    ? AppEmptyState(
                        icon: Icons.video_library_outlined,
                        title: "No Lectures Found",
                        subtitle:
                            "Upload a prerecorded lecture video or start a live broadcast to populate your library.",
                        actionLabel: "Upload Lecture Video",
                        onAction: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const UploadLectureScreen(),
                            ),
                          ).then((_) => _loadTeacherRecordings());
                        },
                      )
                    : RefreshIndicator(
                        onRefresh: _loadTeacherRecordings,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredLectures.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = filteredLectures[index];
                            final isRefreshing = item.recordingModel != null &&
                                _refreshingUids.contains(item.recordingModel!.videoUid);

                            return ModernCard(
                              padding: const EdgeInsets.all(14),
                              backgroundColor: isDark
                                  ? AppColors.darkSurfaceCard
                                  : AppColors.surface,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            CustomBadge(
                                              text: item.isPrerecorded
                                                  ? "PRERECORDED"
                                                  : "LIVE BROADCAST",
                                              variant: item.isPrerecorded
                                                  ? BadgeVariant.primary
                                                  : BadgeVariant.outline,
                                              fontSize: 10,
                                            ),
                                            _buildStatusBadge(item.statusName),
                                            CustomBadge(
                                              text: item.courseName,
                                              variant: BadgeVariant.outline,
                                              fontSize: 10,
                                            ),
                                            CustomBadge(
                                              text: item.batchName,
                                              variant: BadgeVariant.primary,
                                              fontSize: 10,
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (item.recordingModel != null && item.recordingModel!.isProcessing)
                                        IconButton(
                                          icon: isRefreshing
                                              ? const SizedBox(
                                                  width: 14,
                                                  height: 14,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons.refresh,
                                                  size: 18,
                                                  color: AppColors.warning,
                                                ),
                                          tooltip: "Refresh Encoding Status",
                                          onPressed: isRefreshing
                                              ? null
                                              : () => _refreshSingleRecording(item.recordingModel!),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  Text(
                                    item.title,
                                    style: AppTypography.subtitle1.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.deepInk,
                                    ),
                                  ),
                                  const SizedBox(height: 6),

                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 4,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.timer_outlined,
                                              size: 14,
                                              color: AppColors.textSecondary),
                                          const SizedBox(width: 4),
                                          Text(
                                            _formatDuration(item.durationSeconds),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (item.date != null)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.event_outlined,
                                                size: 14,
                                                color: AppColors.textSecondary),
                                            const SizedBox(width: 4),
                                            Text(
                                              Formatters.formatDateTime(item.date!.toLocal()),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      if (item.isPrerecorded && item.lessonModel != null) ...[
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 8,
                                            ),
                                            minimumSize: const Size(0, 34),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                          ),
                                          icon: const Icon(Icons.play_arrow, size: 16),
                                          label: const Text(
                                            "Play Lecture",
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          onPressed: () => _playPrerecordedLesson(item.lessonModel!),
                                        ),
                                        OutlinedButton.icon(
                                          key: Key('edit_lecture_${item.id}'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                                            side: BorderSide(
                                              color: isDark ? AppColors.darkBorder : AppColors.border,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            minimumSize: const Size(0, 34),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                          ),
                                          icon: const Icon(Icons.edit_outlined, size: 15),
                                          label: const Text(
                                            "Edit Details",
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          onPressed: () => _showEditPrerecordedDialog(item.lessonModel!),
                                        ),
                                        OutlinedButton.icon(
                                          key: Key('delete_lecture_${item.id}'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.error,
                                            side: BorderSide(
                                              color: AppColors.error.withValues(alpha: 0.5),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            minimumSize: const Size(0, 34),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                          ),
                                          icon: const Icon(Icons.delete_outline, size: 15, color: AppColors.error),
                                          label: const Text(
                                            "Delete",
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.error,
                                            ),
                                          ),
                                          onPressed: () => _confirmDeleteLecture(item),
                                        ),
                                      ] else if (item.recordingModel != null) ...[
                                        if (item.recordingModel!.isReady)
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.primary,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 8,
                                              ),
                                              minimumSize: const Size(0, 34),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                            ),
                                            icon: const Icon(Icons.play_arrow, size: 16),
                                            label: const Text(
                                              "Play Recording",
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            onPressed: () => _playRecording(item.recordingModel!),
                                          )
                                        else if (item.recordingModel!.isProcessing)
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: AppColors.warning,
                                              side: const BorderSide(
                                                  color: AppColors.warning),
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 8,
                                              ),
                                              minimumSize: const Size(0, 34),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                            ),
                                            icon: isRefreshing
                                                ? const SizedBox(
                                                    width: 12,
                                                    height: 12,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: AppColors.warning,
                                                    ),
                                                  )
                                                : const Icon(Icons.sync, size: 16),
                                            label: const Text(
                                              "Refresh Status (~60s)",
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            onPressed: isRefreshing
                                                ? null
                                                : () => _refreshSingleRecording(item.recordingModel!),
                                          )
                                        else
                                          CustomBadge(
                                            text: "Unavailable (${item.recordingModel!.status})",
                                            variant: BadgeVariant.error,
                                            fontSize: 11,
                                          ),
                                        OutlinedButton.icon(
                                          key: Key('edit_recording_${item.recordingModel!.id}'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                                            side: BorderSide(
                                              color: isDark ? AppColors.darkBorder : AppColors.border,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            minimumSize: const Size(0, 34),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                          ),
                                          icon: const Icon(Icons.edit_outlined, size: 15),
                                          label: const Text(
                                            "Edit Details",
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          onPressed: () => _showEditRecordingDialog(item.recordingModel!),
                                        ),
                                        OutlinedButton.icon(
                                          key: Key('delete_recording_${item.recordingModel!.id}'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.error,
                                            side: BorderSide(
                                              color: AppColors.error.withValues(alpha: 0.5),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            minimumSize: const Size(0, 34),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                          ),
                                          icon: const Icon(Icons.delete_outline, size: 15, color: AppColors.error),
                                          label: const Text(
                                            "Delete",
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.error,
                                            ),
                                          ),
                                          onPressed: () => _confirmDeleteLecture(item),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedStatusFilter == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedStatusFilter = value;
        });
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    switch (status.toLowerCase()) {
      case 'ready':
        return const CustomBadge(
          text: 'READY',
          variant: BadgeVariant.success,
          fontSize: 10,
        );
      case 'processing':
        return const CustomBadge(
          text: 'PROCESSING (~60s)',
          variant: BadgeVariant.warning,
          fontSize: 10,
        );
      case 'failed':
        return const CustomBadge(
          text: 'FAILED',
          variant: BadgeVariant.error,
          fontSize: 10,
        );
      default:
        return CustomBadge(
          text: status.toUpperCase(),
          variant: BadgeVariant.outline,
          fontSize: 10,
        );
    }
  }
}
