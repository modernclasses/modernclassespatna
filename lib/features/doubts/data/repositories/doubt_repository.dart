import '../../../../core/errors/error_handler.dart';
import '../datasources/doubt_remote_data_source.dart';
import '../models/doubt_model.dart';

abstract class DoubtRepository {
  Future<List<DoubtModel>> getDoubts();
  Future<DoubtModel> postDoubt(DoubtModel doubt);
  Future<DoubtModel> resolveDoubt(
    String doubtId,
    String facultyReply,
    String facultyName,
    String resolvedBy,
  );
}

class DoubtRepositoryImpl implements DoubtRepository {
  final DoubtRemoteDataSource _remoteDataSource;

  DoubtRepositoryImpl({DoubtRemoteDataSource? remoteDataSource})
    : _remoteDataSource = remoteDataSource ?? DoubtRemoteDataSourceImpl();

  @override
  Future<List<DoubtModel>> getDoubts() async {
    try {
      return await _remoteDataSource.getDoubts();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<DoubtModel> postDoubt(DoubtModel doubt) async {
    try {
      return await _remoteDataSource.postDoubt(doubt);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<DoubtModel> resolveDoubt(
    String doubtId,
    String facultyReply,
    String facultyName,
    String resolvedBy,
  ) async {
    try {
      return await _remoteDataSource.resolveDoubt(
        doubtId,
        facultyReply,
        facultyName,
        resolvedBy,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
