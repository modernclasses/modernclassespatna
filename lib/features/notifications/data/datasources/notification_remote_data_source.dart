import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/errors/exceptions.dart';
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
      throw const ServerException('Supabase not configured');
    }

    try {
      final response = await client
          .from('announcements')
          .select()
          .order('created_at', ascending: false);

      final list = (response as List)
          .map(
            (item) => NotificationModel.fromMap(item as Map<String, dynamic>),
          )
          .toList();

      return list;
    } catch (e) {
      debugPrint('Error fetching notifications from Supabase: $e');
      throw ServerException('Failed to fetch notifications', e);
    }
  }

  @override
  Future<void> broadcastAnnouncement(NotificationModel notification) async {
    final client = _supabase;
    if (client == null) return;

    // 1. Fast Realtime broadcast to peers on live_announcements channel
    try {
      final channel = client.channel('live_announcements');
      await channel.sendBroadcastMessage(
        event: 'live_alert',
        payload: {
          'title': notification.title,
          'message': notification.message,
          'category': notification.category.name,
          'target_batch_id': notification.targetBatchId,
          'created_at': notification.timestamp.toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('[NotificationRemoteDataSource] Realtime broadcast notice: $e');
    }

    // 2. Persist to PostgreSQL announcements table
    try {
      final data = <String, dynamic>{
        'title': notification.title,
        'message': notification.message,
        'type': notification.category.name,
        'created_at': notification.timestamp.toIso8601String(),
      };
      if (notification.targetBatchId != null && notification.targetBatchId!.isNotEmpty) {
        data['target_batch_id'] = notification.targetBatchId;
      }
      if (client.auth.currentUser != null) {
        data['created_by'] = client.auth.currentUser!.id;
      }
      await client.from('announcements').insert(data);
    } catch (e) {
      debugPrint('Error creating announcement in Supabase: $e');
      // If broadcast succeeded or DB has temporary RLS mismatch, log notice
    }
  }
}
