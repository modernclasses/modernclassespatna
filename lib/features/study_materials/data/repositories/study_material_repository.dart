import 'dart:typed_data';
import '../../../../core/errors/error_handler.dart';
import '../datasources/study_material_remote_data_source.dart';
import '../models/study_material_model.dart';

abstract class StudyMaterialRepository {
  Future<List<StudyMaterialModel>> getMaterials();
  Future<StudyMaterialModel> uploadMaterial(StudyMaterialModel material);
  Future<String> uploadMaterialFile({
    required String courseId,
    required String fileName,
    required Uint8List fileBytes,
  });
  Future<void> deleteMaterial(String materialId, {String? fileUrl});
}

class StudyMaterialRepositoryImpl implements StudyMaterialRepository {
  final StudyMaterialRemoteDataSource _remoteDataSource;

  StudyMaterialRepositoryImpl({StudyMaterialRemoteDataSource? remoteDataSource})
    : _remoteDataSource =
          remoteDataSource ?? StudyMaterialRemoteDataSourceImpl();

  @override
  Future<List<StudyMaterialModel>> getMaterials() async {
    try {
      return await _remoteDataSource.getMaterials();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<String> uploadMaterialFile({
    required String courseId,
    required String fileName,
    required Uint8List fileBytes,
  }) async {
    try {
      return await _remoteDataSource.uploadMaterialFile(
        courseId: courseId,
        fileName: fileName,
        fileBytes: fileBytes,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<StudyMaterialModel> uploadMaterial(StudyMaterialModel material) async {
    try {
      return await _remoteDataSource.uploadMaterial(material);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> deleteMaterial(String materialId, {String? fileUrl}) async {
    try {
      await _remoteDataSource.deleteMaterial(materialId, fileUrl: fileUrl);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
