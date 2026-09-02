import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../data/mock_data.dart';
import '../models/study_material_model.dart';

abstract class StudyMaterialRemoteDataSource {
  Future<List<StudyMaterialModel>> getMaterials();
  Future<void> uploadMaterial(StudyMaterialModel material);
}

class StudyMaterialRemoteDataSourceImpl implements StudyMaterialRemoteDataSource {
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
      return List.from(MockData.studyMaterials);
    }

    try {
      final response = await client
          .from('study_materials')
          .select()
          .order('uploaded_at', ascending: false);

      final list = (response as List)
          .map((item) => StudyMaterialModel.fromMap(item as Map<String, dynamic>))
          .toList();

      return list.isNotEmpty ? list : List.from(MockData.studyMaterials);
    } catch (e) {
      debugPrint('Error fetching study materials from Supabase: $e');
      return List.from(MockData.studyMaterials);
    }
  }

  @override
  Future<void> uploadMaterial(StudyMaterialModel material) async {
    final client = _supabase;
    if (client == null) return;

    try {
      await client.from('study_materials').insert(material.toMap());
    } catch (e) {
      debugPrint('Error uploading study material in Supabase: $e');
      throw ServerException('Failed to upload study material', e);
    }
  }
}
