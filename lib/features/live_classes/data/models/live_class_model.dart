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

  factory LiveChatMessage.fromMap(Map<String, dynamic> rawMap) {
    final map = (rawMap['payload'] is Map)
        ? Map<String, dynamic>.from(rawMap['payload'] as Map)
        : rawMap;

    final idVal = map['id']?.toString();
    final senderNameVal = map['sender_name'] ?? map['senderName'] ?? 'Student';
    final senderRoleVal = map['sender_role'] ?? map['senderRole'] ?? 'Student';
    final textVal = map['text'] ?? map['message'] ?? '';
    final isPinnedVal = map['is_pinned'] ?? map['isPinned'] ?? false;

    return LiveChatMessage(
      id: (idVal != null && idVal.isNotEmpty)
          ? idVal
          : "msg_${DateTime.now().millisecondsSinceEpoch}_${senderNameVal.hashCode.abs()}",
      senderName: senderNameVal.toString(),
      senderRole: senderRoleVal.toString(),
      text: textVal.toString(),
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : (map['created_at'] != null
              ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
              : DateTime.now()),
      isPinned: isPinnedVal is bool ? isPinnedVal : false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender_name': senderName,
      'sender_role': senderRole,
      'text': text,
      'message': text,
      'timestamp': timestamp.toIso8601String(),
      'created_at': timestamp.toIso8601String(),
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
  final String? thumbnailUrl;
  final int activeViewersCount;
  final List<LiveChatMessage> chatMessages;
  final bool isRecorded;
  final DateTime? actualStartTime;
  final DateTime? actualEndTime;
  final int actualDurationSeconds;
  final String? liveInputUid;
  final String? cloudflareVideoUid;
  final String recordingStatus; // "pending", "processing", "ready", "unavailable", "failed"

  /// Returns the authoritative duration for this lecture.
  /// For recorded sessions, this returns the actual recorded length (seconds or end - start),
  /// avoiding misleading default fallback durations (e.g. 1h 30m).
  Duration get effectiveDuration {
    if (actualDurationSeconds > 0) {
      return Duration(seconds: actualDurationSeconds);
    }
    // For ended sessions with no recorded duration, return zero rather than misleading fallback
    if (status == LiveStatus.ended) {
      return Duration.zero;
    }
    return estimatedDuration;
  }

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
    this.thumbnailUrl,
    this.activeViewersCount = 0,
    this.chatMessages = const [],
    this.isRecorded = true,
    this.actualStartTime,
    this.actualEndTime,
    this.actualDurationSeconds = 0,
    this.liveInputUid,
    this.cloudflareVideoUid,
    this.recordingStatus = 'pending',
  });

  factory LiveClassModel.fromMap(Map<String, dynamic> map) {
    LiveStatus parsedStatus = LiveStatus.upcoming;
    final statusStr = map['status']?.toString().toLowerCase();
    if (statusStr == 'live') {
      parsedStatus = LiveStatus.live;
    } else if (statusStr == 'ended') {
      parsedStatus = LiveStatus.ended;
    }

    final batchInfo = map['batches'] as Map<String, dynamic>?;
    final courseInfo = batchInfo?['courses'] as Map<String, dynamic>?;

    final parsedActualDuration =
        (map['actual_duration_seconds'] as num?)?.toInt() ?? 0;
    final parsedStart = map['actual_start_time'] != null
        ? DateTime.tryParse(map['actual_start_time'].toString())
        : null;
    final parsedEnd = map['actual_end_time'] != null
        ? DateTime.tryParse(map['actual_end_time'].toString())
        : null;

    int computedActualSec = parsedActualDuration;
    // Only use parsedEnd - parsedStart if:
    // 1) parsedActualDuration is missing (0)
    // 2) AND the difference is reasonable for a real single lecture (<= 2 hours / 7200s)
    // 3) AND parsedStatus == LiveStatus.ended
    // If diff is > 2 hours with 0 actual duration, it was an abandoned slot left open (e.g. 3h 46m ghost duration).
    if (computedActualSec <= 0 && parsedStart != null && parsedEnd != null && parsedStatus == LiveStatus.ended) {
      final diffSec = parsedEnd.difference(parsedStart).inSeconds;
      if (diffSec > 0 && diffSec <= 7200) {
        computedActualSec = diffSec;
      } else {
        computedActualSec = 0;
      }
    }

    final hasRealVideoInMap = (map['recording_url'] != null &&
            map['recording_url'].toString().isNotEmpty &&
            !map['recording_url'].toString().contains('rec_')) ||
        (map['cloudflare_video_uid'] != null &&
            map['cloudflare_video_uid'].toString().isNotEmpty &&
            !map['cloudflare_video_uid'].toString().startsWith('rec_'));

    // Drop bloated duration for ghost sessions that have no real video
    if (computedActualSec > 7200 && !hasRealVideoInMap) {
      computedActualSec = 0;
    }

    String resolvedRecordingStatus =
        map['recording_status']?.toString().toLowerCase() ?? 'pending';
    // Auto-promote: If an ended live class has status 'processing', but ended > 90 seconds ago,
    // Cloudflare Stream has completed encoding; promote to 'ready'
    if (resolvedRecordingStatus == 'processing' && parsedStatus == LiveStatus.ended) {
      final endedAt = parsedEnd ??
          parsedStart ??
          (map['scheduled_at'] != null
              ? DateTime.tryParse(map['scheduled_at'].toString())
              : null);
      if (endedAt != null && DateTime.now().difference(endedAt).inSeconds > 90) {
        resolvedRecordingStatus = 'ready';
      }
    }

    final rawDurationMinutes =
        (map['duration_minutes'] ?? map['estimated_duration_minutes'] as num?)
            ?.toInt();

    Duration resolvedDuration;
    if (parsedStatus == LiveStatus.ended) {
      if (computedActualSec > 0) {
        resolvedDuration = Duration(seconds: computedActualSec);
      } else if (rawDurationMinutes != null && rawDurationMinutes != 90) {
        resolvedDuration = Duration(minutes: rawDurationMinutes);
      } else {
        resolvedDuration = Duration.zero;
      }
    } else {
      resolvedDuration = Duration(minutes: rawDurationMinutes ?? 90);
    }

    return LiveClassModel(
      id: map['id']?.toString() ?? '',
      courseId:
          map['course_id']?.toString() ?? (courseInfo?['id']?.toString() ?? ''),
      batchId: map['batch_id']?.toString() ?? '',
      courseName:
          map['course_name'] ?? (courseInfo?['title'] ?? 'General Studies'),
      batchName: map['batch_name'] ?? (batchInfo?['name'] ?? 'Target Batch A'),
      title: map['title'] ?? 'Live Interactive Class',
      subject: map['subject'] ?? 'General Studies',
      teacherName: map['teacher_name'] ?? 'Faculty Member',
      teacherAvatar: map['teacher_avatar'] ?? '',
      scheduledStartTime: map['scheduled_at'] != null
          ? DateTime.tryParse(map['scheduled_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      estimatedDuration: resolvedDuration,
      status: parsedStatus,
      streamUrl: map['stream_url'] ?? '',
      recordingUrl: map['recording_url'],
      thumbnailUrl: map['thumbnail_url'],
      activeViewersCount: (map['active_viewers_count'] as num?)?.toInt() ?? 0,
      isRecorded: map['is_recorded'] ?? true,
      actualStartTime: parsedStart,
      actualEndTime: parsedEnd,
      actualDurationSeconds: computedActualSec,
      liveInputUid: map['live_input_uid']?.toString(),
      cloudflareVideoUid: map['cloudflare_video_uid']?.toString(),
      recordingStatus: resolvedRecordingStatus,
    );
  }

  /// Map for database insertion against public.live_classes schema
  Map<String, dynamic> toInsertMap({String? teacherId}) {
    final map = <String, dynamic>{
      'batch_id': batchId,
      'title': title,
      'subject': subject,
      'teacher_name': teacherName,
      'stream_url': streamUrl,
      'scheduled_at': scheduledStartTime.toIso8601String(),
      'duration_minutes': estimatedDuration.inMinutes,
      'status': status.name,
    };
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
      map['thumbnail_url'] = thumbnailUrl;
    }
    if (teacherId != null && teacherId.isNotEmpty) {
      map['teacher_id'] = teacherId;
    }
    if (actualStartTime != null) {
      map['actual_start_time'] = actualStartTime!.toIso8601String();
    }
    if (actualEndTime != null) {
      map['actual_end_time'] = actualEndTime!.toIso8601String();
    }
    if (actualDurationSeconds > 0) {
      map['actual_duration_seconds'] = actualDurationSeconds;
    }
    if (liveInputUid != null && liveInputUid!.isNotEmpty) {
      map['live_input_uid'] = liveInputUid;
    }
    if (cloudflareVideoUid != null && cloudflareVideoUid!.isNotEmpty) {
      map['cloudflare_video_uid'] = cloudflareVideoUid;
    }
    if (recordingUrl != null && recordingUrl!.isNotEmpty) {
      map['recording_url'] = recordingUrl;
    }
    map['recording_status'] = recordingStatus;

    // Only pass id if it is a valid UUID
    if (RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id)) {
      map['id'] = id;
    }
    return map;
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
      'scheduled_at': scheduledStartTime.toIso8601String(),
      'estimated_duration_minutes': estimatedDuration.inMinutes,
      'status': status.name,
      'stream_url': streamUrl,
      'recording_url': recordingUrl,
      'thumbnail_url': thumbnailUrl,
      'active_viewers_count': activeViewersCount,
      'is_recorded': isRecorded,
      'actual_start_time': actualStartTime?.toIso8601String(),
      'actual_end_time': actualEndTime?.toIso8601String(),
      'actual_duration_seconds': actualDurationSeconds,
      'live_input_uid': liveInputUid,
      'cloudflare_video_uid': cloudflareVideoUid,
      'recording_status': recordingStatus,
    };
  }

  LiveClassModel copyWith({
    String? title,
    LiveStatus? status,
    Duration? estimatedDuration,
    int? activeViewersCount,
    List<LiveChatMessage>? chatMessages,
    String? recordingUrl,
    String? thumbnailUrl,
    DateTime? actualStartTime,
    DateTime? actualEndTime,
    int? actualDurationSeconds,
    String? liveInputUid,
    String? cloudflareVideoUid,
    String? recordingStatus,
  }) {
    return LiveClassModel(
      id: id,
      courseId: courseId,
      batchId: batchId,
      courseName: courseName,
      batchName: batchName,
      title: title ?? this.title,
      subject: subject,
      teacherName: teacherName,
      teacherAvatar: teacherAvatar,
      scheduledStartTime: scheduledStartTime,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      status: status ?? this.status,
      streamUrl: streamUrl,
      recordingUrl: recordingUrl ?? this.recordingUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      activeViewersCount: activeViewersCount ?? this.activeViewersCount,
      chatMessages: chatMessages ?? this.chatMessages,
      isRecorded: isRecorded,
      actualStartTime: actualStartTime ?? this.actualStartTime,
      actualEndTime: actualEndTime ?? this.actualEndTime,
      actualDurationSeconds: actualDurationSeconds ?? this.actualDurationSeconds,
      liveInputUid: liveInputUid ?? this.liveInputUid,
      cloudflareVideoUid: cloudflareVideoUid ?? this.cloudflareVideoUid,
      recordingStatus: recordingStatus ?? this.recordingStatus,
    );
  }
}
