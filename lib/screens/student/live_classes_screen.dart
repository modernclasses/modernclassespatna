import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_button.dart';
import '../../core/widgets/modern_card.dart';
import '../../providers/live_class_provider.dart';
import 'live_classroom_screen.dart';

class LiveClassesScreen extends StatefulWidget {
  const LiveClassesScreen({super.key});

  @override
  State<LiveClassesScreen> createState() => _LiveClassesScreenState();
}

class _LiveClassesScreenState extends State<LiveClassesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final liveProvider = context.watch<LiveClassProvider>();
    final activeLive = liveProvider.currentActiveLiveClass;
    final upcoming = liveProvider.upcomingClasses;
    final past = liveProvider.pastRecordings;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Live Classroom Hub"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Live & Upcoming"),
            Tab(text: "Past Recordings"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Live & Upcoming
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Highlighted LIVE NOW Card
              if (activeLive != null) ...[
                const Text(
                  "🔴 HAPPENING RIGHT NOW",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.error,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                ModernCard(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: AppTheme.surfaceCard,
                  borderColor: AppTheme.error.withValues(alpha: 0.5),
                  hasGlow: true,
                  glowColor: AppTheme.error.withValues(alpha: 0.2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          CustomBadge(
                            text: "LIVE STREAM",
                            variant: BadgeVariant.error,
                            isLivePulse: true,
                          ),
                          CustomBadge(
                            text: "${activeLive.activeViewersCount} Students Online",
                            variant: BadgeVariant.outline,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        activeLive.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "${activeLive.subject} • ${activeLive.batchName}",
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: AppTheme.primary,
                            child: Text(
                              activeLive.teacherName.substring(0, 1),
                              style: const TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            activeLive.teacherName,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ModernButton(
                        text: "Join Live Stream Now",
                        width: double.infinity,
                        icon: Icons.play_arrow_rounded,
                        variant: ButtonVariant.danger,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => LiveClassroomScreen(liveClass: activeLive),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Upcoming Live Sessions
              const Text(
                "Scheduled Upcoming Classes",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              if (upcoming.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      "No upcoming live classes scheduled today.",
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  ),
                )
              else
                ...upcoming.map((live) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ModernCard(
                      padding: const EdgeInsets.all(14),
                      backgroundColor: AppTheme.surface,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.alarm, color: AppTheme.primary, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  live.title,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${live.subject} • Faculty: ${live.teacherName}",
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Starts at ${Formatters.formatDateTime(live.scheduledStartTime)}",
                                  style: const TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              minimumSize: const Size(0, 32),
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("⏰ Reminder set for ${live.title}!"),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            child: const Text("Remind Me", style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),

          // Tab 2: Past Recorded Classes
          past.isEmpty
              ? const Center(
                  child: Text(
                    "No recorded classes available yet.",
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: past.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final live = past[index];
                    return ModernCard(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LiveClassroomScreen(liveClass: live),
                          ),
                        );
                      },
                      padding: const EdgeInsets.all(14),
                      backgroundColor: AppTheme.surface,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.secondary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.play_circle_filled, color: AppTheme.secondaryLight, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  live.title,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${live.subject} • ${live.teacherName}",
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Conducted on ${Formatters.formatDate(live.scheduledStartTime)}",
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textMuted),
                        ],
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}
