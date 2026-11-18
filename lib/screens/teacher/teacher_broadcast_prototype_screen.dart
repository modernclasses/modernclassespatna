import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/platform_settings_service.dart';
import '../../core/utils/batch_timing_helper.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/image_upload_picker_widget.dart';
import '../../features/courses/data/models/batch_model.dart';
import '../../features/live_classes/data/models/live_class_model.dart';
import '../../features/live_classes/data/datasources/live_class_remote_data_source.dart';
import '../../features/notifications/data/models/notification_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/live_class_provider.dart';
import '../../providers/notification_provider.dart';

/// Production Live Broadcast Studio for Teachers.
/// Provides native Camera2 hardware preview and RTMP streaming via RootEncoder.
/// Configuration (RTMPS URL & Stream Key) is strictly managed by Admins and
/// never displayed or edited by Teachers.
class TeacherBroadcastPrototypeScreen extends StatefulWidget {
  const TeacherBroadcastPrototypeScreen({super.key});

  @override
  State<TeacherBroadcastPrototypeScreen> createState() =>
      _TeacherBroadcastPrototypeScreenState();
}

class _TeacherBroadcastPrototypeScreenState
    extends State<TeacherBroadcastPrototypeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  MethodChannel? _methodChannel;
  EventChannel? _eventChannel;
  StreamSubscription<dynamic>? _eventSubscription;

  bool _isInitialized = false;
  bool _isStreaming = false;
  bool _isMicMuted = false;
  bool _isLoadingConfig = true;
  LiveStreamConfig? _streamConfig;

  String? _errorMessage;
  String _statusMessage = 'Initializing camera preview...';

  // Live timer & connection monitoring state
  Timer? _liveDurationTimer;
  DateTime? _actualStartTime;
  int _elapsedSeconds = 0;
  String _connectionStatus = 'Ready to go live';
  bool _isCheckingStatus = false;
  bool _hasShownEndWarning = false;
  DateTime? _scheduledSlotEndTime;
  BatchModel? _activeBroadcastingBatch;

  final TextEditingController _titleController = TextEditingController(
    text: 'Live Concept Lecture',
  );
  final TextEditingController _subjectController = TextEditingController(
    text: 'General Studies',
  );
  final TextEditingController _thumbnailUrlController = TextEditingController();
  final TextEditingController _teacherChatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  late TabController _studioTabController;
  bool _isNotifyingStudents = false;
  String? _selectedBatchId;
  String? _activeLiveClassId;
  Orientation? _lastOrientation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _studioTabController = TabController(length: 2, vsync: this);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _loadStreamConfig();
    _ensureCameraAndMicPermissions(showRationaleIfDenied: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CourseProvider>().fetchCatalog();
      }
    });
  }

  Future<bool> _ensureCameraAndMicPermissions({bool showRationaleIfDenied = true}) async {
    if (kIsWeb) return true;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return true;
    }

    try {
      final cameraStatus = await Permission.camera.status;
      final micStatus = await Permission.microphone.status;

      if (cameraStatus.isGranted && micStatus.isGranted) {
        return true;
      }

      // Request both permissions from OS (triggers standard OS prompt dialog)
      final statuses = await [
        Permission.camera,
        Permission.microphone,
      ].request();

      final cameraGranted = statuses[Permission.camera]?.isGranted ?? false;
      final micGranted = statuses[Permission.microphone]?.isGranted ?? false;

      if (cameraGranted && micGranted) {
        return true;
      }

      final cameraPermDenied =
          statuses[Permission.camera]?.isPermanentlyDenied ?? false;
      final micPermDenied =
          statuses[Permission.microphone]?.isPermanentlyDenied ?? false;

      if ((cameraPermDenied || micPermDenied) && showRationaleIfDenied && mounted) {
        _showPermissionSettingsDialog();
      }

      return false;
    } catch (e) {
      debugPrint('Error requesting camera/microphone permissions: $e');
      return false;
    }
  }

  void _showPermissionSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.videocam_off, color: AppColors.error),
            SizedBox(width: 8),
            Text('Permissions Required'),
          ],
        ),
        content: const Text(
          'Modern Classes Patna requires Camera and Microphone permissions to broadcast live lectures to your students.\n\nPlease enable Camera and Microphone in App Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadStreamConfig() async {
    try {
      final config = await PlatformSettingsService.getLiveStreamConfig();
      if (mounted) {
        setState(() {
          _streamConfig = config;
          _isLoadingConfig = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingConfig = false;
        });
      }
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    _liveDurationTimer?.cancel();
    _eventSubscription?.cancel();
    if (_activeLiveClassId != null) {
      final unendedId = _activeLiveClassId!;
      try {
        LiveClassRemoteDataSourceImpl().endAuthenticatedLiveSession(unendedId);
      } catch (_) {}
    }
    if (_methodChannel != null && _isInitialized) {
      try {
        if (_isStreaming) {
          _methodChannel!.invokeMethod('stopStream');
        }
        _methodChannel!.invokeMethod('stopPreview');
      } catch (_) {}
    }
    _titleController.dispose();
    _subjectController.dispose();
    _thumbnailUrlController.dispose();
    _teacherChatController.dispose();
    _chatScrollController.dispose();
    _studioTabController.dispose();
    super.dispose();
  }

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final hStr = hours.toString().padLeft(2, '0');
    final mStr = minutes.toString().padLeft(2, '0');
    final sStr = seconds.toString().padLeft(2, '0');
    return hours > 0 ? '$hStr:$mStr:$sStr' : '$mStr:$sStr';
  }

  void _startDurationTimer() {
    _liveDurationTimer?.cancel();
    _actualStartTime = DateTime.now();
    _elapsedSeconds = 0;
    _hasShownEndWarning = false;
    _liveDurationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_isStreaming) {
        timer.cancel();
        return;
      }
      final now = DateTime.now();
      final elapsed = now.difference(_actualStartTime!).inSeconds;

      // Check approaching slot end (within 5 minutes) and slot end
      if (_scheduledSlotEndTime != null) {
        final remainingSeconds =
            _scheduledSlotEndTime!.difference(now).inSeconds;
        if (remainingSeconds <= 300 && remainingSeconds > 0 && !_hasShownEndWarning) {
          _hasShownEndWarning = true;
          _showSlotEndingApproachingNotice();
        } else if (remainingSeconds <= 0 && !_hasShownEndWarning) {
          _hasShownEndWarning = true;
          _showSlotEndedNotice();
        }
      }

      setState(() {
        _elapsedSeconds = elapsed < 0 ? 0 : elapsed;
      });
    });
  }

  void _showSlotEndingApproachingNotice() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Notice: 5 minutes remaining in this scheduled batch slot.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.warning,
        duration: Duration(seconds: 5),
      ),
    );
  }

  void _showSlotEndedNotice() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.timer_off_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Batch slot ended. Please wrap up your broadcast to respect institute scheduling.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.error,
        duration: Duration(seconds: 7),
      ),
    );
  }

  void _showScheduleRestrictionDialog({
    required String title,
    required String message,
    required String windowDescription,
    String? currentIst,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.schedule, color: AppColors.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PERMITTED BROADCAST WINDOW (IST)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.error,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    windowDescription.isNotEmpty
                        ? windowDescription
                        : 'No valid slot assigned',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.deepInk,
                    ),
                  ),
                  if (currentIst != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Current Institute Time: $currentIst IST (Asia/Kolkata)',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 8),
            const Text(
              'Per institute regulations, live lectures can only be started within their assigned slot. To adjust this slot, please contact the admin.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkCloudflareLiveStatus() async {
    final courseProvider = context.read<CourseProvider>();
    final batches = courseProvider.batches;
    final batch = batches.where((b) => b.id == _selectedBatchId).firstOrNull ??
        (batches.isNotEmpty ? batches.first : null);

    final inputUid = batch?.streamKey ?? '';
    if (inputUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No stream key/input configured to query Cloudflare.'),
        ),
      );
      return;
    }

    setState(() {
      _isCheckingStatus = true;
    });

    try {
      final liveProvider = context.read<LiveClassProvider>();
      final result = await liveProvider.checkLiveStatus(inputUid);
      final liveStatus = result['status']?.toString().toLowerCase() ?? '';
      final isConnected =
          result['connected'] == true || liveStatus == 'connected';

      if (mounted) {
        setState(() {
          _isCheckingStatus = false;
          if (isConnected) {
            _connectionStatus = 'LIVE — Cloudflare confirmed';
            _statusMessage = 'Cloudflare confirmed: Stream is ACTIVE and receiving ingest.';
          } else if (liveStatus == 'reconnecting') {
            _connectionStatus = 'Connection interrupted / reconnecting';
            _statusMessage = 'Cloudflare: Stream reconnecting / unstable ingest.';
          } else if (_isStreaming) {
            _connectionStatus = 'Status unavailable — retrying';
            _statusMessage = 'Cloudflare reporting: $liveStatus';
          } else {
            _connectionStatus = 'Ready to go live';
            _statusMessage = 'Cloudflare: Input idle. Ready to broadcast.';
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Live Status: $_connectionStatus ($liveStatus)'),
            backgroundColor:
                isConnected ? AppColors.success : AppColors.deepInk,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingStatus = false;
          _connectionStatus = 'Status unavailable — retrying';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to query Cloudflare: $e')),
        );
      }
    }
  }

  void _onPlatformViewCreated(int id) {
    _methodChannel = MethodChannel('modern_classes_patna/broadcast_$id');
    _eventChannel = EventChannel('modern_classes_patna/broadcast_events_$id');

    _eventSubscription = _eventChannel!
        .receiveBroadcastStream()
        .listen(_onBroadcastEvent, onError: _onBroadcastError);

    _initializePreview();
  }

  Future<void> _updateNativeOrientation(bool isLandscape) async {
    if (_methodChannel == null || !_isInitialized) return;
    try {
      await _methodChannel!.invokeMethod('setOrientation', <String, dynamic>{
        'isLandscape': isLandscape,
        'degrees': isLandscape ? 0 : 90,
      });
    } catch (e) {
      debugPrint('Error updating native camera orientation: $e');
    }
  }

  Future<void> _initializePreview() async {
    if (_methodChannel == null) return;
    setState(() {
      _errorMessage = null;
      _statusMessage = 'Connecting hardware camera sensor...';
    });

    final hasPermissions = await _ensureCameraAndMicPermissions();
    if (!hasPermissions) {
      if (mounted) {
        setState(() {
          _isInitialized = false;
          _errorMessage =
              'Camera and microphone permissions are required to broadcast live. Please grant permissions in the prompt.';
          _statusMessage = 'Permissions required.';
        });
      }
      return;
    }

    if (!mounted) return;
    try {
      // Force 16:9 Landscape (1280x720) broadcast profile universally
      final bool? success = await _methodChannel!
          .invokeMethod<bool>('initializePreview', <String, dynamic>{
        'isLandscape': true,
        'width': 1280,
        'height': 720,
        'fps': 30,
        'bitrate': 2000 * 1024,
        'rotation': 0,
      });

      if (mounted) {
        setState(() {
          _isInitialized = success ?? false;
          _statusMessage = _isInitialized
              ? 'Camera ready. Ready to broadcast.'
              : 'Failed to access camera hardware.';
        });
      }
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() {
          _isInitialized = false;
          _errorMessage = e.message ?? 'Hardware error initializing camera.';
          _statusMessage = 'Preview initialization failed.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitialized = false;
          _errorMessage = 'Unexpected error: $e';
          _statusMessage = 'Camera initialization error.';
        });
      }
    }
  }

  void _onBroadcastEvent(dynamic eventData) {
    if (!mounted || eventData is! Map) return;
    final Map<dynamic, dynamic> data = eventData;
    final String? event = data['event']?.toString();

    switch (event) {
      case 'connecting':
        setState(() {
          _connectionStatus = 'Connecting';
          _statusMessage = 'Connecting to RTMP destination...';
        });
        break;
      case 'connected':
        setState(() {
          _isStreaming = true;
          _connectionStatus = 'LIVE — Cloudflare confirmed';
          _errorMessage = null;
          _statusMessage = '🔴 LIVE — Broadcasting to Students';
        });
        _startDurationTimer();
        _createLiveSessionOnConnect();
        break;
      case 'failed':
        final String reason = data['reason']?.toString() ?? 'Connection failed';
        _liveDurationTimer?.cancel();
        setState(() {
          _isStreaming = false;
          _connectionStatus = 'Connection interrupted / reconnecting';
          _errorMessage = 'Live Stream Connection Failed: $reason';
          _statusMessage = 'Broadcast stopped.';
        });
        break;
      case 'disconnected':
        _liveDurationTimer?.cancel();
        setState(() {
          _isStreaming = false;
          _connectionStatus = 'Ended';
          _statusMessage = 'Disconnected from RTMP broadcast server.';
        });
        break;
      case 'bitrate':
        final num? bitrate = data['bitrate'] as num?;
        if (bitrate != null && _isStreaming) {
          final int kbps = (bitrate / 1000).round();
          setState(() {
            _statusMessage = '🔴 LIVE — Broadcasting ($kbps kbps)';
          });
        }
        break;
      case 'auth_error':
        _liveDurationTimer?.cancel();
        setState(() {
          _isStreaming = false;
          _connectionStatus = 'Status unavailable — retrying';
          _errorMessage =
              'RTMP authentication failed. Please verify Admin settings.';
          _statusMessage = 'Authentication error.';
        });
        break;
      case 'auth_success':
        setState(() {
          _statusMessage = 'RTMP handshake authenticated.';
        });
        break;
    }
  }

  void _onBroadcastError(dynamic error) {
    if (!mounted) return;
    setState(() {
      _connectionStatus = 'Status unavailable — retrying';
      _errorMessage = 'Live event error: $error';
    });
  }

  Future<void> _createLiveSessionOnConnect([
    BatchModel? targetBatch,
    String? effectivePlaybackUrl,
  ]) async {
    if (_activeLiveClassId != null) return;
    try {
      final auth = context.read<AuthProvider>();
      final courseProvider = context.read<CourseProvider>();
      final liveProvider = context.read<LiveClassProvider>();
      final notifProvider = context.read<NotificationProvider>();

      final batches = courseProvider.batches;
      if (batches.isEmpty) return;
      final batch = targetBatch ??
          batches.where((b) => b.id == _selectedBatchId).firstOrNull ??
          batches.first;

      final playbackUrl = (effectivePlaybackUrl != null &&
              effectivePlaybackUrl.isNotEmpty)
          ? effectivePlaybackUrl
          : (batch.playbackUrl != null && batch.playbackUrl!.isNotEmpty
              ? batch.playbackUrl!
              : (batch.streamKey != null && batch.streamKey!.isNotEmpty
                  ? batch.streamKey!
                  : ''));

      final created = await liveProvider.startAuthenticatedLiveSession(
        batchId: batch.id,
        title: _titleController.text.trim(),
        subject: _subjectController.text.trim(),
        streamUrl: playbackUrl,
        thumbnailUrl: _thumbnailUrlController.text.trim().isNotEmpty
            ? _thumbnailUrlController.text.trim()
            : null,
        liveInputUid: batch.streamKey,
      );

      _activeLiveClassId = created.id;
      liveProvider.subscribeToLiveChat(created.id);

      notifProvider.broadcastAnnouncement(
        title: "🔴 ${auth.currentUser.name} is LIVE NOW!",
        message:
            "Live lecture '${_titleController.text.trim()}' is streaming now for ${batch.name}.",
        category: NotificationCategory.liveClass,
        targetBatchId: batch.id,
      );
    } catch (e) {
      debugPrint("Live session creation notice: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "⚠️ Database publish notice: $e";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "⚠️ Could not publish live class to database: $e. Students won't see this class.",
            ),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_methodChannel == null || !_isInitialized) return;
    try {
      await _methodChannel!.invokeMethod('switchCamera');
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to switch camera: ${e.message}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Camera switch error: $e';
        });
      }
    }
  }

  Future<void> _toggleMute() async {
    if (_methodChannel == null || !_isInitialized) return;
    try {
      final bool? isMuted =
          await _methodChannel!.invokeMethod<bool>('toggleMute');
      if (mounted) {
        setState(() {
          _isMicMuted = isMuted ?? !_isMicMuted;
          _statusMessage =
              _isMicMuted ? 'Microphone muted.' : 'Microphone active.';
        });
      }
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to toggle mute: ${e.message}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to toggle mute: $e');
      }
    }
  }

  Future<void> _startStreaming() async {
    final courseProvider = context.read<CourseProvider>();
    final batches = courseProvider.batches;
    if (batches.isEmpty) {
      setState(() {
        _errorMessage = 'No batches available. Please create or assign a batch.';
      });
      return;
    }

    final batch = batches.where((b) => b.id == _selectedBatchId).firstOrNull ??
        batches.first;
    _activeBroadcastingBatch = batch;

    // 1. Authoritative Batch Schedule Verification in Asia/Kolkata timezone (IST)
    final slotResult = BatchTimingHelper.validateCurrentTimeSlot(batch.timing);
    if (!slotResult.isValid) {
      final nowIst = BatchTimingHelper.getNowInKolkata();
      final currentIstStr = BatchTimingHelper.formatTimeOfDay(
        TimeOfDay(hour: nowIst.hour, minute: nowIst.minute),
      );
      if (mounted) {
        _showScheduleRestrictionDialog(
          title: slotResult.isPastEndTime
              ? 'Scheduled Slot Has Ended'
              : (slotResult.isTooEarly
                  ? 'Scheduled Slot Not Started'
                  : 'Outside Scheduled Slot'),
          message: slotResult.message,
          windowDescription: slotResult.permittedWindowDescription,
          currentIst: currentIstStr,
        );
      }
      return;
    }

    // Secondary Authoritative Backend Verification
    final liveProvider = context.read<LiveClassProvider>();
    try {
      final backendValidation =
          await liveProvider.validateBatchSchedule(batch.id);
      if (!backendValidation.isValid) {
        if (mounted) {
          _showScheduleRestrictionDialog(
            title: 'Institute Slot Validation Failed',
            message: backendValidation.message,
            windowDescription: backendValidation.permittedWindowDescription,
          );
        }
        return;
      }
    } catch (e) {
      debugPrint('Backend slot validation notice: $e');
    }

    // Calculate scheduled slot end time in local time
    final parsed = BatchTimingHelper.parseTiming(batch.timing);
    final now = DateTime.now();
    _scheduledSlotEndTime = DateTime(
      now.year,
      now.month,
      now.day,
      parsed.end.hour,
      parsed.end.minute,
    );

    // 2. Get credentials directly from batch settings
    String streamKey = batch.streamKey?.trim() ?? '';
    String rtmpUrl = batch.rtmpsUrl?.trim() ?? '';
    String playbackUrl = batch.playbackUrl?.trim() ?? '';

    // Check optional legacy admin fallback only if batch is unconfigured
    if (streamKey.isEmpty) {
      final config = await PlatformSettingsService.getLiveStreamConfig();
      _streamConfig = config;
      if (config.isConfigured) {
        streamKey = config.streamKey.trim();
        if (rtmpUrl.isEmpty) rtmpUrl = config.rtmpUrl.trim();
        if (playbackUrl.isEmpty) playbackUrl = config.playbackUrl.trim();
      }
    }

    if (rtmpUrl.isEmpty && streamKey.isNotEmpty) {
      rtmpUrl = 'rtmps://live.cloudflare.com:443/live/';
    }

    if (streamKey.isEmpty) {
      setState(() {
        _errorMessage =
            "Live streaming credentials have not been configured for '${batch.name}'. Please configure the Stream Key in Batch Settings (Manage Courses > Edit Batch).";
      });
      return;
    }

    // 3. Ensure Camera and Microphone permissions with OS prompt dialog
    final hasPermissions = await _ensureCameraAndMicPermissions();
    if (!hasPermissions) {
      setState(() {
        _errorMessage =
            'Camera and microphone permissions are required to broadcast live. Please grant permissions in the prompt.';
      });
      return;
    }

    if (_methodChannel == null || !_isInitialized) {
      setState(() {
        _errorMessage =
            'Camera hardware is not initialized. Please tap Retry Preview.';
      });
      return;
    }

    setState(() {
      _connectionStatus = 'Connecting';
      _errorMessage = null;
      _statusMessage = 'Initiating RTMP broadcast connection...';
      _actualStartTime = DateTime.now();
      _elapsedSeconds = 0;
    });

    if (!mounted) return;
    try {
      // Force 16:9 Landscape (1280x720) encoding universally
      await _methodChannel!.invokeMethod('startStream', <String, dynamic>{
        'url': rtmpUrl,
        'streamKey': streamKey,
        'isLandscape': true,
        'width': 1280,
        'height': 720,
        'fps': 30,
        'bitrate': 2000 * 1024,
        'iFrameInterval': 2,
        'rotation': 0,
      });

      if (mounted) {
        setState(() {
          _statusMessage = 'Negotiating RTMP handshake...';
        });
      }

      await _createLiveSessionOnConnect(batch, playbackUrl);
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() {
          _isStreaming = false;
          _connectionStatus = 'Ready to go live';
          _errorMessage = 'Failed to start stream: ${e.message}';
          _statusMessage = 'Start broadcast failed.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isStreaming = false;
          _connectionStatus = 'Ready to go live';
          _errorMessage = 'Failed to initiate stream: $e';
          _statusMessage = 'Connection error.';
        });
      }
    }
  }

  Future<void> _stopStreaming() async {
    if (_methodChannel == null) return;
    setState(() {
      _connectionStatus = 'Ending stream';
      _statusMessage = 'Ending live broadcast session...';
    });

    _liveDurationTimer?.cancel();
    final actualEndTime = DateTime.now();
    final savedStartTime = _actualStartTime;
    final durationSeconds = _elapsedSeconds > 0
        ? _elapsedSeconds
        : (_actualStartTime != null && _isStreaming
            ? actualEndTime.difference(_actualStartTime!).inSeconds
            : 0);

    try {
      await _methodChannel!.invokeMethod('stopStream');
    } catch (e) {
      debugPrint('Error invoking stopStream: $e');
    }

    if (!mounted) return;
    final liveProvider = context.read<LiveClassProvider>();
    final courseProvider = context.read<CourseProvider>();
    final authProvider = context.read<AuthProvider>();
    final teacherId = authProvider.currentUser.id;
    final batches = courseProvider.batches;
    final batch = _activeBroadcastingBatch ??
        batches.where((b) => b.id == _selectedBatchId).firstOrNull ??
        (batches.isNotEmpty ? batches.first : null);

    final endedSessionId = _activeLiveClassId;

    if (endedSessionId != null) {
      try {
        await liveProvider.endAuthenticatedLiveSession(
          endedSessionId,
          durationSeconds: durationSeconds,
          endTime: actualEndTime,
        );
      } catch (e) {
        debugPrint('Error ending authenticated live session: $e');
      }
    }

    if (batch != null && mounted) {
      try {
        // Automatically detect and save Cloudflare recordings via server-side Edge Function / DB RPC
        final savedRec = await liveProvider.syncBroadcastRecording(
          batchId: batch.id,
          courseId: batch.courseId,
          title: _titleController.text.trim(),
          liveClassId: endedSessionId,
          liveInputUid: batch.streamKey,
          playbackUrl: batch.playbackUrl,
          teacherId: teacherId,
          durationSeconds: durationSeconds,
          startTime: savedStartTime,
          endTime: actualEndTime,
        );
        if (savedRec != null) {
          debugPrint(
            '[TeacherBroadcast] Recording persisted: ${savedRec.videoUid} (status: ${savedRec.statusName})',
          );
        }
      } catch (e) {
        debugPrint('Recording sync notice: $e');
      }
    }

    try {
      liveProvider.unsubscribeFromLiveChat();
    } catch (_) {}
    _activeLiveClassId = null;

    if (mounted) {
      setState(() {
        _isStreaming = false;
        _actualStartTime = null;
        _elapsedSeconds = 0;
        _connectionStatus = 'Ended';
        _statusMessage =
            'Broadcast ended. Recording saved to library (~60s processing buffer).';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Live lecture ended. Recording saved to library (~60s to finalize on Cloudflare).',
          ),
          backgroundColor: AppColors.deepInk,
        ),
      );
    }
  }

  Future<void> _notifyStudents(BatchModel batch) async {
    if (_isNotifyingStudents) return;
    setState(() => _isNotifyingStudents = true);
    try {
      final auth = context.read<AuthProvider>();
      final notifProvider = context.read<NotificationProvider>();
      final title = _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : "Live Lecture";

      await notifProvider.broadcastAnnouncement(
        title: "🔴 ${auth.currentUser.name} is LIVE NOW!",
        message:
            "Live class '$title' is streaming now for ${batch.name}. Tap to enter classroom!",
        category: NotificationCategory.liveClass,
        targetBatchId: batch.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.notifications_active_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "📢 Alert sent to all students enrolled in '${batch.name}'!",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.emerald,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to send notification: $e"),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isNotifyingStudents = false);
      }
    }
  }

  void _sendTeacherChatMessage() {
    final text = _teacherChatController.text.trim();
    final effectiveClassId = _activeLiveClassId ?? context.read<LiveClassProvider>().currentActiveLiveClass?.id;
    if (text.isEmpty || effectiveClassId == null) return;
    final auth = context.read<AuthProvider>();
    final liveProvider = context.read<LiveClassProvider>();
    liveProvider.subscribeToLiveChat(effectiveClassId);

    liveProvider.sendLiveChatMessage(
      classId: effectiveClassId,
      senderName: auth.currentUser.name,
      senderRole: "TEACHER",
      text: text,
    );

    _teacherChatController.clear();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _confirmEndLiveClass() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("End Live Broadcast?"),
        content: const Text(
          "This will end the broadcast for all students and save the recording to the lecture archive.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("End Broadcast Now"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _stopStreaming();
      if (mounted) {
        try {
          await context.read<LiveClassProvider>().fetchLiveClasses();
        } catch (_) {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentOrientation = MediaQuery.orientationOf(context);
    final isLandscape = currentOrientation == Orientation.landscape;

    if (_lastOrientation != currentOrientation) {
      _lastOrientation = currentOrientation;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateNativeOrientation(isLandscape);
      });
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final isSmallDevice = MediaQuery.sizeOf(context).height < 700;
    final courseProvider = context.watch<CourseProvider>();
    final batches = courseProvider.batches;

    if (_selectedBatchId == null && batches.isNotEmpty) {
      _selectedBatchId = batches.first.id;
    }

    final selectedBatch = batches.where((b) => b.id == _selectedBatchId).firstOrNull ??
        (batches.isNotEmpty ? batches.first : null);

    final bool isBatchConfigured = selectedBatch != null &&
        ((selectedBatch.streamKey != null && selectedBatch.streamKey!.trim().isNotEmpty) ||
         (selectedBatch.rtmpsUrl != null && selectedBatch.rtmpsUrl!.trim().isNotEmpty));

    final isConfigured = isBatchConfigured || (_streamConfig?.isConfigured ?? false);

    return PopScope(
      canPop: !_isStreaming,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _confirmEndLiveClass();
        if (!_isStreaming && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Studio Camera Header Bar (portrait only)
            if (!isLandscape)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.border,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                      onPressed: () async {
                        if (_isStreaming) {
                          await _confirmEndLiveClass();
                          if (!_isStreaming && context.mounted) {
                            Navigator.of(context).pop();
                          }
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Live Broadcast Studio",
                            style: TextStyle(
                              color: isDark ? Colors.white : AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _statusMessage,
                            style: TextStyle(
                              color: _isStreaming
                                  ? AppColors.error
                                  : (isDark ? Colors.white70 : AppColors.textSecondary),
                              fontSize: 11,
                              fontWeight: _isStreaming
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (_isStreaming) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.fiber_manual_record,
                                color: Colors.white, size: 10),
                            const SizedBox(width: 4),
                            Text(
                              "LIVE · ${_formatDuration(_elapsedSeconds)}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    IconButton(
                      icon: _isCheckingStatus
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              Icons.sync_rounded,
                              size: 20,
                              color: isDark
                                  ? Colors.white70
                                  : AppColors.textSecondary,
                            ),
                      tooltip: 'Check Cloudflare Live Status',
                      onPressed: _isCheckingStatus
                          ? null
                          : _checkCloudflareLiveStatus,
                    ),
                  ],
                ),
              ),

            Expanded(
              child: isLandscape
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 5, child: _buildCameraViewport(isAndroid, isLandscape: true)),
                        Expanded(
                          flex: 4,
                          child: _isStreaming
                              ? _buildLiveStudioPanel(
                                  context,
                                  isDark: isDark,
                                  isLandscape: true,
                                  selectedBatch: selectedBatch,
                                )
                              : _buildConsole(
                                  context,
                                  isDark: isDark,
                                  isConfigured: isConfigured,
                                  isBatchConfigured: isBatchConfigured,
                                  selectedBatch: selectedBatch,
                                  batches: batches,
                                  isLandscape: true,
                                ),
                        ),
                      ],
                    )
                  : Column(
                          children: [
                            if (isKeyboardOpen && isSmallDevice)
                              SizedBox(
                                height: 110,
                                child: _buildCameraViewport(isAndroid, isLandscape: true),
                              )
                            else
                              _buildCameraViewport(isAndroid, isLandscape: true),
                            Expanded(
                              child: _isStreaming
                                  ? _buildLiveStudioPanel(
                                      context,
                                      isDark: isDark,
                                      isLandscape: false,
                                      selectedBatch: selectedBatch,
                                    )
                                  : _buildConsole(
                                      context,
                                      isDark: isDark,
                                      isConfigured: isConfigured,
                                      isBatchConfigured: isBatchConfigured,
                                      selectedBatch: selectedBatch,
                                      batches: batches,
                                      isLandscape: false,
                                    ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildCameraViewport(bool isAndroid, {required bool isLandscape}) {
    return Container(
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (isAndroid)
                AndroidView(
                  viewType: 'modern_classes_patna/broadcast_preview',
                  onPlatformViewCreated: _onPlatformViewCreated,
                )
              else
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.videocam_outlined,
                          size: 56,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Camera Preview Active',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isLandscape
                              ? '16:9 Landscape Video Feed Active (1280×720)'
                              : '9:16 Portrait Video Feed Active (720×1280)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Visual Aspect Ratio Indicator Badge (Always visible on viewport)
              Positioned(
                bottom: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isLandscape ? Icons.crop_16_9 : Icons.stay_current_portrait,
                        size: 13,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        '16:9 Widescreen (1280×720)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // In Landscape Mode: Floating Top-Left Back Button & Studio Pill
              if (isLandscape)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.of(context).pop(),
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 4),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isStreaming) ...[
                              const Icon(Icons.fiber_manual_record,
                                  color: AppColors.error, size: 10),
                              const SizedBox(width: 5),
                              Text(
                                'LIVE · ${_formatDuration(_elapsedSeconds)}',
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(width: 1, height: 12, color: Colors.black12),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              _isStreaming ? 'On-Air' : 'Live Studio',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '16:9',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // In Landscape Mode: Floating Bottom-Left Status Pill
              if (isLandscape)
                Positioned(
                  bottom: 38,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      _statusMessage,
                      style: TextStyle(
                        color: _isStreaming ? AppColors.error : Colors.white,
                        fontSize: 11,
                        fontWeight: _isStreaming ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),

              // Overlay Camera Quick Controls
              Positioned(
                top: 12,
                right: 12,
                child: Column(
                  children: [
                    _buildFloatingCircleButton(
                      icon: Icons.flip_camera_android,
                      tooltip: 'Switch Camera',
                      color: Colors.white,
                      iconColor: AppColors.textPrimary,
                      onTap: _switchCamera,
                    ),
                    const SizedBox(height: 10),
                    _buildFloatingCircleButton(
                      icon: _isMicMuted ? Icons.mic_off : Icons.mic,
                      tooltip: _isMicMuted ? 'Unmute Mic' : 'Mute Mic',
                      color: _isMicMuted ? AppColors.error : Colors.white,
                      iconColor: _isMicMuted ? Colors.white : AppColors.textPrimary,
                      onTap: _toggleMute,
                    ),
                  ],
                ),
              ),

              // Camera Initialization Retry Banner if failed
              if (!_isInitialized && isAndroid)
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.videocam_off,
                              color: AppColors.warning, size: 30),
                          const SizedBox(height: 6),
                          Text(
                            _errorMessage ??
                                'Camera hardware is initializing or awaiting permission.',
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            alignment: WrapAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                ),
                                icon: const Icon(Icons.security, size: 15),
                                label: const Text('Grant Permissions', style: TextStyle(fontSize: 12)),
                                onPressed: () async {
                                  final cam = await Permission.camera.status;
                                  final mic = await Permission.microphone.status;
                                  if (cam.isGranted && mic.isGranted) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text("Camera & Microphone permissions already granted. Initializing camera..."),
                                          backgroundColor: AppColors.emerald,
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                    _initializePreview();
                                    return;
                                  }
                                  final granted = await _ensureCameraAndMicPermissions(showRationaleIfDenied: true);
                                  if (granted) {
                                    _initializePreview();
                                  } else if (mounted) {
                                    _showPermissionSettingsDialog();
                                  }
                                },
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white38),
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                ),
                                icon: const Icon(Icons.refresh, size: 15),
                                label: const Text('Retry Preview', style: TextStyle(fontSize: 12)),
                                onPressed: _initializePreview,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveStudioPanel(
    BuildContext context, {
    required bool isDark,
    required bool isLandscape,
    required BatchModel? selectedBatch,
  }) {
    final liveProvider = context.watch<LiveClassProvider>();
    final effectiveClassId = _activeLiveClassId ??
        liveProvider.currentActiveLiveClass?.id ??
        liveProvider.classes
            .where((c) =>
                (selectedBatch != null && c.batchId == selectedBatch.id && c.status == LiveStatus.live) ||
                c.status == LiveStatus.live)
            .firstOrNull
            ?.id;
    final activeClass = effectiveClassId != null
        ? liveProvider.getLiveClassById(effectiveClassId)
        : liveProvider.currentActiveLiveClass;
    if (effectiveClassId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          liveProvider.subscribeToLiveChat(effectiveClassId);
        }
      });
    }
    final chatMessages = effectiveClassId != null
        ? liveProvider.getChatMessagesForClass(effectiveClassId)
        : (activeClass?.chatMessages ?? const <LiveChatMessage>[]);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: isLandscape
            ? const BorderRadius.horizontal(left: Radius.circular(20))
            : const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Studio Tab Bar
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceCard : const Color(0xFFF8FAFC),
              borderRadius: isLandscape
                  ? const BorderRadius.only(topLeft: Radius.circular(20))
                  : const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                ),
              ),
            ),
            child: TabBar(
              controller: _studioTabController,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              labelColor: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
              unselectedLabelColor:
                  isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.chat_bubble_outline_rounded, size: 15),
                      const SizedBox(width: 4),
                      const Flexible(
                        child: Text(
                          "Chat",
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (chatMessages.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "${chatMessages.length}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune_rounded, size: 15),
                      SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          "Controls",
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _studioTabController,
              children: [
                _buildStudioChatTab(
                  context,
                  isDark: isDark,
                  chatMessages: chatMessages,
                ),
                _buildStudioControlsTab(
                  context,
                  isDark: isDark,
                  selectedBatch: selectedBatch,
                  isLandscape: isLandscape,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudioChatTab(
    BuildContext context, {
    required bool isDark,
    required List<LiveChatMessage> chatMessages,
  }) {
    return Column(
      children: [
        // Chat Header Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          color: isDark ? AppColors.darkSurfaceCard : const Color(0xFFF8FAFC),
          child: Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppColors.emerald,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "LIVE CHAT",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                "${chatMessages.length} msgs",
                style: TextStyle(
                  fontSize: 10.5,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),

        // Messages List
        Expanded(
          child: chatMessages.isEmpty
              ? Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.forum_outlined,
                          size: 38,
                          color: isDark ? Colors.white24 : Colors.black26,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Waiting for student questions...",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "When students ask doubts in the classroom, their messages will appear here live.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _chatScrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  itemCount: chatMessages.length,
                  itemBuilder: (ctx, index) {
                    final msg = chatMessages[index];
                    final isTeacher = msg.senderRole.toUpperCase() == 'TEACHER' ||
                        msg.senderRole.toUpperCase() == 'FACULTY';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isTeacher
                            ? (isDark
                                ? AppColors.primary.withValues(alpha: 0.15)
                                : AppColors.saffronMuted.withValues(alpha: 0.5))
                            : (isDark ? AppColors.darkSurfaceCard : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isTeacher
                              ? AppColors.primary.withValues(alpha: 0.3)
                              : (isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 10,
                                backgroundColor: isTeacher
                                    ? AppColors.primary
                                    : const Color(0xFF64748B),
                                child: Text(
                                  msg.senderName.isNotEmpty
                                      ? msg.senderName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  msg.senderName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: isTeacher
                                      ? AppColors.primary.withValues(alpha: 0.2)
                                      : Colors.black.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isTeacher ? "FACULTY" : "STUDENT",
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: isTeacher
                                        ? AppColors.primaryDark
                                        : (isDark ? Colors.white70 : AppColors.textSecondary),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            msg.text,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),

        // Bottom Input Field (Teacher can reply to live chat)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceCard : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.border,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _teacherChatController,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                  ),
                  decoration: InputDecoration(
                    hintText: "Send message to students...",
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    filled: true,
                    fillColor: isDark ? AppColors.darkSurface : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _sendTeacherChatMessage(),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: AppColors.primary, size: 20),
                tooltip: "Send Message",
                onPressed: _sendTeacherChatMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStudioControlsTab(
    BuildContext context, {
    required bool isDark,
    required BatchModel? selectedBatch,
    required bool isLandscape,
  }) {
    final liveProvider = context.watch<LiveClassProvider>();
    final activeClass = _activeLiveClassId != null
        ? liveProvider.getLiveClassById(_activeLiveClassId!)
        : liveProvider.currentActiveLiveClass;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // On-Air Stream Status Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceCard : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.fiber_manual_record,
                              color: AppColors.error, size: 10),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              "ON AIR · ${_formatDuration(_elapsedSeconds)}",
                              style: const TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.bold,
                                fontSize: 11.5,
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: AppColors.emerald.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.visibility_outlined, size: 12, color: AppColors.emerald),
                          const SizedBox(width: 4),
                          Text(
                            "${activeClass?.activeViewersCount ?? 0} in class",
                            style: const TextStyle(
                              color: AppColors.emerald,
                              fontWeight: FontWeight.bold,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _titleController.text.trim().isNotEmpty
                      ? _titleController.text.trim()
                      : "Live Lecture",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  "${_subjectController.text.trim()} • ${selectedBatch?.name ?? 'Batch'}",
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                  ),
                ),
                if (selectedBatch != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    "Scheduled Slot: ${selectedBatch.timing} (IST)",
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                if (_activeLiveClassId != null)
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          size: 13, color: AppColors.emerald),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          "Published to students in ${selectedBatch?.name ?? 'batch'}",
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.emerald,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                else
                  InkWell(
                    onTap: () => _createLiveSessionOnConnect(selectedBatch),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.5)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 13, color: AppColors.warning),
                          SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              "Not published to students (Tap to publish)",
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.warning,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Broadcast Health / Telemetry
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "BROADCAST FORMAT",
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isLandscape ? "16:9 Landscape" : "9:16 Portrait",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                        ),
                      ),
                      Text(
                        isLandscape ? "1280×720 · 30 FPS" : "720×1280 · 30 FPS",
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "STREAM BITRATE",
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "2,000 kbps",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                        ),
                      ),
                      Text(
                        _connectionStatus,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.emerald,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // "Notify Students" Button
          if (selectedBatch != null) ...[
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: _isNotifyingStudents
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.notifications_active_rounded, size: 18),
                label: Text(
                  _isNotifyingStudents
                      ? "Sending Alerts..."
                      : "📢 Notify Enrolled Students",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                onPressed: _isNotifyingStudents
                    ? null
                    : () => _notifyStudents(selectedBatch),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Quick Hardware Actions (Switch Camera & Mute)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.flip_camera_android, size: 18),
                  label: const Text("Flip Camera", style: TextStyle(fontSize: 12)),
                  onPressed: _switchCamera,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    foregroundColor: _isMicMuted ? AppColors.error : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: Icon(
                    _isMicMuted ? Icons.mic_off : Icons.mic,
                    size: 18,
                  ),
                  label: Text(
                    _isMicMuted ? "Unmute Mic" : "Mute Mic",
                    style: const TextStyle(fontSize: 12),
                  ),
                  onPressed: _toggleMute,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // End Broadcast Button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.stop_circle_outlined, size: 18),
              label: const Text(
                "End Live Broadcast",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: _confirmEndLiveClass,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsole(
    BuildContext context, {
    required bool isDark,
    required bool isConfigured,
    required bool isBatchConfigured,
    required BatchModel? selectedBatch,
    required List<dynamic> batches,
    required bool isLandscape,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: isLandscape
            ? const BorderRadius.horizontal(left: Radius.circular(20))
            : const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: isLandscape ? 12 : 14,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // System Ingest Status Badge (No secrets exposed)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Broadcast Configuration',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                if (_isLoadingConfig)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (isConfigured)
                  CustomBadge(
                    text: isBatchConfigured ? 'Batch Configured' : 'Configured',
                    variant: BadgeVariant.success,
                    fontSize: 10,
                  )
                else
                  const CustomBadge(
                    text: 'Not Configured',
                    variant: BadgeVariant.warning,
                    fontSize: 10,
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Live Status & Schedule Monitor Card
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isStreaming ? Icons.fiber_manual_record : Icons.schedule,
                    size: 13,
                    color: _isStreaming ? AppColors.error : AppColors.primary,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      _isStreaming
                          ? 'LIVE · ${_formatDuration(_elapsedSeconds)}'
                          : (selectedBatch != null
                              ? '${selectedBatch.timing} (IST)'
                              : 'Slot: Unassigned (IST)'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: _isStreaming
                            ? AppColors.error
                            : (isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.deepInk),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: (_connectionStatus.contains('LIVE') ||
                              _connectionStatus.contains('confirmed'))
                          ? AppColors.success.withValues(alpha: 0.12)
                          : (_connectionStatus.contains('interrupted') ||
                                  _connectionStatus.contains('failed'))
                              ? AppColors.error.withValues(alpha: 0.12)
                              : AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _connectionStatus,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: (_connectionStatus.contains('LIVE') ||
                                _connectionStatus.contains('confirmed'))
                            ? AppColors.success
                            : (_connectionStatus.contains('interrupted') ||
                                    _connectionStatus.contains('failed'))
                                ? AppColors.error
                                : AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (!isConfigured && !_isLoadingConfig)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: AppColors.warning, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        selectedBatch != null
                            ? "Live streaming credentials have not been configured for '${selectedBatch.name}'. Please configure the Stream Key in Batch Settings (Manage Courses > Edit Batch)."
                            : 'Live streaming credentials have not been configured. Please configure the Stream Key in Batch Settings.',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.warning,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Lecture Title Field
            TextField(
              controller: _titleController,
              enabled: !_isStreaming,
              decoration: InputDecoration(
                labelText: 'Lecture Title',
                hintText: 'e.g. Modern Indian History — Lecture 4',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Target Batch Selector
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedBatchId,
                    isDense: true,
                    isExpanded: true,
                    dropdownColor:
                        isDark ? AppColors.darkSurfaceCard : Colors.white,
                    decoration: InputDecoration(
                      labelText: 'Target Batch',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: batches.map<DropdownMenuItem<String>>((b) {
                      return DropdownMenuItem<String>(
                        value: b.id as String,
                        child: Text(
                          b.name as String,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: _isStreaming
                        ? null
                        : (val) {
                            setState(() => _selectedBatchId = val);
                          },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Thumbnail Poster Picker
            ImageUploadPickerWidget(
              controller: _thumbnailUrlController,
              labelText: 'Live Thumbnail Poster',
              hintText: 'https://.../thumbnail.jpg',
              helperText: 'Poster displayed on classroom card',
              isCompact: true,
              enabled: !_isStreaming,
              onUpload: (fileName, bytes) async {
                final liveProvider = context.read<LiveClassProvider>();
                return await liveProvider.uploadLiveClassThumbnail(
                  fileName: fileName,
                  fileBytes: bytes,
                );
              },
            ),
            const SizedBox(height: 12),

            // Error message banner if any
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

            // Broadcast Action Button (Start / Stop)
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                key: const Key('broadcast_action_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isStreaming
                      ? AppColors.error
                      : (isConfigured
                          ? AppColors.primary
                          : Colors.grey),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: _isStreaming ? 4 : 1,
                ),
                icon: Icon(
                  _isStreaming ? Icons.stop_circle : Icons.cell_tower,
                  size: 20,
                ),
                label: Text(
                  _isStreaming
                      ? 'End Live Broadcast'
                      : 'Start Live Broadcast',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: _isStreaming
                    ? _stopStreaming
                    : (isConfigured ? _startStreaming : null),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingCircleButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color color = Colors.white,
    Color iconColor = AppColors.textPrimary,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color,
        elevation: 2,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Icon(icon, color: iconColor, size: 22),
          ),
        ),
      ),
    );
  }
}
