import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_card.dart';
import '../../providers/auth_provider.dart';
import '../../providers/doubt_provider.dart';

class TeacherDoubtsScreen extends StatefulWidget {
  const TeacherDoubtsScreen({super.key});

  @override
  State<TeacherDoubtsScreen> createState() => _TeacherDoubtsScreenState();
}

class _TeacherDoubtsScreenState extends State<TeacherDoubtsScreen> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _postTeacherAnswer(DoubtProvider doubtProvider, AuthProvider auth, String doubtId) {
    final controller = _controllers[doubtId];
    if (controller == null || controller.text.trim().isEmpty) return;

    doubtProvider.replyToDoubt(
      doubtId: doubtId,
      authorId: auth.currentUser.id,
      authorName: auth.currentUser.name,
      authorRole: "TEACHER",
      message: controller.text.trim(),
      isOfficialTeacherAnswer: true,
    );

    controller.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("✨ Official Teacher Answer posted! Student notified."),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final doubtProvider = context.watch<DoubtProvider>();
    final doubts = doubtProvider.doubts;

    final unresolvedCount = doubts.where((d) => !d.isResolved).length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Student Doubt Resolution Desk"),
      ),
      body: Column(
        children: [
          // Banner summary
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppTheme.surface,
            child: Row(
              children: [
                CustomBadge(
                  text: "$unresolvedCount Pending Questions",
                  variant: unresolvedCount > 0 ? BadgeVariant.warning : BadgeVariant.success,
                ),
                const Spacer(),
                Text(
                  "Total Doubts: ${doubts.length}",
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),

          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: doubts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final doubt = doubts[index];
                _controllers.putIfAbsent(doubt.id, () => TextEditingController());

                return ModernCard(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: AppTheme.surface,
                  borderColor: doubt.isResolved ? AppTheme.border : AppTheme.warning.withValues(alpha: 0.4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CustomBadge(text: doubt.subject, variant: BadgeVariant.primary),
                          const SizedBox(width: 8),
                          CustomBadge(
                            text: doubt.isResolved ? "RESOLVED" : "NEEDS ANSWER",
                            variant: doubt.isResolved ? BadgeVariant.success : BadgeVariant.warning,
                          ),
                          const Spacer(),
                          Text(
                            Formatters.timeAgo(doubt.askedAt),
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Student: ${doubt.studentName} (${doubt.topic})",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.secondaryLight),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        doubt.questionText,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4),
                      ),

                      // Existing replies
                      if (doubt.replies.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        for (var rep in doubt.replies) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: rep.isOfficialTeacherAnswer
                                  ? AppTheme.primary.withValues(alpha: 0.1)
                                  : AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "${rep.authorName}: ${rep.message}",
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ],

                      // Teacher Official Reply Input
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controllers[doubt.id],
                              style: const TextStyle(fontSize: 13),
                              decoration: const InputDecoration(
                                hintText: "Provide official faculty solution...",
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              minimumSize: const Size(0, 38),
                            ),
                            onPressed: () => _postTeacherAnswer(doubtProvider, auth, doubt.id),
                            child: const Text("Post Solution"),
                          ),
                        ],
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
