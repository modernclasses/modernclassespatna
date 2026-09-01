import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_card.dart';
import '../../models/test_model.dart';
import 'test_taking_screen.dart';

class TestResultScreen extends StatelessWidget {
  final TestResultModel result;
  final TestModel test;

  const TestResultScreen({super.key, required this.result, required this.test});

  @override
  Widget build(BuildContext context) {
    final isPassed = result.score >= test.passingMarks;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Exam Performance & Solutions"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Score Banner
            ModernCard(
              padding: const EdgeInsets.all(20),
              backgroundColor: AppTheme.surfaceCard,
              hasGlow: true,
              glowColor: isPassed
                  ? AppTheme.success.withValues(alpha: 0.2)
                  : AppTheme.error.withValues(alpha: 0.2),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            test.title,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Candidate: ${result.studentName}",
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                      CustomBadge(
                        text: isPassed ? "PASSED" : "NEEDS PRACTICE",
                        variant: isPassed ? BadgeVariant.success : BadgeVariant.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: AppTheme.border),
                  const SizedBox(height: 20),

                  // Key Performance Metrics Grid
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetricItem(
                        label: "Total Score",
                        value: "${result.score.toInt()} / ${result.maxScore.toInt()}",
                        color: AppTheme.primary,
                        icon: Icons.emoji_events,
                      ),
                      _buildMetricItem(
                        label: "Accuracy",
                        value: "${result.percentage.toStringAsFixed(1)}%",
                        color: isPassed ? AppTheme.success : AppTheme.warning,
                        icon: Icons.pie_chart,
                      ),
                      _buildMetricItem(
                        label: "Patna Rank",
                        value: "#${result.rank}",
                        subValue: "out of ${result.totalParticipants}",
                        color: AppTheme.secondaryLight,
                        icon: Icons.leaderboard,
                      ),
                      _buildMetricItem(
                        label: "Percentile",
                        value: "${result.percentile}%",
                        color: AppTheme.purple,
                        icon: Icons.trending_up,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Performance Breakdown Chips
            Row(
              children: [
                Expanded(
                  child: _buildCountCard(
                    title: "Correct",
                    count: result.correctCount,
                    color: AppTheme.success,
                    icon: Icons.check_circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCountCard(
                    title: "Incorrect",
                    count: result.incorrectCount,
                    color: AppTheme.error,
                    icon: Icons.cancel,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCountCard(
                    title: "Unattempted",
                    count: result.unattemptedCount,
                    color: AppTheme.textMuted,
                    icon: Icons.help,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Section Header: Detailed Solutions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Question by Question Review",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (test.allowsRetake)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: const Size(0, 36),
                    ),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text("Retake Test"),
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => TestTakingScreen(test: test),
                        ),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Question Solutions List
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: test.questions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final q = test.questions[index];
                final response = result.responses[q.id];

                bool isCorrect = false;
                bool isAttempted = false;

                if (q.type == QuestionType.descriptive) {
                  isAttempted = response != null && response.writtenAnswer != null && response.writtenAnswer!.isNotEmpty;
                  isCorrect = isAttempted;
                } else {
                  if (response != null && response.selectedOptionIndices.isNotEmpty) {
                    isAttempted = true;
                    final sel = List<int>.from(response.selectedOptionIndices)..sort();
                    final cor = List<int>.from(q.correctOptionIndices)..sort();
                    isCorrect = sel.toString() == cor.toString();
                  }
                }

                return ModernCard(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: AppTheme.surface,
                  borderColor: isCorrect
                      ? AppTheme.success.withValues(alpha: 0.4)
                      : isAttempted
                          ? AppTheme.error.withValues(alpha: 0.4)
                          : AppTheme.border,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isCorrect
                                  ? AppTheme.success.withValues(alpha: 0.2)
                                  : isAttempted
                                      ? AppTheme.error.withValues(alpha: 0.2)
                                      : AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "Q${index + 1}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: isCorrect
                                    ? AppTheme.success
                                    : isAttempted
                                        ? AppTheme.error
                                        : AppTheme.textMuted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          CustomBadge(
                            text: isCorrect
                                ? "Correct (+${q.marks.toInt()})"
                                : isAttempted
                                    ? "Incorrect (0)"
                                    : "Not Attempted (0)",
                            variant: isCorrect
                                ? BadgeVariant.success
                                : isAttempted
                                    ? BadgeVariant.error
                                    : BadgeVariant.outline,
                            fontSize: 10,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Question Text
                      Text(
                        q.text,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),

                      // Options breakdown
                      if (q.type != QuestionType.descriptive) ...[
                        for (int i = 0; i < q.options.length; i++) ...[
                          _buildResultOptionTile(
                            optionText: q.options[i],
                            optionIndex: i,
                            isUserSelected: response?.selectedOptionIndices.contains(i) ?? false,
                            isCorrectOption: q.correctOptionIndices.contains(i),
                          ),
                          const SizedBox(height: 6),
                        ],
                      ] else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Your Submitted Answer:",
                                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                response?.writtenAnswer ?? "No response provided.",
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Explanation box
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.secondary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.lightbulb_outline, size: 14, color: AppTheme.secondaryLight),
                                SizedBox(width: 6),
                                Text(
                                  "Explanation & Concept:",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppTheme.secondaryLight,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              q.explanation,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textPrimary,
                                height: 1.4,
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
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem({
    required String label,
    required String value,
    String? subValue,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color),
        ),
        if (subValue != null)
          Text(
            subValue,
            style: const TextStyle(fontSize: 9, color: AppTheme.textMuted),
          ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildCountCard({
    required String title,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "$count",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
              ),
              Text(
                title,
                style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultOptionTile({
    required String optionText,
    required int optionIndex,
    required bool isUserSelected,
    required bool isCorrectOption,
  }) {
    final label = String.fromCharCode(65 + optionIndex);

    Color bg = AppTheme.surfaceLight;
    Color border = AppTheme.border;
    Widget? icon;

    if (isCorrectOption) {
      bg = AppTheme.success.withValues(alpha: 0.15);
      border = AppTheme.success;
      icon = const Icon(Icons.check, size: 16, color: AppTheme.success);
    } else if (isUserSelected && !isCorrectOption) {
      bg = AppTheme.error.withValues(alpha: 0.15);
      border = AppTheme.error;
      icon = const Icon(Icons.close, size: 16, color: AppTheme.error);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Text(
            "$label.",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: isCorrectOption ? AppTheme.success : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              optionText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: (isCorrectOption || isUserSelected) ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          ?icon,
        ],
      ),
    );
  }
}
