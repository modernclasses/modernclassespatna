import '../../../../core/errors/error_handler.dart';
import '../datasources/doubt_remote_data_source.dart';
import '../models/doubt_model.dart';

abstract class DoubtRepository {
  Future<List<DoubtModel>> getDoubts();
  Future<void> postDoubt(DoubtModel doubt);
  Future<void> replyDoubt(String doubtId, DoubtReplyModel reply);
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
  Future<void> postDoubt(DoubtModel doubt) async {
    try {
      await _remoteDataSource.postDoubt(doubt);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> replyDoubt(String doubtId, DoubtReplyModel reply) async {
    try {
      await _remoteDataSource.replyDoubt(doubtId, reply);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
