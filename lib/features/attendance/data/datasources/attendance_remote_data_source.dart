import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/attendance_model.dart';

abstract class AttendanceRemoteDataSource {
  Future<List<AttendanceRecordModel>> getAttendanceRecords();
  Future<void> saveAttendanceRecords(List<AttendanceRecordModel> records);
}

class AttendanceRemoteDataSourceImpl implements AttendanceRemoteDataSource {
  SupabaseClient? get _supabase {
    if (!AppConfig.isSupabaseConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<AttendanceRecordModel>> getAttendanceRecords() async {
    final client = _supabase;
    if (client == null) {
      throw const ServerException('Supabase not configured');
    }

    try {
      final response = await client
          .from('attendance')
          .select()
          .order('date', ascending: false);

      final list = (response as List)
          .map(
            (item) =>
                AttendanceRecordModel.fromMap(item as Map<String, dynamic>),
          )
          .toList();

      return list;
    } catch (e) {
      debugPrint('Error fetching attendance from Supabase: $e');
      throw ServerException('Failed to fetch attendance records', e);
    }
  }

  @override
  Future<void> saveAttendanceRecords(
    List<AttendanceRecordModel> records,
  ) async {
    final client = _supabase;
    if (client == null) return;

    try {
      await client
          .from('attendance')
          .upsert(records.map((r) => r.toMap()).toList());
    } catch (e) {
      debugPrint('Error saving attendance in Supabase: $e');
      throw ServerException('Failed to save attendance in database', e);
    }
  }
}
