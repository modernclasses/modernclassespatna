import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../data/mock_data.dart';
import '../models/doubt_model.dart';

abstract class DoubtRemoteDataSource {
  Future<List<DoubtModel>> getDoubts();
  Future<void> postDoubt(DoubtModel doubt);
  Future<void> replyDoubt(String doubtId, DoubtReplyModel reply);
}

class DoubtRemoteDataSourceImpl implements DoubtRemoteDataSource {
  SupabaseClient? get _supabase {
    if (!AppConfig.isSupabaseConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<DoubtModel>> getDoubts() async {
    final client = _supabase;
    if (client == null) {
      return List.from(MockData.doubts);
    }

    try {
      final response = await client
          .from('doubts')
          .select()
          .order('asked_at', ascending: false);

      final list = (response as List)
          .map((item) => DoubtModel.fromMap(item as Map<String, dynamic>))
          .toList();

      return list.isNotEmpty ? list : List.from(MockData.doubts);
    } catch (e) {
      debugPrint('Error fetching doubts from Supabase: $e');
      return List.from(MockData.doubts);
    }
  }

  @override
  Future<void> postDoubt(DoubtModel doubt) async {
    final client = _supabase;
    if (client == null) return;

    try {
      await client.from('doubts').insert(doubt.toMap());
    } catch (e) {
      debugPrint('Error posting doubt in Supabase: $e');
      throw ServerException('Failed to post doubt', e);
    }
  }

  @override
  Future<void> replyDoubt(String doubtId, DoubtReplyModel reply) async {
    final client = _supabase;
    if (client == null) return;

    try {
      final doubtDoc = await client.from('doubts').select().eq('id', doubtId).maybeSingle();
      if (doubtDoc != null) {
        final existing = DoubtModel.fromMap(doubtDoc);
        final updatedReplies = List<DoubtReplyModel>.from(existing.replies)..add(reply);
        await client.from('doubts').update({
          'replies': updatedReplies.map((r) => r.toMap()).toList(),
          'is_resolved': reply.isOfficialTeacherAnswer ? true : existing.isResolved,
        }).eq('id', doubtId);
      }
    } catch (e) {
      debugPrint('Error replying to doubt in Supabase: $e');
      throw ServerException('Failed to reply to doubt', e);
    }
  }
}
