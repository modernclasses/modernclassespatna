import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../data/mock_data.dart';
import '../models/live_class_model.dart';

abstract class LiveClassRemoteDataSource {
  Future<List<LiveClassModel>> getLiveClasses();
  Future<void> scheduleLiveClass(LiveClassModel liveClass);
}

class LiveClassRemoteDataSourceImpl implements LiveClassRemoteDataSource {
  SupabaseClient? get _supabase {
    if (!AppConfig.isSupabaseConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<LiveClassModel>> getLiveClasses() async {
    final client = _supabase;
    if (client == null) {
      return List.from(MockData.liveClasses);
    }

    try {
      final response = await client
          .from('live_classes')
          .select()
          .order('scheduled_start_time', ascending: true);

      final list = (response as List)
          .map((item) => LiveClassModel.fromMap(item as Map<String, dynamic>))
          .toList();

      return list.isNotEmpty ? list : List.from(MockData.liveClasses);
    } catch (e) {
      debugPrint('Error fetching live classes from Supabase: $e');
      return List.from(MockData.liveClasses);
    }
  }

  @override
  Future<void> scheduleLiveClass(LiveClassModel liveClass) async {
    final client = _supabase;
    if (client == null) return;

    try {
      await client.from('live_classes').insert(liveClass.toMap());
    } catch (e) {
      debugPrint('Error scheduling live class in Supabase: $e');
      throw ServerException('Failed to schedule live class', e);
    }
  }
}
