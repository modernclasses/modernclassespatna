import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/organization_provider.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    OrganizationProvider? org;
    try {
      org = context.watch<OrganizationProvider>();
    } catch (_) {}
    final instituteName = org?.instituteName ?? "MODERN CLASSES PATNA";
    final directorName = org?.directorName ?? "Madhurendra Kumar Yadav";
    final helpline = org?.helplinePhone ?? "+91 6209016951";
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 60,
        elevation: 0,
        centerTitle: true,
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(size: 30, showShadow: false),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                instituteName.toUpperCase(),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Digital Learning & Institutional Management Platform",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  CustomBadge(
                    text: "Director: $directorName",
                    variant: BadgeVariant.primary,
                  ),
                  const SizedBox(height: 24),

                  // Portal Selection Section Header
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "SELECT YOUR PORTAL GATEWAY",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 1. Student Portal (Primary highlighted gateway)
                  _buildGatewayTile(
                    context: context,
                    title: "Student Learning App",
                    subtitle:
                        "Attend live classes, watch recordings, take tests & read notes",
                    badge: "For Students",
                    badgeColor: AppColors.primaryDark,
                    badgeBg: AppColors.saffronMuted,
                    badgeBorder: AppColors.saffronBorder,
                    icon: Icons.school_outlined,
                    iconColor: AppColors.primaryDark,
                    iconBg: AppColors.saffronMuted,
                    accentSpine: AppColors.primary,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // 2. Faculty & Admin Portal (Unified Staff Gateway)
                  _buildGatewayTile(
                    context: context,
                    title: "Faculty & Admin Portal",
                    subtitle:
                        "Deliver live lectures, publish tests, manage student roster & admin suite",
                    badge: "Faculty & Administration",
                    badgeColor: AppColors.secondary,
                    badgeBg: AppColors.secondaryMuted,
                    badgeBorder: AppColors.secondaryLight.withValues(
                      alpha: 0.3,
                    ),
                    icon: Icons.admin_panel_settings_outlined,
                    iconColor: AppColors.secondary,
                    iconBg: AppColors.secondaryMuted,
                    accentSpine: AppColors.secondary,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const StaffLoginScreen(initialTabIndex: 0),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 28),

                  // Support & Helpline Footer
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.support_agent_rounded,
                          size: 18,
                          color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            "Official Helpline: $helpline",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
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
    required Color badgeBg,
    required Color badgeBorder,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required Color accentSpine,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ModernCard(
      onTap: onTap,
      accentSpineColor: accentSpine,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
      borderColor: isDark ? AppColors.darkBorder : AppColors.border,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? accentSpine.withValues(alpha: 0.2) : iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: isDark ? AppColors.primaryLight : iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? badgeColor.withValues(alpha: 0.2) : badgeBg,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: isDark ? badgeColor.withValues(alpha: 0.4) : badgeBorder, width: 0.8),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.primaryLight : badgeColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 12,
            color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}
