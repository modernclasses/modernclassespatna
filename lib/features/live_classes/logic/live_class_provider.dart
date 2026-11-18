import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/batch_timing_helper.dart';
import '../data/models/lecture_recording_model.dart';
import '../data/models/live_class_model.dart';
import '../data/repositories/live_class_repository.dart';

class LiveClassProvider extends ChangeNotifier {
  final LiveClassRepository _repository;

  List<LiveClassModel> _classes = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<LectureRecordingModel> _recordings = [];
  bool _isRecordingsLoading = false;
  String? _recordingsErrorMessage;

  List<LiveClassModel> get classes => _classes;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<LectureRecordingModel> get recordings => _recordings;
  bool get isRecordingsLoading => _isRecordingsLoading;
  String? get recordingsErrorMessage => _recordingsErrorMessage;

  /// Determines whether a session is truly live in real-time.
  /// Automatically filters out stale or abandoned sessions whose duration has lapsed.
  static bool isClassActiveLive(LiveClassModel c) {
    if (c.status != LiveStatus.live) return false;
    final start = c.actualStartTime ?? c.scheduledStartTime;
    final elapsed = DateTime.now().difference(start);
    final maxAllowed = c.estimatedDuration > Duration.zero
        ? c.estimatedDuration + const Duration(hours: 1)
        : const Duration(hours: 3);
    if (elapsed > maxAllowed || elapsed.inHours >= 3) {
      return false;
    }
    return true;
  }

  List<LiveClassModel> get liveNow =>
      _classes.where((c) => isClassActiveLive(c)).toList();

  List<LiveClassModel> get upcoming =>
      _classes.where((c) => c.status == LiveStatus.upcoming).toList();

  /// Returns authentic recorded lectures for student playback.
  /// 1. Excludes phantom/abandoned test sessions with 0 duration and no real recording.
  /// 2. Allows 'processing' recordings so students see their recently completed live broadcasts.
  /// 3. Excludes permanently failed or unavailable recordings.
  List<LiveClassModel> get pastRecordings => _classes.where((c) {
    if (c.status != LiveStatus.ended) return false;

    // Filter out phantom/abandoned test sessions:
    final hasRealVideo = (c.recordingUrl != null &&
            c.recordingUrl!.isNotEmpty &&
            !c.recordingUrl!.contains('rec_')) ||
        (c.streamUrl.isNotEmpty &&
            !c.streamUrl.contains('rec_') &&
            (c.streamUrl.contains('cloudflarestream.com') ||
                c.streamUrl.contains('.m3u8') ||
                c.streamUrl.contains('.mp4')));

    // A playable recording must have real video OR be an active recent processing session
    if (!hasRealVideo && c.recordingStatus != 'processing') {
      return false;
    }

    // Ghost session protection: if duration is suspiciously > 2 hours and it has no real video, exclude
    if (c.actualDurationSeconds > 7200 && !hasRealVideo) {
      return false;
    }

    // Exclude permanently failed or unavailable recordings
    if (c.recordingStatus == 'failed' || c.recordingStatus == 'unavailable') {
      return false;
    }

    return true;
  }).toList();

  RealtimeChannel? _liveChatChannel;
  String? _subscribedLiveChatClassId;
  Timer? _chatPollTimer;
  RealtimeChannel? _liveClassesRealtimeChannel;
  final Map<String, List<LiveChatMessage>> _chatMessagesByClassId = {};

  LiveClassProvider({LiveClassRepository? repository})
    : _repository = repository ?? LiveClassRepositoryImpl() {
    fetchLiveClasses();
    subscribeToLiveClassesChanges();
  }

  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Listens to real-time Postgres changes on public.live_classes table.
  /// Automatically refreshes the live classes list for all students whenever
  /// a teacher starts, updates, or ends a live broadcast.
  void subscribeToLiveClassesChanges() {
    final client = _supabase;
    if (client == null || _liveClassesRealtimeChannel != null) return;
    try {
      _liveClassesRealtimeChannel = client
          .channel('public:live_classes')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'live_classes',
            callback: (payload) {
              debugPrint(
                '[LiveClassProvider] Realtime live_classes event: ${payload.eventType}',
              );
              fetchLiveClasses();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[LiveClassProvider] Error subscribing to live_classes updates: $e');
    }
  }

  /// Returns active or cached chat messages for a specific class
  List<LiveChatMessage> getChatMessagesForClass(String classId) {
    final cached = _chatMessagesByClassId[classId];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    try {
      return _classes.firstWhere((c) => c.id == classId).chatMessages;
    } catch (_) {
      return const [];
    }
  }

  /// Subscribes to the live chat broadcast channel and database changes for an active live class.
  /// Used by both students in LiveClassroomScreen and teachers in TeacherBroadcastStudio.
  Future<void> subscribeToLiveChat(String classId) async {
    if (_subscribedLiveChatClassId == classId && _liveChatChannel != null) {
      return;
    }
    unsubscribeFromLiveChat();
    _subscribedLiveChatClassId = classId;

    final client = _supabase;
    if (client == null) return;

    // 1. Initial fetch of existing persistent chat messages from database
    try {
      final history = await client
          .from('live_chat_messages')
          .select()
          .eq('class_id', classId)
          .order('created_at', ascending: true);
      for (final item in history) {
        final msg = LiveChatMessage.fromMap(Map<String, dynamic>.from(item));
        addLiveChatMessage(classId, msg);
      }
    } catch (e) {
      debugPrint('[LiveClassProvider] Initial chat history notice: $e');
    }

    // 2. Realtime channel subscription (Broadcast & Postgres Changes)
    try {
      final channel = client.channel(
        'live_class_chat_$classId',
        opts: const RealtimeChannelConfig(
          self: false,
          ack: false,
        ),
      );

      channel.onBroadcast(
        event: 'chat_message',
        callback: (payload) {
          try {
            Map<String, dynamic> data = Map<String, dynamic>.from(payload);
            if (data['payload'] is Map) {
              data = Map<String, dynamic>.from(data['payload'] as Map);
            }
            final msg = LiveChatMessage.fromMap(data);
            if (msg.text.trim().isNotEmpty) {
              addLiveChatMessage(classId, msg);
            }
          } catch (e) {
            debugPrint('[LiveClassProvider] Error parsing remote broadcast chat message: $e');
          }
        },
      );

      channel.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'live_chat_messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'class_id',
          value: classId,
        ),
        callback: (payload) {
          try {
            final newRec = payload.newRecord;
            if (newRec.isNotEmpty) {
              final msg = LiveChatMessage.fromMap(newRec);
              addLiveChatMessage(classId, msg);
            }
          } catch (e) {
            debugPrint('[LiveClassProvider] Error parsing postgres chat message: $e');
          }
        },
      );

      // Presence listeners for real-time live active viewers count
      channel.onPresenceSync((payload) {
        try {
          final count = channel.presenceState().length;
          updateViewerCount(classId, count);
        } catch (e) {
          debugPrint('[LiveClassProvider] Error updating presence viewer count: $e');
        }
      });

      channel.onPresenceJoin((payload) {
        try {
          final count = channel.presenceState().length;
          updateViewerCount(classId, count);
        } catch (_) {}
      });

      channel.onPresenceLeave((payload) {
        try {
          final count = channel.presenceState().length;
          updateViewerCount(classId, count);
        } catch (_) {}
      });

      channel.subscribe((status, [error]) {
        debugPrint('[LiveClassProvider] Chat channel subscription: $status ${error ?? ""}');
        if (status == RealtimeSubscribeStatus.subscribed) {
          try {
            channel.track({
              'user_id': client.auth.currentUser?.id ?? 'guest_${DateTime.now().millisecondsSinceEpoch}',
              'online_at': DateTime.now().toIso8601String(),
            });
          } catch (e) {
            debugPrint('[LiveClassProvider] Error tracking presence: $e');
          }
        }
      });

      _liveChatChannel = channel;

      // 3. Periodic fallback poll for background sync resilience
      _chatPollTimer?.cancel();
      _chatPollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
        if (_subscribedLiveChatClassId != classId) return;
        try {
          final history = await client
              .from('live_chat_messages')
              .select()
              .eq('class_id', classId)
              .order('created_at', ascending: true);
          for (final item in history) {
            final msg = LiveChatMessage.fromMap(Map<String, dynamic>.from(item));
            if (msg.text.trim().isNotEmpty) {
              addLiveChatMessage(classId, msg);
            }
          }
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('[LiveClassProvider] Error subscribing to live chat: $e');
    }
  }

  /// Unsubscribes from the live chat channel when leaving the classroom or broadcast.
  void unsubscribeFromLiveChat() {
    _chatPollTimer?.cancel();
    _chatPollTimer = null;
    try {
      _liveChatChannel?.untrack();
      _liveChatChannel?.unsubscribe();
    } catch (_) {}
    _liveChatChannel = null;
    _subscribedLiveChatClassId = null;
  }

  Future<void> fetchLiveClasses() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetched = await _repository.getLiveClasses();
      _classes = fetched.map((c) {
        final cachedMessages = _chatMessagesByClassId[c.id];
        if (cachedMessages != null && cachedMessages.isNotEmpty) {
          return c.copyWith(chatMessages: cachedMessages);
        }
        return c;
      }).toList();

      // Automatically remedy stale orphaned live sessions in background database
      for (final c in _classes) {
        if (c.status == LiveStatus.live && !isClassActiveLive(c)) {
          debugPrint('[LiveClassProvider] Auto-ending stale live class: ${c.id} (${c.title})');
          endLiveClass(c.id);
        }
      }

      // Automatically promote stale 'processing' recordings whose stream ended > 90 seconds ago
      final now = DateTime.now();
      for (int i = 0; i < _classes.length; i++) {
        final c = _classes[i];
        if (c.status == LiveStatus.ended && c.recordingStatus == 'processing') {
          final endedAt = c.actualEndTime ?? c.scheduledStartTime;
          if (now.difference(endedAt).inSeconds > 90) {
            _classes[i] = c.copyWith(recordingStatus: 'ready');
            final vidUid = c.cloudflareVideoUid;
            if (vidUid != null && vidUid.isNotEmpty && !vidUid.startsWith('rec_')) {
              _repository.refreshRecordingStatus(vidUid).catchError((err) {
                debugPrint('[LiveClassProvider] Background recording refresh notice: $err');
                return null;
              });
            }
          }
        }
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('[LiveClassProvider] Error fetching live classes: $e');
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  static String _generateUuidV4() {
    final rnd = math.Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  void addLiveChatMessage(String classId, LiveChatMessage message) {
    final list = _chatMessagesByClassId.putIfAbsent(classId, () => []);

    // 1. Direct ID match deduplication
    final existingById = list.indexWhere((m) => m.id == message.id);
    if (existingById != -1) {
      return; // Exact duplicate ID already present
    }

    // 2. Optimistic-to-Server reconciliation:
    // If a local message was created with a temporary ID (starts with 'msg_'),
    // and a matching message arrives from Supabase with a standard UUID,
    // reconcile the ID in-place instead of creating a second bubble.
    final tempIdx = list.indexWhere((m) =>
        m.id.startsWith('msg_') &&
        !message.id.startsWith('msg_') &&
        m.senderName == message.senderName &&
        m.text.trim() == message.text.trim() &&
        (m.timestamp.difference(message.timestamp).inSeconds.abs() <= 5));

    if (tempIdx != -1) {
      list[tempIdx] = message;
      _syncClassChatMessages(classId, list);
      notifyListeners();
      return;
    }

    list.add(message);
    _syncClassChatMessages(classId, list);
    notifyListeners();
  }

  void _syncClassChatMessages(String classId, List<LiveChatMessage> messages) {
    final index = _classes.indexWhere((c) => c.id == classId);
    if (index != -1) {
      _classes[index] = _classes[index].copyWith(chatMessages: List.unmodifiable(messages));
    }
  }

  void updateViewerCount(String classId, int count) {
    final index = _classes.indexWhere((c) => c.id == classId);
    if (index != -1) {
      if (_classes[index].activeViewersCount != count) {
        _classes[index] = _classes[index].copyWith(activeViewersCount: count);
        notifyListeners();
      }
    }
  }

  LiveClassModel? get currentActiveLiveClass =>
      liveNow.isNotEmpty ? liveNow.first : null;

  LiveClassModel? get nextUpcomingClass =>
      upcoming.isNotEmpty ? upcoming.first : null;

  List<LiveClassModel> get upcomingClasses => upcoming;

  LiveClassModel? getLiveClassById(String id) {
    try {
      return _classes.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> sendLiveChatMessage({
    required String classId,
    required String senderName,
    String senderRole = "Student",
    required String text,
  }) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return;

    final now = DateTime.now();
    final msgId = _generateUuidV4();
    final msg = LiveChatMessage(
      id: msgId,
      senderName: senderName,
      senderRole: senderRole,
      text: trimmedText,
      timestamp: now,
    );
    addLiveChatMessage(classId, msg);

    final client = _supabase;
    if (client != null) {
      // 1. Fast Realtime broadcast to peers
      try {
        if (_liveChatChannel != null) {
          await _liveChatChannel!.sendBroadcastMessage(
            event: 'chat_message',
            payload: msg.toMap(),
          );
        } else {
          await subscribeToLiveChat(classId);
          await _liveChatChannel?.sendBroadcastMessage(
            event: 'chat_message',
            payload: msg.toMap(),
          );
        }
      } catch (e) {
        debugPrint('[LiveClassProvider] Broadcast notice: $e');
      }

      // 2. Persist to PostgreSQL public.live_chat_messages with matching msgId
      try {
        final insertPayload = <String, dynamic>{
          'id': msgId,
          'class_id': classId,
          'sender_name': senderName,
          'sender_role': senderRole,
          'message': trimmedText,
          'created_at': now.toUtc().toIso8601String(),
        };
        final uid = client.auth.currentUser?.id;
        if (uid != null && uid.isNotEmpty) {
          insertPayload['sender_id'] = uid;
        }
        await client.from('live_chat_messages').insert(insertPayload);
      } catch (e) {
        debugPrint('[LiveClassProvider] Persistent chat database notice: $e');
      }
    }
  }

  Future<LiveClassModel> scheduleClass(
    LiveClassModel newClass, {
    String? teacherId,
  }) async {
    _classes.insert(0, newClass);
    notifyListeners();
    try {
      final saved = await _repository.scheduleLiveClass(
        newClass,
        teacherId: teacherId,
      );
      final idx = _classes.indexWhere((c) => c.id == newClass.id);
      if (idx != -1) {
        _classes[idx] = saved;
      }
      notifyListeners();
      return saved;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<LiveClassModel> scheduleLiveClass({
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
    LiveStatus status = LiveStatus.upcoming,
    String? teacherId,
    String? thumbnailUrl,
  }) async {
    final newClass = LiveClassModel(
      id: '',
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
      status: status,
      streamUrl: streamUrl,
      thumbnailUrl: thumbnailUrl,
    );
    return await scheduleClass(newClass, teacherId: teacherId);
  }

  Future<String> uploadLiveClassThumbnail({
    required String fileName,
    required Uint8List fileBytes,
  }) async {
    return await _repository.uploadLiveClassThumbnail(
      fileName: fileName,
      fileBytes: fileBytes,
    );
  }

  Future<void> startLiveClass(String classId) async {
    final index = _classes.indexWhere((c) => c.id == classId);
    if (index != -1) {
      _classes[index] = _classes[index].copyWith(status: LiveStatus.live);
      notifyListeners();
    }
    try {
      await _repository.updateLiveClassStatus(classId, LiveStatus.live);
    } catch (e) {
      debugPrint('Note updating live class status: $e');
    }
  }

  Future<void> endLiveClass(String classId) async {
    final index = _classes.indexWhere((c) => c.id == classId);
    final now = DateTime.now();
    int resolvedSec = 0;
    if (index != -1) {
      final current = _classes[index];
      if (current.actualStartTime != null) {
        resolvedSec = now.difference(current.actualStartTime!).inSeconds;
        if (resolvedSec < 0) resolvedSec = 0;
      }
      _classes[index] = current.copyWith(
        status: LiveStatus.ended,
        actualEndTime: now,
        actualDurationSeconds: resolvedSec,
        estimatedDuration: resolvedSec > 0 ? Duration(seconds: resolvedSec) : Duration.zero,
      );
      notifyListeners();
    }
    try {
      await _repository.updateLiveClassStatus(classId, LiveStatus.ended);
    } catch (e) {
      debugPrint('Note updating ended live class status: $e');
    }
  }

  Future<void> updateLiveClassStatus(String classId, LiveStatus status) async {
    if (status == LiveStatus.live) {
      await startLiveClass(classId);
    } else {
      await endLiveClass(classId);
    }
  }

  // =========================================================================
  // BATCH SCHEDULE VALIDATION & AUTHENTICATED SESSION LIFECYCLE
  // =========================================================================

  /// Validates whether the current IST time is permitted for the given batch schedule.
  Future<SlotValidationResult> validateBatchSchedule(String batchId) async {
    return await _repository.validateBatchSchedule(batchId);
  }

  /// Authoritatively begins an authenticated live session on both database and state.
  Future<LiveClassModel> startAuthenticatedLiveSession({
    required String batchId,
    required String title,
    required String subject,
    required String streamUrl,
    String? thumbnailUrl,
    String? liveInputUid,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final session = await _repository.startAuthenticatedLiveSession(
        batchId: batchId,
        title: title,
        subject: subject,
        streamUrl: streamUrl,
        thumbnailUrl: thumbnailUrl,
        liveInputUid: liveInputUid,
      );
      final existingIdx = _classes.indexWhere((c) => c.id == session.id);
      if (existingIdx != -1) {
        _classes[existingIdx] = session;
      } else {
        _classes.insert(0, session);
      }
      _isLoading = false;
      notifyListeners();
      return session;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Ends live session authoritatively, saving actual timestamps and triggering status updates.
  Future<void> endAuthenticatedLiveSession(
    String liveClassId, {
    int? durationSeconds,
    DateTime? endTime,
  }) async {
    final now = endTime ?? DateTime.now();
    final index = _classes.indexWhere((c) => c.id == liveClassId);
    int resolvedSec = durationSeconds ?? 0;
    if (index != -1) {
      final current = _classes[index];
      if (resolvedSec <= 0 && current.actualStartTime != null) {
        resolvedSec = now.difference(current.actualStartTime!).inSeconds;
        if (resolvedSec < 0) resolvedSec = 0;
      }
      _classes[index] = current.copyWith(
        status: LiveStatus.ended,
        actualEndTime: now,
        actualDurationSeconds: resolvedSec,
        estimatedDuration: resolvedSec > 0 ? Duration(seconds: resolvedSec) : Duration.zero,
        recordingStatus: 'processing',
      );
      notifyListeners();
    }
    try {
      await _repository.endAuthenticatedLiveSession(
        liveClassId,
        durationSeconds: resolvedSec,
        endTime: now,
      );
    } catch (e) {
      debugPrint('Error ending authenticated live session: $e');
    }
  }

  /// Verifies connection state of Cloudflare Live Input
  Future<Map<String, dynamic>> checkLiveStatus(String liveInputUid) async {
    return await _repository.checkCloudflareLiveStatus(liveInputUid);
  }

  // =========================================================================
  // LECTURE RECORDINGS LIBRARY MANAGEMENT
  // =========================================================================

  /// Fetches lecture recordings from database according to role RLS
  Future<void> fetchLectureRecordings({
    String? courseId,
    String? batchId,
    String? teacherId,
  }) async {
    _isRecordingsLoading = true;
    _recordingsErrorMessage = null;
    notifyListeners();

    try {
      _recordings = await _repository.getLectureRecordings(
        courseId: courseId,
        batchId: batchId,
        teacherId: teacherId,
      );
      _isRecordingsLoading = false;
      notifyListeners();
    } catch (e) {
      _recordingsErrorMessage = e.toString();
      _isRecordingsLoading = false;
      notifyListeners();
    }
  }

  /// Synchronizes a broadcast recording from Cloudflare and records in state
  Future<LectureRecordingModel?> syncBroadcastRecording({
    required String batchId,
    required String courseId,
    required String title,
    String? liveClassId,
    String? liveInputUid,
    String? teacherId,
    String? playbackUrl,
    int? durationSeconds,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    try {
      final rec = await _repository.syncBroadcastRecording(
        batchId: batchId,
        courseId: courseId,
        title: title,
        liveClassId: liveClassId,
        liveInputUid: liveInputUid,
        teacherId: teacherId,
        playbackUrl: playbackUrl,
        durationSeconds: durationSeconds,
        startTime: startTime,
        endTime: endTime,
      );
      if (rec != null) {
        final existingIdx = _recordings.indexWhere(
          (r) => r.videoUid == rec.videoUid,
        );
        if (existingIdx != -1) {
          _recordings[existingIdx] = rec;
        } else {
          _recordings.insert(0, rec);
        }

        // Mirror status to _classes list for instant student archive synchronization
        final classIdx = _classes.indexWhere((c) =>
            (liveClassId != null && c.id == liveClassId) ||
            c.cloudflareVideoUid == rec.videoUid);
        if (classIdx != -1) {
          final current = _classes[classIdx];
          _classes[classIdx] = current.copyWith(
            status: LiveStatus.ended,
            recordingStatus: rec.statusName,
            recordingUrl: rec.playbackUrl,
            cloudflareVideoUid: rec.videoUid,
            actualDurationSeconds: rec.durationSeconds,
            actualEndTime: rec.endTime,
          );
        }
        notifyListeners();
      }
      return rec;
    } catch (e) {
      debugPrint('Error syncing broadcast recording: $e');
      return null;
    }
  }

  /// Refreshes processing status of a recording from Cloudflare
  Future<LectureRecordingModel?> refreshRecording(String videoUid) async {
    try {
      final updated = await _repository.refreshRecordingStatus(videoUid);
      if (updated != null) {
        final idx = _recordings.indexWhere((r) => r.videoUid == videoUid);
        if (idx != -1) {
          _recordings[idx] = updated;
        }

        // Mirror status to _classes list
        final classIdx = _classes.indexWhere((c) =>
            c.cloudflareVideoUid == videoUid ||
            (updated.liveClassId != null && c.id == updated.liveClassId));
        if (classIdx != -1) {
          final current = _classes[classIdx];
          _classes[classIdx] = current.copyWith(
            recordingStatus: updated.statusName,
            recordingUrl: updated.playbackUrl,
            cloudflareVideoUid: updated.videoUid,
            actualDurationSeconds: updated.durationSeconds,
          );
        }
        notifyListeners();
      }
      return updated;
    } catch (e) {
      debugPrint('Error refreshing recording: $e');
      return null;
    }
  }

  /// Updates recording details such as title and thumbnail
  Future<LectureRecordingModel> updateRecordingDetails({
    required String recordingId,
    String? title,
    String? thumbnailUrl,
  }) async {
    try {
      final updated = await _repository.updateRecordingDetails(
        recordingId: recordingId,
        title: title,
        thumbnailUrl: thumbnailUrl,
      );
      final idx = _recordings.indexWhere((r) => r.id == recordingId);
      if (idx != -1) {
        _recordings[idx] = updated;
      }
      final classIdx = _classes.indexWhere(
        (c) =>
            (updated.liveClassId != null && c.id == updated.liveClassId) ||
            c.cloudflareVideoUid == updated.videoUid,
      );
      if (classIdx != -1) {
        final current = _classes[classIdx];
        _classes[classIdx] = current.copyWith(
          title: title ?? current.title,
          thumbnailUrl: thumbnailUrl ?? current.thumbnailUrl,
        );
      }
      notifyListeners();
      return updated;
    } catch (e) {
            _recordingsErrorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Permanently deletes a lecture recording
  Future<void> deleteRecording(String recordingId) async {
    try {
      await _repository.deleteRecording(recordingId);
      final rec = _recordings.cast<LectureRecordingModel?>().firstWhere(
        (r) => r?.id == recordingId,
        orElse: () => null,
      );
      _recordings.removeWhere((r) => r.id == recordingId);
      if (rec != null) {
        _classes.removeWhere(
          (c) =>
              (rec.liveClassId != null && c.id == rec.liveClassId) ||
              (rec.videoUid.isNotEmpty && c.cloudflareVideoUid == rec.videoUid) ||
              c.id == recordingId,
        );
      } else {
        _classes.removeWhere((c) => c.id == recordingId);
      }
      notifyListeners();
    } catch (e) {
      _recordingsErrorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    unsubscribeFromLiveChat();
    try {
      _liveClassesRealtimeChannel?.unsubscribe();
    } catch (_) {}
    super.dispose();
  }
}
