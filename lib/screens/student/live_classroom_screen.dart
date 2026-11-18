import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import '../../widgets/confirm_delete_lecture_dialog.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/image_upload_picker_widget.dart';
import '../../core/widgets/modern_card.dart';
import '../../models/live_class_model.dart';
import '../../features/live_classes/data/models/lecture_recording_model.dart';
import '../../features/auth/data/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/live_class_provider.dart';
import 'ask_doubt_dialog.dart';
import '../../features/attendance/logic/attendance_provider.dart';
import '../../models/course_model.dart';

class LiveClassroomScreen extends StatefulWidget {
  final LiveClassModel liveClass;

  const LiveClassroomScreen({super.key, required this.liveClass});

  @override
  State<LiveClassroomScreen> createState() => _LiveClassroomScreenState();
}

class _LiveClassroomScreenState extends State<LiveClassroomScreen> {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _fullscreenScrollController = ScrollController();
  bool _showLandscapeChat = true;

  VideoPlayerController? _videoPlayerController;
  bool _isVideoInitialized = false;
  bool _isVideoError = false;
  String? _videoErrorMessage;
  bool _isBuffering = false;
  bool _isPlaying = true;
  bool _isMuted = false;
  double _playbackSpeed = 1.0;
  bool _isFullscreen = false;
  bool _controlsVisible = true;
  Timer? _controlsTimer;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isSeeking = false;
  double _seekSliderValue = 0.0;
  bool _isHandRaised = false;
  String? _lastInitializedUrl;
  bool _hasAutoMarkedAttendance = false;
  double _lastSavedProgress = 0.0;
  int _lastRecordedPositionSec = 0;
  CourseProvider? _courseProvider;
  AuthProvider? _authProvider;
  LiveClassProvider? _liveClassProvider;
  bool _isDeleted = false;
  bool _isProcessingVideo = false;
  int _processingRetryCount = 0;
  static const int _maxProcessingRetries = 15;
  Timer? _processingRetryTimer;
  Timer? _liveTickerTimer;

  @override
  void initState() {
    super.initState();
    final url = _resolvePlaybackUrl(widget.liveClass);
    if (widget.liveClass.status == LiveStatus.ended &&
        (widget.liveClass.recordingStatus == 'processing' || url.contains('rec_') || url.isEmpty)) {
      _isProcessingVideo = true;
      _pollRecordingReadiness();
    } else if (url.isNotEmpty) {
      _initializePlayer(url);
    }
    if (widget.liveClass.status == LiveStatus.live) {
      _liveTickerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_controlsVisible) {
          setState(() {});
        }
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _recordPlayback(0.0, 0);
        try {
          context.read<LiveClassProvider>().subscribeToLiveChat(widget.liveClass.id);
        } catch (_) {}
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _courseProvider = Provider.of<CourseProvider?>(context, listen: false);
    _authProvider = Provider.of<AuthProvider?>(context, listen: false);
    _liveClassProvider = Provider.of<LiveClassProvider?>(context, listen: false);
  }

  @override
  void didUpdateWidget(covariant LiveClassroomScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldUrl = _resolvePlaybackUrl(oldWidget.liveClass);
    final newUrl = _resolvePlaybackUrl(widget.liveClass);
    if (newUrl.isNotEmpty && newUrl != oldUrl) {
      _initializePlayer(newUrl);
    }
  }

  @override
  void dispose() {
    final finalPos = _currentPosition.inSeconds;
    final finalDur = _totalDuration.inSeconds;
    final finalProg = finalDur > 0 ? (finalPos / finalDur).clamp(0.0, 1.0) : _lastSavedProgress;
    if (!_isDeleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isDeleted) {
          _recordPlayback(finalProg, finalPos);
        }
      });
    }
    _controlsTimer?.cancel();
    _processingRetryTimer?.cancel();
    _liveTickerTimer?.cancel();
    _chatController.dispose();
    _scrollController.dispose();
    _fullscreenScrollController.dispose();
    _videoPlayerController?.removeListener(_videoListener);
    _videoPlayerController?.dispose();
    try {
      _liveClassProvider?.unsubscribeFromLiveChat();
    } catch (_) {}
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    super.dispose();
  }

  String _resolvePlaybackUrl(LiveClassModel current) {
    if (current.recordingUrl != null &&
        current.recordingUrl!.isNotEmpty &&
        !current.recordingUrl!.contains('rec_')) {
      return current.recordingUrl!;
    }
    if (widget.liveClass.recordingUrl != null &&
        widget.liveClass.recordingUrl!.isNotEmpty &&
        !widget.liveClass.recordingUrl!.contains('rec_')) {
      return widget.liveClass.recordingUrl!;
    }
    if (current.streamUrl.isNotEmpty && !current.streamUrl.contains('rec_')) {
      return current.streamUrl;
    }
    return widget.liveClass.streamUrl;
  }

  void _pollRecordingReadiness() {
    _processingRetryTimer?.cancel();
    _processingRetryTimer = Timer(const Duration(seconds: 3), () async {
      if (!mounted) return;
      final liveProv = _liveClassProvider;
      if (liveProv != null) {
        final vidUid = widget.liveClass.cloudflareVideoUid;
        if (vidUid != null && vidUid.isNotEmpty) {
          final refreshed = await liveProv.refreshRecording(vidUid);
          if (refreshed != null &&
              refreshed.playbackUrl.isNotEmpty &&
              !refreshed.playbackUrl.contains('rec_')) {
            _initializePlayer(refreshed.playbackUrl);
            return;
          }
        }
      }
      final curUrl = _resolvePlaybackUrl(widget.liveClass);
      if (curUrl.isNotEmpty && !curUrl.contains('rec_')) {
        _initializePlayer(curUrl);
      } else if (_processingRetryCount < _maxProcessingRetries) {
        _processingRetryCount++;
        _pollRecordingReadiness();
      } else {
        if (mounted) {
          setState(() {
            _isProcessingVideo = false;
            _isVideoError = true;
            _videoErrorMessage =
                "The lecture recording is being prepared by the streaming network (~60s). Please tap Retry in a moment.";
          });
        }
      }
    });
  }

  Future<void> _initializePlayer(String url, {bool isRetry = false}) async {
    if (url.isEmpty) return;
    if (url == _lastInitializedUrl && _isVideoInitialized && !isRetry) return;
    _lastInitializedUrl = url;

    _processingRetryTimer?.cancel();
    if (!isRetry) {
      _processingRetryCount = 0;
    }

    final courseProvider = Provider.of<CourseProvider?>(context, listen: false);

    try {
      if (mounted) {
        setState(() {
          _isVideoInitialized = false;
          if (!isRetry) {
            _isVideoError = false;
            _videoErrorMessage = null;
            _isProcessingVideo = false;
          }
        });
      }

      _videoPlayerController?.removeListener(_videoListener);
      await _videoPlayerController?.dispose();
      _videoPlayerController = null;

      String effectiveUrl = url.trim();
      if (!effectiveUrl.startsWith('http://') && !effectiveUrl.startsWith('https://')) {
        try {
          if (courseProvider != null) {
            effectiveUrl = await courseProvider.getLessonSignedUrl(effectiveUrl);
          }
        } catch (e) {
          debugPrint("[LiveClassroom] Failed to sign video URL: $e");
        }
      }

      // Guard: Never pass an un-resolved relative path to networkUrl
      if (!effectiveUrl.startsWith('http://') && !effectiveUrl.startsWith('https://')) {
        if (mounted) {
          setState(() {
            _isProcessingVideo = false;
            _isVideoError = true;
            _videoErrorMessage =
                "Unable to obtain video access stream. Please verify storage permissions.";
          });
        }
        return;
      }

      final uri = Uri.tryParse(effectiveUrl);
      if (uri == null || !uri.hasScheme || (uri.host.isEmpty && uri.scheme != 'file')) {
        if (mounted) {
          setState(() {
            _isProcessingVideo = false;
            _isVideoError = true;
            _videoErrorMessage = "Invalid stream or recording URL format.";
          });
        }
        return;
      }

      VideoFormat? formatHint;
      final lowerUrl = effectiveUrl.toLowerCase();
      if (lowerUrl.contains('.m3u8') ||
          lowerUrl.contains('cloudflarestream.com') ||
          lowerUrl.contains('videodelivery.net')) {
        formatHint = VideoFormat.hls;
      } else if (lowerUrl.contains('.mpd')) {
        formatHint = VideoFormat.dash;
      } else if (lowerUrl.contains('.mp4')) {
        formatHint = VideoFormat.other;
      }

      final controller = VideoPlayerController.networkUrl(
        uri,
        formatHint: formatHint,
      );
      _videoPlayerController = controller;

      controller.addListener(_videoListener);
      await controller.initialize();
      await controller.setPlaybackSpeed(_playbackSpeed);
      await controller.setVolume(_isMuted ? 0.0 : 1.0);

      // Auto-seek to existing progress if available for recorded lecture
      if (widget.liveClass.status == LiveStatus.ended && courseProvider != null) {
        try {
          final recent = courseProvider.recentPlaybacks
              .cast<RecentLecturePlayback?>()
              .firstWhere((p) => p?.lectureId == widget.liveClass.id, orElse: () => null);

          if (recent != null && recent.positionSeconds > 0) {
            await controller.seekTo(Duration(seconds: recent.positionSeconds));
            _lastSavedProgress = recent.progressPercent;
            _lastRecordedPositionSec = recent.positionSeconds;
          } else {
            final lesson = courseProvider.videoLessons
                .cast<VideoLessonModel?>()
                .firstWhere((l) => l?.id == widget.liveClass.id, orElse: () => null);
            if (lesson != null && lesson.progressPercent > 0 && lesson.progressPercent < 1.0) {
              final seekSeconds = (controller.value.duration.inSeconds * lesson.progressPercent).toInt();
              if (seekSeconds > 0) {
                await controller.seekTo(Duration(seconds: seekSeconds));
                _lastSavedProgress = lesson.progressPercent;
                _lastRecordedPositionSec = seekSeconds;
              }
            }
          }
        } catch (_) {}
      }

      if (_isPlaying) {
        await controller.play();
      }

      if (mounted) {
        setState(() {
          _isProcessingVideo = false;
          _isVideoInitialized = true;
          _isVideoError = false;
          _videoErrorMessage = null;
          _processingRetryCount = 0;
          _totalDuration = controller.value.duration;
          _currentPosition = controller.value.position;
        });
        _startControlsTimer();
      }
    } catch (e) {
      _handlePlaybackError(e.toString(), url);
    }
  }

  void _handlePlaybackError(String errorString, String originalUrl) {
    if (!mounted) return;
    final isCloudflareOrHls = originalUrl.contains('cloudflarestream.com') ||
        originalUrl.contains('videodelivery.net') ||
        originalUrl.contains('.m3u8');
    final isSourceError = errorString.contains('Source error') ||
        errorString.contains('rO.j') ||
        errorString.contains('VideoError') ||
        errorString.contains('404');

    if (isCloudflareOrHls && isSourceError && _processingRetryCount < _maxProcessingRetries) {
      _processingRetryCount++;
      setState(() {
        _isProcessingVideo = true;
        _isVideoError = false;
        _videoErrorMessage = null;
      });
      _processingRetryTimer?.cancel();
      _processingRetryTimer = Timer(const Duration(seconds: 4), () async {
        if (!mounted) return;
        final liveProv = _liveClassProvider;
        if (liveProv != null && widget.liveClass.status == LiveStatus.ended) {
          final vidUid = widget.liveClass.cloudflareVideoUid;
          if (vidUid != null && vidUid.isNotEmpty) {
            final refreshed = await liveProv.refreshRecording(vidUid);
            if (refreshed != null &&
                refreshed.playbackUrl.isNotEmpty &&
                !refreshed.playbackUrl.contains('rec_')) {
              _initializePlayer(refreshed.playbackUrl, isRetry: true);
              return;
            }
          }
        }
        _initializePlayer(originalUrl, isRetry: true);
      });
      return;
    }

    setState(() {
      _isProcessingVideo = false;
      _isVideoError = true;
      _videoErrorMessage = isSourceError
          ? "The video is either still processing or temporarily unreachable. Please tap Retry in a few moments."
          : errorString;
    });
  }

  void _videoListener() {
    if (!mounted || _videoPlayerController == null) return;
    final value = _videoPlayerController!.value;

    if (value.hasError && !_isVideoError) {
      _handlePlaybackError(
        value.errorDescription ?? "Video playback failed.",
        _lastInitializedUrl ?? "",
      );
      return;
    }

    if (!_isSeeking) {
      final isStateChanged = _isPlaying != value.isPlaying ||
          _isBuffering != value.isBuffering ||
          _totalDuration != value.duration;
      final isSecondChanged = _currentPosition.inSeconds != value.position.inSeconds;

      // Throttle setState to avoid rebuilding the 2,000+ line widget tree 60 times/sec.
      // When controls are hidden during normal playback, zero UI rebuilds occur,
      // freeing up 100% of the UI thread & GPU for smooth 60fps hardware video decoding.
      if (isStateChanged || (_controlsVisible && isSecondChanged)) {
        setState(() {
          _isPlaying = value.isPlaying;
          _isBuffering = value.isBuffering;
          _currentPosition = value.position;
          _totalDuration = value.duration;
        });
      } else {
        _isPlaying = value.isPlaying;
        _isBuffering = value.isBuffering;
        _currentPosition = value.position;
        _totalDuration = value.duration;
      }

      if (value.isInitialized && widget.liveClass.status == LiveStatus.ended) {
        final totalSec = value.duration.inSeconds;
        if (totalSec > 0) {
          final posSec = value.position.inSeconds;
          final progress = (posSec / totalSec).clamp(0.0, 1.0);
          if (progress >= 0.75 && !_hasAutoMarkedAttendance) {
            _triggerAutoAttendance(progress);
          }
          if (progress > _lastSavedProgress || (posSec - _lastRecordedPositionSec).abs() >= 4) {
            _lastSavedProgress = progress;
            _lastRecordedPositionSec = posSec;
            _recordPlayback(progress, posSec);
          }
        }
      }
    }
  }

  void _recordPlayback(double progress, int positionSec) {
    if (_isDeleted) return;
    try {
      final cp = _courseProvider;
      final auth = _authProvider;
      if (cp != null) {
        cp.recordLecturePlayback(
          lectureId: widget.liveClass.id,
          courseId: widget.liveClass.courseId,
          batchId: widget.liveClass.batchId,
          courseName: widget.liveClass.courseName,
          batchName: widget.liveClass.batchName,
          title: widget.liveClass.title,
          subject: widget.liveClass.subject,
          teacherName: widget.liveClass.teacherName,
          videoUrl: widget.liveClass.streamUrl,
          thumbnailUrl: widget.liveClass.thumbnailUrl,
          duration: _totalDuration.inSeconds > 0
              ? _totalDuration
              : widget.liveClass.estimatedDuration,
          progressPercent: progress,
          positionSeconds: positionSec,
          isLiveRecording: widget.liveClass.status == LiveStatus.ended,
          userId: auth?.currentUser.id,
        );
      }
    } catch (e) {
      debugPrint('[LiveClassroom] Error recording playback: $e');
    }
  }

  Future<void> _triggerAutoAttendance(double watchProgress) async {
    _hasAutoMarkedAttendance = true;
    try {
      final auth = Provider.of<AuthProvider?>(context, listen: false);
      final attendance = Provider.of<AttendanceProvider?>(context, listen: false);
      if (attendance != null && auth != null) {
        final marked = await attendance.logLectureAttendanceAuto(
          batchId: widget.liveClass.batchId,
          batchName: widget.liveClass.batchName.isNotEmpty
              ? widget.liveClass.batchName
              : widget.liveClass.courseName,
          studentId: auth.currentUser.id,
          studentName: auth.currentUser.name,
          lessonTitle: widget.liveClass.title,
          watchPercentage: watchProgress,
        );
        if (marked && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.verified_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "🎯 Attendance Auto-Logged: 75% of '${widget.liveClass.title}' completed!",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppTheme.success,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error auto-logging attendance in LiveClassroom: $e");
    }
  }

  void _togglePlayPause() {
    if (_videoPlayerController != null && _isVideoInitialized) {
      if (_videoPlayerController!.value.isPlaying) {
        _videoPlayerController!.pause();
        setState(() {
          _isPlaying = false;
          _controlsVisible = true;
        });
        _controlsTimer?.cancel();
      } else {
        _videoPlayerController!.play();
        setState(() {
          _isPlaying = true;
        });
        _startControlsTimer();
      }
    } else {
      setState(() {
        _isPlaying = !_isPlaying;
      });
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    _videoPlayerController?.setVolume(_isMuted ? 0.0 : 1.0);
  }

  void _setPlaybackSpeed(double speed) {
    setState(() {
      _playbackSpeed = speed;
    });
    _videoPlayerController?.setPlaybackSpeed(speed);
  }

  Duration _getEffectiveLiveDuration(LiveClassModel currentClass) {
    return _calculateEffectiveLiveDuration(currentClass);
  }

  void _seekRelative(Duration delta) {
    if (_videoPlayerController == null || !_isVideoInitialized) return;
    final liveProvider = Provider.of<LiveClassProvider?>(context, listen: false);
    final currentClass = liveProvider?.getLiveClassById(widget.liveClass.id) ?? widget.liveClass;
    final effectiveTotal = _getEffectiveLiveDuration(currentClass);
    final newPos = _videoPlayerController!.value.position + delta;
    final clamped = newPos < Duration.zero
        ? Duration.zero
        : (effectiveTotal > Duration.zero && newPos > effectiveTotal
            ? effectiveTotal
            : newPos);
    _videoPlayerController!.seekTo(clamped);
    setState(() {
      _currentPosition = clamped;
    });
    _startControlsTimer();
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
      _controlsVisible = true;
    });
    _startControlsTimer();

    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    if (!_isPlaying) {
      if (!_controlsVisible && mounted) {
        setState(() => _controlsVisible = true);
      }
      return;
    }
    _controlsTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted && _isPlaying) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControlsVisibility() {
    setState(() {
      _controlsVisible = !_controlsVisible;
    });
    if (_controlsVisible && _isPlaying) {
      _startControlsTimer();
    }
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) d = Duration.zero;
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Duration _calculateEffectiveLiveDuration(LiveClassModel currentClass) {
    if (_totalDuration > Duration.zero) {
      if (_currentPosition > _totalDuration) {
        return _currentPosition;
      }
      return _totalDuration;
    }
    final startTime = currentClass.actualStartTime ?? currentClass.scheduledStartTime;
    final elapsed = DateTime.now().difference(startTime);
    if (elapsed > Duration.zero) {
      return elapsed;
    }
    return const Duration(seconds: 1);
  }

  double _getBufferedFraction(Duration totalDuration) {
    if (totalDuration.inMilliseconds <= 0 || _videoPlayerController == null) {
      return 0.0;
    }
    try {
      final buffered = _videoPlayerController!.value.buffered;
      if (buffered.isEmpty) return 0.0;
      Duration maxEnd = Duration.zero;
      for (final range in buffered) {
        if (range.end > maxEnd) {
          maxEnd = range.end;
        }
      }
      return (maxEnd.inMilliseconds / totalDuration.inMilliseconds).clamp(0.0, 1.0);
    } catch (_) {
      return 0.0;
    }
  }

  void _jumpToLiveEdge(Duration liveTotal) {
    if (_videoPlayerController != null && _isVideoInitialized) {
      _videoPlayerController!.seekTo(liveTotal);
    }
    if (mounted) {
      setState(() {
        _currentPosition = liveTotal;
        _isSeeking = false;
        if (!_isPlaying && _videoPlayerController != null) {
          _isPlaying = true;
          _videoPlayerController!.play();
        }
      });
      _startControlsTimer();
    }
  }



  void _sendMessage(LiveClassProvider liveProvider, AuthProvider auth) {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    _chatController.clear();

    liveProvider.sendLiveChatMessage(
      classId: widget.liveClass.id,
      senderName: auth.currentUser.name.isNotEmpty
          ? auth.currentUser.name
          : "Student",
      senderRole: auth.currentUser.role.name.toUpperCase(),
      text: text,
    );
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
      if (_fullscreenScrollController.hasClients) {
        _fullscreenScrollController.animateTo(
          _fullscreenScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _showEditLectureDialog(
    BuildContext context,
    LiveClassModel currentClass,
  ) async {
    final titleCtrl = TextEditingController(text: currentClass.title);
    final thumbCtrl =
        TextEditingController(text: currentClass.thumbnailUrl ?? '');
    final formKey = GlobalKey<FormState>();
    final liveProvider = context.read<LiveClassProvider>();
    final courseProvider = context.read<CourseProvider>();
    bool isSaving = false;
    String? localError;

    await showDialog(
      context: context,
      barrierDismissible: !isSaving,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(
              children: [
                const Icon(Icons.edit_note, color: AppColors.primaryDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Edit Lecture Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 380,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (localError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.error),
                          ),
                          child: Text(
                            localError!,
                            style: const TextStyle(color: AppColors.error, fontSize: 12),
                          ),
                        ),
                      ],
                      TextFormField(
                        key: const Key('live_edit_lecture_title_input'),
                        controller: titleCtrl,
                        decoration: InputDecoration(
                          labelText: "Lecture Title",
                          hintText: "Enter title...",
                          prefixIcon: const Icon(Icons.title, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          isDense: true,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return "Title cannot be empty";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      ImageUploadPickerWidget(
                        controller: thumbCtrl,
                        labelText: "Lecture Thumbnail",
                        hintText: "https://.../thumbnail.jpg",
                        helperText: "Appears on recordings list and student dashboard",
                        isCompact: true,
                        enabled: !isSaving,
                        onUpload: (fileName, bytes) async {
                          return await courseProvider.uploadLessonThumbnail(
                            batchId: currentClass.batchId,
                            fileName: fileName,
                            fileBytes: bytes,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                key: const Key('live_save_lecture_details_btn'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                icon: isSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save, size: 16),
                label: Text(isSaving ? "Saving..." : "Save Changes"),
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() {
                          isSaving = true;
                          localError = null;
                        });
                        try {
                          final newTitle = titleCtrl.text.trim();
                          final newUrl = thumbCtrl.text.trim();

                          final rec = liveProvider.recordings.where(
                            (r) => r.liveClassId == currentClass.id ||
                                   r.id == currentClass.id ||
                                   (currentClass.cloudflareVideoUid != null &&
                                    r.videoUid == currentClass.cloudflareVideoUid),
                          ).firstOrNull;

                          if (rec != null) {
                            await liveProvider.updateRecordingDetails(
                              recordingId: rec.id,
                              title: newTitle,
                              thumbnailUrl: newUrl.isEmpty ? null : newUrl,
                            );
                          } else {
                            await liveProvider.updateRecordingDetails(
                              recordingId: currentClass.id,
                              title: newTitle,
                              thumbnailUrl: newUrl.isEmpty ? null : newUrl,
                            );
                          }

                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Lecture details updated successfully!'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                            setState(() {});
                          }
                        } catch (e) {
                          setDialogState(() {
                            isSaving = false;
                            localError = e.toString();
                          });
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
    }

  Future<void> _confirmDeleteCurrentLecture(
    LiveClassModel currentClass,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => ConfirmDeleteLectureDialog(
        lectureTitle: currentClass.title,
        batchName: currentClass.batchName,
        textFieldKey: 'confirm_live_delete_text_field',
        confirmButtonKey: 'confirm_live_delete_lecture_btn',
      ),
    );

    if (confirmed == true && mounted) {
      _isDeleted = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        final courseProvider = context.read<CourseProvider>();
        final liveProvider = context.read<LiveClassProvider>();

        // 1. Check if it matches a prerecorded course lesson
        final lesson = courseProvider.videoLessons
            .cast<VideoLessonModel?>()
            .firstWhere((l) => l?.id == currentClass.id, orElse: () => null);

        if (lesson != null) {
          await courseProvider.deleteLesson(
            lesson.id,
            videoPath: lesson.videoUrl,
            thumbnailPath: lesson.thumbnailUrl,
          );
        } else {
          // 2. Check if it matches a lecture recording
          final rec = liveProvider.recordings.cast<LectureRecordingModel?>().firstWhere(
                (r) =>
                    r?.liveClassId == currentClass.id ||
                    r?.id == currentClass.id ||
                    (currentClass.cloudflareVideoUid != null &&
                        r?.videoUid == currentClass.cloudflareVideoUid),
                orElse: () => null,
              );
          if (rec != null) {
            await liveProvider.deleteRecording(rec.id);
          } else {
            // Attempt both fallback cleanups
            try {
              await courseProvider.deleteLesson(
                currentClass.id,
                videoPath: currentClass.recordingUrl ?? currentClass.streamUrl,
                thumbnailPath: currentClass.thumbnailUrl,
              );
            } catch (_) {}
            try {
              await liveProvider.deleteRecording(currentClass.id);
            } catch (_) {}
          }
        }

        courseProvider.removeRecentPlayback(currentClass.id);

        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lecture "${currentClass.title}" deleted successfully.'),
              backgroundColor: AppColors.success,
            ),
          );

          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete lecture: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final liveProvider = context.watch<LiveClassProvider>();
    final auth = context.watch<AuthProvider>();

    final currentClass =
        liveProvider.getLiveClassById(widget.liveClass.id) ?? widget.liveClass;
    final isLiveNow = currentClass.status == LiveStatus.live;
    final isRecorded = currentClass.status == LiveStatus.ended ||
        currentClass.recordingStatus == 'ready' ||
        widget.liveClass.recordingStatus == 'ready';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final isSmallDevice = MediaQuery.sizeOf(context).height < 700;
    final isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;

    // Fullscreen View
    if (_isFullscreen) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && _isFullscreen) {
            _toggleFullscreen();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          resizeToAvoidBottomInset: true,
          body: SizedBox.expand(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: _buildVideoSurface(currentClass, isLiveNow),
                ),
                if (_isBuffering)
                  const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                _buildControlsOverlay(
                  currentClass: currentClass,
                  isLiveNow: isLiveNow,
                  isRecorded: isRecorded,
                  isFullscreen: true,
                ),
                if (isLiveNow && _showLandscapeChat)
                  Positioned(
                    top: 0,
                    bottom: 0,
                    right: 0,
                    width: MediaQuery.sizeOf(context).width > 700 ? 340 : 280,
                    child: _buildFullscreenChatOverlay(
                      currentClass: currentClass,
                      isDark: isDark,
                      liveProvider: liveProvider,
                      auth: auth,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    // Portrait / Regular Screen View
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              currentClass.title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              "${currentClass.subject} • ${currentClass.teacherName}",
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          if (isLiveNow)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: CustomBadge(
                text: "${currentClass.activeViewersCount} Watching",
                variant: BadgeVariant.error,
                isLivePulse: true,
              ),
            ),
          if (isRecorded) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: CustomBadge(
                text: "Recorded Lecture",
                variant: BadgeVariant.success,
              ),
            ),
                        if (auth.currentUser.role == UserRole.teacher ||
                auth.currentUser.role == UserRole.admin) ...[
              IconButton(
                key: const Key('live_edit_lecture_action'),
                icon: const Icon(Icons.edit_outlined),
                tooltip: "Edit Lecture Details",
                onPressed: () => _showEditLectureDialog(context, currentClass),
              ),
              IconButton(
                key: const Key('live_delete_lecture_action'),
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                tooltip: "Delete Lecture",
                onPressed: () => _confirmDeleteCurrentLecture(currentClass),
              ),
            ],
          ],
          if (isLiveNow &&
              (auth.currentUser.role == UserRole.teacher ||
                  auth.currentUser.role == UserRole.admin))
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                icon: const Icon(
                  Icons.stop_circle_outlined,
                  color: AppColors.error,
                  size: 18,
                ),
                label: const Text(
                  "End Live",
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("End Live Class?"),
                      content: const Text(
                        "This will end the broadcast for all students and mark the session completed.",
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
                          child: const Text("End Class Now"),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await liveProvider.endLiveClass(currentClass.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Live class ended."),
                          backgroundColor: AppColors.emerald,
                        ),
                      );
                      Navigator.pop(context);
                    }
                  }
                },
              ),
            ),
        ],
      ),
      body: (isLandscape && !isRecorded)
          ? Row(
              children: [
                Expanded(
                  flex: 6,
                  child: Container(
                    color: Colors.black,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _buildVideoSurface(currentClass, isLiveNow),
                        if (_isBuffering)
                          const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          ),
                        _buildControlsOverlay(
                          currentClass: currentClass,
                          isLiveNow: isLiveNow,
                          isRecorded: isRecorded,
                          isFullscreen: false,
                        ),
                      ],
                    ),
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                ),
                Expanded(
                  flex: 4,
                  child: _buildLiveClassroomContent(
                    currentClass,
                    isDark,
                    liveProvider,
                    auth,
                    isKeyboardOpen: isKeyboardOpen,
                    isSideBySide: true,
                  ),
                ),
              ],
            )
          : Column(
              children: [
                // Video Player Container (Responsive height in portrait to avoid keyboard overflow on small devices)
                Container(
                  width: double.infinity,
                  height: (isKeyboardOpen && isSmallDevice) ? 110.0 : 230.0,
                  color: Colors.black,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _buildVideoSurface(currentClass, isLiveNow),
                      if (_isBuffering)
                        const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      _buildControlsOverlay(
                        currentClass: currentClass,
                        isLiveNow: isLiveNow,
                        isRecorded: isRecorded,
                        isFullscreen: false,
                        isCompact: (isKeyboardOpen && isSmallDevice),
                      ),
                    ],
                  ),
                ),

                // Content below video: Differentiated between Recorded vs Live
                Expanded(
                  child: isRecorded
                      ? _buildRecordedLectureContent(currentClass, isDark, auth)
                      : _buildLiveClassroomContent(
                          currentClass,
                          isDark,
                          liveProvider,
                          auth,
                          isKeyboardOpen: isKeyboardOpen,
                        ),
                ),
              ],
            ),
    );
  }

  /// Builds the video surface (VideoPlayer, Thumbnail Poster, or Error State)
  Widget _buildVideoSurface(LiveClassModel currentClass, bool isLiveNow) {
    if (_videoPlayerController != null && _isVideoInitialized) {
      return Center(
        child: AspectRatio(
          aspectRatio: _videoPlayerController!.value.aspectRatio > 0
              ? _videoPlayerController!.value.aspectRatio
              : (16 / 9),
          child: VideoPlayer(_videoPlayerController!),
        ),
      );
    }

    if (_isProcessingVideo) {
      return Center(
        child: Container(
          color: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Optimizing Lecture Video...",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "This video was recently uploaded and is being prepared for high-quality streaming.\nIt will begin playing automatically in a few seconds.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 14),
              Text(
                "Attempt $_processingRetryCount of $_maxProcessingRetries",
                style: TextStyle(
                  color: AppColors.primary.withValues(alpha: 0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isVideoError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isLiveNow ? Icons.sensors_off_rounded : Icons.error_outline_rounded,
                color: isLiveNow ? AppColors.warning : AppColors.error,
                size: 36,
              ),
              const SizedBox(height: 8),
              Text(
                isLiveNow ? "Faculty Not Broadcasting Yet" : "Playback Unavailable",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isLiveNow
                    ? "The faculty member has not started broadcasting live video yet or has ended the session. Live video will begin automatically when the teacher goes live."
                    : (_videoErrorMessage ??
                        "Could not load recording stream. Please check connection."),
                style: const TextStyle(color: Colors.white70, fontSize: 11),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  _processingRetryCount = 0;
                  final url = _resolvePlaybackUrl(currentClass);
                  _initializePlayer(url, isRetry: true);
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(isLiveNow ? "Check Live Stream" : "Retry Playback"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Loading / Poster Surface
    return Stack(
      children: [
        if (currentClass.thumbnailUrl != null &&
            currentClass.thumbnailUrl!.isNotEmpty)
          Positioned.fill(
            child: Image.network(
              currentClass.thumbnailUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  (currentClass.thumbnailUrl != null &&
                          currentClass.thumbnailUrl!.isNotEmpty)
                      ? Colors.black.withValues(alpha: 0.65)
                      : const Color(0xFF0F172A),
                  (currentClass.thumbnailUrl != null &&
                          currentClass.thumbnailUrl!.isNotEmpty)
                      ? Colors.black.withValues(alpha: 0.85)
                      : const Color(0xFF050B14),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isLiveNow
                    ? "CONNECTING TO LIVE STREAM..."
                    : "LOADING RECORDED LECTURE...",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Modern Classes Patna • Cloudflare Stream",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds interactive controls overlay
  Widget _buildControlsOverlay({
    required LiveClassModel currentClass,
    required bool isLiveNow,
    required bool isRecorded,
    required bool isFullscreen,
    bool isCompact = false,
  }) {
    if (isCompact) {
      return Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleControlsVisibility,
          child: AnimatedOpacity(
            opacity: _controlsVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: IgnorePointer(
              ignoring: !_controlsVisible,
              child: Container(
                color: Colors.black.withValues(alpha: 0.6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(
                        _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: _togglePlayPause,
                    ),
                    if (isLiveNow)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.error),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.fiber_manual_record, color: AppColors.error, size: 8),
                            SizedBox(width: 4),
                            Text("LIVE", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 24),
                      onPressed: _toggleFullscreen,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControlsVisibility,
        child: AnimatedOpacity(
          opacity: _controlsVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 250),
          child: IgnorePointer(
            ignoring: !_controlsVisible,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.85),
                  ],
                  stops: const [0.0, 0.25, 0.7, 1.0],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Overlay Bar (especially useful in fullscreen)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isFullscreen ? 16 : 8,
                      vertical: isFullscreen ? 14 : 6,
                    ),
                    child: Row(
                      children: [
                        if (isFullscreen) ...[
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                            tooltip: "Exit Fullscreen",
                            onPressed: _toggleFullscreen,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              currentClass.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ] else ...[
                          const Spacer(),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isLiveNow
                                ? "LIVE"
                                : (_formatDuration(_totalDuration).isNotEmpty
                                      ? "HD RECORDING"
                                      : "HD"),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Center Controls: Quick replay, Play/Pause, Quick forward
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.replay_10_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                        tooltip: "Rewind 10s",
                        onPressed: () =>
                            _seekRelative(const Duration(seconds: -10)),
                      ),
                      const SizedBox(width: 24),
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.9),
                        ),
                        child: IconButton(
                          icon: Icon(
                            _isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.black,
                            size: 38,
                          ),
                          tooltip: _isPlaying ? "Pause" : "Play",
                          onPressed: _togglePlayPause,
                        ),
                      ),
                      const SizedBox(width: 24),
                      IconButton(
                        icon: const Icon(
                          Icons.forward_10_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                        tooltip: "Forward 10s",
                        onPressed: () =>
                            _seekRelative(const Duration(seconds: 10)),
                      ),
                    ],
                  ),

                  // Bottom Overlay Bar: Play/Pause, Scrubber, Time, Mute, Speed, Fullscreen
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isFullscreen ? 16 : 8,
                      vertical: 6,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Scrubber Slider: YouTube-style DVR Live Bar for active broadcasts, seekable slider for recordings
                        if (isLiveNow)
                          Builder(
                            builder: (context) {
                              final effectiveLiveTotal = _calculateEffectiveLiveDuration(currentClass);
                              final liveTotalMs = math.max(1000, effectiveLiveTotal.inMilliseconds);
                              final currentMs = _isSeeking
                                  ? (_seekSliderValue * liveTotalMs).round().clamp(0, liveTotalMs)
                                  : _currentPosition.inMilliseconds.clamp(0, liveTotalMs);
                              final currentPosDuration = Duration(milliseconds: currentMs);
                              final diffFromLiveEdge = Duration(milliseconds: liveTotalMs - currentMs);
                              final isAtLiveEdge = diffFromLiveEdge.inSeconds <= 6;
                              final bufferedFraction = _getBufferedFraction(effectiveLiveTotal);
                              final playedFraction = (currentMs / liveTotalMs).clamp(0.0, 1.0);

                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isSeeking)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 2),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.black87,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.white24, width: 0.8),
                                        ),
                                        child: Text(
                                          isAtLiveEdge
                                              ? "LIVE (Current Broadcast)"
                                              : "${_formatDuration(currentPosDuration)} (-${_formatDuration(diffFromLiveEdge)} from live)",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  Row(
                                    children: [
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 28,
                                          minHeight: 28,
                                        ),
                                        icon: const Icon(
                                          Icons.skip_previous_rounded,
                                          color: Colors.white70,
                                          size: 20,
                                        ),
                                        tooltip: "Watch from Start (00:00)",
                                        onPressed: () {
                                          _videoPlayerController?.seekTo(Duration.zero);
                                          setState(() {
                                            _currentPosition = Duration.zero;
                                            _isSeeking = false;
                                          });
                                        },
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        _formatDuration(currentPosDuration),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Expanded(
                                        child: LayoutBuilder(
                                          builder: (context, trackConstraints) {
                                            final w = trackConstraints.maxWidth;
                                            return Stack(
                                              alignment: Alignment.centerLeft,
                                              children: [
                                                // 1. Dark Inactive Base Line
                                                Container(
                                                  width: w,
                                                  height: 3.5,
                                                  margin: const EdgeInsets.symmetric(horizontal: 12),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white24,
                                                    borderRadius: BorderRadius.circular(2),
                                                  ),
                                                ),
                                                // 2. Buffered Range Line
                                                Container(
                                                  width: (w - 24) * bufferedFraction,
                                                  height: 3.5,
                                                  margin: const EdgeInsets.only(left: 12),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white54,
                                                    borderRadius: BorderRadius.circular(2),
                                                  ),
                                                ),
                                                // 3. Played Media Line (YouTube Red)
                                                Container(
                                                  width: (w - 24) * playedFraction,
                                                  height: 3.5,
                                                  margin: const EdgeInsets.only(left: 12),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFFF0000),
                                                    borderRadius: BorderRadius.circular(2),
                                                  ),
                                                ),
                                                // 4. Native Slider
                                                SliderTheme(
                                                  data: SliderTheme.of(context).copyWith(
                                                    thumbShape: RoundSliderThumbShape(
                                                      enabledThumbRadius: _isSeeking ? 7.0 : 5.5,
                                                      elevation: 2,
                                                    ),
                                                    overlayShape: const RoundSliderOverlayShape(
                                                      overlayRadius: 14,
                                                    ),
                                                    trackHeight: 3.5,
                                                    activeTrackColor: Colors.transparent,
                                                    inactiveTrackColor: Colors.transparent,
                                                    thumbColor: const Color(0xFFFF0000),
                                                  ),
                                                  child: Slider(
                                                    value: playedFraction,
                                                    onChanged: (val) {
                                                      setState(() {
                                                        _isSeeking = true;
                                                        _seekSliderValue = val;
                                                      });
                                                    },
                                                    onChangeEnd: (val) {
                                                      final targetMs = (val * liveTotalMs).round();
                                                      final target = Duration(milliseconds: targetMs);
                                                      _videoPlayerController?.seekTo(target);
                                                      setState(() {
                                                        _isSeeking = false;
                                                        _currentPosition = target;
                                                      });
                                                      _startControlsTimer();
                                                    },
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      InkWell(
                                        key: const Key('youtube_live_badge_button'),
                                        onTap: () => _jumpToLiveEdge(effectiveLiveTotal),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isAtLiveEdge
                                                ? const Color(0xFFFF0000).withValues(alpha: 0.25)
                                                : Colors.black54,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isAtLiveEdge
                                                  ? const Color(0xFFFF0000)
                                                  : Colors.white38,
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 7,
                                                height: 7,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: isAtLiveEdge
                                                      ? const Color(0xFFFF0000)
                                                      : Colors.white60,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                isAtLiveEdge
                                                    ? "LIVE"
                                                    : "LIVE -${_formatDuration(diffFromLiveEdge)}",
                                                style: TextStyle(
                                                  color: isAtLiveEdge
                                                      ? Colors.white
                                                      : Colors.white70,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          )
                        else if (_totalDuration.inMilliseconds > 0)
                          Row(
                            children: [
                              Text(
                                _formatDuration(
                                  _isSeeking
                                      ? Duration(
                                          milliseconds: (_seekSliderValue *
                                                  _totalDuration.inMilliseconds)
                                              .round(),
                                        )
                                      : (_currentPosition.isNegative ? Duration.zero : _currentPosition),
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 6,
                                    ),
                                    overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 14,
                                    ),
                                    trackHeight: 3,
                                    activeTrackColor: AppColors.primary,
                                    inactiveTrackColor: Colors.white24,
                                    thumbColor: AppColors.primary,
                                  ),
                                  child: Slider(
                                    value: (_totalDuration.inMilliseconds > 0)
                                        ? (_isSeeking
                                            ? _seekSliderValue
                                            : ((_currentPosition.isNegative ? 0.0 : _currentPosition.inMilliseconds.toDouble()) /
                                                    _totalDuration
                                                        .inMilliseconds)
                                                .clamp(0.0, 1.0))
                                        : 0.0,
                                    onChanged: (val) {
                                      setState(() {
                                        _isSeeking = true;
                                        _seekSliderValue = val;
                                      });
                                    },
                                    onChangeEnd: (val) {
                                      final target = Duration(
                                        milliseconds: (val *
                                                _totalDuration.inMilliseconds)
                                            .round(),
                                      );
                                      _videoPlayerController?.seekTo(target);
                                      setState(() {
                                        _isSeeking = false;
                                        _currentPosition = target;
                                      });
                                      _startControlsTimer();
                                    },
                                  ),
                                ),
                              ),
                              Text(
                                _formatDuration(_totalDuration),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),

                        // Action Row
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                _isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                                size: 20,
                              ),
                              tooltip: _isPlaying ? "Pause" : "Play",
                              onPressed: _togglePlayPause,
                            ),
                            IconButton(
                              icon: Icon(
                                _isMuted ? Icons.volume_off : Icons.volume_up,
                                color: Colors.white,
                                size: 20,
                              ),
                              tooltip: _isMuted ? "Unmute" : "Mute",
                              onPressed: _toggleMute,
                            ),
                            if (isLiveNow) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                key: const Key('live_chat_toggle_button'),
                                icon: Icon(
                                  _showLandscapeChat
                                      ? Icons.chat_rounded
                                      : Icons.chat_bubble_outline_rounded,
                                  color: _showLandscapeChat
                                      ? AppColors.primary
                                      : Colors.white,
                                  size: 20,
                                ),
                                tooltip: _showLandscapeChat
                                    ? "Hide Chat"
                                    : "Show Chat",
                                onPressed: () {
                                  setState(() {
                                    _showLandscapeChat = !_showLandscapeChat;
                                  });
                                },
                              ),
                            ],
                            const Spacer(),

                            // Speed Selector
                            PopupMenuButton<double>(
                              tooltip: "Playback Speed",
                              color: AppTheme.surfaceLight,
                              onSelected: _setPlaybackSpeed,
                              itemBuilder: (context) =>
                                  [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
                                      .map(
                                        (s) => PopupMenuItem(
                                          value: s,
                                          child: Text(
                                            "${s}x",
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white12,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  "${_playbackSpeed}x",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Fullscreen Toggle
                            IconButton(
                              icon: Icon(
                                isFullscreen
                                    ? Icons.fullscreen_exit_rounded
                                    : Icons.fullscreen_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                              tooltip: isFullscreen
                                  ? "Exit Fullscreen"
                                  : "Enter Fullscreen",
                              onPressed: _toggleFullscreen,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Recorded Lecture UI: Academic details, notes, and doubt button.
  /// Strictly removes live classroom chat, live doubts stream, and raise hand.
  Widget _buildRecordedLectureContent(
    LiveClassModel currentClass,
    bool isDark,
    AuthProvider auth,
  ) {
    final isStudent = auth.currentUser.role == UserRole.student;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Faculty & Batch Summary Header
        ModernCard(
          padding: const EdgeInsets.all(16),
          backgroundColor: isDark
              ? AppColors.darkSurfaceCard
              : AppColors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.primary,
                    child: Text(
                      currentClass.teacherName.isNotEmpty
                          ? currentClass.teacherName.substring(0, 1)
                          : "T",
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentClass.title,
                          style: AppTypography.titleMedium.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.deepInk,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Faculty: ${currentClass.teacherName} • ${currentClass.subject}",
                          style: AppTypography.bodySmall.copyWith(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  CustomBadge(
                    text: currentClass.batchName,
                    variant: BadgeVariant.primary,
                  ),
                  CustomBadge(
                    text: currentClass.courseName,
                    variant: BadgeVariant.secondary,
                  ),
                  CustomBadge(
                    text: "Recorded Lecture",
                    variant: BadgeVariant.success,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Broadcast Archive Details Card
        ModernCard(
          padding: const EdgeInsets.all(16),
          backgroundColor: isDark
              ? AppColors.darkSurfaceCard
              : AppColors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.history_edu_rounded,
                    color: isDark ? AppColors.primary : AppColors.saffronDark,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Lecture Information",
                    style: AppTypography.subtitle2.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.deepInk,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildMetaRow(
                icon: Icons.calendar_today_rounded,
                label: "Broadcast Date",
                value: Formatters.formatDateTime(
                  currentClass.scheduledStartTime,
                ),
                isDark: isDark,
              ),
              const SizedBox(height: 8),
              _buildMetaRow(
                icon: Icons.timer_outlined,
                label: "Duration",
                value: _totalDuration.inSeconds > 0
                    ? _formatDuration(_totalDuration)
                    : (currentClass.effectiveDuration.inSeconds > 0
                          ? _formatDuration(currentClass.effectiveDuration)
                          : "Full Session"),
                isDark: isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),



        // Asynchronous Academic Doubts Section
        ModernCard(
          padding: const EdgeInsets.all(16),
          backgroundColor: isDark
              ? AppColors.darkSurfaceCard
              : AppColors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.help_outline_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Academic Doubts",
                    style: AppTypography.subtitle2.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.deepInk,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isStudent
                    ? "Have a doubt about this recorded lecture? Submit your question directly to faculty. Your instructor will review and provide a detailed explanation."
                    : "Faculty Review Mode: This recording is archived for enrolled students. Students can submit academic doubts via the Doubts Hub.",
                style: AppTypography.bodySmall.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              if (isStudent) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? AppColors.primary
                          : AppColors.saffronDark,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.quiz_outlined, size: 18),
                    label: const Text(
                      "Ask Doubt to Faculty",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => const AskDoubtDialog(),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetaRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 15,
          color: isDark
              ? AppColors.darkTextSecondary
              : AppColors.textSecondary,
        ),
        const SizedBox(width: 8),
        Text(
          "$label: ",
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTypography.caption.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Fullscreen live chat overlay drawer on the right side of the screen
  Widget _buildFullscreenChatOverlay({
    required LiveClassModel currentClass,
    required bool isDark,
    required LiveClassProvider liveProvider,
    required AuthProvider auth,
  }) {
    final providerMessages = liveProvider.getChatMessagesForClass(widget.liveClass.id);
    final chatMessages = providerMessages.isNotEmpty
        ? providerMessages
        : (currentClass.chatMessages.isNotEmpty
            ? currentClass.chatMessages
            : widget.liveClass.chatMessages);

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        border: const Border(
          left: BorderSide(color: Colors.white24, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.black54,
              border: Border(
                bottom: BorderSide(color: Colors.white12, width: 1),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: AppColors.primary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "Live Chat",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "${chatMessages.length}",
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                  tooltip: "Hide Chat",
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    setState(() {
                      _showLandscapeChat = false;
                    });
                  },
                ),
              ],
            ),
          ),

          // Messages List
          Expanded(
            child: ListView.builder(
              controller: _fullscreenScrollController,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              itemCount: chatMessages.length,
              itemBuilder: (context, index) {
                final msg = chatMessages[index];
                final isTeacher = msg.senderRole.toUpperCase() == "TEACHER";
                final isMe = msg.senderName == auth.currentUser.name;

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: msg.isPinned
                        ? AppColors.primary.withValues(alpha: 0.2)
                        : (isTeacher
                            ? AppColors.secondary.withValues(alpha: 0.25)
                            : Colors.white.withValues(alpha: 0.08)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: msg.isPinned
                          ? AppColors.primary.withValues(alpha: 0.5)
                          : (isTeacher
                              ? AppColors.secondary.withValues(alpha: 0.4)
                              : Colors.white12),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              msg.senderName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isTeacher
                                    ? AppColors.secondaryLight
                                    : (isMe ? AppColors.primary : Colors.white),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          if (isTeacher) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.secondary,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                "TEACHER",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 4),
                          Text(
                            Formatters.formatTime(msg.timestamp),
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        msg.text,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Input field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: const BoxDecoration(
              color: Colors.black87,
              border: Border(
                top: BorderSide(color: Colors.white12, width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Type chat or doubt...",
                      hintStyle: const TextStyle(color: Colors.white54, fontSize: 11),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      isDense: true,
                      fillColor: Colors.white12,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) {
                      _sendMessage(liveProvider, auth);
                    },
                  ),
                ),
                const SizedBox(width: 4),
                IconButton.filled(
                  icon: const Icon(Icons.send_rounded, size: 16),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.all(8),
                    minimumSize: const Size(32, 32),
                  ),
                  onPressed: () {
                    _sendMessage(liveProvider, auth);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Live Classroom UI: Interactive real-time chat, active viewer count, and raise hand.
  Widget _buildLiveClassroomContent(
    LiveClassModel currentClass,
    bool isDark,
    LiveClassProvider liveProvider,
    AuthProvider auth, {
    bool isKeyboardOpen = false,
    bool isSideBySide = false,
  }) {
    final providerMessages = liveProvider.getChatMessagesForClass(widget.liveClass.id);
    final chatMessages = providerMessages.isNotEmpty
        ? providerMessages
        : (currentClass.chatMessages.isNotEmpty
            ? currentClass.chatMessages
            : widget.liveClass.chatMessages);

    return Column(
      children: [
        if (!isKeyboardOpen && !isSideBySide) ...[
          // Live Header Information Banner (Portrait)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: isDark ? AppColors.darkSurface : AppColors.surface,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.primary,
                  child: Text(
                    currentClass.teacherName.isNotEmpty
                        ? currentClass.teacherName.substring(0, 1)
                        : "T",
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentClass.teacherName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.deepInk,
                        ),
                      ),
                      Text(
                        currentClass.batchName,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isHandRaised = !_isHandRaised;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _isHandRaised
                              ? "✋ Hand raised! Teacher has been notified for doubts."
                              : "Hand lowered.",
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: Icon(
                    _isHandRaised ? Icons.back_hand : Icons.back_hand_outlined,
                    size: 15,
                  ),
                  label: Text(_isHandRaised ? "Raised" : "Raise Hand"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isHandRaised
                        ? AppTheme.warning
                        : (isDark
                              ? AppColors.darkSurfaceCard
                              : AppTheme.surfaceElevated),
                    foregroundColor: _isHandRaised
                        ? Colors.black
                        : (isDark ? AppColors.darkTextPrimary : Colors.white),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: const Size(0, 32),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
        ] else if (isSideBySide && !isKeyboardOpen) ...[
          // Compact Header for 2-column landscape mode
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: isDark ? AppColors.darkSurface : AppColors.surface,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppTheme.primary,
                  child: Text(
                    currentClass.teacherName.isNotEmpty
                        ? currentClass.teacherName.substring(0, 1)
                        : "T",
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "${currentClass.teacherName} • ${currentClass.batchName}",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                IconButton(
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    _isHandRaised ? Icons.back_hand : Icons.back_hand_outlined,
                    size: 16,
                    color: _isHandRaised
                        ? AppColors.warning
                        : (isDark ? Colors.white70 : Colors.black54),
                  ),
                  tooltip: _isHandRaised ? "Lower Hand" : "Raise Hand",
                  onPressed: () {
                    setState(() => _isHandRaised = !_isHandRaised);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _isHandRaised
                              ? "✋ Hand raised! Teacher has been notified for doubts."
                              : "Hand lowered.",
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
        ],

        // Live Chat Stream
        Expanded(
          child: Container(
            color: isDark ? AppColors.darkBackground : AppColors.background,
            child: Column(
              children: [
                // Live Chat Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  color: isDark
                      ? AppColors.darkSurface
                      : AppColors.surfaceSubtle,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline,
                        size: 15,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "Live Classroom Chat & Doubts",
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.deepInk,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "${chatMessages.length} msgs",
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),

                // Chat Message List
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: chatMessages.length,
                    itemBuilder: (context, index) {
                      final msg = chatMessages[index];
                      final isTeacher =
                          msg.senderRole.toUpperCase() == "TEACHER";
                      final isMe = msg.senderName == auth.currentUser.name;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: msg.isPinned
                              ? AppTheme.primary.withValues(alpha: 0.15)
                              : isTeacher
                              ? AppTheme.secondary.withValues(alpha: 0.12)
                              : (isDark
                                    ? AppColors.darkSurfaceCard
                                    : AppColors.surface),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: msg.isPinned
                                ? AppTheme.primary.withValues(alpha: 0.4)
                                : isTeacher
                                ? AppTheme.secondary.withValues(alpha: 0.3)
                                : (isDark
                                      ? AppColors.darkBorder
                                      : AppColors.border),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (msg.isPinned) ...[
                                  const Icon(
                                    Icons.push_pin,
                                    size: 12,
                                    color: AppTheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Expanded(
                                  child: Text(
                                    msg.senderName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isTeacher
                                          ? AppTheme.secondaryLight
                                          : isMe
                                          ? AppTheme.primary
                                          : (isDark
                                                ? AppColors.darkTextPrimary
                                                : AppColors.deepInk),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                                if (isTeacher) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.secondary,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      "TEACHER",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 6),
                                Text(
                                  Formatters.formatTime(msg.timestamp),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              msg.text,
                              style: TextStyle(
                                fontSize: 13,
                                color: (isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.deepInk),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Chat Input Bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.surface,
                    border: Border(
                      top: BorderSide(
                        color: isDark ? AppColors.darkBorder : AppColors.border,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatController,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: "Ask a doubt or send a message...",
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              isDense: true,
                              fillColor: isDark
                                  ? AppColors.darkSurfaceCard
                                  : AppColors.surfaceSubtle,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: (_) =>
                                _sendMessage(liveProvider, auth),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          icon: const Icon(Icons.send_rounded, size: 18),
                          style: IconButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.black,
                          ),
                          onPressed: () => _sendMessage(liveProvider, auth),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
