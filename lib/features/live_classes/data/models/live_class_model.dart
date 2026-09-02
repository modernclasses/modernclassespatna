enum LiveStatus { upcoming, live, ended }

/// Real-time live class chat message.
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

  factory LiveChatMessage.fromMap(Map<String, dynamic> map) {
    return LiveChatMessage(
      id: map['id']?.toString() ?? '',
      senderName: map['sender_name'] ?? 'Student',
      senderRole: map['sender_role'] ?? 'Student',
      text: map['text'] ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isPinned: map['is_pinned'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender_name': senderName,
      'sender_role': senderRole,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'is_pinned': isPinned,
    };
  }
}

/// Live Stream Lecture Entity.
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

  factory LiveClassModel.fromMap(Map<String, dynamic> map) {
    LiveStatus parsedStatus = LiveStatus.upcoming;
    final statusStr = map['status']?.toString().toLowerCase();
    if (statusStr == 'live') {
      parsedStatus = LiveStatus.live;
    } else if (statusStr == 'ended') {
      parsedStatus = LiveStatus.ended;
    }

    return LiveClassModel(
      id: map['id']?.toString() ?? '',
      courseId: map['course_id']?.toString() ?? '',
      batchId: map['batch_id']?.toString() ?? '',
      courseName: map['course_name'] ?? 'BPSC 71st Batch',
      batchName: map['batch_name'] ?? 'Target Batch A',
      title: map['title'] ?? 'Live Interactive Class',
      subject: map['subject'] ?? 'General Studies',
      teacherName: map['teacher_name'] ?? 'Faculty Member',
      teacherAvatar: map['teacher_avatar'] ?? '',
      scheduledStartTime: map['scheduled_start_time'] != null
          ? DateTime.tryParse(map['scheduled_start_time'].toString()) ?? DateTime.now()
          : DateTime.now(),
      estimatedDuration: Duration(
        minutes: (map['estimated_duration_minutes'] as num?)?.toInt() ?? 90,
      ),
      status: parsedStatus,
      streamUrl: map['stream_url'] ?? 'https://www.youtube.com/watch?v=live_stream_demo',
      recordingUrl: map['recording_url'],
      activeViewersCount: (map['active_viewers_count'] as num?)?.toInt() ?? 0,
      isRecorded: map['is_recorded'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'course_id': courseId,
      'batch_id': batchId,
      'course_name': courseName,
      'batch_name': batchName,
      'title': title,
      'subject': subject,
      'teacher_name': teacherName,
      'teacher_avatar': teacherAvatar,
      'scheduled_start_time': scheduledStartTime.toIso8601String(),
      'estimated_duration_minutes': estimatedDuration.inMinutes,
      'status': status.name,
      'stream_url': streamUrl,
      'recording_url': recordingUrl,
      'active_viewers_count': activeViewersCount,
      'is_recorded': isRecorded,
    };
  }

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
