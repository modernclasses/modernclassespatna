import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import 'app_logo.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../screens/student/notifications_screen.dart';

class ModernAppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? floatingActionButton;
  final List<Widget>? actions;
  final Widget? bottomNavigationBar;
  final int selectedNavIndex;
  final ValueChanged<int>? onNavIndexChanged;
  final List<NavigationDestination>? navDestinations;
  final bool showAppBar;

  const ModernAppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.floatingActionButton,
    this.actions,
    this.bottomNavigationBar,
    this.selectedNavIndex = 0,
    this.onNavIndexChanged,
    this.navDestinations,
    this.showAppBar = true,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final notifProvider = context.watch<NotificationProvider>();
    final isDesktopOrTablet = !Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: showAppBar
          ? AppBar(
              backgroundColor: AppTheme.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              title: Row(
                children: [
                  const AppLogo(size: 34, showShadow: false),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title.isNotEmpty ? title : "Modern Classes Patna",
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppTheme.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                auth.isStudent
                                    ? "Student Learning Portal"
                                    : auth.isTeacher
                                        ? "Faculty Web Console"
                                        : "Master Admin Suite",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                // Clean Status Badge
                _buildRoleIndicator(context, auth),
                const SizedBox(width: 4),

                // Notifications icon
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined, size: 22),
                      tooltip: "Notifications",
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                        );
                      },
                    ),
                    if (notifProvider.unreadCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppTheme.error,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '${notifProvider.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),

                // Quick Logout for Teacher/Admin
                if (!auth.isStudent) ...[
                  IconButton(
                    icon: const Icon(Icons.logout, size: 20, color: AppTheme.textMuted),
                    tooltip: "Exit Portal",
                    onPressed: () => _confirmLogout(context, auth),
                  ),
                ],
                ...?actions,
                const SizedBox(width: 8),
              ],
            )
          : null,
      body: isDesktopOrTablet && navDestinations != null
          ? Row(
              children: [
                NavigationRail(
                  backgroundColor: AppTheme.surface,
                  selectedIndex: selectedNavIndex,
                  onDestinationSelected: onNavIndexChanged,
                  labelType: NavigationRailLabelType.all,
                  selectedIconTheme: const IconThemeData(color: AppTheme.primary),
                  unselectedIconTheme: const IconThemeData(color: AppTheme.textMuted),
                  selectedLabelTextStyle: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  unselectedLabelTextStyle: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                  destinations: navDestinations!.map((d) {
                    return NavigationRailDestination(
                      icon: d.icon,
                      selectedIcon: d.selectedIcon ?? d.icon,
                      label: Text(d.label),
                    );
                  }).toList(),
                ),
                const VerticalDivider(thickness: 1, width: 1, color: AppTheme.border),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: isDesktopOrTablet ? null : bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }

  Widget _buildRoleIndicator(BuildContext context, AuthProvider auth) {
    final isCompact = MediaQuery.sizeOf(context).width < 480;

    final roleColor = auth.isStudent
        ? AppTheme.primary
        : auth.isTeacher
            ? AppTheme.secondaryLight
            : AppTheme.purple;

    final iconData = auth.isStudent
        ? Icons.school
        : auth.isTeacher
            ? Icons.cast_for_education
            : Icons.admin_panel_settings;

    if (isCompact) {
      return Tooltip(
        message: "${auth.currentUser.role.name.toUpperCase()} PORTAL",
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: roleColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: roleColor.withValues(alpha: 0.4)),
          ),
          child: Icon(
            iconData,
            size: 14,
            color: roleColor,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: roleColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: roleColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            iconData,
            size: 13,
            color: roleColor,
          ),
          const SizedBox(width: 4),
          Text(
            auth.currentUser.role.name.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: roleColor,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        title: const Text("Exit Portal"),
        content: const Text("Are you sure you want to sign out of this portal?"),
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
}
