enum LiveStatus { upcoming, live, ended }

class LiveChatMessage {
  final String id;
  final String senderName;
  final String senderRole; // "Student", "Teacher", "Admin"
  final String text;
  final DateTime timestamp;
  final bool isPinned;

  const LiveChatMessage({
    required this.id,
    required this.senderName,
    this.senderRole = "Student",
    required this.text,
    required this.timestamp,
    this.isPinned = false,
  });
}

class LiveClassModel {
  final String id;
  final String courseId;
  final String batchId;
  final String courseName;
  final String batchName;
  final String title;
  final String subject;
  final String teacherName;
  final String teacherAvatar;
  final DateTime scheduledStartTime;
  final Duration estimatedDuration;
  final LiveStatus status;
  final String streamUrl; // YouTube live or RTMP stream
  final String? recordingUrl;
  final int activeViewersCount;
  final List<LiveChatMessage> chatMessages;
  final bool isRecorded;

  const LiveClassModel({
    required this.id,
    required this.courseId,
    required this.batchId,
    required this.courseName,
    required this.batchName,
    required this.title,
    required this.subject,
    required this.teacherName,
    required this.teacherAvatar,
    required this.scheduledStartTime,
    this.estimatedDuration = const Duration(hours: 1, minutes: 30),
    required this.status,
    required this.streamUrl,
    this.recordingUrl,
    this.activeViewersCount = 0,
    this.chatMessages = const [],
    this.isRecorded = true,
  });

  LiveClassModel copyWith({
    LiveStatus? status,
    int? activeViewersCount,
    List<LiveChatMessage>? chatMessages,
    String? recordingUrl,
  }) {
    return LiveClassModel(
      id: id,
      courseId: courseId,
      batchId: batchId,
      courseName: courseName,
      batchName: batchName,
      title: title,
      subject: subject,
      teacherName: teacherName,
      teacherAvatar: teacherAvatar,
      scheduledStartTime: scheduledStartTime,
      estimatedDuration: estimatedDuration,
      status: status ?? this.status,
      streamUrl: streamUrl,
      recordingUrl: recordingUrl ?? this.recordingUrl,
      activeViewersCount: activeViewersCount ?? this.activeViewersCount,
      chatMessages: chatMessages ?? this.chatMessages,
      isRecorded: isRecorded,
    );
  }
}
