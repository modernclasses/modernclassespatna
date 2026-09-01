import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../data/mock_data.dart';

class NotificationProvider extends ChangeNotifier {
  final List<NotificationModel> _notifications = List.from(MockData.notifications);

  List<NotificationModel> get notifications => _notifications;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      notifyListeners();
    }
  }

  void markAllAsRead() {
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    notifyListeners();
  }

  void broadcastAnnouncement({
    required String title,
    required String message,
    NotificationCategory category = NotificationCategory.announcement,
  }) {
    final newNotif = NotificationModel(
      id: "notif_${DateTime.now().millisecondsSinceEpoch}",
      title: title,
      message: message,
      category: category,
      timestamp: DateTime.now(),
    );

    _notifications.insert(0, newNotif);
    notifyListeners();
  }
}
