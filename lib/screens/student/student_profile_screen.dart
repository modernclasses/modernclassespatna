import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_card.dart';
import '../../providers/auth_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/theme_provider.dart';
import 'my_batches_screen.dart';
import 'attendance_screen.dart';
import 'payment_history_screen.dart';

class StudentProfileScreen extends StatelessWidget {
  const StudentProfileScreen({super.key});


  void _showLegalDialog(BuildContext context, String title, String body) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
        title: Text(
          title,
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(
              body,
              style: AppTypography.bodySmall.copyWith(
                height: 1.5,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Close",
              style: AppTypography.button.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAccountDeletionDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.errorBorder),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
            const SizedBox(width: 8),
            Text(
              "Delete Student Account",
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.error,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "In accordance with Google Play Developer Policies and student data protection standards, you have the right to permanently delete your account and all associated personal data.",
                  style: AppTypography.bodySmall.copyWith(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "What happens upon deletion:\n"
                  "• Your profile, registered phone, and email are permanently purged.\n"
                  "• All mock test scores, rank history, and attendance records are deleted.\n"
                  "• All active batch enrollments and video access will be forfeited.\n"
                  "• Requests are processed and confirmed within 30 days.",
                  style: AppTypography.caption.copyWith(
                    height: 1.45,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Official Deletion Mailbox:",
                        style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      SelectableText(
                        "madhurendrayadav06@gmail.com",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Include your registered mobile number and reason.",
                        style: AppTypography.caption.copyWith(fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Cancel",
              style: AppTypography.button.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "Deletion request noted. Please check your email or contact support to confirm.",
                  ),
                  duration: Duration(seconds: 4),
                ),
              );
            },
            child: Text(
              "Confirm Request",
              style: AppTypography.button.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final courseProvider = context.watch<CourseProvider>();
    final user = auth.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ThemeProvider? themeProvider;
    try {
      themeProvider = Provider.of<ThemeProvider>(context, listen: true);
    } catch (_) {
      themeProvider = null;
    }
    final isThemeDark = themeProvider?.isDarkMode ?? isDark;

    return Scaffold(
      key: const Key('student_profile_root'),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Student Academic Dossier"),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Student Identity Credential Card
            ModernCard(
              padding: const EdgeInsets.all(20),
              accentSpineColor: AppColors.saffron,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: isDark
                        ? AppColors.primary.withValues(alpha: 0.2)
                        : AppColors.saffronMuted,
                    child: Text(
                      user.name.isNotEmpty
                          ? user.name.substring(0, 1).toUpperCase()
                          : 'S',
                      style: AppTypography.displayMedium.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.primaryLight
                            : AppColors.saffronDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      user.name,
                      key: const Key('profile_name_display'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.deepInk,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: AppTypography.bodySmall.copyWith(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      CustomBadge(
                        text: "📱 ${user.phone}",
                        variant: BadgeVariant.primary,
                      ),
                      CustomBadge(
                        text:
                            "${courseProvider.myEnrolledCourseIds.length} Active Courses",
                        variant: BadgeVariant.success,
                      ),
                      const CustomBadge(
                        text: "Single Device Bound",
                        variant: BadgeVariant.outline,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Night Study Mode (Dark Theme Switch)
            ModernCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isThemeDark
                          ? AppColors.primary.withValues(alpha: 0.18)
                          : AppColors.saffronMuted,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isThemeDark
                          ? Icons.dark_mode_outlined
                          : Icons.light_mode_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Night Study Mode",
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isThemeDark
                              ? "Dark theme active (easier on eyes)"
                              : "Light academic theme active",
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    key: const Key('student_theme_mode_switch'),
                    value: isThemeDark,
                    activeTrackColor: AppColors.primary,
                    onChanged: (val) {
                      if (themeProvider != null) {
                        themeProvider.toggleTheme();
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Navigation Options
            ModernCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildProfileTile(
                    context: context,
                    icon: Icons.school_outlined,
                    title: "My Enrolled Batches",
                    subtitle:
                        "Curriculum schedule, video lectures, and syllabus",
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const MyBatchesScreen(),
                        ),
                      );
                    },
                  ),
                  Divider(
                    height: 1,
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                  ),
                  _buildProfileTile(
                    context: context,
                    icon: Icons.fact_check_outlined,
                    title: "Attendance & Engagement",
                    subtitle: "Track monthly session regularity and roll call",
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AttendanceScreen(),
                        ),
                      );
                    },
                  ),
                  Divider(
                    height: 1,
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                  ),
                  _buildProfileTile(
                    context: context,
                    icon: Icons.receipt_long_outlined,
                    title: "Payment History & Invoices",
                    subtitle: "View fee receipts and tax vouchers",
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PaymentHistoryScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Legal, Compliance & Data Rights Card
            ModernCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildProfileTile(
                    context: context,
                    icon: Icons.gavel_outlined,
                    title: "Terms of Use",
                    subtitle: "Educational service terms, single-device rule, and rules of conduct",
                    onTap: () => _showLegalDialog(
                      context,
                      "Terms of Use",
                      "Modern Classes Patna Terms of Use:\n\n"
                      "1. Acceptance & Age Eligibility: Accessing the app binds the user to these terms. Users affirm they are at least 18 years of age or accessing under the supervision and consent of a parent or legal guardian.\n\n"
                      "2. Single-Device Session: Only one smartphone session is active at a time to protect educational content.\n\n"
                      "3. Intellectual Property: All lectures, notes, and tests are exclusive property of Modern Classes Patna. Unauthorized recording, downloading, or sharing is strictly prohibited.\n\n"
                      "4. Disclaimer & Liability Cap: Educational services are provided 'as is'. Maximum aggregate liability is limited to fees paid in the prior 12 months.\n\n"
                      "5. Governing Law: Governed by the laws of India and jurisdiction of courts in Patna, Bihar.",
                    ),
                  ),
                  Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.border),
                  _buildProfileTile(
                    context: context,
                    icon: Icons.privacy_tip_outlined,
                    title: "Privacy Policy",
                    subtitle: "Student data protection, encryption, and zero advertising disclosures",
                    onTap: () => _showLegalDialog(
                      context,
                      "Privacy Policy",
                      "Modern Classes Patna Privacy Disclosures:\n\n"
                      "1. Data Collected: Name, mobile number, email, target exam goal, performance scores, and Google Play billing tokens.\n\n"
                      "2. No Tracking / No Ads: We do not display third-party advertisements or sell student profiles to marketing networks.\n\n"
                      "3. Security: Encrypted via TLS 1.3 in transit and protected by PostgreSQL Row Level Security (RLS) in Supabase.\n\n"
                      "4. User Rights: Students have full rights to inspect, update, or request complete account and data deletion within 30 days.\n\n"
                      "5. Data Protection Officer: Madhurendra Kumar Yadav, Director, Patna, Bihar.",
                    ),
                  ),
                  Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.border),
                  _buildProfileTile(
                    context: context,
                    icon: Icons.assignment_return_outlined,
                    title: "Refund & Cancellation Policy",
                    subtitle: "Google Play billing guidelines and digital course access terms",
                    onTap: () => _showLegalDialog(
                      context,
                      "Refund & Cancellation Policy",
                      "Modern Classes Patna Refund Guidelines:\n\n"
                      "1. Instant Access: Enrolling in digital course batches grants immediate access to video archives, syllabus materials, and live schedule feeds.\n\n"
                      "2. Google Play Billing: In-app purchases adhere to Google Play Developer policies. Self-service refund requests can be submitted via Google Play within 48 hours of purchase.\n\n"
                      "3. Direct Support: For accidental duplicate transactions or access failures, contact madhurendrayadav06@gmail.com with your Google Play Order Number (GPA.xxxx).\n\n"
                      "4. Fixed Batches: Standard enrollments are one-time payments for the published batch duration without hidden recurring monthly fees.",
                    ),
                  ),
                  Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.border),
                  _buildProfileTile(
                    context: context,
                    icon: Icons.delete_forever_outlined,
                    title: "Request Account Deletion",
                    subtitle: "Permanently delete student account, test history, and personal data",
                    onTap: () => _showAccountDeletionDialog(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Coaching Centre Support Info Card
            ModernCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.primary.withValues(alpha: 0.2)
                              : AppColors.saffronMuted,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.location_city_rounded,
                          color: isDark
                              ? AppColors.primaryLight
                              : AppColors.saffronDark,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "Modern Classes Patna Support",
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.deepInk,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildInfoRow(
                    context: context,
                    label: "Director & Faculty",
                    value: "Madhurendra Kumar Yadav",
                    isHighlight: false,
                  ),
                  _buildInfoRow(
                    context: context,
                    label: "Center Helpline",
                    value: "+91 6209016951",
                    isHighlight: true,
                  ),
                  _buildInfoRow(
                    context: context,
                    label: "Support Email",
                    value: "madhurendrayadav06@gmail.com",
                    isHighlight: false,
                  ),
                  _buildInfoRow(
                    context: context,
                    label: "Patna Campus",
                    value: "Boring Road / Musallahpur Hat, Patna, Bihar",
                    isHighlight: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Sign Out Button
            OutlinedButton.icon(
              icon: const Icon(
                Icons.logout_rounded,
                size: 18,
                color: AppColors.error,
              ),
              label: Text(
                "Sign Out of Account",
                style: AppTypography.button.copyWith(color: AppColors.error),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.errorBorder),
                backgroundColor: isDark
                    ? AppColors.error.withValues(alpha: 0.15)
                    : AppColors.errorBg,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                _showLogoutDialog(context, auth);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required BuildContext context,
    required String label,
    required String value,
    required bool isHighlight,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: AppTypography.caption.copyWith(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodySmall.copyWith(
                color: isHighlight
                    ? (isDark ? AppColors.primaryLight : AppColors.saffronDark)
                    : (isDark ? AppColors.darkTextPrimary : AppColors.deepInk),
                fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider auth) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
        ),
        title: Text(
          "Sign Out Confirmation",
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
          ),
        ),
        content: Text(
          "Are you sure you want to sign out from your student account?",
          style: AppTypography.bodySmall.copyWith(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Cancel",
              style: AppTypography.button.copyWith(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              auth.logout();
            },
            child: Text(
              "Sign Out",
              style: AppTypography.button.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: AppTypography.subtitle2.copyWith(
            color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AppTypography.caption.copyWith(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 14,
          color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
        ),
        onTap: onTap,
      ),
    );
  }
}
