import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/modern_card.dart';
import '../../models/notification_model.dart';
import '../../providers/notification_provider.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notifProvider = context.watch<NotificationProvider>();
    final notifs = notifProvider.notifications;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Notifications"),
        actions: [
          if (notifProvider.unreadCount > 0)
            TextButton.icon(
              onPressed: () {
                notifProvider.markAllAsRead();
              },
              icon: const Icon(Icons.done_all, size: 16, color: AppTheme.primary),
              label: const Text(
                "Mark all read",
                style: TextStyle(color: AppTheme.primary, fontSize: 12),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: notifs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: AppTheme.textMuted),
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
                return ModernCard(
                  onTap: () {
                    notifProvider.markAsRead(notif.id);
                  },
                  backgroundColor: notif.isRead
                      ? AppTheme.surface
                      : AppTheme.surfaceElevated,
                  borderColor: notif.isRead ? AppTheme.border : AppTheme.primary.withValues(alpha: 0.4),
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(notif.category).withValues(alpha: 0.15),
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    notif.title,
                                    style: TextStyle(
                                      fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.w800,
                                      fontSize: 14,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                                if (!notif.isRead)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: AppTheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              notif.message,
                              style: TextStyle(
                                fontSize: 13,
                                color: notif.isRead ? AppTheme.textMuted : AppTheme.textSecondary,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              Formatters.timeAgo(notif.timestamp),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
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
