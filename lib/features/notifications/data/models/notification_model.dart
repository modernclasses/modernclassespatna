enum NotificationCategory {
  liveClass,
  test,
  material,
  announcement,
  payment,
  reminder,
}

/// In-App & Cloud Push Notification / Announcement Model.
class NotificationModel {
  final String id;
  final String title;
  final String message;
  final NotificationCategory category;
  final DateTime timestamp;
  final bool isRead;
  final String? actionRoute;
  final String? relatedId;
  final String? targetBatchId;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    required this.timestamp,
    this.isRead = false,
    this.actionRoute,
    this.relatedId,
    this.targetBatchId,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    NotificationCategory parsedCat = NotificationCategory.announcement;
    final catStr = (map['category'] ?? map['type'])?.toString().toLowerCase();
    switch (catStr) {
      case 'liveclass':
      case 'live_class':
        parsedCat = NotificationCategory.liveClass;
        break;
      case 'test':
        parsedCat = NotificationCategory.test;
        break;
      case 'material':
        parsedCat = NotificationCategory.material;
        break;
      case 'payment':
        parsedCat = NotificationCategory.payment;
        break;
      case 'reminder':
        parsedCat = NotificationCategory.reminder;
        break;
      default:
        parsedCat = NotificationCategory.announcement;
    }

    return NotificationModel(
      id: map['id']?.toString() ?? '',
      title: map['title'] ?? 'Notice',
      message: map['message'] ?? '',
      category: parsedCat,
      timestamp: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isRead: map['is_read'] ?? false,
      actionRoute: map['action_route'],
      relatedId: map['related_id'],
      targetBatchId: map['target_batch_id']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'category': category.name,
      'created_at': timestamp.toIso8601String(),
      'is_read': isRead,
      'action_route': actionRoute,
      'related_id': relatedId,
      'target_batch_id': targetBatchId,
    };
  }

  NotificationModel copyWith({bool? isRead}) {
    return NotificationModel(
      id: id,
      title: title,
      message: message,
      category: category,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
      actionRoute: actionRoute,
      relatedId: relatedId,
    );
  }
}
