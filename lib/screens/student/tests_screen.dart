import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_card.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../../providers/auth_provider.dart';
import '../../providers/test_provider.dart';
import '../../features/tests/data/models/test_model.dart';
import '../teacher/create_test_screen.dart';
import '../teacher/teacher_test_results_screen.dart';
import 'test_taking_screen.dart';
import 'test_result_screen.dart';

class TestsScreen extends StatelessWidget {
  const TestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final testProvider = context.watch<TestProvider>();
    final tests = testProvider.tests;
    final results = testProvider.testResults;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    bool canCreate = false;
    try {
      final auth = context.watch<AuthProvider>();
      canCreate = auth.isTeacher || auth.isAdmin;
    } catch (_) {}

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Test Series & Mock Exams"),
        actions: [
          if (canCreate)
            IconButton(
              key: const Key('create_test_appbar_action'),
              icon: const Icon(Icons.add_task),
              tooltip: "Create Test",
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateTestScreen()),
                );
              },
            ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              key: const Key('create_test_fab'),
              icon: const Icon(Icons.add),
              label: const Text("Create Test"),
              backgroundColor: isDark ? AppColors.primary : AppColors.deepInk,
              foregroundColor: isDark ? Colors.black : Colors.white,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateTestScreen()),
                );
              },
            )
          : null,
      body: testProvider.isLoading
          ? const AppLoadingIndicator()
          : testProvider.errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Failed to load tests.",
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark ? AppColors.primary : AppColors.deepInk,
                                  foregroundColor: isDark ? Colors.black : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed: () => testProvider.fetchTests(),
                    child: const Text("Retry"),
                  ),
                ],
              ),
            )
          : tests.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "No tests scheduled right now.",
                      style: TextStyle(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    if (canCreate) ...[
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        key: const Key('create_first_test_button'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isDark ? AppColors.primary : AppColors.deepInk,
                          foregroundColor: isDark ? Colors.black : Colors.white,
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text("Create First Test"),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const CreateTestScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
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
                  accentSpineColor: isCompleted
                      ? AppColors.success
                      : AppColors.purple,
                  padding: const EdgeInsets.all(16),
                  backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                  borderColor: isDark ? AppColors.darkBorder : AppColors.border,
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
                              text:
                                  "Score: ${result.score.toInt()}/${result.maxScore.toInt()} (${result.percentage.toStringAsFixed(0)}%)",
                              variant: result.score >= test.passingMarks
                                  ? BadgeVariant.success
                                  : BadgeVariant.warning,
                            )
                          else if (test.attemptsCount > 0)
                            CustomBadge(
                              text: "${test.attemptsCount} Attempts",
                              variant: BadgeVariant.outline,
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        test.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.deepInk,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildInfoChip(
                            context,
                            Icons.format_list_numbered_rounded,
                            "${test.totalQuestions} Questions",
                          ),
                          const SizedBox(width: 14),
                          _buildInfoChip(
                            context,
                            Icons.timer_outlined,
                            "${test.duration.inMinutes} Mins",
                          ),
                          const SizedBox(width: 14),
                          _buildInfoChip(
                            context,
                            Icons.grade_outlined,
                            "${test.totalMarks.toInt()} Marks",
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Divider(color: isDark ? AppColors.darkBorder : AppColors.border),
                      const SizedBox(height: 10),
                      if (canCreate) ...[
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                key: Key('view_results_${test.id}'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark
                                      ? AppColors.primary
                                      : AppColors.deepInk,
                                  foregroundColor:
                                      isDark ? Colors.black : Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 9,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.people_alt_outlined,
                                  size: 16,
                                ),
                                label: const Text(
                                  'View Student Results',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          TeacherTestResultsScreen(test: test),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              key: Key('delete_test_${test.id}'),
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppColors.error,
                                size: 20,
                              ),
                              tooltip: 'Delete Test',
                              onPressed: () => _confirmDeleteTest(context, test),
                            ),
                          ],
                        ),
                      ] else ...[
                        Row(
                          children: [
                            if (isCompleted) ...[
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                                  side: BorderSide(
                                    color: isDark ? AppColors.darkBorder : AppColors.border,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.analytics_outlined,
                                  size: 16,
                                ),
                                label: const Text(
                                  "View Scorecard & Review",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => TestResultScreen(
                                        result: result,
                                        test: test,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              onPressed: () => _openTestPaper(context, test),
                              child: const Text(
                                "Retake",
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ] else ...[
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark ? AppColors.primary : AppColors.deepInk,
                                  foregroundColor: isDark ? Colors.black : Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.play_circle_outline_rounded,
                                  size: 18,
                                ),
                                label: const Text(
                                  "Start Mock Test",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                onPressed: () => _openTestPaper(context, test),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                    ],
                  ),
                );
              },
            ),
    );
  }

  Future<void> _confirmDeleteTest(BuildContext context, TestModel test) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor:
            isDark ? AppColors.darkSurfaceCard : AppColors.surface,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
            SizedBox(width: 8),
            Text('Delete Test Paper?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to permanently delete "${test.title}"?',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            const Text(
              'Warning: All associated student attempts, question responses, and score records will be permanently deleted. This action cannot be reversed.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Delete Test'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await context.read<TestProvider>().deleteTest(test.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Test "${test.title}" deleted successfully.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete test: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _openTestPaper(
    BuildContext context,
    TestModel testMetadata,
  ) async {
    final testProvider = context.read<TestProvider>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dlgCtx) {
        final isDark = Theme.of(dlgCtx).brightness == Brightness.dark;
        return Center(
          child: Card(
            color: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.border,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Fetching secure test paper...",
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    try {
      final securePaper = await testProvider.getTestPaper(testMetadata.id);
      if (context.mounted) {
        Navigator.of(context).pop(); // Dismiss loading dialog
        if (securePaper.questions.isEmpty) {
          _showErrorDialog(
            context,
            testMetadata,
            "The server returned an empty test paper.",
          );
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TestTakingScreen(test: securePaper),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Dismiss loading dialog
        _showErrorDialog(context, testMetadata, e.toString());
      }
    }
  }

  void _showErrorDialog(BuildContext context, TestModel test, String error) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
          ),
          title: const Text(
            "Unable to Load Test Paper",
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error),
          ),
          content: Text(
            "Could not retrieve the secure test questions from the server:\n\n$error\n\nFallback to raw queries or mock data is strictly prohibited.",
            style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text(
                "Cancel",
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: () {
                Navigator.pop(dialogCtx);
                _openTestPaper(context, test);
              },
              child: const Text(
                "Retry",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoChip(BuildContext context, IconData icon, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11.5,
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
