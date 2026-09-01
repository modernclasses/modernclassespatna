import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_card.dart';
import '../../providers/auth_provider.dart';
import 'my_batches_screen.dart';
import 'attendance_screen.dart';
import 'payment_history_screen.dart';

class StudentProfileScreen extends StatelessWidget {
  const StudentProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Student Profile & Account"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // User Avatar Card
            ModernCard(
              padding: const EdgeInsets.all(20),
              backgroundColor: AppTheme.surfaceCard,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppTheme.primary,
                    child: Text(
                      user.name.substring(0, 1),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CustomBadge(text: "📱 ${user.phone}", variant: BadgeVariant.primary),
                      const SizedBox(width: 8),
                      CustomBadge(
                        text: "${user.enrolledCourseIds.length} Active Courses",
                        variant: BadgeVariant.success,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Navigation Options
            ModernCard(
              padding: EdgeInsets.zero,
              backgroundColor: AppTheme.surface,
              child: Column(
                children: [
                  _buildProfileTile(
                    icon: Icons.school_outlined,
                    title: "My Enrolled Batches",
                    subtitle: "View lectures, PDFs, and assignments",
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const MyBatchesScreen()),
                      );
                    },
                  ),
                  const Divider(color: AppTheme.border),
                  _buildProfileTile(
                    icon: Icons.fact_check_outlined,
                    title: "Attendance & Engagement",
                    subtitle: "Track monthly presence and participation",
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AttendanceScreen()),
                      );
                    },
                  ),
                  const Divider(color: AppTheme.border),
                  _buildProfileTile(
                    icon: Icons.receipt_long_outlined,
                    title: "Payment History & Invoices",
                    subtitle: "View fee receipts and tax invoices",
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PaymentHistoryScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Coaching Centre Info Card
            ModernCard(
              padding: const EdgeInsets.all(16),
              backgroundColor: AppTheme.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.location_city, color: AppTheme.primary, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "Modern Classes Patna Support",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Contact Person: Madhurendra Kumar Yadav",
                    style: TextStyle(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Helpline: +91 6209016951",
                    style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Email: madhurendrayadav06@gmail.com",
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Address: Boring Road / Musallahpur Hat, Patna, Bihar",
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Sign Out / Exit App
            OutlinedButton.icon(
              icon: const Icon(Icons.logout, size: 18, color: AppTheme.error),
              label: const Text("Sign Out of Account", style: TextStyle(color: AppTheme.error)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.error),
                minimumSize: const Size(double.infinity, 46),
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

  void _showLogoutDialog(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        title: const Text("Sign Out Confirmation"),
        content: const Text("Are you sure you want to sign out from your student account?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () {
              Navigator.pop(ctx);
              auth.logout();
            },
            child: const Text("Sign Out", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primary),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textMuted),
        onTap: onTap,
      ),
    );
  }
}
