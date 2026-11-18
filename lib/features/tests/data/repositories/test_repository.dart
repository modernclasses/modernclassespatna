import '../../../../core/errors/error_handler.dart';
import '../datasources/test_remote_data_source.dart';
import '../models/test_model.dart';

abstract class TestRepository {
  Future<List<TestModel>> getTests();
  Future<TestModel> getTestPaper(String testId);
  Future<void> submitTestResult(TestResultModel result);
  Future<void> createTest(TestModel test);
  Future<void> deleteTest(String testId);
  Future<List<TestResultModel>> getTestSubmissionsForTest(String testId);
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
  Future<TestModel> getTestPaper(String testId) async {
    try {
      return await _remoteDataSource.getTestPaper(testId);
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

  @override
  Future<void> deleteTest(String testId) async {
    try {
      await _remoteDataSource.deleteTest(testId);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<List<TestResultModel>> getTestSubmissionsForTest(String testId) async {
    try {
      return await _remoteDataSource.getTestSubmissionsForTest(testId);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
