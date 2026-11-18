import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_card.dart';
import '../../core/widgets/section_header.dart';
import '../../providers/course_provider.dart';
import '../../providers/test_provider.dart';
import 'manage_courses_screen.dart';
import 'manage_students_screen.dart';
import 'manage_teachers_screen.dart';
import 'broadcast_announcement_screen.dart';
import 'revenue_reports_screen.dart';
import 'app_settings_screen.dart';
import 'admin_recordings_screen.dart';
import 'admin_live_monitor_screen.dart';
import '../teacher/upload_lecture_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CourseProvider>().fetchAdminManualCollectionsTotal();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final courseProvider = context.watch<CourseProvider>();
    final testProvider = context.watch<TestProvider>();
    final totalCollections = courseProvider.adminManualCollectionsTotal;
    final netCollections = courseProvider.adminNetCollectionsTotal;
    final totalBatches = courseProvider.batches.length;
    final totalStudents = courseProvider.batches.fold<int>(
      0,
      (sum, b) => sum + b.totalStudents,
    );
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Admin Executive Masthead
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
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
                    child: Icon(
                      Icons.shield_outlined,
                      color: isDark ? AppColors.primaryLight : Colors.white,
                      size: 22,
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
                                "Executive Command Suite",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.2,
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.deepInk,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const CustomBadge(
                              text: "ADMIN",
                              variant: BadgeVariant.primary,
                              fontSize: 9,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Modern Classes Patna • Madhurendra Kumar Yadav",
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
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
            // Top Key Performance Indicators (KPIs)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildKpiTile(
                      title: "MANUAL COLLECTIONS",
                      value: netCollections != null
                          ? Formatters.formatCurrencyWithDecimals(netCollections)
                          : (totalCollections != null
                              ? Formatters.formatCurrency(totalCollections)
                              : "--"),
                      subtext: totalCollections != null && totalCollections > 0
                          ? "Net • Gross ${Formatters.formatCurrency(totalCollections)} (-15% Google)"
                          : "Net revenue (-15% Google cut)",
                      icon: Icons.currency_rupee_rounded,
                      color: AppColors.primaryDark,
                      bg: AppColors.saffronMuted,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildKpiTile(
                      title: "ENROLLED STUDENTS",
                      value: "$totalStudents",
                      subtext: "Across all active batches",
                      icon: Icons.people_alt_outlined,
                      color: AppColors.secondary,
                      bg: AppColors.secondaryMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildKpiTile(
                      title: "Active Batches",
                      value: "$totalBatches Batches",
                      subtext:
                          "${courseProvider.courses.length} Exam Crash Courses",
                      icon: Icons.school_outlined,
                      color: AppColors.purple,
                      bg: AppColors.purpleBg,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildKpiTile(
                      title: "Tests & Exams",
                      value: "${testProvider.tests.length} Active",
                      subtext: "Objective papers & rankings",
                      icon: Icons.quiz_outlined,
                      color: AppColors.success,
                      bg: AppColors.successBg,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Coaching Operations Grid
            const SectionHeader(
              eyebrow: "INSTITUTE CONTROLS",
              title: "Operational Modules",
              subtitle: "Curriculum, faculty allots, rosters & communications",
            ),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: MediaQuery.of(context).size.width < 340
                  ? 1.15
                  : (MediaQuery.of(context).size.width < 400 ? 1.3 : 1.45),
              children: [
                _buildAdminNavTile(
                  title: "Courses & Batches",
                  sub: "Manage pricing & schedule",
                  icon: Icons.menu_book_outlined,
                  color: AppColors.primaryDark,
                  bg: AppColors.saffronMuted,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ManageCoursesScreen(),
                      ),
                    );
                  },
                ),
                _buildAdminNavTile(
                  title: "Student Roster",
                  sub: "Directory & batch enrolls",
                  icon: Icons.badge_outlined,
                  color: AppColors.secondary,
                  bg: AppColors.secondaryMuted,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ManageStudentsScreen(),
                      ),
                    );
                  },
                ),
                _buildAdminNavTile(
                  title: "Faculty Assignments",
                  sub: "Assign teachers to batches",
                  icon: Icons.school_outlined,
                  color: AppColors.purple,
                  bg: AppColors.purpleBg,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ManageTeachersScreen(),
                      ),
                    );
                  },
                ),
                _buildAdminNavTile(
                  title: "Push Notifications",
                  sub: "Broadcast alerts & notices",
                  icon: Icons.campaign_outlined,
                  color: AppColors.error,
                  bg: AppColors.errorBg,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const BroadcastAnnouncementScreen(),
                      ),
                    );
                  },
                ),
                _buildAdminNavTile(
                  title: "Revenue & Ledger",
                  sub: "Transaction history & audits",
                  icon: Icons.receipt_long_outlined,
                  color: AppColors.success,
                  bg: AppColors.successBg,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const RevenueReportsScreen(),
                      ),
                    );
                  },
                ),
                _buildAdminNavTile(
                  title: "Institute & Center Settings",
                  sub: "Identity, Security & DRM",
                  icon: Icons.tune_outlined,
                  color: isDark ? AppColors.primaryLight : AppColors.deepInk,
                  bg: isDark ? AppColors.darkSurface : AppColors.surfaceSubtle,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AppSettingsScreen(),
                      ),
                    );
                  },
                ),
                _buildAdminNavTile(
                  title: "Upload Lecture Video",
                  sub: "Direct upload for any batch",
                  icon: Icons.video_call_outlined,
                  color: AppColors.primary,
                  bg: AppColors.saffronMuted,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const UploadLectureScreen(),
                      ),
                    );
                  },
                ),
                _buildAdminNavTile(
                  title: "Lecture Recordings",
                  sub: "Browse archives & status",
                  icon: Icons.video_library_outlined,
                  color: AppColors.primary,
                  bg: AppColors.saffronMuted,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AdminRecordingsScreen(),
                      ),
                    );
                  },
                ),
                _buildAdminNavTile(
                  title: "Live Stream Monitor",
                  sub: "Active broadcasts & controls",
                  icon: Icons.cell_tower,
                  color: AppColors.error,
                  bg: AppColors.errorBg,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AdminLiveMonitorScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiTile({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color color,
    required Color bg,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark ? color.withValues(alpha: 0.2) : bg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              subtext,
              maxLines: 1,
              style: TextStyle(
                fontSize: 9.5,
                color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminNavTile({
    required String title,
    required String sub,
    required IconData icon,
    required Color color,
    required Color bg,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ModernCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? color.withValues(alpha: 0.2) : bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
