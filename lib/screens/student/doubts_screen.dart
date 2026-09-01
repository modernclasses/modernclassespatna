import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_card.dart';
import '../../providers/auth_provider.dart';
import '../../providers/doubt_provider.dart';
import 'ask_doubt_dialog.dart';

class DoubtsScreen extends StatefulWidget {
  const DoubtsScreen({super.key});

  @override
  State<DoubtsScreen> createState() => _DoubtsScreenState();
}

class _DoubtsScreenState extends State<DoubtsScreen> {
  final Map<String, TextEditingController> _replyControllers = {};

  @override
  void dispose() {
    for (var c in _replyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _postReply(DoubtProvider doubtProvider, AuthProvider auth, String doubtId) {
    final controller = _replyControllers[doubtId];
    if (controller == null || controller.text.trim().isEmpty) return;

    doubtProvider.replyToDoubt(
      doubtId: doubtId,
      authorId: auth.currentUser.id,
      authorName: auth.currentUser.name,
      authorRole: auth.currentUser.role.name.toUpperCase(),
      message: controller.text.trim(),
      isOfficialTeacherAnswer: auth.isTeacher || auth.isAdmin,
    );

    controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final doubtProvider = context.watch<DoubtProvider>();
    final doubts = doubtProvider.getFilteredDoubts(auth.currentUser.id);

    final filters = ['All', 'My Doubts', 'Resolved', 'Unresolved'];

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Doubts & Discussion Forum"),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.help_outline),
        label: const Text("Ask Doubt", style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => const AskDoubtDialog(),
          );
        },
      ),
      body: Column(
        children: [
          // Filter Chips Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppTheme.surface,
            child: Row(
              children: filters.map((f) {
                final isSelected = f == doubtProvider.selectedFilter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f),
                    selected: isSelected,
                    onSelected: (_) => doubtProvider.setFilter(f),
                    backgroundColor: AppTheme.surfaceLight,
                    selectedColor: AppTheme.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    side: BorderSide(color: isSelected ? AppTheme.primary : AppTheme.border),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),

          // Doubts List
          Expanded(
            child: doubts.isEmpty
                ? const Center(
                    child: Text(
                      "No doubts found in this filter.",
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    itemCount: doubts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final doubt = doubts[index];
                      _replyControllers.putIfAbsent(doubt.id, () => TextEditingController());

                      return ModernCard(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: AppTheme.surface,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Doubt Header
                            Row(
                              children: [
                                CustomBadge(text: doubt.subject, variant: BadgeVariant.primary),
                                const SizedBox(width: 8),
                                CustomBadge(
                                  text: doubt.isResolved ? "RESOLVED" : "PENDING",
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

                            // Topic & Question
                            Text(
                              doubt.topic,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.secondaryLight,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              doubt.questionText,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Asked by ${doubt.studentName}",
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),

                            // Replies Section
                            if (doubt.replies.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              const Divider(color: AppTheme.border),
                              const SizedBox(height: 10),
                              const Text(
                                "Answers & Discussion",
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                              ),
                              const SizedBox(height: 8),
                              for (var rep in doubt.replies) ...[
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: rep.isOfficialTeacherAnswer
                                        ? AppTheme.primary.withValues(alpha: 0.1)
                                        : AppTheme.surfaceLight,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: rep.isOfficialTeacherAnswer
                                          ? AppTheme.primary.withValues(alpha: 0.4)
                                          : AppTheme.border,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            rep.authorName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: rep.isOfficialTeacherAnswer ? AppTheme.primary : AppTheme.textPrimary,
                                            ),
                                          ),
                                          if (rep.isOfficialTeacherAnswer) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primary,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                "FACULTY ANSWER",
                                                style: TextStyle(
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 8,
                                                ),
                                              ),
                                            ),
                                          ],
                                          const Spacer(),
                                          Text(
                                            Formatters.timeAgo(rep.timestamp),
                                            style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        rep.message,
                                        style: const TextStyle(fontSize: 13, height: 1.4),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],

                            // Quick Reply Input Field
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _replyControllers[doubt.id],
                                    style: const TextStyle(fontSize: 12),
                                    decoration: InputDecoration(
                                      hintText: auth.isTeacher
                                          ? "Write official teacher solution..."
                                          : "Contribute an answer / reply...",
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      isDense: true,
                                      fillColor: AppTheme.surfaceLight,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: AppTheme.border),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: auth.isTeacher ? AppTheme.primary : AppTheme.surfaceElevated,
                                    foregroundColor: auth.isTeacher ? Colors.black : Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    minimumSize: const Size(0, 36),
                                  ),
                                  onPressed: () => _postReply(doubtProvider, auth, doubt.id),
                                  child: const Text("Reply"),
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
