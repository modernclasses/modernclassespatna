import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_card.dart';
import '../../core/widgets/section_header.dart';
import '../../providers/auth_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/doubt_provider.dart';
import 'schedule_live_class_screen.dart';
import 'upload_material_screen.dart';
import 'create_test_screen.dart';
import 'mark_attendance_screen.dart';
import 'teacher_batches_screen.dart';

class TeacherDashboardScreen extends StatelessWidget {
  const TeacherDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final courseProvider = context.watch<CourseProvider>();
    final doubtProvider = context.watch<DoubtProvider>();

    final user = auth.currentUser;
    final batches = courseProvider.batches;
    final totalStudents = batches.fold<int>(0, (sum, b) => sum + b.totalStudents);
    final pendingDoubts = doubtProvider.doubts.where((d) => !d.isResolved).length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Teacher Welcome Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Faculty Workspace 🎓",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.name,
                        style: const TextStyle(fontSize: 14, color: AppTheme.primary, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const CustomBadge(text: "FACULTY", variant: BadgeVariant.primary),
              ],
            ),
            const SizedBox(height: 16),

            // Metrics Row
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: "Active Batches",
                    value: "${batches.length}",
                    icon: Icons.groups_outlined,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricCard(
                    title: "Total Students",
                    value: "$totalStudents",
                    icon: Icons.school_outlined,
                    color: AppTheme.secondaryLight,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricCard(
                    title: "Pending Doubts",
                    value: "$pendingDoubts",
                    icon: Icons.help_outline,
                    color: pendingDoubts > 0 ? AppTheme.warning : AppTheme.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Faculty Quick Action Shortcuts
            SectionHeader(title: "Teaching Operations"),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _buildActionCard(
                  title: "Schedule Live Class",
                  subtitle: "Broadcast YouTube Live",
                  icon: Icons.live_tv,
                  color: AppTheme.error,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ScheduleLiveClassScreen()),
                    );
                  },
                ),
                _buildActionCard(
                  title: "Upload PDFs & Notes",
                  subtitle: "Secure in-app materials",
                  icon: Icons.upload_file,
                  color: AppTheme.primary,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const UploadMaterialScreen()),
                    );
                  },
                ),
                _buildActionCard(
                  title: "Create Mock Test",
                  subtitle: "Add MCQs & auto-grade",
                  icon: Icons.quiz_outlined,
                  color: AppTheme.purple,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CreateTestScreen()),
                    );
                  },
                ),
                _buildActionCard(
                  title: "Mark Attendance",
                  subtitle: "Batch student roster",
                  icon: Icons.fact_check_outlined,
                  color: AppTheme.success,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const MarkAttendanceScreen()),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Active Batches Quick List
            SectionHeader(
              title: "My Assigned Batches",
              actionText: "View All",
              onActionTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TeacherBatchesScreen()),
                );
              },
            ),
            const SizedBox(height: 8),
            for (var batch in batches.take(2)) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                child: ModernCard(
                  padding: const EdgeInsets.all(14),
                  backgroundColor: AppTheme.surface,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.school, color: AppTheme.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              batch.name,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "⏰ ${batch.timing} • ${batch.totalStudents} enrolled",
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.fact_check, color: AppTheme.primary, size: 20),
                        tooltip: "Mark Attendance",
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const MarkAttendanceScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ModernCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      backgroundColor: AppTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
