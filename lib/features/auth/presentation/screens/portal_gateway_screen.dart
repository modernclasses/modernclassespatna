import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/custom_badge.dart';
import '../../../../core/widgets/modern_card.dart';
import 'login_screen.dart';
import 'staff_login_screen.dart';

class PortalGatewayScreen extends StatelessWidget {
  const PortalGatewayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Brand Logo & Crest
                  const AppLogo(size: 88, showShadow: true),
                  const SizedBox(height: 18),
                  const Text(
                    "MODERN CLASSES PATNA",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Digital Learning & Institutional Management Platform",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  CustomBadge(
                    text: "Director: Madhurendra Kumar Yadav",
                    variant: BadgeVariant.primary,
                  ),
                  const SizedBox(height: 36),

                  // Portal Selection Cards
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Select Your Portal Gateway",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 1. Student Portal
                  _buildGatewayTile(
                    context: context,
                    title: "Student Learning App",
                    subtitle: "Attend live classes, watch recordings, take tests & read notes",
                    badge: "For Students",
                    badgeColor: AppTheme.primary,
                    icon: Icons.school,
                    iconColor: AppTheme.primary,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 14),

                  // 2. Faculty Portal
                  _buildGatewayTile(
                    context: context,
                    title: "Faculty & Teacher Portal",
                    subtitle: "Schedule live YouTube streams, upload notes & mark attendance",
                    badge: "Teaching Staff",
                    badgeColor: AppTheme.secondaryLight,
                    icon: Icons.cast_for_education,
                    iconColor: AppTheme.secondaryLight,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const StaffLoginScreen(initialTabIndex: 0),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),

                  // 3. Admin Command Suite
                  _buildGatewayTile(
                    context: context,
                    title: "Admin Command Suite",
                    subtitle: "Executive center control, student roster, revenue & broadcasts",
                    badge: "5 Admin Seats Lock",
                    badgeColor: AppTheme.purple,
                    icon: Icons.admin_panel_settings,
                    iconColor: AppTheme.purple,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const StaffLoginScreen(initialTabIndex: 1),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // Support & Helpline Footer
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.support_agent, size: 18, color: AppTheme.primary),
                        SizedBox(width: 8),
                        Text(
                          "Official Helpline: +91 6209016951",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGatewayTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return ModernCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      backgroundColor: AppTheme.surface,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: badgeColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textMuted),
        ],
      ),
    );
  }
}
