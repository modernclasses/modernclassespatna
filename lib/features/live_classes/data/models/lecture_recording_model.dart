/// Status of a Cloudflare Stream lecture recording.
enum RecordingStatus {
  ready,
  processing,
  unavailable,
  failed,
}

extension RecordingStatusExtension on RecordingStatus {
  String get name {
    switch (this) {
      case RecordingStatus.ready:
        return 'ready';
      case RecordingStatus.processing:
        return 'processing';
      case RecordingStatus.unavailable:
        return 'unavailable';
      case RecordingStatus.failed:
        return 'failed';
    }
  }

  static RecordingStatus fromString(String? val) {
    switch (val?.toLowerCase().trim()) {
      case 'ready':
        return RecordingStatus.ready;
      case 'processing':
      case 'queued':
      case 'inprogress':
        return RecordingStatus.processing;
      case 'failed':
      case 'error':
        return RecordingStatus.failed;
      default:
        return RecordingStatus.unavailable;
    }
  }
}

/// Entity representing a recorded live lecture.
class LectureRecordingModel {
  final String id;
  final String? liveClassId;
  final String courseId;
  final String batchId;
  final String courseName;
  final String batchName;
  final String? teacherId;
  final String teacherName;
  final String title;
  final String? liveInputUid;
  final String videoUid;
  final String playbackUrl;
  final String? thumbnailUrl;
  final DateTime? startTime;
  final DateTime? endTime;
  final int durationSeconds;
  final RecordingStatus status;
  final bool isPublished;
  final DateTime createdAt;

  bool get isReady => status == RecordingStatus.ready;
  bool get isProcessing => status == RecordingStatus.processing;
  bool get isFailed => status == RecordingStatus.failed;
  bool get isUnavailable => status == RecordingStatus.unavailable;
  String get statusName => status.name;

  const LectureRecordingModel({
    required this.id,
    this.liveClassId,
    required this.courseId,
    required this.batchId,
    this.courseName = '',
    this.batchName = '',
    this.teacherId,
    this.teacherName = 'Faculty Member',
    required this.title,
    this.liveInputUid,
    required this.videoUid,
    required this.playbackUrl,
    this.thumbnailUrl,
    this.startTime,
    this.endTime,
    this.durationSeconds = 0,
    this.status = RecordingStatus.processing,
    this.isPublished = true,
    required this.createdAt,
  });

  factory LectureRecordingModel.fromMap(Map<String, dynamic> map) {
    final batchInfo = map['batches'] as Map<String, dynamic>?;
    final courseInfo = map['courses'] as Map<String, dynamic>? ??
        (batchInfo?['courses'] as Map<String, dynamic>?);
    final teacherInfo = map['profiles'] as Map<String, dynamic>?;

    return LectureRecordingModel(
      id: map['id']?.toString() ?? '',
      liveClassId: map['live_class_id']?.toString(),
      courseId: map['course_id']?.toString() ??
          (courseInfo?['id']?.toString() ?? ''),
      batchId:
          map['batch_id']?.toString() ?? (batchInfo?['id']?.toString() ?? ''),
      courseName: map['course_name'] ??
          (courseInfo?['title'] ?? 'General Course'),
      batchName:
          map['batch_name'] ?? (batchInfo?['name'] ?? 'Target Batch'),
      teacherId: map['teacher_id']?.toString(),
      teacherName: map['teacher_name'] ??
          (teacherInfo?['full_name'] ?? 'Faculty Member'),
      title: map['title'] ?? 'Live Lecture Recording',
      liveInputUid: map['live_input_uid']?.toString(),
      videoUid: map['video_uid']?.toString() ?? '',
      playbackUrl: map['playback_url']?.toString() ?? '',
      thumbnailUrl: map['thumbnail_url']?.toString(),
      startTime: map['start_time'] != null
          ? DateTime.tryParse(map['start_time'].toString())
          : null,
      endTime: map['end_time'] != null
          ? DateTime.tryParse(map['end_time'].toString())
          : null,
      durationSeconds: (map['duration_seconds'] as num?)?.toInt() ?? 0,
      status: RecordingStatusExtension.fromString(map['status']?.toString()),
      isPublished: map['is_published'] ?? true,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'live_class_id': liveClassId,
      'course_id': courseId,
      'batch_id': batchId,
      'teacher_id': teacherId,
      'title': title,
      'live_input_uid': liveInputUid,
      'video_uid': videoUid,
      'playback_url': playbackUrl,
      'thumbnail_url': thumbnailUrl,
      'start_time': startTime?.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'duration_seconds': durationSeconds,
      'status': status.name,
      'is_published': isPublished,
    };
  }

  String get formattedDuration {
    if (durationSeconds <= 0) return '--';
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    final seconds = durationSeconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    }
    return '${minutes}m ${seconds}s';
  }

  LectureRecordingModel copyWith({
    String? title,
    RecordingStatus? status,
    int? durationSeconds,
    String? playbackUrl,
    String? thumbnailUrl,
    bool? isPublished,
  }) {
    return LectureRecordingModel(
      id: id,
      liveClassId: liveClassId,
      courseId: courseId,
      batchId: batchId,
      courseName: courseName,
      batchName: batchName,
      teacherId: teacherId,
      teacherName: teacherName,
      title: title ?? this.title,
      liveInputUid: liveInputUid,
      videoUid: videoUid,
      playbackUrl: playbackUrl ?? this.playbackUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      startTime: startTime,
      endTime: endTime,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      status: status ?? this.status,
      isPublished: isPublished ?? this.isPublished,
      createdAt: createdAt,
    );
  }
}
