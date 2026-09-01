import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_card.dart';
import '../../models/course_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/course_provider.dart';

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
  bool _isPlaying = true;
  double _currentPositionSeconds = 240; // 4 minutes in
  double _playbackSpeed = 1.0;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _isCompleted = widget.lesson.isCompleted;
    _currentPositionSeconds = widget.lesson.duration.inSeconds * widget.lesson.progressPercent;
  }

  void _toggleComplete(CourseProvider courseProvider) {
    setState(() {
      _isCompleted = !_isCompleted;
    });
    courseProvider.updateLessonProgress(
      widget.lesson.id,
      _isCompleted ? 1.0 : (_currentPositionSeconds / widget.lesson.duration.inSeconds),
      _isCompleted,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isCompleted ? "✅ Lesson marked as Completed!" : "Lesson marked as Incomplete",
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final courseProvider = context.watch<CourseProvider>();
    final allLessons = courseProvider.getLessonsForCourse(widget.course.id);
    final totalSeconds = widget.lesson.duration.inSeconds;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: Text(
          widget.lesson.title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Video Canvas Container
          Container(
            width: double.infinity,
            height: 230,
            color: Colors.black,
            child: Stack(
              children: [
                // Simulated Video Frame
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF050B14)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        InkWell(
                          onTap: () {
                            setState(() {
                              _isPlaying = !_isPlaying;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primary.withValues(alpha: 0.25),
                              border: Border.all(color: AppTheme.primary, width: 2),
                            ),
                            child: Icon(
                              _isPlaying ? Icons.pause : Icons.play_arrow_rounded,
                              size: 42,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.lesson.chapter,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Anti-Piracy Watermark Overlay
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      "Modern Classes Patna • ${auth.currentUser.phone}",
                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                  ),
                ),

                // Bottom Video Controls & Scrubber
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.9)],
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
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            trackHeight: 3,
                            activeTrackColor: AppTheme.primary,
                            inactiveTrackColor: Colors.white24,
                            thumbColor: AppTheme.primary,
                          ),
                          child: Slider(
                            value: _currentPositionSeconds.clamp(0, totalSeconds.toDouble()),
                            max: totalSeconds.toDouble(),
                            onChanged: (val) {
                              setState(() {
                                _currentPositionSeconds = val;
                              });
                              courseProvider.updateLessonProgress(
                                widget.lesson.id,
                                _currentPositionSeconds / totalSeconds,
                                _isCompleted,
                              );
                            },
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                _isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPlaying = !_isPlaying;
                                });
                              },
                            ),
                            Text(
                              "${Formatters.formatDuration(Duration(seconds: _currentPositionSeconds.toInt()))} / ${Formatters.formatDuration(widget.lesson.duration)}",
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                            const Spacer(),
                            PopupMenuButton<double>(
                              tooltip: "Speed",
                              color: AppTheme.surfaceLight,
                              onSelected: (speed) {
                                setState(() {
                                  _playbackSpeed = speed;
                                });
                              },
                              itemBuilder: (_) => [0.75, 1.0, 1.25, 1.5, 2.0]
                                  .map(
                                    (s) => PopupMenuItem(
                                      value: s,
                                      child: Text("${s}x", style: const TextStyle(color: Colors.white)),
                                    ),
                                  )
                                  .toList(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white12,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  "${_playbackSpeed}x",
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.fullscreen, color: Colors.white, size: 20),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Fullscreen Mode")),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Lesson Details & Complete Action
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CustomBadge(text: widget.lesson.chapter, variant: BadgeVariant.primary),
                    const Spacer(),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        side: BorderSide(
                          color: _isCompleted ? AppTheme.success : AppTheme.borderLight,
                        ),
                      ),
                      icon: Icon(
                        _isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 16,
                        color: _isCompleted ? AppTheme.success : AppTheme.textSecondary,
                      ),
                      label: Text(
                        _isCompleted ? "Completed" : "Mark Complete",
                        style: TextStyle(
                          fontSize: 12,
                          color: _isCompleted ? AppTheme.success : AppTheme.textSecondary,
                        ),
                      ),
                      onPressed: () => _toggleComplete(courseProvider),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  widget.lesson.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  "Faculty: ${widget.course.teacherName} • Modern Classes Patna",
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),

          // Playlist / Course Lectures List
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              "Course Lectures & Playlist (${allLessons.length} Videos)",
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: allLessons.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final l = allLessons[index];
                final isCurrent = l.id == widget.lesson.id;

                return ModernCard(
                  onTap: () {
                    if (!isCurrent) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => VideoPlayerScreen(lesson: l, course: widget.course),
                        ),
                      );
                    }
                  },
                  backgroundColor: isCurrent ? AppTheme.surfaceElevated : AppTheme.surface,
                  borderColor: isCurrent ? AppTheme.primary : AppTheme.border,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? AppTheme.primary
                              : l.isCompleted
                                  ? AppTheme.success.withValues(alpha: 0.2)
                                  : AppTheme.surfaceLight,
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
                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                                color: isCurrent ? AppTheme.primary : AppTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "${l.chapter} • ${Formatters.formatDuration(l.duration)}",
                              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
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
  }
}
