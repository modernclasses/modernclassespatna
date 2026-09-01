import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_card.dart';
import '../../providers/test_provider.dart';
import 'test_taking_screen.dart';
import 'test_result_screen.dart';

class TestsScreen extends StatelessWidget {
  const TestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final testProvider = context.watch<TestProvider>();
    final tests = testProvider.tests;
    final results = testProvider.testResults;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Test Series & Mock Exams"),
      ),
      body: tests.isEmpty
          ? Center(
              child: Text(
                "No tests scheduled right now.",
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: tests.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final test = tests[index];
                final result = results[test.id];
                final isCompleted = result != null;

                return ModernCard(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: AppTheme.surface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          CustomBadge(
                            text: test.subject,
                            variant: BadgeVariant.purple,
                          ),
                          if (isCompleted)
                            CustomBadge(
                              text: "Score: ${result.score.toInt()}/${result.maxScore.toInt()} (${result.percentage.toStringAsFixed(0)}%)",
                              variant: result.score >= test.passingMarks
                                  ? BadgeVariant.success
                                  : BadgeVariant.warning,
                            )
                          else
                            CustomBadge(
                              text: "${test.attemptsCount}+ Attempts",
                              variant: BadgeVariant.outline,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        test.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildInfoChip(
                            Icons.format_list_numbered,
                            "${test.totalQuestions} Questions",
                          ),
                          const SizedBox(width: 14),
                          _buildInfoChip(
                            Icons.timer_outlined,
                            "${test.duration.inMinutes} Mins",
                          ),
                          const SizedBox(width: 14),
                          _buildInfoChip(
                            Icons.grade_outlined,
                            "${test.totalMarks.toInt()} Marks",
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: AppTheme.border),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (isCompleted) ...[
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.analytics_outlined, size: 16),
                                label: const Text("View Scorecard & Review"),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => TestResultScreen(result: result, test: test),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.black,
                              ),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => TestTakingScreen(test: test),
                                  ),
                                );
                              },
                              child: const Text("Retake"),
                            ),
                          ] else ...[
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.black,
                                ),
                                icon: const Icon(Icons.play_circle_outline, size: 18),
                                label: const Text("Start Mock Test"),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => TestTakingScreen(test: test),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textMuted),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}
