import '../../../../core/errors/error_handler.dart';
import '../datasources/test_remote_data_source.dart';
import '../models/test_model.dart';

abstract class TestRepository {
  Future<List<TestModel>> getTests();
  Future<void> submitTestResult(TestResultModel result);
  Future<void> createTest(TestModel test);
}

class TestRepositoryImpl implements TestRepository {
  final TestRemoteDataSource _remoteDataSource;

  TestRepositoryImpl({TestRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? TestRemoteDataSourceImpl();

  @override
  Future<List<TestModel>> getTests() async {
    try {
      return await _remoteDataSource.getTests();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> submitTestResult(TestResultModel result) async {
    try {
      await _remoteDataSource.submitTestResult(result);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> createTest(TestModel test) async {
    try {
      await _remoteDataSource.createTest(test);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
