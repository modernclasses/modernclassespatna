import 'package:flutter/material.dart';
import '../../../../data/mock_data.dart';
import '../data/models/notification_model.dart';
import '../data/repositories/notification_repository.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationRepository _repository;

  List<NotificationModel> _notifications = List.from(MockData.notifications);
  bool _isLoading = false;
  String? _errorMessage;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  NotificationProvider({NotificationRepository? repository})
      : _repository = repository ?? NotificationRepositoryImpl() {
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetched = await _repository.getNotifications();
      if (fetched.isNotEmpty) _notifications = fetched;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

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
    _repository.broadcastAnnouncement(newNotif);
    notifyListeners();
  }
}
