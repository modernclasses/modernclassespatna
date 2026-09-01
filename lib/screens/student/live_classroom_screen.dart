import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/custom_badge.dart';
import '../../models/live_class_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/live_class_provider.dart';

class LiveClassroomScreen extends StatefulWidget {
  final LiveClassModel liveClass;

  const LiveClassroomScreen({super.key, required this.liveClass});

  @override
  State<LiveClassroomScreen> createState() => _LiveClassroomScreenState();
}

class _LiveClassroomScreenState extends State<LiveClassroomScreen> {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isPlaying = true;
  bool _isMuted = false;
  double _playbackSpeed = 1.0;
  bool _isHandRaised = false;

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage(LiveClassProvider liveProvider, AuthProvider auth) {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    liveProvider.sendLiveChatMessage(
      classId: widget.liveClass.id,
      senderName: auth.currentUser.name,
      senderRole: auth.currentUser.role.name.toUpperCase(),
      text: text,
    );

    _chatController.clear();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final liveProvider = context.watch<LiveClassProvider>();
    final auth = context.watch<AuthProvider>();

    // Current class updated state
    final currentClass = liveProvider.getLiveClassById(widget.liveClass.id) ?? widget.liveClass;
    final isLiveNow = currentClass.status == LiveStatus.live;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
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
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          if (isLiveNow)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: CustomBadge(
                text: "${currentClass.activeViewersCount} Watching",
                variant: BadgeVariant.error,
                isLivePulse: true,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Video Player Container
          Container(
            width: double.infinity,
            height: 230,
            color: Colors.black,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Simulated Stream Graphics / Video Canvas
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
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primary.withValues(alpha: 0.2),
                            border: Border.all(color: AppTheme.primary, width: 2),
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            size: 48,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isLiveNow ? "🔴 LIVE STREAM ACTIVE" : "CLASS RECORDING",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Modern Classes Patna • Studio 1",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Live Watermark (Anti-Piracy)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      "MCP Student: ${auth.currentUser.phone}",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                // Player Controls Overlay Bottom Bar
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.9)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Row(
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
                        IconButton(
                          icon: Icon(
                            _isMuted ? Icons.volume_off : Icons.volume_up,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _isMuted = !_isMuted;
                            });
                          },
                        ),
                        const Spacer(),
                        PopupMenuButton<double>(
                          tooltip: "Playback Speed",
                          color: AppTheme.surfaceLight,
                          onSelected: (speed) {
                            setState(() {
                              _playbackSpeed = speed;
                            });
                          },
                          itemBuilder: (context) => [0.75, 1.0, 1.25, 1.5, 2.0]
                              .map(
                                (s) => PopupMenuItem(
                                  value: s,
                                  child: Text("${s}x", style: const TextStyle(color: Colors.white)),
                                ),
                              )
                              .toList(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "${_playbackSpeed}x",
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.fullscreen, color: Colors.white, size: 22),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Fullscreen Mode activated"),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Live Header Information Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppTheme.surface,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.primary,
                  child: Text(
                    currentClass.teacherName.substring(0, 1),
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentClass.teacherName,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        currentClass.batchName,
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
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
                    backgroundColor: _isHandRaised ? AppTheme.warning : AppTheme.surfaceElevated,
                    foregroundColor: _isHandRaised ? Colors.black : Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: const Size(0, 32),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),

          // Live Chat Stream
          Expanded(
            child: Container(
              color: AppTheme.background,
              child: Column(
                children: [
                  // Live Chat Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: AppTheme.surfaceLight,
                    child: Row(
                      children: [
                        const Icon(Icons.chat_bubble_outline, size: 16, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        const Text(
                          "Live Classroom Chat & Doubts",
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        Text(
                          "${currentClass.chatMessages.length} messages",
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),

                  // Chat Message List
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: currentClass.chatMessages.length,
                      itemBuilder: (context, index) {
                        final msg = currentClass.chatMessages[index];
                        final isTeacher = msg.senderRole.toUpperCase() == "TEACHER";
                        final isMe = msg.senderName == auth.currentUser.name;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: msg.isPinned
                                ? AppTheme.primary.withValues(alpha: 0.15)
                                : isTeacher
                                    ? AppTheme.secondary.withValues(alpha: 0.12)
                                    : AppTheme.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: msg.isPinned
                                  ? AppTheme.primary.withValues(alpha: 0.4)
                                  : isTeacher
                                      ? AppTheme.secondary.withValues(alpha: 0.3)
                                      : AppTheme.border,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (msg.isPinned) ...[
                                    const Icon(Icons.push_pin, size: 12, color: AppTheme.primary),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    msg.senderName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isTeacher
                                          ? AppTheme.secondaryLight
                                          : isMe
                                              ? AppTheme.primary
                                              : AppTheme.textPrimary,
                                    ),
                                  ),
                                  if (isTeacher) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
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
                                  const Spacer(),
                                  Text(
                                    Formatters.formatTime(msg.timestamp),
                                    style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                msg.text,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textPrimary,
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: const BoxDecoration(
                      color: AppTheme.surface,
                      border: Border(top: BorderSide(color: AppTheme.border)),
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
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                isDense: true,
                                fillColor: AppTheme.surfaceLight,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onSubmitted: (_) => _sendMessage(liveProvider, auth),
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
      ),
    );
  }
}
