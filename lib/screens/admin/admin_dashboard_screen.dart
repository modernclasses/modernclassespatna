import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_card.dart';
import '../../core/widgets/section_header.dart';
import '../../providers/course_provider.dart';
import '../../providers/test_provider.dart';
import 'manage_courses_screen.dart';
import 'manage_students_screen.dart';
import 'broadcast_announcement_screen.dart';
import 'revenue_reports_screen.dart';
import 'app_settings_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final courseProvider = context.watch<CourseProvider>();
    final testProvider = context.watch<TestProvider>();

    final totalRevenue = courseProvider.transactions.fold<double>(0, (sum, t) => sum + t.amountPaid);
    final totalBatches = courseProvider.batches.length;
    final totalStudents = courseProvider.batches.fold<int>(0, (sum, b) => sum + b.totalStudents);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Admin Title Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Executive Command Center ⚡",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        "Modern Classes Patna • Madhurendra Kumar Yadav",
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const CustomBadge(text: "ADMIN", variant: BadgeVariant.primary),
              ],
            ),
            const SizedBox(height: 16),

            // Top Key Performance Indicators (KPIs)
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    title: "Total Revenue",
                    value: Formatters.formatCurrency(totalRevenue),
                    sub: "+24% this month",
                    icon: Icons.currency_rupee,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildKpiCard(
                    title: "Active Students",
                    value: "$totalStudents",
                    sub: "100k Capacity",
                    icon: Icons.people_outline,
                    color: AppTheme.secondaryLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    title: "Active Batches",
                    value: "$totalBatches Batches",
                    sub: "${courseProvider.courses.length} Crash Courses",
                    icon: Icons.school_outlined,
                    color: AppTheme.purple,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildKpiCard(
                    title: "Tests & Exams",
                    value: "${testProvider.tests.length} Active",
                    sub: "Auto-graded with ranks",
                    icon: Icons.quiz_outlined,
                    color: AppTheme.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Management Operations Grid
            SectionHeader(title: "Coaching Center Controls"),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.45,
              children: [
                _buildAdminNavTile(
                  title: "Courses & Batches",
                  sub: "Manage pricing & schedule",
                  icon: Icons.menu_book,
                  color: AppTheme.primary,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ManageCoursesScreen()),
                    );
                  },
                ),
                _buildAdminNavTile(
                  title: "Student Roster",
                  sub: "Directory & batch enrolls",
                  icon: Icons.badge_outlined,
                  color: AppTheme.secondaryLight,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ManageStudentsScreen()),
                    );
                  },
                ),
                _buildAdminNavTile(
                  title: "Push Broadcast",
                  sub: "Send alerts to all students",
                  icon: Icons.campaign_outlined,
                  color: AppTheme.error,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const BroadcastAnnouncementScreen()),
                    );
                  },
                ),
                _buildAdminNavTile(
                  title: "Sales & Invoices",
                  sub: "Transaction ledger & coupons",
                  icon: Icons.receipt_long,
                  color: AppTheme.success,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RevenueReportsScreen()),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Quick App Settings shortcut
            ModernCard(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AppSettingsScreen()),
                );
              },
              padding: const EdgeInsets.all(16),
              backgroundColor: AppTheme.surfaceCard,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.settings_outlined, color: AppTheme.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Security & Center Settings",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "Owner: Madhurendra Yadav • Phone: 6209016951",
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textMuted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String sub,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              Icon(icon, size: 18, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
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
            sub,
            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
