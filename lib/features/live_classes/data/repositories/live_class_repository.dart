import '../../../../core/errors/error_handler.dart';
import '../datasources/live_class_remote_data_source.dart';
import '../models/live_class_model.dart';

abstract class LiveClassRepository {
  Future<List<LiveClassModel>> getLiveClasses();
  Future<void> scheduleLiveClass(LiveClassModel liveClass);
}

class LiveClassRepositoryImpl implements LiveClassRepository {
  final LiveClassRemoteDataSource _remoteDataSource;

  LiveClassRepositoryImpl({LiveClassRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? LiveClassRemoteDataSourceImpl();

  @override
  Future<List<LiveClassModel>> getLiveClasses() async {
    try {
      return await _remoteDataSource.getLiveClasses();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> scheduleLiveClass(LiveClassModel liveClass) async {
    try {
      await _remoteDataSource.scheduleLiveClass(liveClass);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
