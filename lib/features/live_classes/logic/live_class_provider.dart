import 'package:flutter/material.dart';
import '../../../../data/mock_data.dart';
import '../data/models/live_class_model.dart';
import '../data/repositories/live_class_repository.dart';

class LiveClassProvider extends ChangeNotifier {
  final LiveClassRepository _repository;

  List<LiveClassModel> _classes = List.from(MockData.liveClasses);
  bool _isLoading = false;
  String? _errorMessage;

  List<LiveClassModel> get classes => _classes;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<LiveClassModel> get liveNow =>
      _classes.where((c) => c.status == LiveStatus.live).toList();

  List<LiveClassModel> get upcoming =>
      _classes.where((c) => c.status == LiveStatus.upcoming).toList();

  List<LiveClassModel> get pastRecordings =>
      _classes.where((c) => c.status == LiveStatus.ended).toList();

  LiveClassProvider({LiveClassRepository? repository})
      : _repository = repository ?? LiveClassRepositoryImpl() {
    fetchLiveClasses();
  }

  Future<void> fetchLiveClasses() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetched = await _repository.getLiveClasses();
      if (fetched.isNotEmpty) _classes = fetched;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void addLiveChatMessage(String classId, LiveChatMessage message) {
    final index = _classes.indexWhere((c) => c.id == classId);
    if (index != -1) {
      final updatedMessages = List<LiveChatMessage>.from(_classes[index].chatMessages)
        ..add(message);
      _classes[index] = _classes[index].copyWith(chatMessages: updatedMessages);
      notifyListeners();
    }
  }

  void updateViewerCount(String classId, int count) {
    final index = _classes.indexWhere((c) => c.id == classId);
    if (index != -1) {
      _classes[index] = _classes[index].copyWith(activeViewersCount: count);
      notifyListeners();
    }
  }

  LiveClassModel? get currentActiveLiveClass =>
      liveNow.isNotEmpty ? liveNow.first : (upcoming.isNotEmpty ? upcoming.first : null);

  List<LiveClassModel> get upcomingClasses => upcoming;

  LiveClassModel? getLiveClassById(String id) {
    try {
      return _classes.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  void sendLiveChatMessage({
    required String classId,
    required String senderName,
    String senderRole = "Student",
    required String text,
  }) {
    addLiveChatMessage(
      classId,
      LiveChatMessage(
        id: "msg_${DateTime.now().millisecondsSinceEpoch}",
        senderName: senderName,
        senderRole: senderRole,
        text: text,
        timestamp: DateTime.now(),
      ),
    );
  }

  void scheduleClass(LiveClassModel newClass) {
    _classes.insert(0, newClass);
    _repository.scheduleLiveClass(newClass);
    notifyListeners();
  }

  void scheduleLiveClass({
    required String courseId,
    required String batchId,
    required String courseName,
    required String batchName,
    required String title,
    required String subject,
    required String teacherName,
    required String teacherAvatar,
    required DateTime scheduledStartTime,
    Duration duration = const Duration(hours: 1, minutes: 30),
    required String streamUrl,
  }) {
    final newClass = LiveClassModel(
      id: "live_${DateTime.now().millisecondsSinceEpoch}",
      courseId: courseId,
      batchId: batchId,
      courseName: courseName,
      batchName: batchName,
      title: title,
      subject: subject,
      teacherName: teacherName,
      teacherAvatar: teacherAvatar,
      scheduledStartTime: scheduledStartTime,
      estimatedDuration: duration,
      status: LiveStatus.upcoming,
      streamUrl: streamUrl,
    );
    scheduleClass(newClass);
  }
}
