import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_card.dart';
import '../../core/widgets/section_header.dart';
import '../../providers/auth_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/doubt_provider.dart';
import 'teacher_broadcast_prototype_screen.dart';
import 'teacher_doubts_screen.dart';
import 'upload_material_screen.dart';
import 'upload_lecture_screen.dart';
import 'create_test_screen.dart';
import 'teacher_batches_screen.dart';
import 'teacher_recordings_screen.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().currentUser;
      if (user.role.name == 'teacher') {
        context.read<CourseProvider>().fetchMyTeacherAssignments(user.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final courseProvider = context.watch<CourseProvider>();
    final doubtProvider = context.watch<DoubtProvider>();

    final user = auth.currentUser;
    final batches = courseProvider.batches
        .where((b) => courseProvider.myAssignedBatchIds.contains(b.id))
        .toList();
    final totalStudents = batches.fold<int>(
      0,
      (sum, b) => sum + b.totalStudents,
    );
    final pendingDoubts = doubtProvider.doubts
        .where((d) => !d.isResolved)
        .length;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Faculty Workspace Identity Masthead
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.secondary,
                    child: Text(
                      user.name.isNotEmpty
                          ? user.name.substring(0, 1).toUpperCase()
                          : "T",
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
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
                            Expanded(
                              child: Text(
                                user.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.2,
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.deepInk,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const CustomBadge(
                              text: "FACULTY",
                              variant: BadgeVariant.secondary,
                              fontSize: 9,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          "Modern Classes Patna • Teaching Faculty",
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            if (courseProvider.activeUploadTask != null &&
                (courseProvider.isUploadingLecture ||
                 courseProvider.activeUploadTask!.status == LectureUploadStatus.success)) ...[
              _buildActiveUploadBanner(context, courseProvider, isDark),
              const SizedBox(height: 14),
            ],

            // Operational Metrics Row (Clean Tabular Numbers)
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    title: "Assigned Batches",
                    value: "${batches.length}",
                    subtext: "Active Teaching",
                    icon: Icons.school_outlined,
                    color: AppColors.secondary,
                    bg: AppColors.secondaryMuted,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    title: "Enrolled Students",
                    value: "$totalStudents",
                    subtext: "Under Mentorship",
                    icon: Icons.groups_outlined,
                    color: AppColors.primaryDark,
                    bg: AppColors.saffronMuted,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    title: "Pending Doubts",
                    value: "$pendingDoubts",
                    subtext: pendingDoubts > 0
                        ? "Requires Review"
                        : "All Clear",
                    icon: Icons.chat_bubble_outline_rounded,
                    color: pendingDoubts > 0
                        ? AppColors.warning
                        : AppColors.success,
                    bg: pendingDoubts > 0
                        ? AppColors.warningBg
                        : AppColors.successBg,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Live Lecture Command Center (Unified Live Studio)
            const SectionHeader(
              eyebrow: "BROADCAST CONTROL",
              title: "Live Lecture Operations",
              subtitle: "Start your classroom live broadcast for your assigned batch",
            ),
            ModernCard(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TeacherBroadcastPrototypeScreen(),
                  ),
                );
              },
              accentSpineColor: AppColors.error,
              padding: const EdgeInsets.all(14),
              backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.error.withValues(alpha: 0.18) : AppColors.errorBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.cell_tower_rounded,
                      size: 24,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              "Go Live & Broadcast Lecture",
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                              ),
                            ),
                            const CustomBadge(
                              text: "LIVE STUDIO",
                              variant: BadgeVariant.error,
                              fontSize: 9,
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          "Access live broadcast studio for your scheduled batch slot",
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Teaching Operations Grid
            const SectionHeader(
              eyebrow: "FACULTY TASKS",
              title: "Academic Operations",
              subtitle: "Attendance, learning materials, lectures & evaluation",
            ),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.20,
              children: [
                _buildActionCard(
                  title: "Student Doubts Desk",
                  subtitle: "Answer student doubts",
                  icon: Icons.question_answer_outlined,
                  color: AppColors.purple,
                  bg: AppColors.purpleBg,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TeacherDoubtsScreen(),
                      ),
                    );
                  },
                ),
                _buildActionCard(
                  title: "Upload Lecture Video",
                  subtitle: courseProvider.isUploadingLecture
                      ? "${(courseProvider.activeUploadTask!.progress * 100).toInt()}% uploading..."
                      : "Batch prerecorded classes",
                  icon: Icons.video_call_outlined,
                  color: courseProvider.isUploadingLecture ? AppColors.saffronDark : AppColors.secondary,
                  bg: courseProvider.isUploadingLecture ? AppColors.saffronMuted : AppColors.secondaryMuted,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const UploadLectureScreen(),
                      ),
                    );
                  },
                ),
                _buildActionCard(
                  title: "Upload PDFs & Notes",
                  subtitle: "Study material repository",
                  icon: Icons.description_outlined,
                  color: AppColors.primaryDark,
                  bg: AppColors.saffronMuted,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const UploadMaterialScreen(),
                      ),
                    );
                  },
                ),
                _buildActionCard(
                  title: "Create Mock Test",
                  subtitle: "Objective test & MCQs",
                  icon: Icons.quiz_outlined,
                  color: AppColors.purple,
                  bg: AppColors.purpleBg,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CreateTestScreen(),
                      ),
                    );
                  },
                ),
                _buildActionCard(
                  title: "My Lectures",
                  subtitle: "Uploads & broadcast archives",
                  icon: Icons.video_library_outlined,
                  color: AppColors.primary,
                  bg: AppColors.saffronMuted,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TeacherRecordingsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Assigned Batches List
            SectionHeader(
              eyebrow: "FACULTY ALLOTMENT",
              title: "My Assigned Batches",
              subtitle: "Batches managed under your mentoring portfolio",
              actionText: "View All",
              onActionTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TeacherBatchesScreen(),
                  ),
                );
              },
            ),
            if (batches.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                ),
                child: const Text(
                  "No batches have been assigned yet. Institute administrators allocate batches via the Admin Suite.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              )
            else
              for (var batch in batches.take(3)) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ModernCard(
                    padding: const EdgeInsets.all(12),
                    backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                    borderColor: isDark ? AppColors.darkBorder : AppColors.border,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.secondary.withValues(alpha: 0.22) : AppColors.secondaryMuted,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.school_outlined,
                            color: AppColors.secondary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                batch.name,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Schedule: ${batch.timing} • ${batch.totalStudents} enrolled",
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.cell_tower_rounded,
                            color: AppColors.error,
                            size: 20,
                          ),
                          tooltip: "Go Live",
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const TeacherBroadcastPrototypeScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color color,
    required Color bg,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(height: 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: -0.4,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtext,
            style: TextStyle(
              fontSize: 9,
              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveUploadBanner(
    BuildContext context,
    CourseProvider courseProvider,
    bool isDark,
  ) {
    final task = courseProvider.activeUploadTask;
    if (task == null) return const SizedBox.shrink();
    final isUploading = courseProvider.isUploadingLecture;
    final isSuccess = task.status == LectureUploadStatus.success;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSuccess
            ? (isDark ? AppColors.emerald.withValues(alpha: 0.15) : AppColors.emeraldBg)
            : (isDark ? AppColors.saffron.withValues(alpha: 0.15) : AppColors.saffronMuted),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSuccess ? AppColors.emerald : AppColors.saffronDark,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSuccess ? Icons.check_circle_outline : Icons.cloud_upload_outlined,
                size: 22,
                color: isSuccess ? AppColors.emerald : AppColors.saffronDark,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSuccess
                          ? "Lecture Uploaded: ${task.title}"
                          : "Uploading Lecture: ${task.title}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      task.batchName,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (isUploading)
                CustomBadge(
                  text: "${(task.progress * 100).toInt()}%",
                  variant: BadgeVariant.primary,
                  fontSize: 11,
                ),
            ],
          ),
          if (isUploading) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: task.progress,
              color: AppColors.saffronDark,
              backgroundColor: AppColors.saffronMuted,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  task.status == LectureUploadStatus.inserting
                      ? "Finalizing lesson record..."
                      : "${(task.uploadedBytes / (1024 * 1024)).toStringAsFixed(1)} MB / ${(task.totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB",
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                Row(
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: const Size(0, 30),
                      ),
                      onPressed: () => courseProvider.cancelLectureUpload(),
                      child: const Text("Cancel", style: TextStyle(color: AppColors.error, fontSize: 12)),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.deepInk,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        minimumSize: const Size(0, 30),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const UploadLectureScreen(),
                          ),
                        );
                      },
                      child: const Text("View Progress", style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ],
            ),
          ] else if (isSuccess) ...[
            const SizedBox(height: 6),
            const Text(
              "Video is being processed by Cloudflare Stream and will be ready to watch in a few moments.",
              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(0, 30),
                  ),
                  onPressed: () => courseProvider.clearActiveUpload(),
                  child: const Text("Dismiss", style: TextStyle(fontSize: 11.5)),
                ),
                const SizedBox(width: 6),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: const Size(0, 30),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: () {
                    courseProvider.clearActiveUpload();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TeacherRecordingsScreen(),
                      ),
                    );
                  },
                  child: const Text("View in My Lectures", style: TextStyle(fontSize: 11.5)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bg,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ModernCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
      borderColor: isDark ? AppColors.darkBorder : AppColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(height: 6),
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.deepInk,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 1),
          Flexible(
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 9.5,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
