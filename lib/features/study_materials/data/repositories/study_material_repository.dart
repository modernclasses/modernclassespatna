import '../../../../core/errors/error_handler.dart';
import '../datasources/study_material_remote_data_source.dart';
import '../models/study_material_model.dart';

abstract class StudyMaterialRepository {
  Future<List<StudyMaterialModel>> getMaterials();
  Future<void> uploadMaterial(StudyMaterialModel material);
}

class StudyMaterialRepositoryImpl implements StudyMaterialRepository {
  final StudyMaterialRemoteDataSource _remoteDataSource;

  StudyMaterialRepositoryImpl({StudyMaterialRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? StudyMaterialRemoteDataSourceImpl();

  @override
  Future<List<StudyMaterialModel>> getMaterials() async {
    try {
      return await _remoteDataSource.getMaterials();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> uploadMaterial(StudyMaterialModel material) async {
    try {
      await _remoteDataSource.uploadMaterial(material);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
