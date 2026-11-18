import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_error_view.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_card.dart';
import '../../features/tests/data/models/test_model.dart';
import '../../features/tests/logic/test_provider.dart';
import '../student/test_result_screen.dart';

enum SubmissionFilter { all, passed, needsPractice }

/// Dedicated Teacher/Admin Screen for viewing individual student exam submissions,
/// question-level answers, scores, and evaluation summaries.
class TeacherTestResultsScreen extends StatefulWidget {
  final TestModel test;

  const TeacherTestResultsScreen({super.key, required this.test});

  @override
  State<TeacherTestResultsScreen> createState() =>
      _TeacherTestResultsScreenState();
}

class _TeacherTestResultsScreenState extends State<TeacherTestResultsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<TestResultModel> _submissions = [];
  String _searchQuery = '';
  SubmissionFilter _selectedFilter = SubmissionFilter.all;

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await context
          .read<TestProvider>()
          .getTestSubmissionsForTest(widget.test.id);
      if (mounted) {
        setState(() {
          _submissions = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<TestResultModel> get _filteredSubmissions {
    return _submissions.where((sub) {
      final matchesSearch = _searchQuery.isEmpty ||
          sub.studentName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          sub.studentId.toLowerCase().contains(_searchQuery.toLowerCase());

      if (!matchesSearch) return false;

      final isPassed = sub.score >= widget.test.passingMarks;
      switch (_selectedFilter) {
        case SubmissionFilter.all:
          return true;
        case SubmissionFilter.passed:
          return isPassed;
        case SubmissionFilter.needsPractice:
          return !isPassed;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Student Submissions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.test.title,
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Results',
            onPressed: _loadSubmissions,
          ),
        ],
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return const Center(child: AppLoadingIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: AppErrorView(
          message: _errorMessage!,
          onRetry: _loadSubmissions,
        ),
      );
    }

    if (_submissions.isEmpty) {
      return Center(
        child: AppEmptyState(
          icon: Icons.assignment_turned_in_outlined,
          title: 'No Student Submissions',
          description:
              'No enrolled students have submitted attempts for "${widget.test.title}" yet.',
        ),
      );
    }

    return Column(
      children: [
        // Summary Performance Card
        _buildSummaryHeader(isDark),

        // Search & Filter Row
        _buildFilterControls(isDark),

        // Submissions List
        Expanded(
          child: _filteredSubmissions.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      'No matching submissions found.',
                      style: TextStyle(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredSubmissions.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final sub = _filteredSubmissions[index];
                    return _buildSubmissionCard(sub, isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSummaryHeader(bool isDark) {
    final total = _submissions.length;
    final passedCount =
        _submissions.where((s) => s.score >= widget.test.passingMarks).length;
    final avgScore = total > 0
        ? _submissions.map((s) => s.score).reduce((a, b) => a + b) / total
        : 0.0;
    final maxScore = total > 0
        ? _submissions.map((s) => s.score).reduce((a, b) => a > b ? a : b)
        : 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryMetric(
            label: 'Total Attempts',
            value: '$total',
            color: AppColors.primary,
          ),
          Container(
            height: 30,
            width: 1,
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
          _buildSummaryMetric(
            label: 'Pass Rate',
            value: total > 0
                ? '${((passedCount / total) * 100).toStringAsFixed(0)}%'
                : '0%',
            color: AppColors.success,
          ),
          Container(
            height: 30,
            width: 1,
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
          _buildSummaryMetric(
            label: 'Avg Score',
            value: avgScore.toStringAsFixed(1),
            color: AppColors.secondary,
          ),
          Container(
            height: 30,
            width: 1,
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
          _buildSummaryMetric(
            label: 'Highest',
            value: maxScore.toStringAsFixed(1),
            color: AppColors.warning,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterControls(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          // Search Box
          TextField(
            decoration: InputDecoration(
              hintText: 'Search student by name...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
          const SizedBox(height: 8),

          // Filter Segmented Controls
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'All (${_submissions.length})',
                  filter: SubmissionFilter.all,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label:
                      'Passed (${_submissions.where((s) => s.score >= widget.test.passingMarks).length})',
                  filter: SubmissionFilter.passed,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label:
                      'Needs Practice (${_submissions.where((s) => s.score < widget.test.passingMarks).length})',
                  filter: SubmissionFilter.needsPractice,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required SubmissionFilter filter,
    required bool isDark,
  }) {
    final isSelected = _selectedFilter == filter;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFilter = filter),
      selectedColor: isDark
          ? AppColors.primary.withValues(alpha: 0.25)
          : AppColors.primary.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _buildSubmissionCard(TestResultModel sub, bool isDark) {
    final isPassed = sub.score >= widget.test.passingMarks;

    return ModernCard(
      accentSpineColor: isPassed ? AppColors.success : AppColors.warning,
      padding: const EdgeInsets.all(14),
      backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
      borderColor: isDark ? AppColors.darkBorder : AppColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  sub.studentName,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.deepInk,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              CustomBadge(
                text: isPassed ? 'PASSED' : 'NEEDS PRACTICE',
                variant:
                    isPassed ? BadgeVariant.success : BadgeVariant.warning,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildInfoItem(
                label: 'Score',
                value:
                    '${sub.score.toStringAsFixed(1)} / ${sub.maxScore.toStringAsFixed(0)}',
                isDark: isDark,
              ),
              const SizedBox(width: 16),
              _buildInfoItem(
                label: 'Percentage',
                value: '${sub.percentage.toStringAsFixed(1)}%',
                isDark: isDark,
              ),
              const SizedBox(width: 16),
              _buildInfoItem(
                label: 'Submitted',
                value: Formatters.timeAgo(sub.submittedAt),
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: isDark ? AppColors.darkBorder : AppColors.border),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                'Correct: ${sub.correctCount}  •  Wrong: ${sub.incorrectCount}  •  Skipped: ${sub.unattemptedCount}',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: const Size(0, 32),
                  side: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                  ),
                ),
                icon: const Icon(Icons.visibility_outlined, size: 14),
                label: const Text(
                  'Inspect Solutions',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TestResultScreen(
                        result: sub,
                        test: widget.test,
                        isTeacherView: true,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color:
                isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
          ),
        ),
      ],
    );
  }
}
