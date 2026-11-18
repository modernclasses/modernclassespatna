import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/doubt_model.dart';

abstract class DoubtRemoteDataSource {
  Future<List<DoubtModel>> getDoubts();
  Future<DoubtModel> postDoubt(DoubtModel doubt);
  Future<DoubtModel> resolveDoubt(
    String doubtId,
    String facultyReply,
    String facultyName,
    String resolvedBy,
  );
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
    if (client == null) throw ServerException('Supabase not configured');

    try {
      final response = await client
          .from('doubts')
          .select('*, batches(name)')
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => DoubtModel.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching doubts from Supabase: $e');
      throw ServerException('Failed to fetch doubts', e);
    }
  }

  @override
  Future<DoubtModel> postDoubt(DoubtModel doubt) async {
    final client = _supabase;
    if (client == null) throw ServerException('Supabase not configured');

    try {
      final response = await client
          .from('doubts')
          .insert(doubt.toInsertMap())
          .select('*, batches(name)')
          .single();
      return DoubtModel.fromMap(response);
    } catch (e) {
      debugPrint('Error posting doubt in Supabase: $e');
      throw ServerException('Failed to post doubt', e);
    }
  }

  @override
  Future<DoubtModel> resolveDoubt(
    String doubtId,
    String facultyReply,
    String facultyName,
    String resolvedBy,
  ) async {
    final client = _supabase;
    if (client == null) {
      throw const ServerException('Backend service is not configured.');
    }

    try {
      final response = await client
          .from('doubts')
          .update({
            'faculty_reply': facultyReply,
            'faculty_name': facultyName,
            'resolved_by': resolvedBy,
            'resolved_at': DateTime.now().toIso8601String(),
            'is_resolved': true,
          })
          .eq('id', doubtId)
          .select('*, batches(name)')
          .single();
      return DoubtModel.fromMap(response);
    } catch (e) {
      debugPrint('Error resolving doubt in Supabase: $e');
      throw ServerException('Failed to resolve doubt', e);
    }
  }
}
