import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/modern_button.dart';
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
  final TextEditingController _contentPoint1 = TextEditingController();
  final TextEditingController _contentPoint2 = TextEditingController();

  String? _selectedCourseId;
  String? _selectedBatchId;
  StudyDocType _selectedType = StudyDocType.pdf;

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _chapterController.dispose();
    _contentPoint1.dispose();
    _contentPoint2.dispose();
    super.dispose();
  }

  void _upload() {
    if (_formKey.currentState!.validate()) {
      final auth = context.read<AuthProvider>();
      final courseProvider = context.read<CourseProvider>();
      final matProvider = context.read<StudyMaterialProvider>();
      final notifProvider = context.read<NotificationProvider>();

      final course = courseProvider.getCourseById(_selectedCourseId ?? courseProvider.courses.first.id)!;
      final batch = courseProvider.getBatchById(_selectedBatchId ?? courseProvider.batches.first.id)!;

      final List<String> previews = [];
      if (_contentPoint1.text.trim().isNotEmpty) previews.add(_contentPoint1.text.trim());
      if (_contentPoint2.text.trim().isNotEmpty) previews.add(_contentPoint2.text.trim());
      if (previews.isEmpty) {
        previews.add("Complete lecture notes and summary tables for ${_titleController.text.trim()}.");
      }

      final newMat = StudyMaterialModel(
        id: "mat_${DateTime.now().millisecondsSinceEpoch}",
        courseId: course.id,
        batchId: batch.id,
        title: _titleController.text.trim(),
        subject: _subjectController.text.trim(),
        chapter: _chapterController.text.trim(),
        type: _selectedType,
        pageCount: 24,
        fileSize: "3.2 MB",
        fileUrl: "assets/docs/uploaded_material.pdf",
        previewPages: previews,
        uploadedAt: DateTime.now(),
        uploaderName: auth.currentUser.name,
        isSecureWatermarked: true,
      );

      matProvider.addStudyMaterial(newMat);

      // Notify batch
      notifProvider.broadcastAnnouncement(
        title: "📚 New Study Material: ${_titleController.text.trim()}",
        message: "${auth.currentUser.name} uploaded new PDF notes for ${batch.name}.",
        category: NotificationCategory.material,
      );

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✨ Study material uploaded with non-downloadable security!"),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final courseProvider = context.watch<CourseProvider>();
    final courses = courseProvider.courses;
    final batches = courseProvider.batches;

    _selectedCourseId ??= courses.isNotEmpty ? courses.first.id : null;
    _selectedBatchId ??= batches.isNotEmpty ? batches.first.id : null;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Upload Study Material / PDF"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Course & Batch target
              const Text("Assign to Batch", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedCourseId,
                dropdownColor: AppTheme.surfaceLight,
                decoration: const InputDecoration(labelText: "Course"),
                items: courses
                    .map((c) => DropdownMenuItem(value: c.id, child: Text(c.title, style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (val) => setState(() => _selectedCourseId = val),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedBatchId,
                dropdownColor: AppTheme.surfaceLight,
                decoration: const InputDecoration(labelText: "Batch"),
                items: batches
                    .map((b) => DropdownMenuItem(value: b.id, child: Text(b.name, style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (val) => setState(() => _selectedBatchId = val),
              ),
              const SizedBox(height: 20),

              // Material Format
              const Text("Material Format", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: StudyDocType.values.map((type) {
                  final isSelected = _selectedType == type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(type.name.toUpperCase()),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _selectedType = type),
                      backgroundColor: AppTheme.surfaceLight,
                      selectedColor: AppTheme.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.black : AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Document Details
              const Text("Document Details", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: "Document Title",
                  hintText: "e.g. Bihar Special Complete GS Handout - Vol 2",
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? "Please enter title" : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _subjectController,
                      decoration: const InputDecoration(
                        labelText: "Subject",
                        hintText: "e.g. Bihar GK",
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty) ? "Enter subject" : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _chapterController,
                      decoration: const InputDecoration(
                        labelText: "Chapter",
                        hintText: "e.g. Freedom Movement",
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty) ? "Enter chapter" : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Summary Key Points / Highlights
              const Text("Key Concepts / Content Points", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _contentPoint1,
                decoration: const InputDecoration(
                  labelText: "Key Point 1",
                  hintText: "e.g. Summary of 1857 leaders in Jagdishpur and Patna.",
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _contentPoint2,
                decoration: const InputDecoration(
                  labelText: "Key Point 2",
                  hintText: "e.g. Chronological timeline of events and key exam MCQs.",
                ),
              ),
              const SizedBox(height: 24),

              ModernButton(
                text: "Upload & Securely Publish",
                width: double.infinity,
                icon: Icons.cloud_upload_outlined,
                onPressed: _upload,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
