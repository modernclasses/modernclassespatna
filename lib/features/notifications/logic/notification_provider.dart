import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/notification_model.dart';
import '../data/repositories/notification_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/push_notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  static const String _kReadNotificationIdsKey = 'read_notification_ids';
  static const String _kDeletedNotificationIdsKey = 'deleted_notification_ids';
  final NotificationRepository _repository;
  RealtimeChannel? _announcementsChannel;

  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  NotificationProvider({NotificationRepository? repository})
      : _repository = repository ?? NotificationRepositoryImpl() {
    fetchNotifications();
    _subscribeToRealtimeAnnouncements();
  }

  @override
  void dispose() {
    try {
      _announcementsChannel?.unsubscribe();
    } catch (_) {}
    super.dispose();
  }


  Future<void> fetchNotifications() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetched = await _repository.getNotifications();
      Set<String> readIds = {};
      Set<String> deletedIds = {};
      try {
        final prefs = await SharedPreferences.getInstance();
        readIds = (prefs.getStringList(_kReadNotificationIdsKey) ?? []).toSet();
        deletedIds =
            (prefs.getStringList(_kDeletedNotificationIdsKey) ?? []).toSet();
      } catch (_) {}

      // Filter out deleted notifications and apply read status
      _notifications = fetched
          .where((n) => !deletedIds.contains(n.id))
          .map((n) {
            if (readIds.contains(n.id)) {
              return n.copyWith(isRead: true);
            }
            return n;
          })
          .toList();

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
      _persistReadId(id);
    }
  }

  void markAllAsRead() {
    final allIds = <String>[];
    for (int i = 0; i < _notifications.length; i++) {
      allIds.add(_notifications[i].id);
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    notifyListeners();
    _persistAllReadIds(allIds);
  }

  Future<void> deleteNotification(String id) async {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final deletedIds =
          (prefs.getStringList(_kDeletedNotificationIdsKey) ?? []).toSet();
      deletedIds.add(id);
      await prefs.setStringList(
          _kDeletedNotificationIdsKey, deletedIds.toList());

      // Free local read-state storage
      final readIds =
          (prefs.getStringList(_kReadNotificationIdsKey) ?? []).toSet();
      if (readIds.remove(id)) {
        await prefs.setStringList(_kReadNotificationIdsKey, readIds.toList());
      }
    } catch (_) {}
  }

  Future<void> clearAllNotifications() async {
    final idsToDelete = _notifications.map((n) => n.id).toList();
    _notifications = [];
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final deletedIds =
          (prefs.getStringList(_kDeletedNotificationIdsKey) ?? []).toSet();
      deletedIds.addAll(idsToDelete);
      await prefs.setStringList(
          _kDeletedNotificationIdsKey, deletedIds.toList());

      // Clear read ids that were deleted
      await prefs.remove(_kReadNotificationIdsKey);
    } catch (_) {}
  }

  Future<void> _persistReadId(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final readIds =
          (prefs.getStringList(_kReadNotificationIdsKey) ?? []).toSet();
      readIds.add(id);
      await prefs.setStringList(_kReadNotificationIdsKey, readIds.toList());
    } catch (_) {}
  }

  Future<void> _persistAllReadIds(List<String> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final readIds =
          (prefs.getStringList(_kReadNotificationIdsKey) ?? []).toSet();
      readIds.addAll(ids);
      await prefs.setStringList(_kReadNotificationIdsKey, readIds.toList());
    } catch (_) {}
  }

  void _subscribeToRealtimeAnnouncements() {
    try {
      final client = Supabase.instance.client;
      final channel = client.channel('live_announcements');
      channel.onBroadcast(
        event: 'live_alert',
        callback: (payload) {
          try {
            Map<String, dynamic> data = Map<String, dynamic>.from(payload);
            if (data['payload'] is Map) {
              data = Map<String, dynamic>.from(data['payload'] as Map);
            }
            final title = data['title']?.toString() ?? "Live Announcement";
            final message = data['message']?.toString() ?? "";
            final notif = NotificationModel(
              id: "notif_${DateTime.now().millisecondsSinceEpoch}",
              title: title,
              message: message,
              category: NotificationCategory.liveClass,
              timestamp: DateTime.now(),
              isRead: false,
              targetBatchId: data['target_batch_id']?.toString(),
            );
            if (!_notifications.any((n) => n.id == notif.id || (n.title == notif.title && n.message == notif.message))) {
              _notifications.insert(0, notif);
              notifyListeners();
            }

            PushNotificationService.showLocalBanner(
              title: title,
              body: message,
              payload: notif.targetBatchId,
            );
          } catch (e) {
            debugPrint('[NotificationProvider] Error parsing live alert: $e');
          }
        },
      ).subscribe();
      _announcementsChannel = channel;
    } catch (_) {}
  }

  Future<void> broadcastAnnouncement({
    required String title,
    required String message,
    NotificationCategory category = NotificationCategory.announcement,
    String? targetBatchId,
  }) async {
    final newNotif = NotificationModel(
      id: "notif_${DateTime.now().millisecondsSinceEpoch}",
      title: title,
      message: message,
      category: category,
      timestamp: DateTime.now(),
      targetBatchId: targetBatchId,
    );

    _notifications.insert(0, newNotif);
    notifyListeners();
    try {
      await _repository.broadcastAnnouncement(newNotif);
    } catch (_) {
      // In offline mode or if network drops, keep local notification
    }
  }
}
