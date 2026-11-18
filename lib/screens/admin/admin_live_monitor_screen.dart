import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/batch_timing_helper.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_card.dart';
import '../../features/live_classes/data/models/live_class_model.dart';
import '../../providers/course_provider.dart';
import '../../providers/live_class_provider.dart';
import '../student/live_classroom_screen.dart';

/// Admin Live Stream Monitor Console.
/// Provides real-time visibility into active faculty broadcasts, live duration,
/// Cloudflare ingest health, and emergency administrator controls.
class AdminLiveMonitorScreen extends StatefulWidget {
  const AdminLiveMonitorScreen({super.key});

  @override
  State<AdminLiveMonitorScreen> createState() => _AdminLiveMonitorScreenState();
}

class _AdminLiveMonitorScreenState extends State<AdminLiveMonitorScreen> {
  Timer? _ticker;
  final Map<String, String> _cloudflareStatusCache = {};
  final Set<String> _checkingUids = {};
  final Set<String> _endingSessionIds = {};

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LiveClassProvider>().fetchLiveClasses();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '00:00';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final hStr = h.toString().padLeft(2, '0');
    final mStr = m.toString().padLeft(2, '0');
    final sStr = s.toString().padLeft(2, '0');
    return h > 0 ? '$hStr:$mStr:$sStr' : '$mStr:$sStr';
  }

  Future<void> _checkSessionStatus(String liveInputUid) async {
    if (liveInputUid.isEmpty) return;
    setState(() => _checkingUids.add(liveInputUid));

    try {
      final liveProvider = context.read<LiveClassProvider>();
      final result = await liveProvider.checkLiveStatus(liveInputUid);
      final status = result['status']?.toString() ?? 'unknown';

      if (mounted) {
        setState(() {
          _checkingUids.remove(liveInputUid);
          _cloudflareStatusCache[liveInputUid] = status;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Cloudflare Ingest Status: $status"),
            backgroundColor: status == 'connected'
                ? AppColors.success
                : AppColors.deepInk,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _checkingUids.remove(liveInputUid));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error querying Cloudflare: $e")),
        );
      }
    }
  }

  Future<void> _emergencyEndSession(LiveClassModel session) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text("Emergency End Session?"),
          ],
        ),
        content: Text(
          "Are you sure you want to forcibly terminate the live broadcast '${session.title}' by ${session.teacherName}?\n\nThis will terminate the stream immediately, mark it ended, and queue Cloudflare recording processing.",
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("End Session Immediately"),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _endingSessionIds.add(session.id));
    final liveProvider = context.read<LiveClassProvider>();

    try {
      await liveProvider.endAuthenticatedLiveSession(session.id);
      if (mounted) {
        setState(() => _endingSessionIds.remove(session.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Broadcast '${session.title}' ended by administrator."),
            backgroundColor: AppColors.deepInk,
          ),
        );
        liveProvider.fetchLiveClasses();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _endingSessionIds.remove(session.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to end session: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final liveProvider = context.watch<LiveClassProvider>();
    final courseProvider = context.watch<CourseProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final liveSessions = liveProvider.liveNow;
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Live Broadcast Monitor"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Live Sessions",
            onPressed: () => liveProvider.fetchLiveClasses(),
          ),
        ],
      ),
      body: liveProvider.isLoading
          ? const AppLoadingIndicator()
          : liveSessions.isEmpty
              ? AppEmptyState(
                  icon: Icons.cell_tower,
                  title: "No Active Live Broadcasts",
                  subtitle:
                      "When faculty members go live in their assigned batch slots, real-time metrics, connection health, and administrative controls will appear here.",
                  actionLabel: "Refresh Live Monitor",
                  onAction: () => liveProvider.fetchLiveClasses(),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: liveSessions.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final session = liveSessions[index];
                    final batch = courseProvider.batches
                        .where((b) => b.id == session.batchId)
                        .firstOrNull;

                    // Elapsed duration
                    final startTime = session.actualStartTime ??
                        session.scheduledStartTime;
                    final elapsedSeconds = now.isAfter(startTime)
                        ? now.difference(startTime).inSeconds
                        : 0;

                    // Cloudflare status
                    final inputUid = session.liveInputUid ?? batch?.streamKey ?? '';
                    final cfStatus = _cloudflareStatusCache[inputUid];
                    final isCheckingCf = _checkingUids.contains(inputUid);
                    final isEnding = _endingSessionIds.contains(session.id);

                    // Scheduled slot end
                    final timing = batch?.timing ?? '';
                    final parsed = BatchTimingHelper.parseTiming(timing);
                    final slotEndToday = DateTime(
                      now.year,
                      now.month,
                      now.day,
                      parsed.end.hour,
                      parsed.end.minute,
                    );
                    final isPastSlotEnd = now.isAfter(slotEndToday);
                    final remainingMinutes =
                        slotEndToday.difference(now).inMinutes;

                    return ModernCard(
                      padding: const EdgeInsets.all(16),
                      accentSpineColor: isPastSlotEnd
                          ? AppColors.error
                          : AppColors.success,
                      backgroundColor: isDark
                          ? AppColors.darkSurfaceCard
                          : AppColors.surface,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Live Indicator & Badges
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
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
                                      "LIVE · ${_formatDuration(elapsedSeconds)}",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              CustomBadge(
                                text: session.courseName,
                                variant: BadgeVariant.outline,
                                fontSize: 10,
                              ),
                              const SizedBox(width: 6),
                              CustomBadge(
                                text: session.batchName,
                                variant: BadgeVariant.primary,
                                fontSize: 10,
                              ),
                              const Spacer(),
                              if (cfStatus != null)
                                CustomBadge(
                                  text: cfStatus.toUpperCase(),
                                  variant: cfStatus == 'connected'
                                      ? BadgeVariant.success
                                      : BadgeVariant.warning,
                                  fontSize: 10,
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Lecture Title
                          Text(
                            session.title,
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.deepInk,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Faculty & Viewers info
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: AppColors.primary,
                                child: Text(
                                  session.teacherName.isNotEmpty
                                      ? session.teacherName
                                          .substring(0, 1)
                                          .toUpperCase()
                                      : 'T',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      session.teacherName,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      "${session.activeViewersCount} students watching live",
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Schedule & Duration Information Card
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isPastSlotEnd
                                  ? AppColors.error.withValues(alpha: 0.08)
                                  : (isDark
                                      ? AppColors.darkSurface
                                      : AppColors.surfaceMuted),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isPastSlotEnd
                                    ? AppColors.error.withValues(alpha: 0.3)
                                    : (isDark
                                        ? AppColors.darkBorder
                                        : AppColors.border),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isPastSlotEnd
                                      ? Icons.timer_off_outlined
                                      : Icons.schedule,
                                  size: 16,
                                  color: isPastSlotEnd
                                      ? AppColors.error
                                      : AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Assigned Slot: ${timing.isNotEmpty ? timing : 'Unassigned'} (IST • Asia/Kolkata)",
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isPastSlotEnd
                                              ? AppColors.error
                                              : (isDark
                                                  ? AppColors.darkTextPrimary
                                                  : AppColors.deepInk),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isPastSlotEnd
                                            ? "OVERTIME: Scheduled slot ended ${now.difference(slotEndToday).inMinutes} min ago."
                                            : "Scheduled end: ${Formatters.formatTime(slotEndToday)} IST ($remainingMinutes min remaining)",
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: isPastSlotEnd
                                              ? AppColors.error
                                              : AppColors.textSecondary,
                                          fontWeight: isPastSlotEnd
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Action Buttons
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  minimumSize: const Size(0, 36),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                icon: const Icon(Icons.remove_red_eye,
                                    size: 16),
                                label: const Text(
                                  "View Classroom",
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold),
                                ),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => LiveClassroomScreen(
                                          liveClass: session),
                                    ),
                                  );
                                },
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.deepInk,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  minimumSize: const Size(0, 36),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                icon: isCheckingCf
                                    ? const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Icon(Icons.sync, size: 16),
                                label: const Text(
                                  "Check Cloudflare",
                                  style: TextStyle(fontSize: 12),
                                ),
                                onPressed: isCheckingCf
                                    ? null
                                    : () => _checkSessionStatus(inputUid),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  minimumSize: const Size(0, 36),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                icon: isEnding
                                    ? const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.power_settings_new,
                                        size: 16),
                                label: const Text(
                                  "End Broadcast",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: isEnding
                                    ? null
                                    : () => _emergencyEndSession(session),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
