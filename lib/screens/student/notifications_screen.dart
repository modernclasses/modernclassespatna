import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/modern_card.dart';
import '../../models/notification_model.dart';
import '../../providers/notification_provider.dart';
import '../../core/widgets/app_loading_indicator.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notifProvider = context.watch<NotificationProvider>();
    final notifs = notifProvider.notifications;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Notifications"),
        actions: [
          if (notifProvider.unreadCount > 0)
            TextButton.icon(
              onPressed: () {
                notifProvider.markAllAsRead();
              },
              icon: const Icon(
                Icons.done_all,
                size: 16,
                color: AppTheme.primary,
              ),
              label: const Text(
                "Mark all read",
                style: TextStyle(color: AppTheme.primary, fontSize: 12),
              ),
            ),
          if (notifs.isNotEmpty)
            IconButton(
              key: const Key('clear_all_notifications_button'),
              icon: const Icon(Icons.delete_sweep_outlined, size: 20),
              tooltip: "Clear all notifications",
              onPressed: () => _confirmClearAll(context, notifProvider),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: notifProvider.isLoading
          ? const AppLoadingIndicator()
          : notifProvider.errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Failed to load notifications.",
                    style: TextStyle(color: AppTheme.error),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () => notifProvider.fetchNotifications(),
                    child: const Text("Retry"),
                  ),
                ],
              ),
            )
          : notifs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: AppTheme.textMuted,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "No notifications yet",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final notif = notifs[index];
                return Dismissible(
                  key: Key('dismissible_${notif.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    notifProvider.deleteNotification(notif.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text("Notification deleted"),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: ModernCard(
                    onTap: () {
                      notifProvider.markAsRead(notif.id);
                    },
                    backgroundColor: notif.isRead
                        ? (isDark
                            ? AppColors.darkSurfaceCard
                            : AppTheme.surface)
                        : (isDark
                            ? AppColors.darkSurface
                            : AppTheme.surfaceElevated),
                    borderColor: notif.isRead
                        ? (isDark ? AppColors.darkBorder : AppTheme.border)
                        : (isDark
                            ? AppColors.primary.withValues(alpha: 0.6)
                            : AppColors.primary.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _getCategoryColor(
                              notif.category,
                            ).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getCategoryIcon(notif.category),
                            size: 20,
                            color: _getCategoryColor(notif.category),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      notif.title,
                                      style: TextStyle(
                                        fontWeight: notif.isRead
                                            ? FontWeight.w600
                                            : FontWeight.w800,
                                        fontSize: 14,
                                        color: isDark
                                            ? AppColors.darkTextPrimary
                                            : AppTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  if (!notif.isRead)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.only(top: 4),
                                      decoration: const BoxDecoration(
                                        color: AppTheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  IconButton(
                                    key: Key('delete_notif_${notif.id}'),
                                    icon: const Icon(Icons.close, size: 16),
                                    color: isDark
                                        ? AppColors.darkTextMuted
                                        : AppTheme.textMuted,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: "Delete",
                                    onPressed: () {
                                      notifProvider.deleteNotification(notif.id);
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                notif.message,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? (notif.isRead
                                          ? AppColors.darkTextMuted
                                          : AppColors.darkTextSecondary)
                                      : (notif.isRead
                                          ? AppTheme.textMuted
                                          : AppTheme.textSecondary),
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                Formatters.timeAgo(notif.timestamp),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppColors.darkTextMuted
                                      : AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _confirmClearAll(
      BuildContext context, NotificationProvider notifProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor:
              isDark ? AppColors.darkSurfaceCard : AppColors.surface,
          title: const Text(
            "Clear all notifications?",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "Are you sure you want to remove all notifications? This action cannot be undone.",
            style: TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                notifProvider.clearAllNotifications();
              },
              child: const Text("Clear All"),
            ),
          ],
        );
      },
    );
  }

  IconData _getCategoryIcon(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.liveClass:
        return Icons.live_tv;
      case NotificationCategory.test:
        return Icons.quiz_outlined;
      case NotificationCategory.material:
        return Icons.menu_book;
      case NotificationCategory.payment:
        return Icons.receipt_long;
      case NotificationCategory.reminder:
        return Icons.alarm;
      case NotificationCategory.announcement:
        return Icons.campaign;
    }
  }

  Color _getCategoryColor(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.liveClass:
        return AppTheme.error;
      case NotificationCategory.test:
        return AppTheme.primary;
      case NotificationCategory.material:
        return AppTheme.secondary;
      case NotificationCategory.payment:
        return AppTheme.success;
      case NotificationCategory.reminder:
        return AppTheme.warning;
      case NotificationCategory.announcement:
        return AppTheme.purple;
    }
  }
}
