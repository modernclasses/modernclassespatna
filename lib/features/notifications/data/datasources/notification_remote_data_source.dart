import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../data/mock_data.dart';
import '../models/notification_model.dart';

abstract class NotificationRemoteDataSource {
  Future<List<NotificationModel>> getNotifications();
  Future<void> broadcastAnnouncement(NotificationModel notification);
}

class NotificationRemoteDataSourceImpl implements NotificationRemoteDataSource {
  SupabaseClient? get _supabase {
    if (!AppConfig.isSupabaseConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<NotificationModel>> getNotifications() async {
    final client = _supabase;
    if (client == null) {
      return List.from(MockData.notifications);
    }

    try {
      final response = await client
          .from('announcements')
          .select()
          .order('timestamp', ascending: false);

      final list = (response as List)
          .map((item) => NotificationModel.fromMap(item as Map<String, dynamic>))
          .toList();

      return list.isNotEmpty ? list : List.from(MockData.notifications);
    } catch (e) {
      debugPrint('Error fetching notifications from Supabase: $e');
      return List.from(MockData.notifications);
    }
  }

  @override
  Future<void> broadcastAnnouncement(NotificationModel notification) async {
    final client = _supabase;
    if (client == null) return;

    try {
      await client.from('announcements').insert(notification.toMap());
    } catch (e) {
      debugPrint('Error creating announcement in Supabase: $e');
      throw ServerException('Failed to broadcast announcement', e);
    }
  }
}
