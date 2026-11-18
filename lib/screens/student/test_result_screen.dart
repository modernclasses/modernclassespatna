import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_card.dart';
import '../../models/test_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import 'test_taking_screen.dart';

class TestResultScreen extends StatelessWidget {
  final TestResultModel result;
  final TestModel test;
  final bool isTeacherView;

  const TestResultScreen({
    super.key,
    required this.result,
    required this.test,
    this.isTeacherView = false,
  });

  @override
  Widget build(BuildContext context) {
    final authUser = context.watch<AuthProvider?>()?.currentUser;
    final isStudent = authUser == null || authUser.role == UserRole.student;
    final isPassed = result.score >= test.passingMarks;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text("Exam Performance & Solutions")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Academic Performance Card (Scorecard)
            ModernCard(
              accentSpineColor: isPassed
                  ? AppColors.success
                  : AppColors.warning,
              padding: const EdgeInsets.all(18),
              backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
              borderColor: isDark ? AppColors.darkBorder : AppColors.border,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              test.title,
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              "Candidate: ${result.studentName}",
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      CustomBadge(
                        text: isPassed ? "PASSED" : "NEEDS PRACTICE",
                        variant: isPassed
                            ? BadgeVariant.success
                            : BadgeVariant.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: isDark ? AppColors.darkBorder : AppColors.border),
                  const SizedBox(height: 14),

                  // Key Performance Metrics Grid
                  Builder(
                    builder: (context) {
                      final isCompact = MediaQuery.sizeOf(context).width < 380;
                      final items = [
                        _buildMetricItem(
                          context: context,
                          label: "Total Score",
                          value:
                              "${result.score.toInt()} / ${result.maxScore.toInt()}",
                          color: AppColors.primaryDark,
                          icon: Icons.emoji_events_outlined,
                        ),
                        _buildMetricItem(
                          context: context,
                          label: "Accuracy",
                          value: "${result.percentage.toStringAsFixed(1)}%",
                          color: isPassed ? AppColors.success : AppColors.warning,
                          icon: Icons.pie_chart_outline_rounded,
                        ),
                        _buildMetricItem(
                          context: context,
                          label: "Patna Rank",
                          value: result.rank != null ? "#${result.rank}" : "—",
                          subValue: result.rank != null
                              ? (result.totalParticipants != null
                                    ? "out of ${result.totalParticipants}"
                                    : null)
                              : "Pending",
                          color: result.rank != null
                              ? AppColors.secondary
                              : AppColors.textMuted,
                          icon: Icons.leaderboard_outlined,
                        ),
                        _buildMetricItem(
                          context: context,
                          label: "Percentile",
                          value: result.percentile != null
                              ? "${result.percentile}%"
                              : "—",
                          subValue: result.percentile != null ? null : "Pending",
                          color: result.percentile != null
                              ? AppColors.purple
                              : AppColors.textMuted,
                          icon: Icons.trending_up_rounded,
                        ),
                      ];

                      if (isCompact) {
                        return Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Expanded(child: items[0]),
                                Expanded(child: items[1]),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Expanded(child: items[2]),
                                Expanded(child: items[3]),
                              ],
                            ),
                          ],
                        );
                      }

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: items.map((w) => Expanded(child: w)).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Performance Breakdown Chips
            Row(
              children: [
                Expanded(
                  child: _buildCountCard(
                    context: context,
                    title: "Correct",
                    count: result.correctCount,
                    color: AppColors.success,
                    bg: AppColors.successBg,
                    icon: Icons.check_circle_outline,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCountCard(
                    context: context,
                    title: "Incorrect",
                    count: result.incorrectCount,
                    color: AppColors.error,
                    bg: AppColors.errorBg,
                    icon: Icons.highlight_off_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCountCard(
                    context: context,
                    title: "Unattempted",
                    count: result.unattemptedCount,
                    color: AppColors.textMuted,
                    bg: AppColors.surfaceSubtle,
                    icon: Icons.help_outline_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Section Header: Detailed Solutions
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Text(
                  "Question by Question Review",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                  ),
                ),
                if (test.allowsRetake && !isTeacherView && isStudent)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppColors.primary : AppColors.deepInk,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 14),
                    label: const Text(
                      "Retake Test",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
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
            const SizedBox(height: 10),

            // Question Solutions List
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: test.questions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final q = test.questions[index];
                final response = result.responses[q.id];

                bool isCorrect = false;
                bool isAttempted = false;

                final isSubjective = q.type == QuestionType.descriptive ||
                    q.type == QuestionType.shortAnswer ||
                    q.type == QuestionType.longAnswer ||
                    (q.type == QuestionType.caseBased && q.options.isEmpty);

                if (isSubjective) {
                  isAttempted = response != null &&
                      response.writtenAnswer != null &&
                      response.writtenAnswer!.trim().isNotEmpty;
                  isCorrect = isAttempted;
                } else {
                  if (response != null &&
                      response.selectedOptionIndices.isNotEmpty) {
                    isAttempted = true;
                    final sel = List<int>.from(response.selectedOptionIndices)
                      ..sort();
                    final cor = List<int>.from(q.correctOptionIndices)..sort();
                    isCorrect = cor.isNotEmpty && sel.toString() == cor.toString();
                  }
                }

                return ModernCard(
                  accentSpineColor: isCorrect
                      ? AppColors.success
                      : isAttempted
                      ? AppColors.error
                      : (isDark ? AppColors.darkBorder : AppColors.border),
                  padding: const EdgeInsets.all(14),
                  backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                  borderColor: isDark ? AppColors.darkBorder : AppColors.border,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isCorrect
                                  ? (isDark ? AppColors.success.withValues(alpha: 0.18) : AppColors.successBg)
                                  : isAttempted
                                  ? (isDark ? AppColors.error.withValues(alpha: 0.18) : AppColors.errorBg)
                                  : (isDark ? AppColors.darkSurface : AppColors.surfaceSubtle),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isCorrect
                                    ? (isDark ? AppColors.success.withValues(alpha: 0.4) : AppColors.successBorder)
                                    : isAttempted
                                    ? (isDark ? AppColors.error.withValues(alpha: 0.4) : AppColors.errorBorder)
                                    : (isDark ? AppColors.darkBorder : AppColors.border),
                              ),
                            ),
                            child: Text(
                              "Q${index + 1}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: isCorrect
                                    ? (isDark ? const Color(0xFF86EFAC) : AppColors.success)
                                    : isAttempted
                                    ? (isDark ? const Color(0xFFFDA4AF) : AppColors.error)
                                    : (isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          CustomBadge(
                            text: isCorrect
                                ? (isSubjective ? "Submitted for Review" : "Correct (+${q.marks.toInt()})")
                                : isAttempted
                                ? (isSubjective ? "Submitted" : "Incorrect (0)")
                                : "Not Attempted (0)",
                            variant: isCorrect
                                ? BadgeVariant.success
                                : isAttempted
                                ? (isSubjective ? BadgeVariant.primary : BadgeVariant.error)
                                : BadgeVariant.outline,
                            fontSize: 9.5,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Case Passage if present
                      if (q.casePassage != null && q.casePassage!.trim().isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : AppColors.saffronMuted,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.saffronBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.menu_book_rounded,
                                    color: AppColors.saffronDark,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    test.questions.where((item) => item.casePassage == q.casePassage).length > 1
                                        ? "Case Study Passage (Sub-Q ${test.questions.where((item) => item.casePassage == q.casePassage).toList().indexOf(q) + 1} of ${test.questions.where((item) => item.casePassage == q.casePassage).length})"
                                        : "Case Study Passage",
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.saffronDark,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                q.casePassage!.trim(),
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.45,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Question Text
                      Text(
                        q.text,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Options breakdown vs Written Response
                      if (q.options.isNotEmpty) ...[
                        for (int i = 0; i < q.options.length; i++) ...[
                          _buildResultOptionTile(
                            context: context,
                            optionText: q.options[i],
                            optionIndex: i,
                            isUserSelected:
                                response?.selectedOptionIndices.contains(i) ??
                                false,
                            isCorrectOption: q.correctOptionIndices.contains(i),
                          ),
                          const SizedBox(height: 5),
                        ],
                      ] else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : AppColors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isDark ? AppColors.darkBorder : AppColors.border,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Your Submitted Answer:",
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                (response?.writtenAnswer != null && response!.writtenAnswer!.trim().isNotEmpty)
                                    ? response.writtenAnswer!.trim()
                                    : "No response provided / Unattempted.",
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                                ),
                              ),
                              if (q.sampleAnswer != null && q.sampleAnswer!.trim().isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  "Model Answer / Key Points:",
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  q.sampleAnswer!.trim(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],

                      // Explanation box
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.secondaryLight.withValues(alpha: 0.15)
                              : AppColors.secondaryMuted,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDark
                                ? AppColors.secondaryLight.withValues(alpha: 0.4)
                                : AppColors.secondaryLight.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.lightbulb_outline_rounded,
                                  size: 14,
                                  color: isDark ? const Color(0xFF93C5FD) : AppColors.secondary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  "Explanation & Concept:",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: isDark ? const Color(0xFF93C5FD) : AppColors.secondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              q.explanation,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
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
    required BuildContext context,
    required String label,
    required String value,
    String? subValue,
    required Color color,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: color,
            letterSpacing: -0.3,
          ),
        ),
        if (subValue != null)
          Text(
            subValue,
            style: TextStyle(
              fontSize: 9,
              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildCountCard({
    required BuildContext context,
    required String title,
    required int count,
    required Color color,
    required Color bg,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveBg = isDark ? color.withValues(alpha: 0.18) : bg;
    final effectiveColor = isDark
        ? (color == AppColors.textMuted ? AppColors.darkTextMuted : color)
        : color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: effectiveBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 15, color: effectiveColor),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "$count",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: effectiveColor,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 9.5,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultOptionTile({
    required BuildContext context,
    required String optionText,
    required int optionIndex,
    required bool isUserSelected,
    required bool isCorrectOption,
  }) {
    final label = String.fromCharCode(65 + optionIndex);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bg = isDark ? AppColors.darkSurface : AppColors.surfaceSubtle;
    Color border = isDark ? AppColors.darkBorder : AppColors.border;
    Widget? icon;

    if (isCorrectOption) {
      bg = isDark
          ? AppColors.success.withValues(alpha: 0.18)
          : AppColors.successBg;
      border = isDark
          ? AppColors.success.withValues(alpha: 0.4)
          : AppColors.successBorder;
      icon = Icon(
        Icons.check_rounded,
        size: 15,
        color: isDark ? const Color(0xFF86EFAC) : AppColors.success,
      );
    } else if (isUserSelected && !isCorrectOption) {
      bg = isDark
          ? AppColors.error.withValues(alpha: 0.18)
          : AppColors.errorBg;
      border = isDark
          ? AppColors.error.withValues(alpha: 0.4)
          : AppColors.errorBorder;
      icon = Icon(
        Icons.close_rounded,
        size: 15,
        color: isDark ? const Color(0xFFFDA4AF) : AppColors.error,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Text(
            "$label.",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11.5,
              color: isCorrectOption
                  ? (isDark ? const Color(0xFF86EFAC) : AppColors.success)
                  : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              optionText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: (isCorrectOption || isUserSelected)
                    ? FontWeight.w700
                    : FontWeight.normal,
                color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
              ),
            ),
          ),
          ?icon,
        ],
      ),
    );
  }
}
