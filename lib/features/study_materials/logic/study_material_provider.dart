import 'package:flutter/material.dart';
import '../../../../data/mock_data.dart';
import '../data/models/study_material_model.dart';
import '../data/repositories/study_material_repository.dart';

class StudyMaterialProvider extends ChangeNotifier {
  final StudyMaterialRepository _repository;

  List<StudyMaterialModel> _materials = List.from(MockData.studyMaterials);
  String _selectedSubject = 'All';
  bool _isLoading = false;
  String? _errorMessage;

  List<StudyMaterialModel> get materials => _materials;
  String get selectedSubject => _selectedSubject;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

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

  StudyMaterialProvider({StudyMaterialRepository? repository})
      : _repository = repository ?? StudyMaterialRepositoryImpl() {
    fetchMaterials();
  }

  Future<void> fetchMaterials() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetched = await _repository.getMaterials();
      if (fetched.isNotEmpty) _materials = fetched;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
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
    _repository.uploadMaterial(material);
    notifyListeners();
  }
}
