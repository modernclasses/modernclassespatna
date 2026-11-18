import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import 'app_logo.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../screens/student/notifications_screen.dart';

class ModernAppScaffold extends StatefulWidget {
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
  State<ModernAppScaffold> createState() => _ModernAppScaffoldState();
}

class _ModernAppScaffoldState extends State<ModernAppScaffold> {
  bool _isBarsVisible = true;

  @override
  void didUpdateWidget(covariant ModernAppScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedNavIndex != widget.selectedNavIndex) {
      _isBarsVisible = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final notifProvider = context.watch<NotificationProvider>();
    final isDesktopOrTablet = !Responsive.isMobile(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final topBarHeight = isLandscape ? 46.0 : (kToolbarHeight + 1.0);
    // Minimum scroll range required before bars are allowed to hide.
    // If maxScrollExtent <= minScrollExtentThreshold, the content fits comfortably within the
    // viewport or hiding the bars will swallow the remaining scroll range, trapping the user.
    final minScrollExtentThreshold = topBarHeight + 60.0;

    final content = NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis == Axis.vertical) {
          if (notification is UserScrollNotification) {
            if (notification.direction == ScrollDirection.reverse) {
              // Only hide bars if content genuinely has a meaningful scroll range
              if (notification.metrics.maxScrollExtent > minScrollExtentThreshold) {
                if (_isBarsVisible) {
                  setState(() => _isBarsVisible = false);
                }
              }
            } else if (notification.direction == ScrollDirection.forward) {
              if (!_isBarsVisible) {
                setState(() => _isBarsVisible = true);
              }
            }
          } else if (notification is ScrollUpdateNotification) {
            // Negative scrollDelta means scrolling up / pulling content down
            if (notification.scrollDelta != null && notification.scrollDelta! < -4.0) {
              if (!_isBarsVisible) {
                setState(() => _isBarsVisible = true);
              }
            }
          } else if (notification is OverscrollNotification) {
            // User is pulling down at the top edge of the scroll view
            if (notification.overscroll < 0) {
              if (!_isBarsVisible) {
                setState(() => _isBarsVisible = true);
              }
            }
          }
        }
        return false;
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerMove: (event) {
          // Reliable recovery: if bars are hidden and user drags down anywhere (> 6px), restore bars
          if (!_isBarsVisible && event.delta.dy > 6.0) {
            setState(() => _isBarsVisible = true);
          }
        },
        onPointerUp: (event) {
          // Reliable recovery: if bars are hidden and user taps in the bottom navigation zone, restore bars
          if (!_isBarsVisible) {
            final screenHeight = MediaQuery.sizeOf(context).height;
            if (event.position.dy > screenHeight - 72.0) {
              setState(() => _isBarsVisible = true);
            }
          }
        },
        child: widget.body,
      ),
    );
    final topBarContent = widget.showAppBar
        ? AppBar(
            toolbarHeight: isLandscape ? 46 : kToolbarHeight,
            backgroundColor:
                Theme.of(context).appBarTheme.backgroundColor ??
                (isDark ? AppColors.darkSurface : AppColors.surface),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(
                height: 1,
                thickness: 1,
                color: isDark ? AppColors.darkBorder : AppColors.border,
              ),
            ),
            titleSpacing: 16,
            title: Row(
              children: [
                AppLogo(size: isLandscape ? 26 : 32, showShadow: false),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title.isNotEmpty
                            ? widget.title
                            : "Modern Classes Patna",
                        style: TextStyle(
                          fontSize: isLandscape ? 13 : 14.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.deepInk,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!isLandscape)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5.5,
                              height: 5.5,
                              decoration: const BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                auth.isStudent
                                    ? "Student Academic Center"
                                    : auth.isTeacher
                                    ? "Faculty Workspace"
                                    : "Executive Admin Suite",
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: isDark
                                      ? AppColors.darkTextMuted
                                      : AppColors.textMuted,
                                  fontWeight: FontWeight.w600,
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
              _buildRoleIndicator(context, auth),
              const SizedBox(width: 4),

              // Notifications icon
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.notifications_outlined,
                      size: 21,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.deepInk,
                    ),
                    tooltip: "Notifications",
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      );
                    },
                  ),
                  if (notifProvider.unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 15,
                          minHeight: 15,
                        ),
                        child: Text(
                          '${notifProvider.unreadCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
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
                  icon: Icon(
                    Icons.logout_rounded,
                    size: 19,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.textMuted,
                  ),
                  tooltip: "Exit Portal",
                  onPressed: () => _confirmLogout(context, auth),
                ),
              ],
              ...?widget.actions,
              const SizedBox(width: 8),
            ],
          )
        : null;

    final animatedTopBar = widget.showAppBar && topBarContent != null
        ? ClipRect(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              height: _isBarsVisible ? topBarHeight : 0.0,
              child: AnimatedSlide(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              offset: _isBarsVisible ? Offset.zero : const Offset(0, -1.2),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                opacity: _isBarsVisible ? 1.0 : 0.0,
                child: SizedBox(
                  height: topBarHeight,
                  child: topBarContent,
                ),
              ),
            ),
          ),
        )
        : null;

    final responsiveBody = isDesktopOrTablet && widget.navDestinations != null
        ? Row(
            children: [
              NavigationRail(
                backgroundColor: isDark
                    ? AppColors.darkSurface
                    : AppColors.surface,
                selectedIndex: widget.selectedNavIndex,
                onDestinationSelected: widget.onNavIndexChanged,
                labelType: NavigationRailLabelType.all,
                selectedIconTheme: IconThemeData(
                  color: isDark
                      ? AppColors.primaryLight
                      : AppColors.primaryDark,
                ),
                unselectedIconTheme: IconThemeData(
                  color: isDark
                      ? AppColors.darkTextMuted
                      : AppColors.textMuted,
                ),
                selectedLabelTextStyle: TextStyle(
                  color: isDark
                      ? AppColors.primaryLight
                      : AppColors.primaryDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                unselectedLabelTextStyle: TextStyle(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                  fontSize: 11,
                ),
                destinations: widget.navDestinations!.map((d) {
                  return NavigationRailDestination(
                    icon: d.icon,
                    selectedIcon: d.icon,
                    label: Text(d.label),
                  );
                }).toList(),
              ),
              VerticalDivider(
                thickness: 1,
                width: 1,
                color: isDark ? AppColors.darkBorder : AppColors.border,
              ),
              Expanded(child: content),
            ],
          )
        : content;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: null,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            ?animatedTopBar,
            Expanded(child: responsiveBody),
          ],
        ),
      ),
      bottomNavigationBar: isDesktopOrTablet
          ? null
          : (widget.bottomNavigationBar != null
              ? AnimatedSlide(
                  offset:
                      _isBarsVisible ? Offset.zero : const Offset(0, 1.2),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    height: _isBarsVisible
                        ? (isLandscape ? 54.0 : null)
                        : 0.0,
                    child: Wrap(
                      children: [
                        if (_isBarsVisible) widget.bottomNavigationBar!,
                      ],
                    ),
                  ),
                )
              : null),
      floatingActionButton: widget.floatingActionButton,
    );
  }

  Widget _buildRoleIndicator(BuildContext context, AuthProvider auth) {
    final isCompact = MediaQuery.sizeOf(context).width < 420;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final roleColor = auth.isStudent
        ? (isDark ? AppColors.primaryLight : AppColors.primaryDark)
        : auth.isTeacher
        ? (isDark ? const Color(0xFF93C5FD) : AppColors.secondary)
        : (isDark ? const Color(0xFFDDD6FE) : AppColors.purple);

    final roleBg = auth.isStudent
        ? (isDark
              ? AppColors.primary.withValues(alpha: 0.18)
              : AppColors.saffronMuted)
        : auth.isTeacher
        ? (isDark
              ? AppColors.secondary.withValues(alpha: 0.25)
              : AppColors.secondaryMuted)
        : (isDark
              ? AppColors.purple.withValues(alpha: 0.22)
              : AppColors.purpleBg);

    final roleBorder = auth.isStudent
        ? (isDark
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.saffronBorder)
        : auth.isTeacher
        ? (isDark
              ? AppColors.secondaryLight.withValues(alpha: 0.4)
              : AppColors.secondaryLight.withValues(alpha: 0.3))
        : (isDark
              ? AppColors.purple.withValues(alpha: 0.4)
              : AppColors.purpleBorder);

    final iconData = auth.isStudent
        ? Icons.school_outlined
        : auth.isTeacher
        ? Icons.cast_for_education
        : Icons.admin_panel_settings_outlined;

    if (isCompact) {
      return Tooltip(
        message: "${auth.currentUser.role.name.toUpperCase()} PORTAL",
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: roleBg,
            shape: BoxShape.circle,
            border: Border.all(color: roleBorder),
          ),
          child: Icon(iconData, size: 13, color: roleColor),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: roleBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: roleBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 12, color: roleColor),
          const SizedBox(width: 4),
          Text(
            auth.currentUser.role.name.toUpperCase(),
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: roleColor,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, AuthProvider auth) {
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
          "Exit Portal",
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
          ),
        ),
        content: Text(
          "Are you sure you want to sign out of this portal?",
          style: TextStyle(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
            fontSize: 13.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Cancel",
              style: TextStyle(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              auth.logout();
            },
            child: const Text(
              "Sign Out",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
