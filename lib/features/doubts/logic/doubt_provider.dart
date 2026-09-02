import 'package:flutter/material.dart';
import '../../../../data/mock_data.dart';
import '../data/models/doubt_model.dart';
import '../data/repositories/doubt_repository.dart';

class DoubtProvider extends ChangeNotifier {
  final DoubtRepository _repository;

  List<DoubtModel> _doubts = List.from(MockData.doubts);
  String _selectedFilter = 'All'; // 'All', 'My Doubts', 'Resolved', 'Unresolved'
  bool _isLoading = false;
  String? _errorMessage;

  List<DoubtModel> get doubts => _doubts;
  String get selectedFilter => _selectedFilter;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  DoubtProvider({DoubtRepository? repository})
      : _repository = repository ?? DoubtRepositoryImpl() {
    fetchDoubts();
  }

  Future<void> fetchDoubts() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetched = await _repository.getDoubts();
      if (fetched.isNotEmpty) _doubts = fetched;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  List<DoubtModel> getFilteredDoubts(String currentUserId) {
    switch (_selectedFilter) {
      case 'My Doubts':
        return _doubts.where((d) => d.studentId == currentUserId).toList();
      case 'Resolved':
        return _doubts.where((d) => d.isResolved).toList();
      case 'Unresolved':
        return _doubts.where((d) => !d.isResolved).toList();
      default:
        return _doubts;
    }
  }

  void setFilter(String filter) {
    _selectedFilter = filter;
    notifyListeners();
  }

  void askNewDoubt({
    required String studentId,
    required String studentName,
    required String subject,
    required String topic,
    required String questionText,
    String? imageUrl,
  }) {
    final newDoubt = DoubtModel(
      id: "dbt_${DateTime.now().millisecondsSinceEpoch}",
      studentId: studentId,
      studentName: studentName,
      subject: subject,
      topic: topic,
      questionText: questionText,
      imageUrl: imageUrl,
      askedAt: DateTime.now(),
      isResolved: false,
      replies: const [],
    );

    _doubts.insert(0, newDoubt);
    _repository.postDoubt(newDoubt);
    notifyListeners();
  }

  void replyToDoubt({
    required String doubtId,
    required String authorId,
    required String authorName,
    required String authorRole,
    required String message,
    bool isOfficialTeacherAnswer = false,
  }) {
    final index = _doubts.indexWhere((d) => d.id == doubtId);
    if (index != -1) {
      final reply = DoubtReplyModel(
        id: "rep_${DateTime.now().millisecondsSinceEpoch}",
        authorId: authorId,
        authorName: authorName,
        authorRole: authorRole,
        message: message,
        timestamp: DateTime.now(),
        isOfficialTeacherAnswer: isOfficialTeacherAnswer,
      );

      final updatedReplies = List<DoubtReplyModel>.from(_doubts[index].replies)..add(reply);
      _doubts[index] = _doubts[index].copyWith(
        replies: updatedReplies,
        isResolved: isOfficialTeacherAnswer ? true : _doubts[index].isResolved,
      );
      _repository.replyDoubt(doubtId, reply);
      notifyListeners();
    }
  }
}
