import 'package:flutter/material.dart';
import '../models/live_class_model.dart';
import '../data/mock_data.dart';

class LiveClassProvider extends ChangeNotifier {
  final List<LiveClassModel> _liveClasses = List.from(MockData.liveClasses);

  List<LiveClassModel> get liveClasses => _liveClasses;

  LiveClassModel? get currentActiveLiveClass {
    try {
      return _liveClasses.firstWhere((l) => l.status == LiveStatus.live);
    } catch (_) {
      return null;
    }
  }

  List<LiveClassModel> get upcomingClasses =>
      _liveClasses.where((l) => l.status == LiveStatus.upcoming).toList();

  List<LiveClassModel> get pastRecordings =>
      _liveClasses.where((l) => l.status == LiveStatus.ended).toList();

  LiveClassModel? getLiveClassById(String id) {
    try {
      return _liveClasses.firstWhere((l) => l.id == id);
    } catch (_) {
      return null;
    }
  }

  void sendLiveChatMessage({
    required String classId,
    required String senderName,
    required String senderRole,
    required String text,
  }) {
    final index = _liveClasses.indexWhere((l) => l.id == classId);
    if (index != -1) {
      final newMessage = LiveChatMessage(
        id: "msg_${DateTime.now().millisecondsSinceEpoch}",
        senderName: senderName,
        senderRole: senderRole,
        text: text,
        timestamp: DateTime.now(),
      );

      final updatedMessages = List<LiveChatMessage>.from(_liveClasses[index].chatMessages)
        ..add(newMessage);

      _liveClasses[index] = _liveClasses[index].copyWith(
        chatMessages: updatedMessages,
      );
      notifyListeners();
    }
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
    required Duration duration,
    required String streamUrl,
  }) {
    final newLiveClass = LiveClassModel(
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

    _liveClasses.insert(0, newLiveClass);
    notifyListeners();
  }
}
