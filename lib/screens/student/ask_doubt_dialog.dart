import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/modern_button.dart';
import '../../features/courses/data/models/batch_model.dart';
import '../../features/courses/data/models/course_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/doubt_provider.dart';
import '../../providers/course_provider.dart';

class AskDoubtDialog extends StatefulWidget {
  const AskDoubtDialog({super.key});

  @override
  State<AskDoubtDialog> createState() => _AskDoubtDialogState();
}

class _AskDoubtDialogState extends State<AskDoubtDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedBatchId;
  String _selectedSubject = "General Studies";
  final TextEditingController _questionController = TextEditingController();

  List<String> _getSubjectsForSelectedBatch(CourseProvider courseProvider) {
    if (_selectedBatchId == null) {
      return const ["General Studies", "Exam Strategy", "General Doubt"];
    }

    final batch = courseProvider.myEnrolledBatches.cast<BatchModel?>().firstWhere(
          (b) => b?.id == _selectedBatchId,
          orElse: () => null,
        ) ??
        courseProvider.batches.cast<BatchModel?>().firstWhere(
          (b) => b?.id == _selectedBatchId,
          orElse: () => null,
        );

    if (batch == null) {
      return const ["General Studies", "Exam Strategy", "General Doubt"];
    }

    final course = courseProvider.courses.cast<CourseModel?>().firstWhere(
          (c) => c?.id == batch.courseId,
          orElse: () => null,
        );

    if (course != null && course.subjects.isNotEmpty) {
      return course.subjects;
    }

    if (course != null && course.category.isNotEmpty) {
      return [course.category, "General Doubt", "Exam Strategy"];
    }

    return const ["General Studies", "Exam Strategy", "General Doubt"];
  }


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final courseProvider = context.read<CourseProvider>();
      final batches = courseProvider.myEnrolledBatches;
      if (batches.isNotEmpty) {
        final firstBatch = batches.first;
        final course = courseProvider.courses.cast<CourseModel?>().firstWhere(
              (c) => c?.id == firstBatch.courseId,
              orElse: () => null,
            );
        final initialSubjects = (course != null && course.subjects.isNotEmpty)
            ? course.subjects
            : [course?.category ?? "General Studies", "General Doubt"];

        setState(() {
          _selectedBatchId = firstBatch.id;
          _selectedSubject = initialSubjects.first;
        });
      }
    });
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  void _submitDoubt() {
    if (_formKey.currentState!.validate()) {
      if (_selectedBatchId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("You must select a batch to ask a doubt."),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      final auth = context.read<AuthProvider>();
      final doubtProvider = context.read<DoubtProvider>();

      doubtProvider.askNewDoubt(
        studentId: auth.currentUser.id,
        batchId: _selectedBatchId!,
        studentName: auth.currentUser.name,
        subject: _selectedSubject,
        questionText: _questionController.text.trim(),
      );

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Doubt submitted! Madhurendra Sir & faculty will answer shortly.",
          ),
          backgroundColor: AppColors.emerald,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final courseProvider = context.watch<CourseProvider>();
    final batches = courseProvider.myEnrolledBatches;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (batches.isEmpty) {
      return Dialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 36,
                  color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Enrollment Required",
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "You must be enrolled in an active course batch to submit academic inquiries to faculty.",
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              ModernButton(
                text: "Close",
                onPressed: () => Navigator.pop(context),
                variant: ButtonVariant.secondary,
              ),
            ],
          ),
        ),
      );
    }

    return Dialog(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.primary.withValues(alpha: 0.18)
                              : AppColors.saffronMuted,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.help_outline_rounded,
                          size: 18,
                          color: isDark ? AppColors.primaryLight : AppColors.saffronDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Ask a Doubt",
                        style: AppTypography.titleMedium.copyWith(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AppColors.textMuted,
                    ),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Batch Dropdown
              Text(
                "SELECT BATCH",
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _selectedBatchId,
                dropdownColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurfaceCard : AppColors.warmIvory,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                  ),
                ),
                items: batches.map((b) {
                  return DropdownMenuItem<String>(
                    value: b.id,
                    child: Text(
                      b.name,
                      style: AppTypography.bodyMedium.copyWith(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedBatchId = val;
                    final newSubjects = _getSubjectsForSelectedBatch(courseProvider);
                    if (!newSubjects.contains(_selectedSubject)) {
                      _selectedSubject = newSubjects.isNotEmpty ? newSubjects.first : "General Studies";
                    }
                  });
                },
              ),
              const SizedBox(height: 14),

              // Subject Dropdown
              Builder(
                builder: (context) {
                  final availableSubjects = _getSubjectsForSelectedBatch(courseProvider);
                  final activeSubject = availableSubjects.contains(_selectedSubject)
                      ? _selectedSubject
                      : (availableSubjects.isNotEmpty ? availableSubjects.first : "General Studies");

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "SUBJECT",
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: activeSubject,
                        dropdownColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: isDark ? AppColors.darkSurfaceCard : AppColors.warmIvory,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                          ),
                        ),
                        items: availableSubjects.map((sub) {
                          return DropdownMenuItem<String>(
                            value: sub,
                            child: Text(
                              sub,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: AppTypography.bodyMedium.copyWith(
                                color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedSubject = val;
                            });
                          }
                        },
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),

              // Question Text Field
              Text(
                "YOUR QUESTION",
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _questionController,
                maxLines: 4,
                style: AppTypography.bodyMedium.copyWith(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                ),
                decoration: InputDecoration(
                  hintText:
                      "Type your academic question clearly. Include question number or chapter reference if applicable...",
                  hintStyle: AppTypography.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurfaceCard : AppColors.warmIvory,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return "Please enter your question.";
                  }
                  if (val.trim().length < 10) {
                    return "Question must be at least 10 characters.";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ModernButton(
                      text: "Cancel",
                      variant: ButtonVariant.secondary,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ModernButton(
                      text: "Submit Question",
                      variant: ButtonVariant.primary,
                      onPressed: _submitDoubt,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
