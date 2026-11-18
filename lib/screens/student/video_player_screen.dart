import 'dart:async';
import 'package:flutter/material.dart';
import '../../widgets/confirm_delete_lecture_dialog.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/image_upload_picker_widget.dart';
import '../../core/widgets/modern_card.dart';
import '../../models/course_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/live_class_provider.dart';

class VideoPlayerScreen extends StatefulWidget {
  final VideoLessonModel lesson;
  final CourseModel course;

  const VideoPlayerScreen({
    super.key,
    required this.lesson,
    required this.course,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  bool _isPlaying = false;
  double _currentPositionSeconds = 0.0;
  double _actualWatchedSeconds = 0.0;
  double _playbackSpeed = 1.0;
  bool _isCompleted = false;
  bool _hasAutoMarkedAttendance = false;
  bool _isFullscreen = false;
  Timer? _playbackTimer;
  bool _controlsVisible = true;
  Timer? _controlsTimer;
  VideoPlayerController? _videoController;
  double _lastObservedPositionSeconds = 0.0;

  String? _resolvedStreamUrl;
  bool _isLoadingStreamUrl = false;
  String? _streamUrlError;
  VideoLessonModel? _currentLesson;

  @override
  void initState() {
    super.initState();
    _currentLesson = widget.lesson;
    _isCompleted = widget.lesson.isCompleted;
    final totalSec = widget.lesson.duration.inSeconds;
    if (totalSec > 0 && widget.lesson.progressPercent > 0) {
      _currentPositionSeconds =
          (totalSec * widget.lesson.progressPercent).clamp(0, totalSec.toDouble());
    }
    if (widget.lesson.progressPercent >= 0.75) {
      _hasAutoMarkedAttendance = true;
      _actualWatchedSeconds = totalSec * widget.lesson.progressPercent;
    }
    _resolveStreamUrl();
    _startPlaybackTimer();
    _startControlsTimer();
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _controlsTimer?.cancel();
    _videoController?.removeListener(_handleVideoValueChanged);
    _videoController?.dispose();
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
    _controlsTimer = Timer(const Duration(seconds: 3), () {
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

  void _togglePlayPause() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    setState(() {
      _isPlaying = !_isPlaying;
      if (!_isPlaying) {
        _controlsVisible = true;
        _controlsTimer?.cancel();
      } else {
        _startControlsTimer();
      }
    });
    if (_isPlaying) {
      controller.play();
    } else {
      controller.pause();
    }
  }

  void _startPlaybackTimer() {
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPlaying || !mounted) return;
      final controller = _videoController;
      if (controller == null || !controller.value.isInitialized) return;
      final totalSec = controller.value.duration.inSeconds;
      if (totalSec <= 0) return;

      final positionSeconds = controller.value.position.inMilliseconds / 1000.0;
      final elapsed = positionSeconds - _lastObservedPositionSeconds;
      _lastObservedPositionSeconds = positionSeconds;
      if (elapsed <= 0) return;

      setState(() {
        _currentPositionSeconds = positionSeconds.clamp(0, totalSec.toDouble());
        _actualWatchedSeconds =
            (_actualWatchedSeconds + elapsed).clamp(0, totalSec.toDouble());
      });

      final watchProgress = _currentPositionSeconds / totalSec;
      final actualProgress = _actualWatchedSeconds / totalSec;
      final isFinished = (watchProgress >= 0.95 && actualProgress >= 0.75) ||
          _actualWatchedSeconds >= totalSec * 0.95;

      context.read<CourseProvider>().updateLessonProgress(
        widget.lesson.id,
        watchProgress,
        _isCompleted || isFinished,
      );

      // ONLY trigger attendance when genuine actual watched time reaches 75%
      if (actualProgress >= 0.75 && !_hasAutoMarkedAttendance) {
        _triggerAutoAttendance(actualProgress);
      }

      if (_currentPositionSeconds >= totalSec) {
        setState(() {
          _isPlaying = false;
          _isCompleted = actualProgress >= 0.75;
        });
      }
    });
  }

  Future<void> _triggerAutoAttendance(double watchProgress) async {
    _hasAutoMarkedAttendance = true;
    try {
      final auth = context.read<AuthProvider>();
      final attendance = context.read<AttendanceProvider>();
      final marked = await attendance.logLectureAttendanceAuto(
        batchId: widget.lesson.batchId,
        batchName: widget.course.title,
        studentId: auth.currentUser.id,
        studentName: auth.currentUser.name,
        lessonTitle: widget.lesson.title,
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
                    "🎯 Attendance Auto-Logged: 75% of '${widget.lesson.title}' completed!",
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
    } catch (e) {
      debugPrint("Error auto-logging attendance: $e");
    }
  }

  Future<void> _resolveStreamUrl() async {
    final rawUrl = widget.lesson.videoUrl;
    if (rawUrl.isEmpty) {
      if (mounted) setState(() => _streamUrlError = 'This lecture has no video URL.');
      return;
    }

    if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
      setState(() {
        _resolvedStreamUrl = rawUrl;
      });
      await _initializeVideoController(rawUrl);
      return;
    }

    setState(() {
      _isLoadingStreamUrl = true;
      _streamUrlError = null;
    });

    try {
      final courseProvider = context.read<CourseProvider>();
      final signedUrl = await courseProvider.getLessonSignedUrl(rawUrl);
      if (mounted) {
        setState(() {
          _resolvedStreamUrl = signedUrl;
          _isLoadingStreamUrl = false;
        });
        await _initializeVideoController(signedUrl);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _streamUrlError = e.toString();
          _isLoadingStreamUrl = false;
        });
      }
    }
  }

  Future<void> _initializeVideoController(String url) async {
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      if (mounted) {
        setState(() {
          _isLoadingStreamUrl = false;
          _streamUrlError = 'Invalid streaming URL format.';
          _isPlaying = false;
        });
      }
      return;
    }

    final previous = _videoController;
    previous?.removeListener(_handleVideoValueChanged);
    await previous?.dispose();

    VideoFormat? formatHint;
    final lower = url.toLowerCase();
    if (lower.contains('.m3u8') ||
        lower.contains('cloudflarestream.com') ||
        lower.contains('videodelivery.net')) {
      formatHint = VideoFormat.hls;
    } else if (lower.contains('.mp4')) {
      formatHint = VideoFormat.other;
    }

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      formatHint: formatHint,
    );
    _videoController = controller;
    try {
      await controller.initialize();
      await controller.setPlaybackSpeed(_playbackSpeed);
      controller.addListener(_handleVideoValueChanged);
      if (!mounted) return;
      setState(() {
        _isLoadingStreamUrl = false;
        _streamUrlError = null;
        _currentPositionSeconds = controller.value.position.inMilliseconds / 1000.0;
      });
      await controller.play();
      if (mounted) setState(() => _isPlaying = true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStreamUrl = false;
          _streamUrlError = 'Unable to play lecture: $e';
          _isPlaying = false;
        });
      }
    }
  }

  void _handleVideoValueChanged() {
    final controller = _videoController;
    if (!mounted || controller == null || !controller.value.isInitialized) return;
    if (controller.value.hasError) {
      setState(() => _streamUrlError = controller.value.errorDescription);
    }
  }

  void _navigateToLesson(VideoLessonModel l) {
    if (l.id == widget.lesson.id) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          lesson: l,
          course: widget.course,
        ),
      ),
    );
  }

  Future<void> _confirmDeleteLesson(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => ConfirmDeleteLectureDialog(
        lectureTitle: widget.lesson.title,
        textFieldKey: 'confirm_video_delete_text_field',
        confirmButtonKey: 'confirm_video_delete_lecture_btn',
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await context.read<CourseProvider>().deleteLesson(
              widget.lesson.id,
              videoPath: widget.lesson.videoUrl,
              thumbnailPath: widget.lesson.thumbnailUrl,
            );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Lecture "${widget.lesson.title}" deleted successfully.'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (context.mounted) {
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

  Future<void> _showEditThumbnailDialog(BuildContext context) async {
    await _showEditLectureDialog(context);
  }

  Future<void> _showEditLectureDialog(BuildContext context) async {
    final effectiveLesson = _currentLesson ?? widget.lesson;
    final titleCtrl = TextEditingController(text: effectiveLesson.title);
    final chapterCtrl = TextEditingController(text: effectiveLesson.chapter);
    final thumbCtrl =
        TextEditingController(text: effectiveLesson.thumbnailUrl ?? '');
    final formKey = GlobalKey<FormState>();
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
                        key: const Key('edit_lecture_title_input'),
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
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const Key('edit_lecture_chapter_input'),
                        controller: chapterCtrl,
                        decoration: InputDecoration(
                          labelText: "Chapter / Topic",
                          hintText: "e.g. Chapter 1: Introduction",
                          prefixIcon: const Icon(Icons.topic_outlined, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          isDense: true,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return "Chapter cannot be empty";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      ImageUploadPickerWidget(
                        controller: thumbCtrl,
                        labelText: "Lecture Thumbnail",
                        hintText: "https://.../thumbnail.jpg",
                        helperText: "Appears on playlist and curriculum",
                        isCompact: true,
                        enabled: !isSaving,
                        onUpload: (fileName, bytes) async {
                          return await courseProvider.uploadLessonThumbnail(
                            batchId: effectiveLesson.batchId,
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
                key: const Key('save_lecture_details_btn'),
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
                          final newChapter = chapterCtrl.text.trim();
                          final newUrl = thumbCtrl.text.trim();
                          final liveProv = context.read<LiveClassProvider>();

                          final updated = await courseProvider.updateLesson(
                            lessonId: effectiveLesson.id,
                            title: newTitle,
                            chapter: newChapter,
                            thumbnailUrl: newUrl.isEmpty ? null : newUrl,
                          );

                          // Also attempt to sync live_classes/lecture_recordings if matching
                          try {
                            final rec = liveProv.recordings.where(
                              (r) => r.title == effectiveLesson.title || r.id == effectiveLesson.id,
                            ).firstOrNull;
                            if (rec != null) {
                              await liveProv.updateRecordingDetails(
                                recordingId: rec.id,
                                title: newTitle,
                                thumbnailUrl: newUrl.isEmpty ? null : newUrl,
                              );
                            }
                          } catch (_) {}

                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Lecture details updated successfully!'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                            setState(() {
                              _currentLesson = updated;
                            });
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

  @override
  Widget build(BuildContext context) {
    final currentLesson = _currentLesson ?? widget.lesson;
    final courseProvider = context.watch<CourseProvider>();
    final allLessons = courseProvider.getLessonsForBatch(widget.lesson.batchId);
    final totalSeconds = _videoController?.value.isInitialized == true
      ? _videoController!.value.duration.inSeconds
      : widget.lesson.duration.inSeconds;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    bool canManage = false;
    try {
      final auth = context.watch<AuthProvider>();
      canManage = auth.isTeacher || auth.isAdmin;
    } catch (_) {}

    final videoCanvas = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleControlsVisibility,
      child: Container(
        width: double.infinity,
        height: _isFullscreen || isLandscape
            ? double.infinity
            : 230,
        color: Colors.black,
        child: Stack(
          children: [
            // Video Canvas
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF050B14)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_videoController?.value.isInitialized == true)
                    Center(
                      child: AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: VideoPlayer(_videoController!),
                      ),
                    ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedOpacity(
                          opacity: _controlsVisible ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 250),
                          child: IgnorePointer(
                            ignoring: !_controlsVisible,
                            child: InkWell(
                              key: const Key('video_center_play_button'),
                              onTap: _togglePlayPause,
                              child: Tooltip(
                                message: _resolvedStreamUrl != null
                                    ? "Secure Stream Active"
                                    : "Play / Pause",
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppTheme.primary.withValues(alpha: 0.25),
                                    border: Border.all(
                                      color: AppTheme.primary,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    _isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow_rounded,
                                    size: 42,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                      ],
                    ),
                  ),
                ],
              ),
            ),



          if (_isLoadingStreamUrl)
            const Positioned(
              top: 10,
              right: 10,
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white70,
                ),
              ),
            ),

          if (_streamUrlError != null)
            Positioned(
              top: 10,
              left: 10,
              right: 40,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _streamUrlError!,
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

          // Bottom Video Controls & Scrubber
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: _controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.9),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Scrubber Slider
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          trackHeight: 3,
                          activeTrackColor: AppTheme.primary,
                          inactiveTrackColor: Colors.white24,
                          thumbColor: AppTheme.primary,
                        ),
                        child: Slider(
                          value: _currentPositionSeconds.clamp(
                            0,
                            totalSeconds.toDouble(),
                          ),
                          max: totalSeconds > 0 ? totalSeconds.toDouble() : 1.0,
                          onChanged: (val) {
                            _videoController?.seekTo(
                              Duration(milliseconds: (val * 1000).round()),
                            );
                            setState(() {
                              _currentPositionSeconds = val;
                            });
                            // Seeking does NOT trigger attendance or inflate progress!
                            final watchProgress =
                                totalSeconds > 0 ? (val / totalSeconds) : 0.0;
                            courseProvider.updateLessonProgress(
                              widget.lesson.id,
                              watchProgress,
                              _isCompleted,
                            );
                          },
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            key: const Key('video_bottom_play_button'),
                            icon: Icon(
                              _isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: _togglePlayPause,
                          ),
                      Text(
                        "${Formatters.formatDuration(Duration(seconds: _currentPositionSeconds.toInt()))} / ${Formatters.formatDuration(widget.lesson.duration)}",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),

                      // Playback speed selector with clear high-contrast theme
                      PopupMenuButton<double>(
                        tooltip: "Playback Speed",
                        color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                        surfaceTintColor: Colors.transparent,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: isDark ? AppColors.darkBorder : AppColors.border,
                          ),
                        ),
                        onSelected: (speed) {
                          _videoController?.setPlaybackSpeed(speed);
                          setState(() {
                            _playbackSpeed = speed;
                          });
                        },
                        itemBuilder: (_) => [0.75, 1.0, 1.25, 1.5, 2.0]
                            .map(
                              (s) => PopupMenuItem(
                                value: s,
                                child: Row(
                                  children: [
                                    Text(
                                      "${s}x",
                                      style: TextStyle(
                                        color: isDark
                                            ? AppColors.darkTextPrimary
                                            : AppColors.deepInk,
                                        fontWeight: s == _playbackSpeed
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    if (s == _playbackSpeed) ...[
                                      const Spacer(),
                                      const Icon(
                                        Icons.check,
                                        size: 16,
                                        color: AppColors.primaryDark,
                                      ),
                                    ],
                                  ],
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
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "${_playbackSpeed}x",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: _toggleFullscreen,
                        tooltip: _isFullscreen ? "Exit Fullscreen" : "Fullscreen",
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
        ],
      ),
    ),
    );

    if (_isFullscreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: videoCanvas,
        ),
      );
    }

    final currentIndex = allLessons.indexWhere((l) => l.id == widget.lesson.id);

    final detailsAndPlaylist = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity == null) return;
        if (details.primaryVelocity! < -300) {
          // Swipe Left -> Next Lecture
          if (currentIndex != -1 && currentIndex < allLessons.length - 1) {
            _navigateToLesson(allLessons[currentIndex + 1]);
          }
        } else if (details.primaryVelocity! > 300) {
          // Swipe Right -> Previous Lecture
          if (currentIndex > 0) {
            _navigateToLesson(allLessons[currentIndex - 1]);
          }
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Lesson Title & Authoritative Completion Status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: isDark ? AppColors.darkSurfaceCard : AppTheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    CustomBadge(
                      text: currentLesson.chapter,
                      variant: BadgeVariant.primary,
                    ),
                    if (_isCompleted)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.success, width: 0.8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, color: AppTheme.success, size: 14),
                            SizedBox(width: 4),
                            Text(
                              "Completed",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.success,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Text(
                        "${((_actualWatchedSeconds / (totalSeconds > 0 ? totalSeconds : 1)) * 100).toInt()}% Verified Watch",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextSecondary : AppTheme.textSecondary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  currentLesson.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? AppColors.darkBorder : AppTheme.border),

          // Playlist Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 2,
              children: [
                Text(
                  "Course Lectures (${allLessons.length} Video${allLessons.length == 1 ? '' : 's'})",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  "Swipe horizontal to switch",
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),

          // Playlist List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              itemCount: allLessons.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final l = allLessons[index];
                final isCurrent = l.id == widget.lesson.id;

                return ModernCard(
                  onTap: () => _navigateToLesson(l),
                  backgroundColor: isCurrent
                      ? (isDark ? AppColors.darkSurface : AppTheme.surfaceElevated)
                      : (isDark ? AppColors.darkSurfaceCard : AppTheme.surface),
                  borderColor: isCurrent
                      ? AppTheme.primary
                      : (isDark ? AppColors.darkBorder : AppTheme.border),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      (l.thumbnailUrl != null &&
                              l.thumbnailUrl!.trim().isNotEmpty &&
                              l.thumbnailUrl!.startsWith('http'))
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: SizedBox(
                                width: 44,
                                height: 32,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(
                                      l.thumbnailUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Container(
                                        color: isDark
                                            ? AppColors.darkSurface
                                            : AppTheme.surfaceLight,
                                        child: Icon(
                                          isCurrent
                                              ? Icons.play_arrow
                                              : Icons.play_circle_outline,
                                          size: 16,
                                          color: isCurrent
                                              ? AppTheme.primary
                                              : AppTheme.textSecondary,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      color: Colors.black.withValues(alpha: 0.25),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        isCurrent
                                            ? Icons.play_arrow
                                            : (l.isCompleted
                                                ? Icons.check
                                                : Icons.play_circle_outline),
                                        size: 16,
                                        color: isCurrent
                                            ? AppTheme.primary
                                            : Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? AppTheme.primary
                                    : l.isCompleted
                                    ? AppTheme.success.withValues(alpha: 0.2)
                                    : (isDark ? AppColors.darkSurface : AppTheme.surfaceLight),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                isCurrent
                                    ? Icons.play_arrow
                                    : l.isCompleted
                                    ? Icons.check
                                    : Icons.play_circle_outline,
                                size: 18,
                                color: isCurrent
                                    ? Colors.black
                                    : l.isCompleted
                                    ? AppTheme.success
                                    : AppTheme.textSecondary,
                              ),
                            ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isCurrent
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                color: isCurrent
                                    ? AppTheme.primary
                                    : (isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.deepInk),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "${l.chapter} • ${Formatters.formatDuration(l.duration)}",
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: isLandscape ? 44 : kToolbarHeight,
        backgroundColor: isDark ? AppColors.darkSurface : AppTheme.surface,
        foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
        title: Text(
          currentLesson.title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (canManage) ...[
            IconButton(
              key: const Key('edit_lecture_action'),
              icon: const Icon(Icons.edit_outlined),
              tooltip: "Edit Lecture Details",
              onPressed: () => _showEditLectureDialog(context),
            ),
            IconButton(
              key: const Key('edit_thumbnail_action'),
              icon: const Icon(Icons.image_outlined),
              tooltip: "Change Lecture Thumbnail",
              onPressed: () => _showEditThumbnailDialog(context),
            ),
            IconButton(
              key: const Key('delete_lecture_action'),
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              tooltip: "Delete Lecture",
              onPressed: () => _confirmDeleteLesson(context),
            ),
          ],
        ],
      ),
      body: isLandscape
          ? Row(
              children: [
                Expanded(flex: 3, child: videoCanvas),
                Expanded(flex: 1, child: detailsAndPlaylist),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                videoCanvas,
                Expanded(child: detailsAndPlaylist),
              ],
            ),
    );
  }
}
