import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_card.dart';
import '../../models/test_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/test_provider.dart';
import 'test_result_screen.dart';

/// Formatter that prevents copy-paste into exam text inputs.
class _BlockPasteTextInputFormatter extends TextInputFormatter {
  final VoidCallback onPasteBlocked;

  _BlockPasteTextInputFormatter({required this.onPasteBlocked});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Normal human typing adds 1 char (or 2 for emoji/surrogate pair).
    // Deletions decrease text length.
    final lengthDelta = newValue.text.length - oldValue.text.length;
    if (lengthDelta > 2) {
      onPasteBlocked();
      return oldValue;
    }
    return newValue;
  }
}

class TestTakingScreen extends StatefulWidget {
  final TestModel test;

  const TestTakingScreen({super.key, required this.test});

  @override
  State<TestTakingScreen> createState() => _TestTakingScreenState();
}

class _TestTakingScreenState extends State<TestTakingScreen> with WidgetsBindingObserver {
  Timer? _timer;
  late int _remainingSeconds;
  int _secondsElapsed = 0;
  final Map<String, TextEditingController> _descriptiveControllers = {};

  bool _appSwitchedAway = false;
  bool _isResettingDueToAppSwitch = false;
  DateTime? _lastPasteWarningTime;

  void _showAntiCheatPasteWarning() {
    if (!mounted) return;
    final now = DateTime.now();
    if (_lastPasteWarningTime != null &&
        now.difference(_lastPasteWarningTime!) < const Duration(seconds: 2)) {
      return;
    }
    _lastPasteWarningTime = now;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.shield_outlined, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                "Copy/Pasting answers is disabled during examinations. Please type your response directly.",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.error,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  TextEditingController _getControllerForQuestion(String qId, String? initialText) {
    return _descriptiveControllers.putIfAbsent(qId, () {
      return TextEditingController(text: initialText ?? '');
    });
  }

  void _flushAllDescriptiveAnswers() {
    if (!mounted) return;
    final testProvider = context.read<TestProvider>();
    _descriptiveControllers.forEach((qId, ctrl) {
      final text = ctrl.text.trim();
      final currentResp = testProvider.currentResponses[qId];
      if (currentResp?.writtenAnswer != text) {
        testProvider.setDescriptiveAnswerForQuestion(qId, text);
      }
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
          _secondsElapsed++;
        });
        context.read<TestProvider>().updateTimer(
          Duration(seconds: _secondsElapsed),
        );
      } else {
        _timer?.cancel();
        _autoSubmit();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _remainingSeconds = widget.test.duration.inSeconds;

    if (widget.test.questions.isEmpty) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TestProvider>().startTest(widget.test);
    });

    _startTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (_isSubmitting || _isResettingDueToAppSwitch) return;

    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _appSwitchedAway = true;
      _timer?.cancel();
    } else if (state == AppLifecycleState.resumed && _appSwitchedAway) {
      _handleAppSwitchViolation();
    }
  }

  void _handleAppSwitchViolation() {
    if (_isResettingDueToAppSwitch || _isSubmitting || !mounted) return;
    setState(() {
      _isResettingDueToAppSwitch = true;
    });

    _timer?.cancel();

    // Reset test state immediately in provider
    final testProvider = context.read<TestProvider>();
    testProvider.resetActiveTest();

    // Clear all local text controllers
    for (final ctrl in _descriptiveControllers.values) {
      ctrl.clear();
    }
    _descriptiveControllers.clear();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
                SizedBox(width: 8),
                Text(
                  "Exam Integrity Alert",
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            content: const Text(
              "You switched away from or minimized the exam screen.\n\n"
              "Under Modern Classes Patna examination integrity rules, switching apps during a live test is prohibited.\n\n"
              "Your test session has been reset. You must start the test all over from Question 1.",
              style: TextStyle(fontSize: 13.5, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                },
                child: const Text("Exit to Tests"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepInk,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _restartTestFromScratch();
                },
                child: const Text("Start Test Over"),
              ),
            ],
          ),
        );
      },
    );
  }

  void _restartTestFromScratch() {
    if (!mounted) return;
    final testProvider = context.read<TestProvider>();
    testProvider.startTest(widget.test);

    setState(() {
      _remainingSeconds = widget.test.duration.inSeconds;
      _secondsElapsed = 0;
      _appSwitchedAway = false;
      _isResettingDueToAppSwitch = false;
    });

    _startTimer();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Test restarted from Question 1 with a fresh timer."),
        backgroundColor: AppColors.deepInk,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    for (final ctrl in _descriptiveControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  bool _isSubmitting = false;

  Future<void> _autoSubmit() async {
    if (_isSubmitting) return;
    _flushAllDescriptiveAnswers();
    setState(() => _isSubmitting = true);

    final auth = context.read<AuthProvider>();
    final testProvider = context.read<TestProvider>();

    try {
      final result = await testProvider.submitTest(
        studentId: auth.currentUser.id,
        studentName: auth.currentUser.name,
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => TestResultScreen(result: result, test: widget.test),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) {
            final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                ),
              ),
              title: const Text(
                "Submission Failed",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
              content: Text(
                "Unable to save your test submission to the cloud:\n$e\n\nYour answers have been preserved. Please check your network and retry.",
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text(
                    "Review Answers",
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
                    _autoSubmit();
                  },
                  child: const Text(
                    "Retry Submission",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      }
    }
  }

  void _confirmSubmit(BuildContext context) {
    _flushAllDescriptiveAnswers();
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
      builder: (dialogCtx) {
        final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.border,
            ),
          ),
          title: Text(
            "Submit Test Confirmation",
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Are you sure you want to finish and submit your exam?",
                style: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                  ),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow(
                      context,
                      "Total Questions",
                      "${widget.test.totalQuestions}",
                      isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                    ),
                    const SizedBox(height: 6),
                    _buildSummaryRow(
                      context,
                      "Answered",
                      "$answeredCount",
                      AppColors.success,
                    ),
                    const SizedBox(height: 6),
                    _buildSummaryRow(
                      context,
                      "Marked for Review",
                      "$markedCount",
                      AppColors.warning,
                    ),
                    const SizedBox(height: 6),
                    _buildSummaryRow(
                      context,
                      "Unattempted",
                      "$unattempted",
                      AppColors.error,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(
                "Resume Test",
                style: TextStyle(
                  color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.primary : AppColors.deepInk,
                foregroundColor: isDark ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: () {
                Navigator.pop(dialogCtx);
                _timer?.cancel();
                _autoSubmit();
              },
              child: const Text(
                "Confirm & Submit",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryRow(BuildContext context, String label, String value, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  void _openQuestionPalette(BuildContext context, TestProvider testProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
                      Text(
                        "Question Palette",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 20,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                        ),
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
                      _buildLegendItem(context, "Answered", AppColors.success),
                      _buildLegendItem(context, "Review", AppColors.warning),
                      _buildLegendItem(
                        context,
                        "Unanswered",
                        isDark ? AppColors.darkBorder : AppColors.border,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Divider(color: isDark ? AppColors.darkBorder : AppColors.border),
                  const SizedBox(height: 14),
                  // Grid
                  Expanded(
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 1.2,
                          ),
                      itemCount: widget.test.questions.length,
                      itemBuilder: (context, index) {
                        final q = widget.test.questions[index];
                        final resp = testProvider.currentResponses[q.id];
                        final isCurrent =
                            index == testProvider.currentQuestionIndex;

                        Color bg = isDark
                            ? AppColors.darkSurfaceCard
                            : AppColors.surfaceSubtle;
                        Color textC = isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary;
                        Color borderC = isDark ? AppColors.darkBorder : AppColors.border;

                        if (resp != null) {
                          if (resp.isMarkedForReview) {
                            bg = isDark
                                ? AppColors.warning.withValues(alpha: 0.18)
                                : AppColors.warningBg;
                            textC = isDark ? const Color(0xFFFCD34D) : AppColors.warning;
                            borderC = isDark
                                ? AppColors.warning.withValues(alpha: 0.4)
                                : AppColors.warningBorder;
                          } else if (resp.selectedOptionIndices.isNotEmpty ||
                              (resp.writtenAnswer != null &&
                                  resp.writtenAnswer!.isNotEmpty)) {
                            bg = isDark
                                ? AppColors.success.withValues(alpha: 0.18)
                                : AppColors.successBg;
                            textC = isDark ? const Color(0xFF86EFAC) : AppColors.success;
                            borderC = isDark
                                ? AppColors.success.withValues(alpha: 0.4)
                                : AppColors.successBorder;
                          }
                        }

                        if (isCurrent) {
                          borderC = isDark ? AppColors.primary : AppColors.deepInk;
                        }

                        return InkWell(
                          onTap: () {
                            _flushAllDescriptiveAnswers();
                            testProvider.jumpToQuestion(index);
                            Navigator.pop(ctx);
                          },
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: borderC,
                                width: isCurrent ? 2 : 1,
                              ),
                            ),
                            child: Text(
                              "Q${index + 1}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: textC,
                                fontSize: 12.5,
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

  Widget _buildLegendItem(BuildContext context, String label, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: color),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.test.questions.isEmpty) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(title: Text(widget.test.title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: AppColors.error,
                ),
                const SizedBox(height: 16),
                Text(
                  "No Question Paper Available",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "The question paper could not be loaded from the secure server. Please return to the test series and try again.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.deepInk,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Go Back"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final testProvider = context.watch<TestProvider>();
    final currentQIndex = testProvider.currentQuestionIndex;
    final currentQuestion = widget.test.questions[currentQIndex];
    final currentResponse =
        testProvider.currentResponses[currentQuestion.id] ??
        UserQuestionResponse(questionId: currentQuestion.id);

    final duration = Duration(seconds: _remainingSeconds);
    final timeString = Formatters.formatDuration(duration);
    final isTimeRunningOut = _remainingSeconds < 180; // Under 3 mins
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_isSubmitting) {
          _confirmSubmit(context);
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
          automaticallyImplyLeading: false,
          title: Text(
            widget.test.title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
            ),
          ),
          actions: [
            // Timer Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isTimeRunningOut
                    ? (isDark
                        ? AppColors.error.withValues(alpha: 0.18)
                        : AppColors.errorBg)
                    : (isDark
                        ? AppColors.darkSurfaceCard
                        : AppColors.surfaceSubtle),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isTimeRunningOut
                      ? (isDark
                          ? AppColors.error.withValues(alpha: 0.4)
                          : AppColors.errorBorder)
                      : (isDark ? AppColors.darkBorder : AppColors.border),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 15,
                    color: isTimeRunningOut
                        ? AppColors.error
                        : (isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.deepInk),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    timeString,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: isTimeRunningOut
                          ? AppColors.error
                          : (isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.deepInk),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.grid_view_rounded,
                size: 20,
                color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
              ),
              tooltip: "Question Palette",
              onPressed: () => _openQuestionPalette(context, testProvider),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                // Question Progress Bar & Index Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  color: isDark ? AppColors.darkSurface : AppColors.surface,
                  child: Row(
                    children: [
                      Text(
                        "Question ${currentQIndex + 1} of ${widget.test.totalQuestions}",
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.deepInk,
                        ),
                      ),
                      const Spacer(),
                      CustomBadge(
                        text: "+${currentQuestion.marks.toInt()} Marks",
                        variant: BadgeVariant.success,
                        fontSize: 9.5,
                      ),
                      const SizedBox(width: 6),
                      CustomBadge(
                        text: _getQuestionTypeName(currentQuestion.type),
                        variant: BadgeVariant.outline,
                        fontSize: 9.5,
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                ),

                // Anti-Cheating Security Status Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                  color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceSubtle,
                  child: const Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 13, color: AppColors.saffronDark),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "Anti-Cheat Active: Copy/Paste is blocked. Switching or closing the app restarts the test.",
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                ),

                // Question Content & Options
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Case Study Passage if available (Copy-disabled)
                        if (currentQuestion.casePassage != null &&
                            currentQuestion.casePassage!.trim().isNotEmpty) ...[
                          SelectionContainer.disabled(
                            child: ModernCard(
                              padding: const EdgeInsets.all(16),
                              backgroundColor: Theme.of(context).brightness == Brightness.dark
                                  ? AppColors.darkSurfaceCard
                                  : AppColors.saffronMuted,
                              borderColor: AppColors.saffronBorder,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.menu_book_rounded,
                                        color: AppColors.saffronDark,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        (widget.test.questions.where((q) => q.casePassage == currentQuestion.casePassage).length > 1
                                            ? "Case Study Passage (Question ${widget.test.questions.where((q) => q.casePassage == currentQuestion.casePassage).toList().indexOf(currentQuestion) + 1} of ${widget.test.questions.where((q) => q.casePassage == currentQuestion.casePassage).length})"
                                            : "Case Study / Comprehension Passage"),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppColors.saffronDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    currentQuestion.casePassage!,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      height: 1.55,
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.deepInk,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Question Prompt Card (Copy-disabled)
                        SelectionContainer.disabled(
                          child: ModernCard(
                            padding: const EdgeInsets.all(16),
                            backgroundColor: isDark
                                ? AppColors.darkSurfaceCard
                                : AppColors.surface,
                            borderColor:
                                isDark ? AppColors.darkBorder : AppColors.border,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (currentQuestion.casePassage != null &&
                                    currentQuestion.casePassage!.trim().isNotEmpty &&
                                    widget.test.questions.where((q) => q.casePassage == currentQuestion.casePassage).length > 1)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Text(
                                      "Sub-Question ${widget.test.questions.where((q) => q.casePassage == currentQuestion.casePassage).toList().indexOf(currentQuestion) + 1} of ${widget.test.questions.where((q) => q.casePassage == currentQuestion.casePassage).length}:",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.saffronDark,
                                      ),
                                    ),
                                  ),
                                Text(
                                  currentQuestion.text,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    height: 1.5,
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.deepInk,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Options / Answer Input
                        if (currentQuestion.type == QuestionType.descriptive ||
                            currentQuestion.type == QuestionType.shortAnswer ||
                            currentQuestion.type == QuestionType.longAnswer ||
                            (currentQuestion.type == QuestionType.caseBased &&
                                currentQuestion.options.isEmpty)) ...[
                          Text(
                            currentQuestion.type == QuestionType.shortAnswer
                                ? "Write your concise answer (2-4 sentences):"
                                : currentQuestion.type == QuestionType.longAnswer
                                    ? "Write your detailed essay / analysis:"
                                    : "Type your response below:",
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Actions(
                            actions: {
                              PasteTextIntent: CallbackAction<PasteTextIntent>(
                                onInvoke: (intent) {
                                  _showAntiCheatPasteWarning();
                                  return null;
                                },
                              ),
                            },
                            child: TextField(
                              maxLines: currentQuestion.type == QuestionType.shortAnswer
                                  ? 4
                                  : currentQuestion.type == QuestionType.longAnswer
                                      ? 9
                                      : 6,
                              controller: _getControllerForQuestion(currentQuestion.id, currentResponse.writtenAnswer),
                              enableInteractiveSelection: false,
                              contextMenuBuilder: (context, editableTextState) => const SizedBox.shrink(),
                              enableSuggestions: false,
                              autocorrect: false,
                              inputFormatters: [
                                _BlockPasteTextInputFormatter(
                                  onPasteBlocked: _showAntiCheatPasteWarning,
                                ),
                              ],
                              decoration: InputDecoration(
                                hintText: currentQuestion.type == QuestionType.shortAnswer
                                    ? "Enter brief answer points (manual typing only)..."
                                    : currentQuestion.type == QuestionType.longAnswer
                                        ? "Enter structured response with introduction, arguments, and conclusion..."
                                        : "Enter solution / analysis points...",
                                helperText: "Anti-Cheating Protection: Copy/Pasting is blocked.",
                                helperStyle: const TextStyle(
                                  fontSize: 10.5,
                                  color: AppColors.textSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              onChanged: (val) {
                                testProvider.setDescriptiveAnswerForQuestion(currentQuestion.id, val);
                              },
                            ),
                          ),
                        ] else ...[
                          // MCQ / True False Options
                          for (
                            int i = 0;
                            i < currentQuestion.options.length;
                            i++
                          ) ...[
                            _buildOptionTile(
                              context: context,
                              optionText: currentQuestion.options[i],
                              optionIndex: i,
                              type: currentQuestion.type,
                              isSelected: currentResponse.selectedOptionIndices
                                  .contains(i),
                              onTap: () {
                                testProvider.selectOptionForCurrentQuestion(i);
                              },
                            ),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),

                // Bottom Navigation Actions
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.surface,
                    border: Border(
                      top: BorderSide(
                        color: isDark ? AppColors.darkBorder : AppColors.border,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        // Mark for review toggle
                        IconButton(
                          tooltip: currentResponse.isMarkedForReview
                              ? "Unmark Review"
                              : "Mark for Review",
                          icon: Icon(
                            currentResponse.isMarkedForReview
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            color: currentResponse.isMarkedForReview
                                ? AppColors.warning
                                : (isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.textMuted),
                          ),
                          onPressed: () => testProvider.toggleMarkForReview(),
                        ),
                        // Clear selection
                        IconButton(
                          tooltip: "Clear Response",
                          icon: Icon(
                            Icons.refresh,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.textMuted,
                            size: 20,
                          ),
                          onPressed: () {
                            _descriptiveControllers[currentQuestion.id]?.clear();
                            testProvider.clearCurrentResponse();
                          },
                        ),
                        const Spacer(),
                        if (currentQIndex > 0) ...[
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.deepInk,
                              side: BorderSide(
                                color: isDark
                                    ? AppColors.darkBorder
                                    : AppColors.border,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                            ),
                            onPressed: () =>
                                (() {
                              _flushAllDescriptiveAnswers();
                              testProvider.jumpToQuestion(currentQIndex - 1);
                            })(),
                            child: const Text(
                              "Previous",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (currentQIndex < widget.test.totalQuestions - 1) ...[
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark
                                  ? AppColors.primary
                                  : AppColors.deepInk,
                              foregroundColor: isDark ? Colors.black : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                            onPressed: () =>
                                (() {
                              _flushAllDescriptiveAnswers();
                              testProvider.jumpToQuestion(currentQIndex + 1);
                            })(),
                            child: const Text(
                              "Next",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ] else ...[
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                            icon: const Icon(
                              Icons.check_circle_outline,
                              size: 16,
                            ),
                            label: const Text(
                              "Submit Test",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            onPressed: () => _confirmSubmit(context),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_isSubmitting)
              Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppColors.primary),
                      SizedBox(height: 16),
                      Text(
                        "Submitting answers to cloud...",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
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
    required BuildContext context,
    required String optionText,
    required int optionIndex,
    required QuestionType type,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final optionLabel = String.fromCharCode(65 + optionIndex);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isSelected
        ? (isDark ? AppColors.primary.withValues(alpha: 0.18) : AppColors.saffronMuted)
        : (isDark ? AppColors.darkSurfaceCard : AppColors.surface);
    final borderColor = isSelected
        ? (isDark ? AppColors.primaryLight : AppColors.primaryDark)
        : (isDark ? AppColors.darkBorder : AppColors.border);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? AppColors.primary : AppColors.primaryDark)
                    : (isDark ? AppColors.darkSurface : AppColors.surfaceSubtle),
                shape: BoxShape.circle,
              ),
              child: Text(
                optionLabel,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isSelected
                      ? (isDark ? Colors.black : Colors.white)
                      : (isDark ? AppColors.darkTextPrimary : AppColors.deepInk),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                optionText,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                  height: 1.35,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
              ),
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
      case QuestionType.shortAnswer:
        return "Short Answer";
      case QuestionType.longAnswer:
        return "Long Answer";
      case QuestionType.caseBased:
        return "Case Study";
      case QuestionType.descriptive:
        return "Descriptive";
    }
  }
}
