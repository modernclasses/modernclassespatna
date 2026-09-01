import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_card.dart';
import '../../models/test_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/test_provider.dart';
import 'test_result_screen.dart';

class TestTakingScreen extends StatefulWidget {
  final TestModel test;

  const TestTakingScreen({super.key, required this.test});

  @override
  State<TestTakingScreen> createState() => _TestTakingScreenState();
}

class _TestTakingScreenState extends State<TestTakingScreen> {
  late Timer _timer;
  late int _remainingSeconds;
  int _secondsElapsed = 0;
  final TextEditingController _descriptiveController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.test.duration.inSeconds;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TestProvider>().startTest(widget.test);
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
          _secondsElapsed++;
        });
        context.read<TestProvider>().updateTimer(Duration(seconds: _secondsElapsed));
      } else {
        _timer.cancel();
        _autoSubmit();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _descriptiveController.dispose();
    super.dispose();
  }

  void _autoSubmit() {
    final auth = context.read<AuthProvider>();
    final testProvider = context.read<TestProvider>();
    final result = testProvider.submitTest(
      studentId: auth.currentUser.id,
      studentName: auth.currentUser.name,
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TestResultScreen(result: result, test: widget.test),
      ),
    );
  }

  void _confirmSubmit(BuildContext context) {
    final testProvider = context.read<TestProvider>();
    final responses = testProvider.currentResponses;

    int answeredCount = 0;
    int markedCount = 0;

    for (var q in widget.test.questions) {
      final r = responses[q.id];
      if (r != null) {
        if (r.selectedOptionIndices.isNotEmpty ||
            (r.writtenAnswer != null && r.writtenAnswer!.isNotEmpty)) {
          answeredCount++;
        }
        if (r.isMarkedForReview) {
          markedCount++;
        }
      }
    }

    final unattempted = widget.test.totalQuestions - answeredCount;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Submit Test Confirmation", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Are you sure you want to finish and submit your exam?",
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  _buildSummaryRow("Total Questions", "${widget.test.totalQuestions}", AppTheme.textPrimary),
                  const SizedBox(height: 6),
                  _buildSummaryRow("Answered", "$answeredCount", AppTheme.success),
                  const SizedBox(height: 6),
                  _buildSummaryRow("Marked for Review", "$markedCount", AppTheme.warning),
                  const SizedBox(height: 6),
                  _buildSummaryRow("Unattempted", "$unattempted", AppTheme.error),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text("Resume Test", style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              _timer.cancel();
              _autoSubmit();
            },
            child: const Text("Confirm & Submit"),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  void _openQuestionPalette(BuildContext context, TestProvider testProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Question Palette",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Legend
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _buildLegendItem("Answered", AppTheme.success),
                      _buildLegendItem("Review", AppTheme.warning),
                      _buildLegendItem("Unanswered", AppTheme.surfaceElevated),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: AppTheme.border),
                  const SizedBox(height: 16),
                  // Grid
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.2,
                      ),
                      itemCount: widget.test.questions.length,
                      itemBuilder: (context, index) {
                        final q = widget.test.questions[index];
                        final resp = testProvider.currentResponses[q.id];
                        final isCurrent = index == testProvider.currentQuestionIndex;

                        Color bg = AppTheme.surfaceElevated;
                        Color textC = AppTheme.textSecondary;
                        Color borderC = AppTheme.border;

                        if (resp != null) {
                          if (resp.isMarkedForReview) {
                            bg = AppTheme.warning.withValues(alpha: 0.2);
                            textC = AppTheme.warning;
                            borderC = AppTheme.warning;
                          } else if (resp.selectedOptionIndices.isNotEmpty ||
                              (resp.writtenAnswer != null && resp.writtenAnswer!.isNotEmpty)) {
                            bg = AppTheme.success.withValues(alpha: 0.2);
                            textC = AppTheme.success;
                            borderC = AppTheme.success;
                          }
                        }

                        if (isCurrent) {
                          borderC = AppTheme.primary;
                        }

                        return InkWell(
                          onTap: () {
                            testProvider.jumpToQuestion(index);
                            Navigator.pop(ctx);
                          },
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: borderC, width: isCurrent ? 2 : 1),
                            ),
                            child: Text(
                              "Q${index + 1}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: textC,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: color),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final testProvider = context.watch<TestProvider>();
    final currentQIndex = testProvider.currentQuestionIndex;
    final currentQuestion = widget.test.questions[currentQIndex];
    final currentResponse = testProvider.currentResponses[currentQuestion.id] ??
        UserQuestionResponse(questionId: currentQuestion.id);

    final duration = Duration(seconds: _remainingSeconds);
    final timeString = Formatters.formatDuration(duration);
    final isTimeRunningOut = _remainingSeconds < 180; // Under 3 mins

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _confirmSubmit(context);
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          automaticallyImplyLeading: false,
          title: Text(
            widget.test.title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          actions: [
            // Timer Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isTimeRunningOut
                    ? AppTheme.error.withValues(alpha: 0.15)
                    : AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isTimeRunningOut ? AppTheme.error : AppTheme.borderLight,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: isTimeRunningOut ? AppTheme.error : AppTheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    timeString,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isTimeRunningOut ? AppTheme.error : AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.grid_view_rounded, size: 20),
              tooltip: "Question Palette",
              onPressed: () => _openQuestionPalette(context, testProvider),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            // Question Progress Bar & Index Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppTheme.surface,
              child: Row(
                children: [
                  Text(
                    "Question ${currentQIndex + 1} of ${widget.test.totalQuestions}",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  CustomBadge(
                    text: "+${currentQuestion.marks.toInt()} Marks",
                    variant: BadgeVariant.success,
                    fontSize: 10,
                  ),
                  const SizedBox(width: 8),
                  CustomBadge(
                    text: _getQuestionTypeName(currentQuestion.type),
                    variant: BadgeVariant.outline,
                    fontSize: 10,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.border),

            // Question Content & Options
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question Prompt
                    ModernCard(
                      padding: const EdgeInsets.all(18),
                      backgroundColor: AppTheme.surfaceCard,
                      child: Text(
                        currentQuestion.text,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Options / Answer Input
                    if (currentQuestion.type == QuestionType.descriptive) ...[
                      const Text(
                        "Type your response below:",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        maxLines: 6,
                        controller: _descriptiveController..text = currentResponse.writtenAnswer ?? "",
                        decoration: const InputDecoration(
                          hintText: "Enter explanation / solution points...",
                        ),
                        onChanged: (val) {
                          testProvider.setDescriptiveAnswer(val);
                        },
                      ),
                    ] else ...[
                      // MCQ / True False Options
                      for (int i = 0; i < currentQuestion.options.length; i++) ...[
                        _buildOptionTile(
                          optionText: currentQuestion.options[i],
                          optionIndex: i,
                          type: currentQuestion.type,
                          isSelected: currentResponse.selectedOptionIndices.contains(i),
                          onTap: () {
                            testProvider.selectOptionForCurrentQuestion(i);
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ],
                ),
              ),
            ),

            // Bottom Navigation Actions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    // Mark for review toggle
                    IconButton(
                      tooltip: currentResponse.isMarkedForReview ? "Unmark Review" : "Mark for Review",
                      icon: Icon(
                        currentResponse.isMarkedForReview ? Icons.bookmark : Icons.bookmark_border,
                        color: currentResponse.isMarkedForReview ? AppTheme.warning : AppTheme.textMuted,
                      ),
                      onPressed: () => testProvider.toggleMarkForReview(),
                    ),
                    // Clear selection
                    IconButton(
                      tooltip: "Clear Response",
                      icon: const Icon(Icons.refresh, color: AppTheme.textMuted, size: 20),
                      onPressed: () => testProvider.clearCurrentResponse(),
                    ),
                    const Spacer(),
                    if (currentQIndex > 0) ...[
                      OutlinedButton(
                        onPressed: () => testProvider.jumpToQuestion(currentQIndex - 1),
                        child: const Text("Previous"),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (currentQIndex < widget.test.totalQuestions - 1) ...[
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: () => testProvider.jumpToQuestion(currentQIndex + 1),
                        child: const Text("Next"),
                      ),
                    ] else ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text("Submit Test"),
                        onPressed: () => _confirmSubmit(context),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required String optionText,
    required int optionIndex,
    required QuestionType type,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final optionLabel = String.fromCharCode(65 + optionIndex); // A, B, C, D

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withValues(alpha: 0.12) : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary : AppTheme.surfaceElevated,
                shape: BoxShape.circle,
              ),
              child: Text(
                optionLabel,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isSelected ? Colors.black : AppTheme.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                optionText,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                  height: 1.35,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, size: 20, color: AppTheme.primary),
          ],
        ),
      ),
    );
  }

  String _getQuestionTypeName(QuestionType type) {
    switch (type) {
      case QuestionType.singleChoice:
        return "Single Choice";
      case QuestionType.multipleChoice:
        return "Multiple Choice";
      case QuestionType.trueFalse:
        return "True / False";
      case QuestionType.descriptive:
        return "Descriptive";
    }
  }
}
