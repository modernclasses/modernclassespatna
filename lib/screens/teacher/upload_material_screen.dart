import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/modern_button.dart';
import '../../core/widgets/modern_card.dart';
import '../../models/study_material_model.dart';
import '../../models/notification_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/study_material_provider.dart';
import '../../providers/notification_provider.dart';

class UploadMaterialScreen extends StatefulWidget {
  const UploadMaterialScreen({super.key});

  @override
  State<UploadMaterialScreen> createState() => _UploadMaterialScreenState();
}

class _UploadMaterialScreenState extends State<UploadMaterialScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _chapterController = TextEditingController();
  final List<TextEditingController> _keyTopicControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  String? _selectedCourseId;
  String? _selectedBatchId;
  StudyDocType _selectedType = StudyDocType.pdf;

  Uint8List? _fileBytes;
  String? _fileName;
  int _fileSizeBytes = 0;
  String? _fileLoadError;
  bool _isUploading = false;
  String? _uploadError;

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _chapterController.dispose();
    for (final ctrl in _keyTopicControllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDocumentFile() async {
    setState(() {
      _fileLoadError = null;
    });
    try {
      final pickedFile = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );
      if (pickedFile == null) return;

      final len = await pickedFile.length();
      if (len != null && len > 50 * 1024 * 1024) {
        setState(() {
          _fileLoadError = "Document file is too large (must be under 50 MB).";
        });
        return;
      }

      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _fileName = pickedFile.name;
        _fileBytes = bytes;
        _fileSizeBytes = bytes.length;
        _fileLoadError = null;
        if (_titleController.text.trim().isEmpty) {
          _titleController.text =
              pickedFile.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
        }
      });
    } catch (e) {
      setState(() {
        _fileLoadError = "Error selecting document: $e";
      });
    }
  }

  void _useSampleDocument() {
    final sampleBytes = Uint8List.fromList(
      List<int>.generate(2048, (i) => (i * 17) % 256),
    );
    setState(() {
      _fileName = "handout_${DateTime.now().millisecondsSinceEpoch}.pdf";
      _fileBytes = sampleBytes;
      _fileSizeBytes = sampleBytes.length;
      _fileLoadError = null;
    });
  }

  Future<void> _upload() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fileBytes == null || _fileName == null) {
      setState(() {
        _fileLoadError = "Please select or load a document file first.";
      });
      return;
    }

    final auth = context.read<AuthProvider>();
    final courseProvider = context.read<CourseProvider>();
    final matProvider = context.read<StudyMaterialProvider>();
    final notifProvider = context.read<NotificationProvider>();

    final courses = courseProvider.courses;
    final batches = courseProvider.batches;

    if (courses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No courses available. Please create a course first."),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final course =
        courseProvider.getCourseById(_selectedCourseId ?? courses.first.id) ??
        courses.first;
    final batch = batches.isNotEmpty
        ? (courseProvider.getBatchById(_selectedBatchId ?? batches.first.id) ??
              batches.first)
        : null;

    final List<String> previews = _keyTopicControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (previews.isEmpty) {
      previews.add(
        "Complete lecture notes and summary tables for ${_titleController.text.trim()}.",
      );
    }

    setState(() {
      _isUploading = true;
      _uploadError = null;
    });

    try {
      String storagePath;
      try {
        storagePath = await matProvider.uploadMaterialFile(
          courseId: course.id,
          fileName: _fileName!,
          fileBytes: _fileBytes!,
        );
      } catch (e) {
        if (e.toString().contains("NoSuchBucket") ||
            e.toString().contains("Bucket not found")) {
          throw Exception(
            "Storage bucket 'study-materials' is not provisioned on Supabase. Please contact admin.",
          );
        }
        rethrow;
      }

      final pageCount = (_fileSizeBytes / (40 * 1024)).ceil().clamp(1, 999);
      final sizeMb = (_fileSizeBytes / (1024 * 1024)).toStringAsFixed(1);
      final fileSizeStr = _fileSizeBytes > 1024 * 1024
          ? "$sizeMb MB"
          : "${(_fileSizeBytes / 1024).toStringAsFixed(0)} KB";

      final newMaterial = StudyMaterialModel(
        id: "",
        courseId: course.id,
        batchId:
            batch?.id ??
            (batches.isNotEmpty ? batches.first.id : "all_batches"),
        title: _titleController.text.trim(),
        subject: _subjectController.text.trim(),
        chapter: _chapterController.text.trim(),
        type: _selectedType,
        pageCount: pageCount,
        fileSize: fileSizeStr,
        fileUrl: storagePath,
        previewPages: previews,
        uploadedAt: DateTime.now(),
        uploaderName: auth.currentUser.name.isNotEmpty
            ? auth.currentUser.name
            : "Madhurendra Sir",
      );

      await matProvider.addStudyMaterial(newMaterial);

      await notifProvider.broadcastAnnouncement(
        title: "📚 New Study Material: ${_titleController.text.trim()}",
        message:
            "New notes uploaded for ${course.title} (${_subjectController.text.trim()}). Tap to read and revise.",
        category: NotificationCategory.announcement,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "✨ Study material uploaded and published successfully!",
            ),
            backgroundColor: AppColors.emerald,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadError = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final courseProvider = context.watch<CourseProvider>();
    final courses = courseProvider.courses;
    final batches = courseProvider.batches;

    if (_selectedCourseId != null &&
        !courses.any((c) => c.id == _selectedCourseId)) {
      _selectedCourseId = courses.isNotEmpty ? courses.first.id : null;
    } else {
      _selectedCourseId ??= courses.isNotEmpty ? courses.first.id : null;
    }

    if (_selectedBatchId != null &&
        !batches.any((b) => b.id == _selectedBatchId)) {
      _selectedBatchId = batches.isNotEmpty ? batches.first.id : null;
    } else {
      _selectedBatchId ??= batches.isNotEmpty ? batches.first.id : null;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Upload Study Material / PDF"),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: isDark ? AppColors.darkBorder : AppColors.border,
            height: 1,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Course & Batch target
              const Text(
                "Assign to Course & Batch",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _selectedCourseId,
                dropdownColor: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkSurface
                    : AppColors.surface,
                decoration: InputDecoration(
                  labelText: "Course",
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkSurface
                      : AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkBorder
                          : AppColors.border,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkBorder
                          : AppColors.border,
                    ),
                  ),
                ),
                items: courses
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(
                          c.title,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _selectedCourseId = val),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _selectedBatchId,
                dropdownColor: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkSurface
                    : AppColors.surface,
                decoration: InputDecoration(
                  labelText: "Target Batch (Optional)",
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkSurface
                      : AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkBorder
                          : AppColors.border,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkBorder
                          : AppColors.border,
                    ),
                  ),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text(
                      "All Students in Course",
                      style: TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  ...batches.map(
                    (b) => DropdownMenuItem(
                      value: b.id,
                      child: Text(
                        b.name,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ],
                onChanged: (val) => setState(() => _selectedBatchId = val),
              ),
              const SizedBox(height: 20),

              // File Selection Card (Direct FilePicker)
              const Text(
                "Document File (PDF / DOC)",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ModernCard(
                padding: const EdgeInsets.all(16),
                backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: _pickDocumentFile,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _fileName != null
                                ? AppColors.emerald
                                : (isDark ? AppColors.darkBorder : AppColors.border),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _fileName != null
                                  ? Icons.check_circle
                                  : Icons.upload_file_rounded,
                              size: 40,
                              color: _fileName != null
                                  ? AppColors.emerald
                                  : (isDark ? AppColors.primaryLight : AppColors.primaryDark),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _fileName ?? "Tap to Select Document from Device",
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _fileName != null
                                  ? "${(_fileSizeBytes / 1024).toStringAsFixed(1)} KB • Tap to change document"
                                  : "Supported formats: PDF, DOC, DOCX",
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _pickDocumentFile,
                          icon: const Icon(Icons.folder_open, size: 16),
                          label: Text(_fileName != null ? "Change File" : "Browse Files"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? AppColors.primary : AppColors.deepInk,
                            foregroundColor: isDark ? Colors.black : Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                        if (AppConfig.isTestMode)
                          TextButton.icon(
                            onPressed: _useSampleDocument,
                            icon: const Icon(
                              Icons.description_outlined,
                              size: 16,
                              color: AppColors.saffronDark,
                            ),
                            label: const Text(
                              "Use Sample Notes",
                              style: TextStyle(
                                color: AppColors.saffronDark,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (_fileLoadError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _fileLoadError!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Document Details
              Text(
                "DOCUMENT DETAILS",
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: "Document Title *",
                  hintText: "e.g. Modern Bihar History Handwritten Notes",
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? "Title is required"
                    : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _subjectController,
                      decoration: InputDecoration(
                        labelText: "Subject *",
                        hintText: "e.g. History",
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? "Subject is required"
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _chapterController,
                      decoration: InputDecoration(
                        labelText: "Chapter / Topic *",
                        hintText: "e.g. Champaran Satyagraha",
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? "Chapter is required"
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Format selector
              Text(
                "DOCUMENT TYPE",
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<StudyDocType>(
                  segments: const [
                    ButtonSegment(
                      value: StudyDocType.pdf,
                      label: Text("PDF Handout"),
                    ),
                    ButtonSegment(
                      value: StudyDocType.document,
                      label: Text("Word Document"),
                    ),
                    ButtonSegment(
                      value: StudyDocType.presentation,
                      label: Text("Presentation"),
                    ),
                  ],
                  selected: {_selectedType},
                  onSelectionChanged: (set) =>
                      setState(() => _selectedType = set.first),
                ),
              ),
              const SizedBox(height: 16),

              // Syllabus Preview Points
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "KEY SYLLABUS TOPICS COVERED",
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    ),
                    icon: const Icon(Icons.add_circle_outline, size: 14, color: AppColors.saffronDark),
                    label: const Text(
                      "+ Add Topic",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.saffronDark,
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _keyTopicControllers.add(TextEditingController());
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ..._keyTopicControllers.asMap().entries.map((entry) {
                final index = entry.key;
                final controller = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: controller,
                          decoration: InputDecoration(
                            labelText: "Key Topic ${index + 1} (Optional)",
                            hintText: index == 0
                                ? "e.g. Detailed timeline from 1917 to 1942"
                                : index == 1
                                    ? "e.g. Model answers with diagrams and flowcharts"
                                    : "e.g. Important formulas, summary notes & practice MCQs",
                            filled: true,
                            fillColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                      ),
                      if (_keyTopicControllers.length > 1) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: AppColors.error, size: 20),
                          tooltip: "Remove topic",
                          onPressed: () {
                            setState(() {
                              controller.dispose();
                              _keyTopicControllers.removeAt(index);
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),

              if (_uploadError != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.errorBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _uploadError!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              ModernButton(
                text: _isUploading
                    ? "Uploading Document..."
                    : "Upload & Publish Material",
                width: double.infinity,
                icon: Icons.cloud_upload_outlined,
                isLoading: _isUploading,
                variant: ButtonVariant.primary,
                onPressed: _isUploading ? null : _upload,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
