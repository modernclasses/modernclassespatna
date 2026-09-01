import 'package:flutter/material.dart';
import '../models/study_material_model.dart';
import '../data/mock_data.dart';

class StudyMaterialProvider extends ChangeNotifier {
  final List<StudyMaterialModel> _materials = List.from(MockData.studyMaterials);
  String _selectedSubject = 'All';

  List<StudyMaterialModel> get materials => _materials;
  String get selectedSubject => _selectedSubject;

  List<String> get subjects {
    final set = {'All'};
    for (var m in _materials) {
      set.add(m.subject);
    }
    return set.toList();
  }

  List<StudyMaterialModel> get filteredMaterials {
    if (_selectedSubject == 'All') {
      return _materials;
    }
    return _materials.where((m) => m.subject == _selectedSubject).toList();
  }

  void setSelectedSubject(String subject) {
    _selectedSubject = subject;
    notifyListeners();
  }

  List<StudyMaterialModel> getMaterialsForBatch(String batchId) {
    return _materials.where((m) => m.batchId == batchId).toList();
  }

  StudyMaterialModel? getMaterialById(String id) {
    try {
      return _materials.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  void addStudyMaterial(StudyMaterialModel material) {
    _materials.insert(0, material);
    notifyListeners();
  }
}
