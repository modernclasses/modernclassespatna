/// Batch Entity for Classroom & Live Timings.
class BatchModel {
  final String id;
  final String courseId;
  final String name; // e.g. "Morning Target Batch A"
  final String timing; // e.g. "08:00 AM - 10:00 AM"
  final DateTime startDate;
  final DateTime endDate;
  final String teacherName;
  final String teacherId;
  final List<String> teacherIds;
  final int totalStudents;
  final int maxStudents;
  final double batchPrice;
  final String medium; // "Bilingual (Hindi + English)"
  final bool isActive;
  final String? playProductId;
  final String? streamKey;
  final String? playbackUrl;
  final String? rtmpsUrl;

  const BatchModel({
    required this.id,
    required this.courseId,
    required this.name,
    required this.timing,
    required this.startDate,
    required this.endDate,
    required this.teacherName,
    required this.teacherId,
    this.teacherIds = const [],
    required this.totalStudents,
    this.maxStudents = 500,
    required this.batchPrice,
    this.medium = "Bilingual (Hindi + English)",
    this.isActive = true,
    this.playProductId,
    this.streamKey,
    this.playbackUrl,
    this.rtmpsUrl,
  });

  /// Deserialize from Supabase `public.batches` row.
  factory BatchModel.fromMap(Map<String, dynamic> map) {
    return BatchModel(
      id: map['id']?.toString() ?? '',
      courseId: map['course_id']?.toString() ?? '',
      name: map['name'] ?? 'Target Batch',
      timing: map['timing'] ?? '08:00 AM - 10:00 AM',
      startDate: map['start_date'] != null
          ? DateTime.tryParse(map['start_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      endDate: map['end_date'] != null
          ? DateTime.tryParse(map['end_date'].toString()) ??
                DateTime.now().add(const Duration(days: 90))
          : DateTime.now().add(const Duration(days: 90)),
      teacherName: map['teacher_name'] ?? 'Faculty Member',
      teacherId: map['teacher_id']?.toString() ?? '',
      teacherIds: map['teacher_ids'] != null
          ? List<String>.from(map['teacher_ids'])
          : (map['teacher_id'] != null && map['teacher_id'].toString().isNotEmpty
              ? [map['teacher_id'].toString()]
              : const []),
      totalStudents: (map['total_students'] as num?)?.toInt() ?? 0,
      maxStudents: (map['max_students'] as num?)?.toInt() ?? 500,
      batchPrice: (map['batch_price'] as num?)?.toDouble() ?? 799.0,
      medium: map['medium'] ?? 'Bilingual (Hindi + English)',
      isActive: map['is_active'] ?? true,
      playProductId: map['play_product_id']?.toString(),
      streamKey: map['stream_key']?.toString(),
      playbackUrl: map['playback_url']?.toString(),
      rtmpsUrl: map['rtmps_url']?.toString(),
    );
  }

  /// Serialize to Supabase `public.batches` format.
  Map<String, dynamic> toMap({bool includeNullsForUpdates = false}) {
    final data = <String, dynamic>{
      'id': id,
      'course_id': courseId,
      'name': name,
      'timing': timing,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'teacher_name': teacherName,
      'teacher_id': teacherId,
      'total_students': totalStudents,
      'max_students': maxStudents,
      'batch_price': batchPrice,
      'medium': medium,
      'is_active': isActive,
      'play_product_id': playProductId,
    };
    if (streamKey != null && streamKey!.isNotEmpty) {
      data['stream_key'] = streamKey;
    } else if (includeNullsForUpdates) {
      data['stream_key'] = null;
    }
    if (playbackUrl != null && playbackUrl!.isNotEmpty) {
      data['playback_url'] = playbackUrl;
    } else if (includeNullsForUpdates) {
      data['playback_url'] = null;
    }
    if (rtmpsUrl != null && rtmpsUrl!.isNotEmpty) {
      data['rtmps_url'] = rtmpsUrl;
    } else if (includeNullsForUpdates) {
      data['rtmps_url'] = null;
    }
    return data;
  }

  BatchModel copyWith({
    String? id,
    String? courseId,
    String? name,
    String? timing,
    DateTime? startDate,
    DateTime? endDate,
    String? teacherName,
    String? teacherId,
    List<String>? teacherIds,
    int? totalStudents,
    int? maxStudents,
    double? batchPrice,
    String? medium,
    bool? isActive,
    String? playProductId,
    String? streamKey,
    String? playbackUrl,
    String? rtmpsUrl,
    bool clearStreamKey = false,
    bool clearPlaybackUrl = false,
    bool clearRtmpsUrl = false,
  }) {
    return BatchModel(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      name: name ?? this.name,
      timing: timing ?? this.timing,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      teacherName: teacherName ?? this.teacherName,
      teacherId: teacherId ?? this.teacherId,
      teacherIds: teacherIds ?? this.teacherIds,
      totalStudents: totalStudents ?? this.totalStudents,
      maxStudents: maxStudents ?? this.maxStudents,
      batchPrice: batchPrice ?? this.batchPrice,
      medium: medium ?? this.medium,
      isActive: isActive ?? this.isActive,
      playProductId: playProductId ?? this.playProductId,
      streamKey: clearStreamKey ? null : (streamKey ?? this.streamKey),
      playbackUrl: clearPlaybackUrl ? null : (playbackUrl ?? this.playbackUrl),
      rtmpsUrl: clearRtmpsUrl ? null : (rtmpsUrl ?? this.rtmpsUrl),
    );
  }
}
