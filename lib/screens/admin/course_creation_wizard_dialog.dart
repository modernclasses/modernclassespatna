import '../../core/widgets/stepped_price_input_field.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/batch_timing_helper.dart';
import '../../core/widgets/batch_timing_picker_dialog.dart';
import '../../core/widgets/image_upload_picker_widget.dart';
import '../../core/widgets/multi_teacher_selector.dart';
import '../../features/courses/data/models/batch_model.dart';
import '../../features/courses/data/models/course_model.dart';
import '../../features/courses/logic/course_provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';

/// Helper model for a timing slot in the wizard before database creation.
class WizardTimingSlot {
  String name;
  String timing;
  List<String> teacherIds;
  int maxStudents;
  double? batchPrice;

  WizardTimingSlot({
    required this.name,
    required this.timing,
    List<String>? teacherIds,
    this.maxStudents = 500,
    this.batchPrice,
  }) : teacherIds = teacherIds ?? [];
}

/// 2-Step Course Creation Wizard Dialog.
class CourseCreationWizardDialog extends StatefulWidget {
  const CourseCreationWizardDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CourseCreationWizardDialog(),
    );
  }

  @override
  State<CourseCreationWizardDialog> createState() =>
      _CourseCreationWizardDialogState();
}

class _CourseCreationWizardDialogState
    extends State<CourseCreationWizardDialog> {
  int _currentStep = 1;
  bool _isSubmitting = false;

  // Step 1 Controllers
  final _titleCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController(text: "BPSC");
  final _detailCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  // Step 2 Controllers
  final _feeCtrl = TextEditingController();
  final _offerPriceCtrl = TextEditingController();
  final _coverImageCtrl = TextEditingController();
  final _customSubjectCtrl = TextEditingController();
  final List<String> _subjects = [];
  bool _isFeatured = true;
  bool _isCrashCourse = false;

  // Initial Timing Slots
  late List<WizardTimingSlot> _slots;

  // Teachers for multi-teacher assignment
  List<UserModel> _allTeachers = [];
  bool _isLoadingTeachers = true;

  @override
  void initState() {
    super.initState();
    _slots = [
      WizardTimingSlot(
        name: "Morning Slot 1",
        timing: "08:00 AM - 10:00 AM (Mon-Sat)",
        teacherIds: [],
        maxStudents: 500,
      ),
    ];
    _loadTeachers();
  }

  Future<void> _loadTeachers() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final profiles = await authProvider.getAllProfiles();
      if (mounted) {
        setState(() {
          _allTeachers =
              profiles.where((u) => u.role == UserRole.teacher).toList();
          _isLoadingTeachers = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingTeachers = false);
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _categoryCtrl.dispose();
    _detailCtrl.dispose();
    _descCtrl.dispose();
    _feeCtrl.dispose();
    _offerPriceCtrl.dispose();
    _coverImageCtrl.dispose();
    _customSubjectCtrl.dispose();
    super.dispose();
  }

  void _goToStep2() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Course title is required"),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    final category = _categoryCtrl.text.trim();
    if (category.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Course category is required"),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    // Auto-update slot 1 name if default
    if (_slots.isNotEmpty && _slots[0].name == "Morning Slot 1") {
      _slots[0].name = "$title - Slot 1";
    }

    setState(() => _currentStep = 2);
  }

  void _goToStep1() {
    setState(() => _currentStep = 1);
  }

  Future<void> _handleCreateCourse() async {
    final feeInt = int.tryParse(_feeCtrl.text.replaceAll('₹', '').trim());
    if (feeInt == null || feeInt < 9 || feeInt > 3199 || (feeInt - 9) % 10 != 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Course Fee must be in steps of 10 ending in 9 (₹9 to ₹3199)"),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    final fee = feeInt.toDouble();

    if (_slots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("At least one class timing slot is required"),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    for (int i = 0; i < _slots.length; i++) {
      if (_slots[i].timing.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Timing schedule for Slot ${i + 1} cannot be empty"),
            backgroundColor: AppTheme.error,
          ),
        );
        return;
      }
    }

    // Check for duplicate timings within the wizard slots
    final timingList = _slots.map((s) => s.timing.trim()).toList();
    for (int i = 0; i < timingList.length; i++) {
      for (int j = i + 1; j < timingList.length; j++) {
        if (BatchTimingHelper.isDuplicateTiming(timingList[i], [timingList[j]])) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Duplicate timing detected: \"${timingList[i]}\" is assigned to multiple slots."),
              backgroundColor: AppTheme.error,
            ),
          );
          return;
        }
      }
    }

    final offerStr = _offerPriceCtrl.text.replaceAll('₹', '').trim();
    double? offerPrice;
    if (offerStr.isNotEmpty) {
      final opInt = int.tryParse(offerStr);
      if (opInt == null || opInt < 9 || opInt > 3199 || (opInt - 9) % 10 != 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Offer Price must be in steps of 10 ending in 9 (₹9 to ₹3199)"),
            backgroundColor: AppTheme.error,
          ),
        );
        return;
      }
      offerPrice = opInt.toDouble();
    }
    final finalPrice = (offerPrice != null && offerPrice > 0) ? offerPrice : fee;
    final finalOriginalPrice = fee;

    List<String> highlights = _detailCtrl.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (highlights.isEmpty) {
      highlights = const [
        "Live interactive video lectures",
        "Complete digital PDF study material",
        "Weekly mock test series with ranks",
      ];
    }

    final title = _titleCtrl.text.trim();
    final newCourse = CourseModel(
      id: "", // Generated by DB
      title: title,
      category: _categoryCtrl.text.trim(),
      description: _descCtrl.text.trim().isNotEmpty
          ? _descCtrl.text.trim()
          : "High-impact comprehensive course for competitive candidates.",
      coverImageUrl: _coverImageCtrl.text.trim(),
      price: finalPrice,
      originalPrice: finalOriginalPrice,
      teacherName: "Faculty Team",
      teacherId: "",
      totalLessons: 0, // Automatically tracked by the app from uploaded lectures
      totalHours: 0, // Automatically tracked by the app
      totalTests: 0,
      totalNotes: 0,
      highlights: highlights,
      subjects: _subjects,
      isFeatured: _isFeatured,
      isCrashCourse: _isCrashCourse,
    );

    final List<BatchModel> initialBatches = [];
    final Map<int, List<String>> batchTeacherIds = {};

    for (int i = 0; i < _slots.length; i++) {
      final slot = _slots[i];
      final teacherNames = slot.teacherIds
          .map((id) => _allTeachers.firstWhere(
                (t) => t.id == id,
                orElse: () => UserModel(
                  id: id,
                  email: '',
                  phone: '',
                  name: 'Faculty',
                  role: UserRole.teacher,
                ),
              ).name)
          .join(', ');

      initialBatches.add(
        BatchModel(
          id: "",
          courseId: "",
          name: slot.name.trim().isNotEmpty ? slot.name.trim() : "$title - Slot ${i + 1}",
          timing: slot.timing.trim(),
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 90)),
          teacherName: teacherNames.isNotEmpty ? teacherNames : "Faculty Member",
          teacherId: slot.teacherIds.isNotEmpty ? slot.teacherIds.first : "",
          totalStudents: 0,
          maxStudents: slot.maxStudents,
          batchPrice: slot.batchPrice ?? finalPrice,
          medium: "Bilingual (Hindi + English)",
          teacherIds: slot.teacherIds,
        ),
      );
      batchTeacherIds[i] = slot.teacherIds;
    }

    setState(() => _isSubmitting = true);

    try {
      final courseProvider = context.read<CourseProvider>();
      await courseProvider.addCourse(
        newCourse,
        initialBatches: initialBatches,
        batchTeacherIds: batchTeacherIds,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ Course \"$title\" created with ${_slots.length} timing slot(s)!"),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to create course: $e"),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final isShortHeight = mediaQuery.size.height < 500;
    final isNarrow = mediaQuery.size.width < 380;
    final useCompactLayout = isLandscape || isShortHeight || isNarrow;

    return Dialog(
      backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 8 : (isLandscape ? 24 : 16),
        vertical: useCompactLayout ? 6 : 20,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: useCompactLayout ? double.infinity : 720,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with Step Indicator
            _buildHeader(isDark, useCompactLayout),
            const Divider(height: 1),

            // Wizard Body
            Flexible(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.all(useCompactLayout ? 14 : 20),
                child: _currentStep == 1
                    ? _buildStep1(isDark, useCompactLayout)
                    : _buildStep2(isDark, useCompactLayout),
              ),
            ),

            const Divider(height: 1),
            // Footer Navigation Buttons
            _buildFooter(isDark, useCompactLayout),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, bool isCompact) {
    if (isCompact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.school, color: AppColors.saffronDark, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentStep == 1
                        ? "Create Course — Step 1: Basic Information"
                        : "Create Course — Step 2: Course Setup & Timings",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.saffronMuted,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "Step $_currentStep of 2",
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.saffronDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: _currentStep == 2
                          ? AppColors.primary
                          : (isDark ? AppColors.darkBorder : AppColors.border),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.saffronMuted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.school, color: AppColors.saffronDark, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentStep == 1
                          ? "Create Course — Step 1: Basic Information"
                          : "Create Course — Step 2: Course Setup & Timings",
                      style: AppTypography.subtitle1.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _currentStep == 1
                          ? "Enter fundamental course details and syllabus overview"
                          : "Configure pricing, settings, and schedule slots with assigned faculty",
                      style: AppTypography.caption.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Progress Bars / Stepper Pills
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: _currentStep == 2 ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.border),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep1(bool isDark, bool isCompact) {
    final vSpace = isCompact ? 10.0 : 16.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _titleCtrl,
          scrollPadding: const EdgeInsets.only(bottom: 80),
          decoration: const InputDecoration(
            labelText: "Course Name *",
            hintText: "e.g. BPSC 72nd Target Prelims Crash Course",
            prefixIcon: Icon(Icons.title, size: 20),
          ),
          enabled: !_isSubmitting,
        ),
        SizedBox(height: vSpace),
        TextField(
          controller: _categoryCtrl,
          scrollPadding: const EdgeInsets.only(bottom: 80),
          decoration: const InputDecoration(
            labelText: "Category *",
            hintText: "e.g. BPSC, SSC, UPSC, Teaching",
            prefixIcon: Icon(Icons.category_outlined, size: 20),
          ),
          enabled: !_isSubmitting,
        ),
        SizedBox(height: vSpace),
        TextField(
          controller: _detailCtrl,
          scrollPadding: const EdgeInsets.only(bottom: 80),
          maxLines: isCompact ? 2 : 3,
          decoration: const InputDecoration(
            labelText: "Detail / Highlights",
            hintText: "Key course features (enter each highlight on a new line):\n• Live interactive video lectures\n• Complete PDF notes\n• Weekly mock tests",
            alignLabelWithHint: true,
          ),
          enabled: !_isSubmitting,
        ),
        SizedBox(height: vSpace),
        TextField(
          controller: _descCtrl,
          scrollPadding: const EdgeInsets.only(bottom: 80),
          maxLines: isCompact ? 2 : 4,
          decoration: const InputDecoration(
            labelText: "Description",
            hintText: "Comprehensive overview of the course syllabus, target examination, and benefits for students.",
            alignLabelWithHint: true,
          ),
          enabled: !_isSubmitting,
        ),
        SizedBox(height: vSpace),

        // Course Subjects Configuration
        Text(
          "Course Subjects",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
          ),
        ),
        const SizedBox(height: 3),
        const Text(
          "Add the academic subjects in this course (used for student doubts and curriculum organization):",
          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customSubjectCtrl,
                decoration: const InputDecoration(
                  hintText: "Add subject (e.g. History, Polity)",
                  isDense: true,
                  prefixIcon: Icon(Icons.menu_book_rounded, size: 18),
                ),
                enabled: !_isSubmitting,
                onSubmitted: (val) {
                  final trimmed = val.trim();
                  if (trimmed.isNotEmpty && !_subjects.contains(trimmed)) {
                    setState(() {
                      _subjects.add(trimmed);
                      _customSubjectCtrl.clear();
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepInk,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final trimmed = _customSubjectCtrl.text.trim();
                if (trimmed.isNotEmpty && !_subjects.contains(trimmed)) {
                  setState(() {
                    _subjects.add(trimmed);
                    _customSubjectCtrl.clear();
                  });
                }
              },
              child: const Text("Add"),
            ),
          ],
        ),
        if (_subjects.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _subjects.map((sub) {
              return Chip(
                label: Text(sub, style: const TextStyle(fontSize: 12)),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () {
                  setState(() {
                    _subjects.remove(sub);
                  });
                },
                backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.warmIvory,
                side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            "History",
            "Geography",
            "Polity",
            "Economy",
            "General Science",
            "Current Affairs",
            "Mathematics",
            "Reasoning",
            "Bihar Special",
          ].where((s) => !_subjects.contains(s)).map((preset) {
            return ActionChip(
              avatar: const Icon(Icons.add, size: 14, color: AppColors.saffronDark),
              label: Text(preset, style: const TextStyle(fontSize: 11)),
              backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
              onPressed: () {
                setState(() {
                  _subjects.add(preset);
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStep2(bool isDark, bool isCompact) {
    final vSpace = isCompact ? 8.0 : 14.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pricing Section
        Text(
          "Course Pricing",
          style: AppTypography.subtitle2.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SteppedPriceInputField(
          controller: _feeCtrl,
          scrollPadding: const EdgeInsets.only(bottom: 80),
          labelText: "Course Fee (₹) *",
          hintText: "e.g. 2999",
          isCoursePrice: true,
          minPrice: 9,
          maxPrice: 3199,
          enabled: !_isSubmitting,
        ),
        const SizedBox(height: 10),
        SteppedPriceInputField(
          controller: _offerPriceCtrl,
          scrollPadding: const EdgeInsets.only(bottom: 80),
          labelText: "Offer Price (₹, Optional)",
          hintText: "e.g. 1499",
          isCoursePrice: true,
          isRequired: false,
          minPrice: 9,
          maxPrice: 3199,
          enabled: !_isSubmitting,
        ),
        const SizedBox(height: 4),
        const Text(
          "If Offer Price is specified, students enroll at the Offer Price while the regular fee is shown as original price.",
          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
        ),
        SizedBox(height: vSpace),

        // Settings & Media Section
        Text(
          "Course Settings & Media",
          style: AppTypography.subtitle2.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ImageUploadPickerWidget(
          controller: _coverImageCtrl,
          labelText: "Course Cover Image / Thumbnail (Optional)",
          hintText: "https://example.com/course-thumbnail.png",
          helperText: "Cover page & cards",
          isCompact: isCompact,
          enabled: !_isSubmitting,
          onUpload: (fileName, bytes) async {
            final courseProvider = context.read<CourseProvider>();
            return await courseProvider.uploadCourseCoverImage(
              fileName: fileName,
              fileBytes: bytes,
            );
          },
        ),
        SizedBox(height: isCompact ? 8 : 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.warmIvory,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppColors.saffronDark, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Curriculum Tracking: Automated",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      "Total lessons and hours will be tracked and updated automatically as teachers upload or record lectures.",
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: isCompact,
                title: const Text("Featured Course", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                value: _isFeatured,
                activeThumbColor: AppTheme.primary,
                onChanged: _isSubmitting ? null : (v) => setState(() => _isFeatured = v),
              ),
            ),
            Expanded(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: isCompact,
                title: const Text("Crash Course", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                value: _isCrashCourse,
                activeThumbColor: AppTheme.primary,
                onChanged: _isSubmitting ? null : (v) => setState(() => _isCrashCourse = v),
              ),
            ),
          ],
        ),
        SizedBox(height: vSpace),

        // Class Timing Slots & Multi-Teacher Assignment
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Course Schedules & Timings (${_slots.length})",
                    style: AppTypography.subtitle2.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    "Configure multiple class schedules (e.g. 12:00 PM - 2:00 PM, 4:00 PM - 6:00 PM)",
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 10, vertical: isCompact ? 4 : 6),
                side: const BorderSide(color: AppTheme.primary),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: _isSubmitting
                  ? null
                  : () async {
                      final existingTimings = _slots.map((s) => s.timing).toList();
                      final picked = await BatchTimingPickerDialog.show(
                        context,
                        initialTiming: "04:00 PM - 06:00 PM (Mon-Sat)",
                        existingTimings: existingTimings,
                      );
                      if (!mounted) return;
                      if (picked != null) {
                        final overlap = BatchTimingHelper.findOverlappingTiming(picked, existingTimings);
                        if (overlap != null) {
                          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                            SnackBar(
                              content: Text("Timing overlaps with existing slot: $overlap. Two slots cannot have overlapping class hours."),
                              backgroundColor: AppTheme.error,
                            ),
                          );
                          return;
                        }
                        setState(() {
                          final slotNumber = _slots.length + 1;
                          final courseName = _titleCtrl.text.trim();
                          _slots.add(
                            WizardTimingSlot(
                              name: courseName.isNotEmpty ? "$courseName - Schedule $slotNumber" : "Schedule $slotNumber",
                              timing: picked,
                              teacherIds: [],
                            ),
                          );
                        });
                      }
                    },
              icon: const Icon(Icons.add_alarm, size: 16),
              label: const Text("Add Schedule / Timing", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 10),

        ..._slots.asMap().entries.map((entry) {
          final index = entry.key;
          final slot = entry.value;

          return Container(
            margin: EdgeInsets.only(bottom: isCompact ? 8 : 12),
            padding: EdgeInsets.all(isCompact ? 10 : 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.warmIvory,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.saffronMuted,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "Slot ${index + 1}",
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.saffronDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: slot.name,
                        scrollPadding: const EdgeInsets.only(bottom: 80),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          border: OutlineInputBorder(),
                          labelText: "Slot Name",
                        ),
                        onChanged: (v) => slot.name = v,
                        enabled: !_isSubmitting,
                      ),
                    ),
                    if (_slots.length > 1) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                        tooltip: "Remove Slot",
                        onPressed: _isSubmitting
                            ? null
                            : () => setState(() => _slots.removeAt(index)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),

                // Timing picker row
                InkWell(
                  onTap: _isSubmitting
                      ? null
                      : () async {
                          final otherTimings = _slots
                              .asMap()
                              .entries
                              .where((e) => e.key != index)
                              .map((e) => e.value.timing)
                              .toList();
                          final picked = await BatchTimingPickerDialog.show(
                            context,
                            initialTiming: slot.timing,
                            existingTimings: otherTimings,
                          );
                          if (picked != null && mounted) {
                            final overlap = BatchTimingHelper.findOverlappingTiming(picked, otherTimings);
                            if (overlap != null) {
                              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                                SnackBar(
                                  content: Text("Timing overlaps with existing slot: $overlap. Two slots cannot have overlapping class hours."),
                                  backgroundColor: AppTheme.error,
                                ),
                              );
                              return;
                            }
                            setState(() => slot.timing = picked);
                          }
                        },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_filled, size: 16, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            slot.timing,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.edit, size: 14, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Multi-Teacher Selector for this Slot
                _isLoadingTeachers
                    ? const SizedBox(
                        height: 24,
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : MultiTeacherSelector(
                        allTeachers: _allTeachers,
                        selectedTeacherIds: slot.teacherIds,
                        enabled: !_isSubmitting,
                        onChanged: (updatedTeacherIds) {
                          setState(() {
                            slot.teacherIds = updatedTeacherIds;
                          });
                        },
                      ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFooter(bool isDark, bool isCompact) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 20,
        vertical: isCompact ? 6 : 12,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep == 1)
            TextButton(
              style: TextButton.styleFrom(
                visualDensity: isCompact ? VisualDensity.compact : null,
                padding: isCompact ? const EdgeInsets.symmetric(horizontal: 10, vertical: 4) : null,
              ),
              onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            )
          else
            OutlinedButton.icon(
              onPressed: _isSubmitting ? null : _goToStep1,
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text("Back"),
              style: OutlinedButton.styleFrom(
                visualDensity: isCompact ? VisualDensity.compact : null,
                padding: isCompact ? const EdgeInsets.symmetric(horizontal: 10, vertical: 4) : null,
              ),
            ),
          const SizedBox(width: 8),
          if (_currentStep == 1)
            Flexible(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black,
                  visualDensity: isCompact ? VisualDensity.compact : null,
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 10 : 20,
                    vertical: isCompact ? 6 : 10,
                  ),
                ),
                onPressed: _goToStep2,
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text(
                  "Next: Course Setup",
                  style: TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
          else
            Flexible(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black,
                  visualDensity: isCompact ? VisualDensity.compact : null,
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 14 : 20,
                    vertical: isCompact ? 6 : 10,
                  ),
                ),
                onPressed: _isSubmitting ? null : _handleCreateCourse,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Text(
                        "Create Course",
                        style: TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
