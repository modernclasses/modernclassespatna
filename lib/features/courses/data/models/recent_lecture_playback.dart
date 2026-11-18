import 'dart:convert';
import 'package:modern_classes_patna/features/live_classes/data/models/live_class_model.dart';

class RecentLecturePlayback {
  final String lectureId;
  final String courseId;
  final String batchId;
  final String courseName;
  final String batchName;
  final String title;
  final String subject;
  final String teacherName;
  final String videoUrl;
  final String? thumbnailUrl;
  final Duration duration;
  final double progressPercent; // 0.0 to 1.0
  final int positionSeconds;
  final DateTime lastWatchedAt;
  final bool isLiveRecording;

  const RecentLecturePlayback({
    required this.lectureId,
    required this.courseId,
    required this.batchId,
    required this.courseName,
    required this.batchName,
    required this.title,
    required this.subject,
    required this.teacherName,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.duration,
    required this.progressPercent,
    required this.positionSeconds,
    required this.lastWatchedAt,
    this.isLiveRecording = false,
  });

  RecentLecturePlayback copyWith({
    String? lectureId,
    String? courseId,
    String? batchId,
    String? courseName,
    String? batchName,
    String? title,
    String? subject,
    String? teacherName,
    String? videoUrl,
    String? thumbnailUrl,
    Duration? duration,
    double? progressPercent,
    int? positionSeconds,
    DateTime? lastWatchedAt,
    bool? isLiveRecording,
  }) {
    return RecentLecturePlayback(
      lectureId: lectureId ?? this.lectureId,
      courseId: courseId ?? this.courseId,
      batchId: batchId ?? this.batchId,
      courseName: courseName ?? this.courseName,
      batchName: batchName ?? this.batchName,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      teacherName: teacherName ?? this.teacherName,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      duration: duration ?? this.duration,
      progressPercent: progressPercent ?? this.progressPercent,
      positionSeconds: positionSeconds ?? this.positionSeconds,
      lastWatchedAt: lastWatchedAt ?? this.lastWatchedAt,
      isLiveRecording: isLiveRecording ?? this.isLiveRecording,
    );
  }

  LiveClassModel toLiveClassModel() {
    return LiveClassModel(
      id: lectureId,
      courseId: courseId,
      batchId: batchId,
      courseName: courseName,
      batchName: batchName,
      title: title,
      subject: subject,
      teacherName: teacherName.isNotEmpty ? teacherName : 'Faculty',
      teacherAvatar: '',
      scheduledStartTime: lastWatchedAt,
      estimatedDuration: duration,
      status: LiveStatus.ended,
      streamUrl: videoUrl,
      recordingUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      recordingStatus: 'ready',
    );
  }

  Map<String, dynamic> toMap() => {
    'lectureId': lectureId,
    'courseId': courseId,
    'batchId': batchId,
    'courseName': courseName,
    'batchName': batchName,
    'title': title,
    'subject': subject,
    'teacherName': teacherName,
    'videoUrl': videoUrl,
    if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
    'durationSeconds': duration.inSeconds,
    'progressPercent': progressPercent,
    'positionSeconds': positionSeconds,
    'lastWatchedAt': lastWatchedAt.toIso8601String(),
    'isLiveRecording': isLiveRecording,
  };

  factory RecentLecturePlayback.fromMap(Map<String, dynamic> map) {
    return RecentLecturePlayback(
      lectureId: map['lectureId']?.toString() ?? '',
      courseId: map['courseId']?.toString() ?? '',
      batchId: map['batchId']?.toString() ?? '',
      courseName: map['courseName']?.toString() ?? '',
      batchName: map['batchName']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      subject: map['subject']?.toString() ?? '',
      teacherName: map['teacherName']?.toString() ?? '',
      videoUrl: map['videoUrl']?.toString() ?? '',
      thumbnailUrl: map['thumbnailUrl']?.toString(),
      duration: Duration(seconds: (map['durationSeconds'] as num?)?.toInt() ?? 0),
      progressPercent: (map['progressPercent'] as num?)?.toDouble() ?? 0.0,
      positionSeconds: (map['positionSeconds'] as num?)?.toInt() ?? 0,
      lastWatchedAt: map['lastWatchedAt'] != null
          ? DateTime.tryParse(map['lastWatchedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isLiveRecording: map['isLiveRecording'] == true,
    );
  }

  String toJson() => jsonEncode(toMap());
  factory RecentLecturePlayback.fromJson(String source) => RecentLecturePlayback.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
