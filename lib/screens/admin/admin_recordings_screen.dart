import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/image_upload_picker_widget.dart';
import '../../core/widgets/modern_card.dart';
import '../../features/live_classes/data/models/lecture_recording_model.dart';
import '../../features/live_classes/data/models/live_class_model.dart';
import '../../providers/course_provider.dart';
import '../../providers/live_class_provider.dart';
import '../student/live_classroom_screen.dart';
import 'manage_courses_screen.dart';
import '../teacher/upload_lecture_screen.dart';

/// Admin Lecture Recordings Management Library.
/// Displays recorded broadcast archives grouped by Course, Batch, and Date.
/// Allows Admins to inspect processing status, retry Cloudflare sync, play recordings,
/// and navigate to parent courses/batches.
class AdminRecordingsScreen extends StatefulWidget {
  const AdminRecordingsScreen({super.key});

  @override
  State<AdminRecordingsScreen> createState() => _AdminRecordingsScreenState();
}

class _AdminRecordingsScreenState extends State<AdminRecordingsScreen> {
  String _selectedStatusFilter = 'all'; // all, ready, processing, failed
  String? _selectedCourseFilter;
  String? _selectedBatchFilter;
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _refreshingUids = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecordings();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecordings() async {
    final liveProvider = context.read<LiveClassProvider>();
    await liveProvider.fetchLectureRecordings(
      courseId: _selectedCourseFilter,
      batchId: _selectedBatchFilter,
    );
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
                : "Recording status: ${updated?.statusName ?? 'still processing'}",
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

  void _playRecording(LectureRecordingModel rec) {
    if (!rec.isReady || rec.playbackUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            rec.isProcessing
                ? "Recording is still encoding on Cloudflare (~60s buffer). Tap Refresh Status to update."
                : "Recording playback URL is not available (${rec.statusName}).",
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
                        key: const Key('admin_edit_recording_title_input'),
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
                key: const Key('admin_save_recording_details_btn'),
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

    final allRecordings = liveProvider.recordings;
    final query = _searchController.text.trim().toLowerCase();

    final filtered = allRecordings.where((r) {
      if (_selectedStatusFilter != 'all' && r.statusName != _selectedStatusFilter) {
        return false;
      }
      if (_selectedCourseFilter != null && r.courseId != _selectedCourseFilter) {
        return false;
      }
      if (_selectedBatchFilter != null && r.batchId != _selectedBatchFilter) {
        return false;
      }
      if (query.isNotEmpty) {
        final titleMatches = r.title.toLowerCase().contains(query);
        final batchMatches = r.batchName.toLowerCase().contains(query);
        final courseMatches = r.courseName.toLowerCase().contains(query);
        final teacherMatches = r.teacherName.toLowerCase().contains(query);
        return titleMatches || batchMatches || courseMatches || teacherMatches;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Lecture Recordings Library"),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: "Upload Lecture Video",
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const UploadLectureScreen(),
                ),
              ).then((_) => _loadRecordings());
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Library",
            onPressed: _loadRecordings,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter & Search Controls Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.surface,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                ),
              ),
            ),
            child: Column(
              children: [
                // Search Input
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: "Search title, course, batch, or faculty...",
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Status Tabs & Course Filter
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip("All", 'all'),
                      const SizedBox(width: 6),
                      _buildFilterChip("Ready", 'ready'),
                      const SizedBox(width: 6),
                      _buildFilterChip("Processing", 'processing'),
                      const SizedBox(width: 6),
                      _buildFilterChip("Failed", 'failed'),
                      if (courseProvider.courses.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Container(
                          height: 24,
                          width: 1,
                          color: isDark ? AppColors.darkBorder : AppColors.border,
                        ),
                        const SizedBox(width: 12),
                        DropdownButton<String?>(
                          value: _selectedCourseFilter,
                          isDense: true,
                          underline: const SizedBox.shrink(),
                          hint: const Text("All Courses", style: TextStyle(fontSize: 12)),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text("All Courses", style: TextStyle(fontSize: 12)),
                            ),
                            ...courseProvider.courses.map(
                              (c) => DropdownMenuItem<String?>(
                                value: c.id,
                                child: Text(c.title, style: const TextStyle(fontSize: 12)),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedCourseFilter = val;
                            });
                            _loadRecordings();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Recordings List
          Expanded(
            child: liveProvider.isRecordingsLoading
                ? const AppLoadingIndicator()
                : filtered.isEmpty
                    ? AppEmptyState(
                        icon: Icons.video_library_outlined,
                        title: "No Lecture Recordings Found",
                        subtitle: _selectedStatusFilter == 'processing'
                            ? "No broadcasts currently encoding. Cloudflare recordings appear here after faculty finish streaming."
                            : "Broadcast sessions completed by faculty will automatically sync and archive here.",
                        actionLabel: "Reload Recordings",
                        onAction: _loadRecordings,
                      )
                    : RefreshIndicator(
                        onRefresh: _loadRecordings,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final rec = filtered[index];
                            final isRefreshing =
                                _refreshingUids.contains(rec.videoUid);

                            return ModernCard(
                              padding: const EdgeInsets.all(14),
                              backgroundColor: isDark
                                  ? AppColors.darkSurfaceCard
                                  : AppColors.surface,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top Row: Badges & Actions
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            _buildStatusBadge(rec.statusName),
                                            CustomBadge(
                                              text: rec.courseName,
                                              variant: BadgeVariant.outline,
                                              fontSize: 10,
                                            ),
                                            CustomBadge(
                                              text: rec.batchName,
                                              variant: BadgeVariant.primary,
                                              fontSize: 10,
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (rec.isProcessing)
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
                                          tooltip: "Check Encoding Status",
                                          onPressed: isRefreshing
                                              ? null
                                              : () => _refreshSingleRecording(rec),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Title
                                  Text(
                                    rec.title,
                                    style: AppTypography.subtitle1.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.deepInk,
                                    ),
                                  ),
                                  const SizedBox(height: 6),

                                  // Details Row: Teacher, Date, Duration
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 4,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.person_outline,
                                              size: 14, color: AppColors.textSecondary),
                                          const SizedBox(width: 4),
                                          Text(
                                            rec.teacherName,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.timer_outlined,
                                              size: 14, color: AppColors.textSecondary),
                                          const SizedBox(width: 4),
                                          Text(
                                            _formatDuration(rec.durationSeconds),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (rec.startTime != null)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.event_outlined,
                                                size: 14,
                                                color: AppColors.textSecondary),
                                            const SizedBox(width: 4),
                                            Text(
                                              Formatters.formatDateTime(
                                                  rec.startTime!.toLocal()),
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

                                  // Action Buttons
                                  Row(
                                    children: [
                                      if (rec.isReady)
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
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                          ),
                                          icon: const Icon(Icons.play_arrow,
                                              size: 16),
                                          label: const Text(
                                            "Play Recording",
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          onPressed: () => _playRecording(rec),
                                        )
                                      else if (rec.isProcessing)
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
                                              borderRadius:
                                                  BorderRadius.circular(6),
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
                                            "Check Processing (~60s)",
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          onPressed: isRefreshing
                                              ? null
                                              : () =>
                                                  _refreshSingleRecording(rec),
                                        )
                                      else
                                        CustomBadge(
                                          text: "Unavailable (${rec.status})",
                                          variant: BadgeVariant.error,
                                          fontSize: 11,
                                        ),
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        key: Key('admin_edit_recording_${rec.id}'),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                          minimumSize: const Size(0, 34),
                                        ),
                                        icon: const Icon(Icons.edit_outlined, size: 14),
                                        label: const Text(
                                          "Edit Details",
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        onPressed: () => _showEditRecordingDialog(rec),
                                      ),
                                      const Spacer(),
                                      TextButton.icon(
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8),
                                          minimumSize: const Size(0, 34),
                                        ),
                                        icon: const Icon(Icons.open_in_new,
                                            size: 14,
                                            color: AppColors.textSecondary),
                                        label: const Text(
                                          "Open Batch",
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const ManageCoursesScreen(),
                                            ),
                                          );
                                        },
                                      ),
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
          text: 'PROCESSING',
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
