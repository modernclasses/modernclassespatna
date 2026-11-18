import '../../../../core/errors/error_handler.dart';
import '../datasources/attendance_remote_data_source.dart';
import '../models/attendance_model.dart';

abstract class AttendanceRepository {
  Future<List<AttendanceRecordModel>> getAttendanceRecords();
  Future<void> saveAttendanceRecords(List<AttendanceRecordModel> records);
}

class AttendanceRepositoryImpl implements AttendanceRepository {
  final AttendanceRemoteDataSource _remoteDataSource;

  AttendanceRepositoryImpl({AttendanceRemoteDataSource? remoteDataSource})
    : _remoteDataSource = remoteDataSource ?? AttendanceRemoteDataSourceImpl();

  @override
  Future<List<AttendanceRecordModel>> getAttendanceRecords() async {
    try {
      return await _remoteDataSource.getAttendanceRecords();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> saveAttendanceRecords(
    List<AttendanceRecordModel> records,
  ) async {
    try {
      await _remoteDataSource.saveAttendanceRecords(records);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
