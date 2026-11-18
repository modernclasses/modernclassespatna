import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/study_material_model.dart';

abstract class StudyMaterialRemoteDataSource {
  Future<List<StudyMaterialModel>> getMaterials();
  Future<StudyMaterialModel> uploadMaterial(StudyMaterialModel material);
  Future<String> uploadMaterialFile({
    required String courseId,
    required String fileName,
    required Uint8List fileBytes,
  });
  Future<void> deleteMaterial(String materialId, {String? fileUrl});
}

class StudyMaterialRemoteDataSourceImpl
    implements StudyMaterialRemoteDataSource {
  SupabaseClient? get _supabase {
    if (!AppConfig.isSupabaseConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<StudyMaterialModel>> getMaterials() async {
    final client = _supabase;
    if (client == null) {
      throw const ServerException('Supabase not configured');
    }

    try {
      final response = await client
          .from('study_materials')
          .select()
          .order('created_at', ascending: false);

      final list = (response as List)
          .map(
            (item) => StudyMaterialModel.fromMap(item as Map<String, dynamic>),
          )
          .toList();

      return list;
    } catch (e) {
      try {
        final response = await client.from('study_materials').select();
        return (response as List)
            .map(
              (item) =>
                  StudyMaterialModel.fromMap(item as Map<String, dynamic>),
            )
            .toList();
      } catch (inner) {
        debugPrint('Error fetching study materials from Supabase: $inner');
        throw ServerException('Failed to fetch materials', inner);
      }
    }
  }

  @override
  Future<String> uploadMaterialFile({
    required String courseId,
    required String fileName,
    required Uint8List fileBytes,
  }) async {
    final client = _supabase;
    if (client == null) throw const ServerException('Supabase not configured');

    try {
      final sanitizedName = fileName.replaceAll(
        RegExp(r'[^a-zA-Z0-9._-]'),
        '_',
      );
      final path =
          '$courseId/${DateTime.now().millisecondsSinceEpoch}_$sanitizedName';
      await client.storage
          .from(AppConstants.bucketStudyMaterials)
          .uploadBinary(
            path,
            fileBytes,
            fileOptions: const FileOptions(
              contentType: 'application/pdf',
              upsert: false,
            ),
          );
      return path;
    } catch (e) {
      debugPrint('Error uploading material file to storage: $e');
      throw ServerException('Failed to upload material file: $e');
    }
  }

  @override
  Future<StudyMaterialModel> uploadMaterial(StudyMaterialModel material) async {
    final client = _supabase;
    if (client == null) throw const ServerException('Supabase not configured');

    try {
      final currentUserId = client.auth.currentUser?.id;
      final response = await client
          .from('study_materials')
          .insert(material.toInsertMap(uploadedBy: currentUserId))
          .select()
          .single();

      return StudyMaterialModel.fromMap(response);
    } catch (e) {
      debugPrint('Error uploading study material in Supabase: $e');
      throw ServerException('Failed to upload study material', e);
    }
  }

  @override
  Future<void> deleteMaterial(String materialId, {String? fileUrl}) async {
    final client = _supabase;
    if (client == null) throw const ServerException('Supabase not configured');

    if (fileUrl != null && fileUrl.isNotEmpty && !fileUrl.startsWith('http')) {
      try {
        await client.storage
            .from(AppConstants.bucketStudyMaterials)
            .remove([fileUrl]);
      } catch (e) {
        debugPrint('Warning: Failed to delete material storage object: $e');
      }
    }

    try {
      await client.from('study_materials').delete().eq('id', materialId);
    } catch (e) {
      debugPrint('Error deleting study material $materialId: $e');
      throw ServerException('Failed to delete study material', e);
    }
  }
}
