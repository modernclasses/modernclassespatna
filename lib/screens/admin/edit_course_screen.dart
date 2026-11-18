import '../../core/widgets/stepped_price_input_field.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/batch_timing_helper.dart';
import '../../core/widgets/batch_timing_picker_dialog.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/image_upload_picker_widget.dart';
import '../../core/widgets/modern_card.dart';
import '../../core/utils/formatters.dart';
import '../../features/courses/data/models/course_model.dart';
import '../../features/courses/data/models/batch_model.dart';
import '../../features/courses/logic/course_provider.dart';

/// Single-page Comprehensive Course Editor.
class EditCourseScreen extends StatefulWidget {
  final CourseModel course;
  final void Function(BuildContext context, BatchModel batch, String courseTitle)? onEditBatch;
  final void Function(BuildContext context, String courseId, String courseTitle, double coursePrice)? onAddBatch;
  final void Function(BuildContext context, BatchModel batch, String courseTitle)? onDeleteBatch;

  const EditCourseScreen({
    super.key,
    required this.course,
    this.onEditBatch,
    this.onAddBatch,
    this.onDeleteBatch,
  });

  @override
  State<EditCourseScreen> createState() => _EditCourseScreenState();
}

class _EditCourseScreenState extends State<EditCourseScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _highlightsCtrl;
  late final TextEditingController _descCtrl;

  late final TextEditingController _priceCtrl;
  late final TextEditingController _originalPriceCtrl;

  late final TextEditingController _coverImageUrlCtrl;
  late final TextEditingController _totalNotesCtrl;
  final TextEditingController _customSubjectCtrl = TextEditingController();
  late List<String> _subjects;

  late bool _isFeatured;
  late bool _isCrashCourse;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.course;
    _titleCtrl = TextEditingController(text: c.title);
    _categoryCtrl = TextEditingController(text: c.category);
    _highlightsCtrl = TextEditingController(text: c.highlights.join(", "));
    _descCtrl = TextEditingController(text: c.description);

    _priceCtrl = TextEditingController(text: c.price > 0 ? c.price.toInt().toString() : "0");
    _originalPriceCtrl = TextEditingController(
      text: c.originalPrice > 0 ? c.originalPrice.toInt().toString() : "0",
    );

    _coverImageUrlCtrl = TextEditingController(text: c.coverImageUrl);
    _totalNotesCtrl = TextEditingController(text: c.totalNotes.toString());
    _subjects = List<String>.from(c.subjects);

    _isFeatured = c.isFeatured;
    _isCrashCourse = c.isCrashCourse;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _categoryCtrl.dispose();
    _highlightsCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _originalPriceCtrl.dispose();
    _coverImageUrlCtrl.dispose();
    _totalNotesCtrl.dispose();
    _customSubjectCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
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

    final priceInt = int.tryParse(_priceCtrl.text.replaceAll('₹', '').trim());
    if (priceInt == null || priceInt < 9 || priceInt > 3199 || (priceInt - 9) % 10 != 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Course price must be in steps of 10 ending in 9 (₹9 to ₹3199)"),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    final price = priceInt.toDouble();

    final origStr = _originalPriceCtrl.text.replaceAll('₹', '').trim();
    double? originalPrice;
    if (origStr.isNotEmpty) {
      final origInt = int.tryParse(origStr);
      if (origInt == null || origInt < 9 || origInt > 3199 || (origInt - 9) % 10 != 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Original MRP must be in steps of 10 ending in 9 (₹9 to ₹3199)"),
            backgroundColor: AppTheme.error,
          ),
        );
        return;
      }
      originalPrice = origInt.toDouble();
    }
    originalPrice ??= price;

    final highlights = _highlightsCtrl.text
        .split(",")
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final updatedCourse = widget.course.copyWith(
      title: title,
      category: _categoryCtrl.text.trim().isNotEmpty ? _categoryCtrl.text.trim() : "General",
      description: _descCtrl.text.trim(),
      highlights: highlights.isNotEmpty
          ? highlights
          : [
              "Live interactive video lectures",
              "Complete digital PDF study material",
              "Weekly mock test series with ranks",
            ],
      subjects: _subjects,
      price: price,
      originalPrice: originalPrice,
      coverImageUrl: _coverImageUrlCtrl.text.trim(),
      totalHours: widget.course.totalHours,
      totalLessons: widget.course.totalLessons,
      totalTests: widget.course.totalTests,
      totalNotes: int.tryParse(_totalNotesCtrl.text.trim()) ?? widget.course.totalNotes,
      isFeatured: _isFeatured,
      isCrashCourse: _isCrashCourse,
    );

    setState(() => _isSaving = true);

    try {
      await context.read<CourseProvider>().updateCourse(updatedCourse);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✅ Course \"${updatedCourse.title}\" updated successfully!"),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to save course changes: $e"),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: AppTypography.subtitle1.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final courseProvider = context.watch<CourseProvider>();
    final batches = courseProvider.getBatchesForCourse(widget.course.id);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.surface,
      appBar: AppBar(
        title: Text("Edit Course: ${widget.course.title}"),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.deepInk,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // -------------------------------------------------------------
              // 1. Basic Information
              // -------------------------------------------------------------
              ModernCard(
                padding: const EdgeInsets.all(16),
                backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader("Basic Information", Icons.info_outline, isDark),
                    TextField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(
                        labelText: "Course Title *",
                        hintText: "e.g. BPSC 72nd Target Batch",
                      ),
                      enabled: !_isSaving,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _categoryCtrl,
                      decoration: const InputDecoration(
                        labelText: "Category *",
                        hintText: "e.g. BPSC / SSC / State Exams",
                      ),
                      enabled: !_isSaving,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _highlightsCtrl,
                      decoration: const InputDecoration(
                        labelText: "Course Highlights (comma separated)",
                        hintText: "Live classes, Notes, Mock Tests",
                      ),
                      enabled: !_isSaving,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: "Full Course Description",
                        hintText: "Enter comprehensive course curriculum details...",
                      ),
                      enabled: !_isSaving,
                    ),
                    const SizedBox(height: 14),
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
                      "Specify the subjects covered in this course (used for student doubts and academic organization):",
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
                            enabled: !_isSaving,
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
                          onPressed: _isSaving
                              ? null
                              : () {
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
                            onDeleted: _isSaving
                                ? null
                                : () {
                                    setState(() {
                                      _subjects.remove(sub);
                                    });
                                  },
                            backgroundColor: isDark ? AppColors.darkSurface : AppColors.warmIvory,
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
                          onPressed: _isSaving
                              ? null
                              : () {
                                  setState(() {
                                    _subjects.add(preset);
                                  });
                                },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // -------------------------------------------------------------
              // 2. Pricing Section
              // -------------------------------------------------------------
              ModernCard(
                padding: const EdgeInsets.all(16),
                backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader("Pricing & Offers", Icons.currency_rupee, isDark),
                    SteppedPriceInputField(
                      controller: _priceCtrl,
                      labelText: "Selling Price (₹) *",
                      hintText: "e.g. 1499",
                      isCoursePrice: true,
                      minPrice: 9,
                      maxPrice: 3199,
                      enabled: !_isSaving,
                    ),
                    const SizedBox(height: 10),
                    SteppedPriceInputField(
                      controller: _originalPriceCtrl,
                      labelText: "Original MRP (₹)",
                      hintText: "e.g. 2999",
                      isCoursePrice: true,
                      isRequired: false,
                      minPrice: 9,
                      maxPrice: 3199,
                      enabled: !_isSaving,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Discount percentage will be automatically calculated for students.",
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // -------------------------------------------------------------
              // 3. Course Settings & Media
              // -------------------------------------------------------------
              ModernCard(
                padding: const EdgeInsets.all(16),
                backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader("Course Settings & Media", Icons.tune, isDark),
                    ImageUploadPickerWidget(
                      controller: _coverImageUrlCtrl,
                      labelText: "Cover Image / Thumbnail (Course Cover Page)",
                      hintText: "https://.../thumbnail.jpg",
                      helperText: "Cover page & cards",
                      enabled: !_isSaving,
                      onUpload: (fileName, bytes) async {
                        final courseProvider = context.read<CourseProvider>();
                        return await courseProvider.uploadCourseCoverImage(
                          fileName: fileName,
                          fileBytes: bytes,
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.warmIvory,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome_rounded, color: AppColors.saffronDark, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Curriculum Tracking (Auto-Calculated)",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  "${widget.course.totalLessons} Lessons • ${widget.course.totalHours} Hours • ${widget.course.totalTests} Tests Tracked",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  "Automatically tracked and updated as faculty upload lectures and publish tests.",
                                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Material(
                      color: Colors.transparent,
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("Featured Course on Store", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: const Text("Highlighted on student home and store banners", style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                            value: _isFeatured,
                            activeThumbColor: AppTheme.primary,
                            onChanged: _isSaving ? null : (v) => setState(() => _isFeatured = v),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("Crash Course Badge", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: const Text("Tags this course as an intensive fast-track program", style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                            value: _isCrashCourse,
                            activeThumbColor: AppTheme.primary,
                            onChanged: _isSaving ? null : (v) => setState(() => _isCrashCourse = v),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // -------------------------------------------------------------
              // 4. Class Timings & Batches Management
              // -------------------------------------------------------------
              ModernCard(
                padding: const EdgeInsets.all(16),
                backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 360;
                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.access_time_filled, size: 20, color: AppTheme.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Class Timings & Batches (${batches.length})",
                                      style: AppTypography.subtitle1.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDark ? AppColors.primary : AppColors.deepInk,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    minimumSize: const Size(0, 32),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  onPressed: () async {
                                    final existingTimings = batches.map((b) => b.timing).toList();
                                    final picked = await BatchTimingPickerDialog.show(
                                      context,
                                      initialTiming: "04:00 PM - 06:00 PM (Mon-Sat)",
                                      existingTimings: existingTimings,
                                    );
                                    if (picked == null || !context.mounted) return;

                                    final courseProvider = context.read<CourseProvider>();
                                    final overlap = BatchTimingHelper.findOverlappingTiming(picked, existingTimings);
                                    if (overlap != null) {
                                      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                                        SnackBar(
                                          content: Text("Timing overlaps with existing course slot: $overlap. Two slots cannot have overlapping class hours."),
                                          backgroundColor: AppTheme.error,
                                        ),
                                      );
                                      return;
                                    }

                                    final slotNumber = batches.length + 1;
                                    final newBatch = BatchModel(
                                      id: "",
                                      courseId: widget.course.id,
                                      name: "${widget.course.title} - Batch $slotNumber",
                                      timing: picked,
                                      startDate: DateTime.now(),
                                      endDate: DateTime.now().add(const Duration(days: 90)),
                                      teacherName: widget.course.teacherName.isNotEmpty ? widget.course.teacherName : "Faculty Member",
                                      teacherId: widget.course.teacherId,
                                      totalStudents: 0,
                                      maxStudents: 500,
                                      batchPrice: widget.course.price,
                                      medium: "Bilingual (Hindi + English)",
                                    );

                                    await courseProvider.addBatch(newBatch);
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                                      SnackBar(
                                        content: Text("✅ Added schedule: $picked"),
                                        backgroundColor: AppTheme.success,
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.add_rounded, size: 16),
                                  label: const Text("Add Timing Slot", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ],
                          );
                        }
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time_filled, size: 20, color: AppTheme.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Class Timings & Batches (${batches.length})",
                                      style: AppTypography.subtitle1.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? AppColors.primary : AppColors.deepInk,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: const Size(0, 32),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              onPressed: () async {
                                final existingTimings = batches.map((b) => b.timing).toList();
                                final picked = await BatchTimingPickerDialog.show(
                                  context,
                                  initialTiming: "04:00 PM - 06:00 PM (Mon-Sat)",
                                  existingTimings: existingTimings,
                                );
                                if (picked == null || !context.mounted) return;

                                final courseProvider = context.read<CourseProvider>();
                                final overlap = BatchTimingHelper.findOverlappingTiming(picked, existingTimings);
                                if (overlap != null) {
                                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                                    SnackBar(
                                      content: Text("Timing overlaps with existing course slot: $overlap. Two slots cannot have overlapping class hours."),
                                      backgroundColor: AppTheme.error,
                                    ),
                                  );
                                  return;
                                }

                                final slotNumber = batches.length + 1;
                                final newBatch = BatchModel(
                                  id: "",
                                  courseId: widget.course.id,
                                  name: "${widget.course.title} - Batch $slotNumber",
                                  timing: picked,
                                  startDate: DateTime.now(),
                                  endDate: DateTime.now().add(const Duration(days: 90)),
                                  teacherName: widget.course.teacherName.isNotEmpty ? widget.course.teacherName : "Faculty Member",
                                  teacherId: widget.course.teacherId,
                                  totalStudents: 0,
                                  maxStudents: 500,
                                  batchPrice: widget.course.price,
                                  medium: "Bilingual (Hindi + English)",
                                );

                                await courseProvider.addBatch(newBatch);
                                if (!context.mounted) return;
                                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                                  SnackBar(
                                    content: Text("✅ Added schedule: $picked"),
                                    backgroundColor: AppTheme.success,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text("Add Schedule / Timing", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    if (batches.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : AppColors.warmIvory,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text(
                            "No class schedules created yet for this course.\nTap '+ Add Schedule / Timing' above to configure class timings.",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                        ),
                      )
                    else
                      ...batches.map((b) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : AppColors.warmIvory,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      b.name,
                                      style: AppTypography.subtitle2.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.saffronDark),
                                    tooltip: "Edit Timing Slot",
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(4),
                                    onPressed: () {
                                      if (widget.onEditBatch != null) {
                                        widget.onEditBatch!(context, b, widget.course.title);
                                      }
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                    tooltip: "Delete Timing Slot",
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(4),
                                    onPressed: () {
                                      if (widget.onDeleteBatch != null) {
                                        widget.onDeleteBatch!(context, b, widget.course.title);
                                      }
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.schedule, size: 14, color: AppTheme.primary),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      b.timing,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                alignment: WrapAlignment.spaceBetween,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CustomBadge(
                                        text: b.medium,
                                        variant: BadgeVariant.secondary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "${b.totalStudents} Students enrolled",
                                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    Formatters.formatCurrency(b.batchPrice),
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomSheet: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: MediaQuery.of(context).orientation == Orientation.landscape ? 8 : 16,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
          border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border)),
        ),
        child: SizedBox(
          width: double.infinity,
          height: MediaQuery.of(context).orientation == Orientation.landscape ? 40 : 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isSaving ? null : _handleSave,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    "Save Course Changes",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
    );
  }
}
