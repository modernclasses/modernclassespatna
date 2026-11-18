/// Entity representing a persistent Cloudflare Stream Live Input.
///
/// Stores ingress and egress endpoints in Supabase to guarantee
/// settings persist across app reinstallation, restarts, and lecture endings.
class CloudflareLiveInput {
  final String id;
  final String uid;
  final String name;
  final String rtmpsUrl;
  final String streamKey;
  final String playbackUrl;
  final String? accountId;
  final String? batchId;
  final bool isActive;
  final bool isPrimary;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CloudflareLiveInput({
    required this.id,
    required this.uid,
    required this.name,
    this.rtmpsUrl = 'rtmps://live.cloudflare.com:443/live/',
    required this.streamKey,
    required this.playbackUrl,
    this.accountId,
    this.batchId,
    this.isActive = true,
    this.isPrimary = false,
    this.createdAt,
    this.updatedAt,
  });

  /// True when the input contains valid RTMPS endpoint credentials.
  bool get isConfigured =>
      rtmpsUrl.isNotEmpty &&
      (rtmpsUrl.startsWith('rtmp://') || rtmpsUrl.startsWith('rtmps://')) &&
      streamKey.isNotEmpty &&
      uid.isNotEmpty;

  /// Deserialize from Supabase `public.cloudflare_live_inputs` record.
  factory CloudflareLiveInput.fromMap(Map<String, dynamic> map) {
    return CloudflareLiveInput(
      id: map['id']?.toString() ?? '',
      uid: map['uid']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Live Stream Broadcaster',
      rtmpsUrl: map['rtmps_url']?.toString() ?? 'rtmps://live.cloudflare.com:443/live/',
      streamKey: map['stream_key']?.toString() ?? '',
      playbackUrl: map['playback_url']?.toString() ?? '',
      accountId: map['account_id']?.toString(),
      batchId: map['batch_id']?.toString(),
      isActive: map['is_active'] as bool? ?? true,
      isPrimary: map['is_primary'] as bool? ?? false,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }

  /// Serialize to JSON/Map for Supabase insert or update.
  Map<String, dynamic> toMap({bool forInsert = false}) {
    final map = <String, dynamic>{
      'uid': uid.trim(),
      'name': name.trim(),
      'rtmps_url': rtmpsUrl.trim(),
      'stream_key': streamKey.trim(),
      'playback_url': playbackUrl.trim(),
      'account_id': accountId?.trim(),
      'batch_id': batchId,
      'is_active': isActive,
      'is_primary': isPrimary,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (!forInsert && id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }

  CloudflareLiveInput copyWith({
    String? id,
    String? uid,
    String? name,
    String? rtmpsUrl,
    String? streamKey,
    String? playbackUrl,
    String? accountId,
    String? batchId,
    bool? isActive,
    bool? isPrimary,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CloudflareLiveInput(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      name: name ?? this.name,
      rtmpsUrl: rtmpsUrl ?? this.rtmpsUrl,
      streamKey: streamKey ?? this.streamKey,
      playbackUrl: playbackUrl ?? this.playbackUrl,
      accountId: accountId ?? this.accountId,
      batchId: batchId ?? this.batchId,
      isActive: isActive ?? this.isActive,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
